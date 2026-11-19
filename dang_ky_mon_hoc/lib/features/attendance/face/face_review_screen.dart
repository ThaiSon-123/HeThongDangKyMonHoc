import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../admin/accounts/account_dialogs.dart' show failureText;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';

const _path = '/attendance/faces/';

/// Trạng thái mẫu → (tên tab / chip, màu).
const _trangThai = <String, (String, (Color, Color))>{
  'CHO_DUYET': ('Chờ duyệt', StatusChip.indigo),
  'DUYET': ('Đã duyệt', StatusChip.green),
  'TU_CHOI': ('Từ chối', StatusChip.red),
  'THU_HOI': ('Thu hồi', StatusChip.gray),
};

const _lyDoTuChoi = [
  'Ảnh tối',
  'Ảnh mờ',
  'Không thấy rõ mặt',
  'Đeo khẩu trang / kính râm',
  'Các ảnh không phải cùng một người',
  'Không phải sinh viên này',
];

const _lyDoThuHoi = [
  'Không phải sinh viên này',
  'Sinh viên yêu cầu đăng ký lại',
  'Ảnh đăng ký không đạt',
];

/// Duyệt khuôn mặt tự điểm danh (chỉ PĐT): lọc theo trạng thái, tìm MSSV / họ tên, xem các lần đăng ký trước,
/// phóng to ảnh, từ chối có lý do chọn nhanh, thu hồi mẫu đã duyệt. Mỗi lần xem ảnh đều được ghi nhật ký.
class FaceReviewScreen extends ConsumerStatefulWidget {
  const FaceReviewScreen({super.key});

  @override
  ConsumerState<FaceReviewScreen> createState() => _FaceReviewScreenState();
}

class _FaceReviewScreenState extends ConsumerState<FaceReviewScreen> {
  String _tt = 'CHO_DUYET';
  String _q = '';
  Timer? _hoan;
  late Future<List<Json>> _data = _fetch();
  final _dangXuLy = <int>{};

  Future<List<Json>> _fetch() => ref
      .read(trainingApiProvider)
      .getList(_path, query: {'trang_thai': _tt, if (_q.isNotEmpty) 'q': _q});

  void _reload() => setState(() {
    _data = _fetch();
  });

  @override
  void dispose() {
    _hoan?.cancel();
    super.dispose();
  }

  void _tim(String v) {
    _hoan?.cancel();
    _hoan = Timer(const Duration(milliseconds: 400), () {
      _q = v.trim();
      _reload();
    });
  }

  Future<void> _lam(
    Json m,
    String path,
    Map<String, Object?> body,
    String ok,
  ) async {
    setState(() => _dangXuLy.add(m.id));
    try {
      await ref.read(trainingApiProvider).post(path, body);
      if (mounted) showAppToast(context, ok);
      _reload();
    } on ApiFailure catch (f) {
      if (mounted) showAppToast(context, failureText(f, 'Thao tác thất bại.'));
    } finally {
      if (mounted) setState(() => _dangXuLy.remove(m.id));
    }
  }

  Future<void> _duyet(Json m) => _lam(m, '$_path${m.id}/review/', {
    'duyet': true,
    'ly_do': '',
  }, 'Đã duyệt ${m.str('ho_ten')}.');

  Future<void> _tuChoi(Json m) async {
    final lyDo = await _hoiLyDo(
      context,
      'Lý do từ chối',
      _lyDoTuChoi,
      'Từ chối',
    );
    if (lyDo == null) return;
    await _lam(m, '$_path${m.id}/review/', {
      'duyet': false,
      'ly_do': lyDo,
    }, 'Đã từ chối ${m.str('ho_ten')}.');
  }

