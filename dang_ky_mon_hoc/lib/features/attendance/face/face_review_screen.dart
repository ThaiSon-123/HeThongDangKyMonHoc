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
import '../../admin/accounts/account_dialogs.dart' show failureText;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';

const _pendingPath = '/attendance/faces/pending/';

/// Duyệt khuôn mặt chờ duyệt: PĐT thấy toàn trường, GV thấy SV lớp mình (backend lọc).
/// Mỗi lần xem ảnh đều được ghi nhật ký.
class FaceReviewScreen extends ConsumerStatefulWidget {
  const FaceReviewScreen({super.key});

  @override
  ConsumerState<FaceReviewScreen> createState() => _FaceReviewScreenState();
}

class _FaceReviewScreenState extends ConsumerState<FaceReviewScreen> {
  late Future<List<Json>> _data = _fetch();
  final _dangXuLy = <int>{};

  Future<List<Json>> _fetch() =>
      ref.read(trainingApiProvider).getList(_pendingPath);

  void _reload() => setState(() {
    _data = _fetch();
  });

  Future<void> _quyet(Json m, bool duyet) async {
    String lyDo = '';
    if (!duyet) {
      final v = await _hoiLyDo(context);
      if (v == null) return;
      lyDo = v;
    }
    setState(() => _dangXuLy.add(m.id));
    try {
      await ref.read(trainingApiProvider).post(
        '/attendance/faces/${m.id}/review/',
        {'duyet': duyet, 'ly_do': lyDo},
      );
      if (mounted) {
        showAppToast(
          context,
          duyet
              ? 'Đã duyệt ${m.str('ho_ten')}.'
              : 'Đã từ chối ${m.str('ho_ten')}.',
        );
      }
      _reload();
    } on ApiFailure catch (f) {
      if (mounted) showAppToast(context, failureText(f, 'Thao tác thất bại.'));
    } finally {
      if (mounted) setState(() => _dangXuLy.remove(m.id));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final ds = snap.data;
      if (ds == null) return const ListSkeleton();
      if (ds.isEmpty) {
        return const AlertBanner(
          kind: BannerKind.info,
          message: 'Không có khuôn mặt nào đang chờ duyệt.',
        );
      }
      return ListView.separated(
        itemCount: ds.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          if (i == 0) {
            return const AlertBanner(
              kind: BannerKind.info,
              message: 'Đối chiếu ảnh với ảnh thẻ / người thật. Ảnh bị xóa ngay sau khi duyệt hoặc từ chối.',
            );
          }
          final m = ds[i - 1];
          return _MauCard(
            m: m,
            busy: _dangXuLy.contains(m.id),
            onDuyet: () => _quyet(m, true),
            onTuChoi: () => _quyet(m, false),
          );
        },
      );
    },
  );
}

Future<String?> _hoiLyDo(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AppDialog(
        title: 'Lý do từ chối',
        maxWidth: 440,
        actions: [
          DialogButton('Hủy', onPressed: () => Navigator.of(ctx).pop()),
          DialogButton(
            'Từ chối',
            filled: true,
            danger: true,
            onPressed: c.text.trim().isEmpty
                ? null
                : () => Navigator.of(ctx).pop(c.text.trim()),
          ),
        ],
        child: TextField(
          controller: c,
          autofocus: true,
          maxLength: 255,
          onChanged: (_) => setS(() {}),
          decoration: const InputDecoration(
            hintText: 'Vd: Ảnh tối, không phải người trong ảnh thẻ…',
          ),
        ),
      ),
    ),
  );
}

class _MauCard extends ConsumerWidget {
  const _MauCard({
    required this.m,
    required this.busy,
    required this.onDuyet,
    required this.onTuChoi,
  });

  final Json m;
  final bool busy;
  final VoidCallback onDuyet;
  final VoidCallback onTuChoi;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${m.str('ho_ten')} · ${m.str('ma_sv')}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        Text(
          'Gửi lúc ${formatIso(m['tao_luc'] as String?)}',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < m.num0('so_anh'); i++)
              _Anh(path: '/attendance/faces/${m.id}/photos/', i: i),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onDuyet,
              icon: const Icon(Icons.check),
              label: const Text('Duyệt'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onTuChoi,
              icon: const Icon(Icons.close),
              label: const Text('Từ chối'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Ảnh đăng ký (đã giải mã ở server, trả `image/jpeg`).
class _Anh extends ConsumerStatefulWidget {
  const _Anh({required this.path, required this.i});

  final String path;
  final int i;

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

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: SizedBox(
      width: 120,
      height: 160,
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (_, s) => s.hasData
            ? Image.memory(s.data!, fit: BoxFit.cover)
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
