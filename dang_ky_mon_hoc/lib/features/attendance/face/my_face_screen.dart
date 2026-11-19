import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../admin/accounts/account_dialogs.dart' show failureText;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import 'face_capture.dart';

const _mePath = '/attendance/face/me/';
/// (lời nhắc, mã tư thế server kiểm tra lúc quét real time).
const tuThe = [
  ('Nhìn thẳng', 'thang'),
  ('Quay đầu hơi sang trái', 'hoi_trai'),
  ('Quay đầu hơi sang phải', 'hoi_phai'),
];

/// Đồng ý dữ liệu sinh trắc + đăng ký / xem / xóa khuôn mặt dùng cho tự điểm danh (KH §7.1, §11).
class MyFaceScreen extends ConsumerStatefulWidget {
  const MyFaceScreen({super.key});

  @override
  ConsumerState<MyFaceScreen> createState() => _MyFaceScreenState();
}

class _MyFaceScreenState extends ConsumerState<MyFaceScreen> {
  late Future<Json> _data = _api.get(_mePath);
  bool _busy = false;
  String? _loi;

  TrainingApi get _api => ref.read(trainingApiProvider);

  void _set(Future<Json> f) => setState(() {
    _data = f;
  });

  Future<void> _lam(Future<Json> Function() call, String ok) async {
    setState(() {
      _busy = true;
      _loi = null;
    });
    try {
      final d = await call();
      _set(Future.value(d));
      if (mounted) showAppToast(context, ok);
    } on ApiFailure catch (f) {
      setState(
        () => _loi =
            f.fields['anh'] ??
            f.message ??
            failureText(f, 'Thao tác thất bại.'),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dangKy() async {
    final anh = await ref.read(faceCaptureProvider)(context, tuThe);
    if (anh == null || !mounted) return;
    await _lam(
      () => _api.postFiles('/attendance/faces/enroll/', 'anh', anh),
      'Đã gửi khuôn mặt, chờ duyệt.',
    );
  }

  Future<void> _xoa() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Xóa dữ liệu khuôn mặt?',
      message: 'Mẫu khuôn mặt bị xóa ngay. Bạn sẽ không tự điểm danh được cho tới khi đăng ký lại và được duyệt.',
      actionLabel: 'Xóa',
      danger: true,
    );
    if (ok) {
      await _lam(() => _api.deleteJson(_mePath), 'Đã xóa dữ liệu khuôn mặt.');
    }
  }

  Future<void> _rutLai() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Rút lại đồng ý?',
      message: 'Dữ liệu khuôn mặt của bạn bị xóa và bạn sẽ phải nhờ giảng viên điểm danh thủ công.',
      actionLabel: 'Rút lại',
      danger: true,
    );
    if (ok) {
      await _lam(
        () => _api.deleteJson('/attendance/consent/'),
        'Đã rút lại đồng ý.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        return ListErrorCard(onRetry: () => _set(_api.get(_mePath)));
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loi != null) ...[
              AlertBanner(kind: BannerKind.error, message: _loi!),
              const SizedBox(height: 16),
            ],
            if (d['da_dong_y'] != true)
              _DongY(
                busy: _busy,
                onDongY: () => _lam(
                  () => _api.post('/attendance/consent/'),
                  'Đã ghi nhận đồng ý.',
                ),
              )
            else
              _TrangThai(
                d: d,
                busy: _busy,
                onDangKy: _dangKy,
                onXoa: _xoa,
                onRutLai: _rutLai,
              ),
          ],
        ),
      );
    },
  );
}

class _DongY extends StatelessWidget {
  const _DongY({required this.busy, required this.onDongY});

  final bool busy;
  final VoidCallback onDongY;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Đồng ý xử lý dữ liệu sinh trắc học',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Để tự điểm danh bằng điện thoại, hệ thống cần lưu đặc trưng khuôn mặt của bạn '
          '(theo Nghị định 13/2023/NĐ-CP về bảo vệ dữ liệu cá nhân):\n\n'
          '• Chỉ lưu vector đặc trưng đã mã hóa, không lưu ảnh lâu dài. Ảnh đăng ký bị xóa ngay '
          'sau khi được duyệt hoặc từ chối.\n'
          '• Khung hình lúc điểm danh chỉ xử lý trong bộ nhớ. Lượt bị nghi ngờ giữ 1 ảnh làm '
          'bằng chứng trong 30 ngày.\n'
          '• Vị trí GPS chỉ lấy lúc bạn bấm điểm danh, không theo dõi liên tục.\n'
          '• Bạn có thể xóa dữ liệu hoặc rút lại đồng ý bất kỳ lúc nào. Khi đó giảng viên '
          'sẽ điểm danh thủ công cho bạn.',
          style: TextStyle(height: 1.5, color: AppColors.label),
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Tôi đồng ý', loading: busy, onPressed: onDongY),
      ],
    ),
  );
}

class _TrangThai extends StatelessWidget {
  const _TrangThai({
    required this.d,
    required this.busy,
    required this.onDangKy,
    required this.onXoa,
    required this.onRutLai,
  });

  final Json d;
  final bool busy;
  final VoidCallback onDangKy;
  final VoidCallback onXoa;
  final VoidCallback onRutLai;

  @override
  Widget build(BuildContext context) {
    final tt = d.str('trang_thai');
    final dangKyLai = d['can_dang_ky_lai'] == true;
    final (nhan, bg, fg, moTa) = switch (tt) {
      'DUYET' when dangKyLai => (
        'Cần đăng ký lại',
        AppColors.warnBannerBg,
        AppColors.warnBannerText,
        'Hệ thống đã đổi mô hình nhận diện. Hãy đăng ký lại khuôn mặt để tiếp tục tự điểm danh.',
      ),
      'DUYET' => (
        'Đã duyệt',
        AppColors.successBg,
        AppColors.success,
        d['dang_cho_cap_nhat'] == true
            ? 'Bạn đã có thể tự điểm danh. Ảnh đăng ký mới đang chờ duyệt.'
            : 'Bạn đã có thể tự điểm danh.',
      ),
      'CHO_DUYET' => (
        'Chờ duyệt',
        AppColors.infoBannerBg,
        AppColors.infoBannerText,
        'Phòng đào tạo đang đối chiếu ảnh của bạn. Trong lúc chờ, hãy nhờ giảng viên điểm danh thủ công.',
      ),
      'TU_CHOI' => (
        'Bị từ chối',
        AppColors.errorBannerBg,
        AppColors.danger,
        'Lý do: ${d.str('ly_do')}. Hãy chụp lại.',
      ),
      _ => (
        'Chưa đăng ký',
        AppColors.divider,
        AppColors.muted,
        'Chụp 3 ảnh khuôn mặt (nhìn thẳng, hơi trái, hơi phải) ở nơi đủ sáng.',
      ),
    };
    final coMau = tt == 'DUYET' || tt == 'CHO_DUYET';
    return SectionCard(
      title: 'Khuôn mặt của tôi',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(nhan, bg: bg, fg: fg),
          ),
          const SizedBox(height: 12),
          Text(moTa, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 16),
          AppButton(
            label: coMau ? 'Đăng ký lại khuôn mặt' : 'Đăng ký khuôn mặt',
            loading: busy,
            onPressed: onDangKy,
          ),
          if (coMau) ...[
            const SizedBox(height: 8),
            AppButton(
              label: 'Xóa dữ liệu khuôn mặt',
              outlined: true,
              onPressed: busy ? null : onXoa,
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onRutLai,
            child: const Text('Rút lại đồng ý xử lý dữ liệu sinh trắc'),
          ),
        ],
      ),
    );
  }
}
