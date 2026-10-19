import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../registration/timetable_screen.dart' show clockProvider;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import '../../training/training_widgets.dart';
import '../accounts/account_dialogs.dart' show failureText;

/// Quá ngưỡng này chưa có bản sao lưu mới thì cảnh báo (design.md 9.0).
const _canhBaoSauGio = 48;

/// `412 MB`, `163 KB`, `980 B` (làm tròn, đơn vị 1024).
String formatBytes(num bytes) {
  if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).round()} MB';
  if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
  return '${bytes.round()} B';
}

/// Sao lưu (ADM-08) — mockup `AD-Web-SaoLuu`. Không có Phục hồi / Tải xuống (làm tay bằng `pg_restore`).
class BackupsScreen extends ConsumerStatefulWidget {
  const BackupsScreen({super.key});

  @override
  ConsumerState<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends ConsumerState<BackupsScreen> {
  static const _path = '/admin/backups/';
  late Future<Json> _future;
  Timer? _poll;
  bool _starting = false;

  /// Sau khi bấm "Tạo": hỏi lại tới khi thấy file mới (hoặc quá 30 giây) — việc chạy nền có thể
  /// chưa kịp bắt đầu ở lần tải lại ngay sau đó nên `dang_chay` chưa đủ để biết.
  DateTime? _waitUntil;
  int _soFile = 0;

  Future<Json> _fetch() => ref.read(trainingApiProvider).get(_path);

  @override
  void initState() {
    super.initState();
    _future = _fetch();
    _watch(_future);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Đang chạy nền → hỏi lại sau vài giây cho tới khi xong (danh sách tự cập nhật).
  void _watch(Future<Json> f) {
    _poll?.cancel();
    f.then((d) {
      if (!mounted) return;
      final chay = d['dang_chay'] == true;
      final them = (d['results'] as List).length > _soFile;
      final cho =
          _waitUntil != null && !them && DateTime.now().isBefore(_waitUntil!);
      if (!chay && !cho) _waitUntil = null;
      if (chay || cho) _poll = Timer(const Duration(seconds: 3), _reload);
    }, onError: (_) {});
  }

  void _reload() {
    final next = _fetch();
    setState(() {
      _future = next;
    });
    _watch(next);
  }

  Future<void> _create() async {
    setState(() => _starting = true);
    try {
      await ref.read(trainingApiProvider).create(_path, {});
      if (!mounted) return;
      showAppToast(context, 'Đang tạo bản sao lưu…');
      _waitUntil = DateTime.now().add(const Duration(seconds: 30));
      _reload();
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, failureText(f, 'Không tạo được bản sao lưu.'));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final files = [for (final f in d['results'] as List) Json.from(f as Map)];
      final dangChay = d['dang_chay'] == true;
      if (_waitUntil == null) _soFile = files.length;
      final latest = files.isEmpty ? null : files.first;
      final now = ref.read(clockProvider)();
      final gio = latest == null
          ? null
          : now
                .difference(DateTime.parse(latest.str('tao_luc')).toLocal())
                .inHours;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _InfoCard(
                  title: 'Bản sao lưu gần nhất',
                  big: latest == null
                      ? 'Chưa có'
                      : formatIso(latest.str('tao_luc')),
                  note: latest == null
                      ? 'Chưa có bản sao lưu nào.'
                      : '${latest.str('ten')} · ${formatBytes(latest.num0('dung_luong'))}',
                ),
                _InfoCard(
                  title: 'Lịch tự động',
                  big: '02:00 hằng ngày',
                  note:
                      'Giữ các bản sao lưu trong ${d.num0('so_ngay_giu')} ngày',
                ),
                _InfoCard(
                  title: 'Tạo thủ công',
                  action: AppButton(
                    label: dangChay ? 'Đang sao lưu…' : 'Tạo bản sao lưu ngay',
                    height: 44,
                    loading: _starting,
                    onPressed: dangChay ? null : _create,
                  ),
                  note: 'Bản sao lưu chạy nền, danh sách tự cập nhật khi xong.',
                ),
              ],
            ),
            if (latest == null || (gio ?? 0) >= _canhBaoSauGio) ...[
              const SizedBox(height: 16),
              AlertBanner(
                kind: BannerKind.warning,
                message: latest == null
                    ? 'Chưa có bản sao lưu nào. Hãy kiểm tra lịch tự động hoặc tạo bản sao lưu ngay.'
                    : 'Đã $gio giờ chưa có bản sao lưu mới. Hãy kiểm tra lịch tự động hoặc tạo bản sao lưu ngay.',
              ),
            ],
            const SizedBox(height: 16),
            PanelCard(
              padding: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Danh sách bản sao lưu',
                      style: sectionTitleStyle,
                    ),
                  ),
                  _row(
                    const Text('TÊN TỆP', style: _headStyle),
                    const Text('THỜI GIAN', style: _headStyle),
                    const Text('DUNG LƯỢNG', style: _headStyle),
                    header: true,
                  ),
                  if (files.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Chưa có bản sao lưu nào.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  for (final f in files)
                    _row(
                      Text(f.str('ten'), style: monoStyle),
                      Text(formatIso(f.str('tao_luc'))),
                      Text(formatBytes(f.num0('dung_luong'))),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${files.length} bản ghi',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const AlertBanner(
              kind: BannerKind.info,
              message: 'Khôi phục dữ liệu: giao diện không có nút phục hồi hay tải xuống. Khi cần khôi phục, hãy liên hệ bộ phận kỹ thuật để thực hiện trực tiếp trên máy chủ.',
            ),
          ],
        ),
      );
    },
  );

  static const _headStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.muted,
  );

  Widget _row(Widget a, Widget b, Widget c, {bool header = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: header ? const Color(0xFFF7F8FC) : null,
      border: const Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        Expanded(flex: 3, child: a),
        Expanded(flex: 2, child: b),
        SizedBox(
          width: 120,
          child: Align(alignment: Alignment.centerRight, child: c),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, this.big, this.note, this.action});

  final String title;
  final String? big;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: 300,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        if (big != null)
          Text(
            big!,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ?action,
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}