  Future<void> _thuHoi(Json m) async {
    final lyDo = await _hoiLyDo(
      context,
      'Thu hồi mẫu của ${m.str('ho_ten')}?',
      _lyDoThuHoi,
      'Thu hồi',
      moTa: 'Sinh viên sẽ không tự điểm danh được cho tới khi đăng ký lại và được duyệt. Không hoàn tác được.',
    );
    if (lyDo == null) return;
    await _lam(m, '$_path${m.id}/thu-hoi/', {
      'ly_do': lyDo,
    }, 'Đã thu hồi mẫu của ${m.str('ho_ten')}.');
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final e in _trangThai.entries)
            ChoiceChip(
              label: Text(e.value.$1),
              selected: _tt == e.key,
              onSelected: (_) {
                _tt = e.key;
                _reload();
              },
            ),
          SizedBox(
            width: 280,
            child: TextField(
              onChanged: _tim,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search),
                hintText: 'Tìm MSSV hoặc họ tên',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(
        child: FutureBuilder<List<Json>>(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) return ListErrorCard(onRetry: _reload);
            final ds = snap.data;
            if (ds == null) return const ListSkeleton();
            final ten = _trangThai[_tt]!.$1.toLowerCase();
            if (ds.isEmpty) {
              return AlertBanner(
                kind: BannerKind.info,
                message: _q.isEmpty
                    ? 'Không có mẫu nào $ten.'
                    : 'Không tìm thấy mẫu $ten khớp "$_q".',
              );
            }
            return ListView.separated(
              itemCount: ds.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    _tt == 'CHO_DUYET'
                        ? '${ds.length} mẫu chờ duyệt (cũ nhất trước). Đối chiếu ảnh với người thật; '
                              'ảnh bị xóa ngay sau khi duyệt hoặc từ chối.'
                        : '${ds.length} mẫu $ten (mới nhất trước${ds.length >= 200 ? ', hiện 200 mẫu gần nhất' : ''}).',
                    style: TextStyle(color: AppColors.muted),
                  );
                }
                final m = ds[i - 1];
                final busy = _dangXuLy.contains(m.id);
                return _MauCard(
                  m: m,
                  actions: switch (m.str('trang_thai')) {
                    'CHO_DUYET' => [
                      FilledButton.icon(
                        onPressed: busy ? null : () => _duyet(m),
                        icon: const Icon(Icons.check),
                        label: const Text('Duyệt'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _tuChoi(m),
                        icon: const Icon(Icons.close),
                        label: const Text('Từ chối'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                    ],
                    'DUYET' => [
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => _thuHoi(m),
                        icon: const Icon(Icons.undo),
                        label: const Text('Thu hồi'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                    ],
                    _ => const [],
                  },
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

/// Hỏi lý do: chạm một lý do có sẵn để điền, hoặc tự gõ.
Future<String?> _hoiLyDo(
  BuildContext context,
  String title,
  List<String> goiY,
  String nut, {
  String? moTa,
}) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AppDialog(
        title: title,
        maxWidth: 480,
        actions: [
          DialogButton('Hủy', onPressed: () => Navigator.of(ctx).pop()),
          DialogButton(
            nut,
            filled: true,
            danger: true,
            onPressed: c.text.trim().isEmpty
                ? null
                : () => Navigator.of(ctx).pop(c.text.trim()),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (moTa != null) ...[
              Text(moTa, style: TextStyle(color: AppColors.label)),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in goiY)
                  ActionChip(
                    label: Text(g),
                    onPressed: () => setS(() => c.text = g),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              maxLength: 255,
              onChanged: (_) => setS(() {}),
              decoration: const InputDecoration(
                hintText: 'Chọn ở trên hoặc tự ghi lý do…',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String _quyetText(Json x) {
  final ai = x.str('nguoi_duyet');
  final luc = formatIso(x['ngay_duyet'] as String?);
  final lyDo = x.str('ly_do');
  return [
    if (ai.isNotEmpty) '${_trangThai[x.str('trang_thai')]?.$1 ?? ''} bởi $ai',
    if (x['ngay_duyet'] != null) luc,
    if (lyDo.isNotEmpty) 'Lý do: $lyDo',
  ].join(' · ');
}

class _MauCard extends StatelessWidget {
  const _MauCard({required this.m, required this.actions});

  final Json m;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final lichSu = [
      for (final x in m['lich_su'] as List? ?? const []) Json.from(x as Map),
    ];
    final quyet = _quyetText(m);
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${m.str('ho_ten')} · ${m.str('ma_sv')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              StatusChip.of(
                _trangThai[m.str('trang_thai')]?.$1 ?? m.str('trang_thai'),
                _trangThai[m.str('trang_thai')]?.$2 ?? StatusChip.gray,
              ),
              if (m.num0('lan_thu') > 1)
                StatusChip.of(
                  'Lần đăng ký thứ ${m.num0('lan_thu')}',
                  StatusChip.yellow,
                ),
              if (m['co_mau_khac_da_duyet'] == true)
                StatusChip.of('Đang có mẫu đã duyệt', StatusChip.teal),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${m.str('nganh')} · Khóa ${m.str('khoa_nhap_hoc')} · '
            'Gửi lúc ${formatIso(m['tao_luc'] as String?)}',
            style: TextStyle(color: AppColors.muted),
          ),
          if (quyet.isNotEmpty)
            Text(quyet, style: TextStyle(color: AppColors.muted)),
          if (m.str('trang_thai') == 'CHO_DUYET' && m.num0('so_anh') > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < m.num0('so_anh'); i++)
                  _Anh(
                    path: '$_path${m.id}/photos/',
                    i: i,
                    ten: m.str('ho_ten'),
                  ),
              ],
            ),
          ],
          if (lichSu.isNotEmpty)
            // Material trong suốt: ExpansionTile/ListTile cần Material ngay phía trên (SectionCard có nền).
            Material(
              color: Colors.transparent,
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    'Các lần đăng ký khác (${lichSu.length})',
                    style: const TextStyle(fontSize: 14),
                  ),
                  children: [
                    for (final x in lichSu)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: StatusChip.of(
                          _trangThai[x.str('trang_thai')]?.$1 ??
                              x.str('trang_thai'),
                          _trangThai[x.str('trang_thai')]?.$2 ??
                              StatusChip.gray,
                        ),
                        title: Text(
                          'Gửi lúc ${formatIso(x['tao_luc'] as String?)}',
                        ),
                        subtitle: _quyetText(x).isEmpty
                            ? null
                            : Text(_quyetText(x)),
                      ),
                  ],
                ),
              ),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// Ảnh đăng ký (đã giải mã ở server, trả `image/jpeg`); chạm để phóng to.
class _Anh extends ConsumerStatefulWidget {
  const _Anh({required this.path, required this.i, required this.ten});

  final String path;
  final int i;
  final String ten;

  @override
  ConsumerState<_Anh> createState() => _AnhState();
}

class _AnhState extends ConsumerState<_Anh> {
  late final Future<Uint8List> _bytes = ref
      .read(apiClientProvider)
      .dio
      .get<List<int>>(
        widget.path,
        queryParameters: {'i': widget.i},
        options: Options(responseType: ResponseType.bytes),
      )
      .then((r) => Uint8List.fromList(r.data ?? const []));

  void _phongTo(Uint8List b) => showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: '${widget.ten} · ảnh ${widget.i + 1}',
      maxWidth: 640,
      actions: [DialogButton('Đóng', onPressed: () => Navigator.of(ctx).pop())],
      child: InteractiveViewer(maxScale: 4, child: Image.memory(b)),
    ),
  );

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 120,
      height: 160,
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (_, s) => s.hasData
            ? Tooltip(
                message: 'Chạm để phóng to',
                child: InkWell(
                  onTap: () => _phongTo(s.data!),
                  child: Image.memory(s.data!, fit: BoxFit.cover),
                ),
              )
            : ColoredBox(
                color: AppColors.divider,
                child: Center(
                  child: s.hasError
                      ? const Icon(Icons.broken_image_outlined)
                      : const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      ),
    ),
  );
}
