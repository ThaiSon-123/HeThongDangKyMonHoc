import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../admin/accounts/account_dialogs.dart' show failureText;
import '../../registration/timetable_screen.dart' show clockProvider;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import '../attendance_format.dart';
import '../face/face_capture.dart';
import 'thiet_bi.dart';
import 'tu_diem_danh_text.dart';

/// SV: các phiên đang mở của lớp mình → điểm danh từng bước:
/// thử thách → mã phòng (nếu bật) → GPS → chụp chuỗi khung → kết quả (KH §7.3, §11).
class SvTuDiemDanhScreen extends ConsumerStatefulWidget {
  const SvTuDiemDanhScreen({super.key});

  @override
  ConsumerState<SvTuDiemDanhScreen> createState() => _SvState();
}

class _SvState extends ConsumerState<SvTuDiemDanhScreen> {
  late Future<List<Json>> _ds = _tai();
  Json? _dangLam; // phiên đang điểm danh

  Future<List<Json>> _tai() =>
      ref.read(trainingApiProvider).getList('/attendance/open-sessions/');

  void _reload() => setState(() {
    _dangLam = null;
    _ds = _tai();
  });

  @override
  Widget build(BuildContext context) {
    final p = _dangLam;
    if (p != null) return SvLuong(phien: p, onXong: _reload);
    return FutureBuilder<List<Json>>(
      future: _ds,
      builder: (context, snap) {
        if (snap.hasError) return ListErrorCard(onRetry: _reload);
        final ds = snap.data;
        if (ds == null) return const ListSkeleton();
        return ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/student/face'),
                  icon: const Icon(Icons.face_outlined),
                  label: const Text('Khuôn mặt của tôi'),
                ),
                TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Làm mới'),
                ),
              ],
            ),
            if (ds.isEmpty)
              const AlertBanner(
                kind: BannerKind.info,
                message: 'Chưa có phiên điểm danh nào đang mở. Giảng viên mở phiên trong giờ học.',
              ),
            for (final s in ds) ...[
              PhienCard(s: s, onDiemDanh: () => setState(() => _dangLam = s)),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// Đầu màn "Điểm danh" của SV: các phiên tự điểm danh đang mở (bấm để vào luồng camera + GPS) và lối
/// vào đăng ký khuôn mặt. Lỗi tải thì chỉ còn lối vào khuôn mặt, không làm hỏng cả màn.
class TheTuDiemDanh extends ConsumerStatefulWidget {
  const TheTuDiemDanh({super.key, required this.onDiemDanh});

  final void Function(Json phien) onDiemDanh;

  @override
  ConsumerState<TheTuDiemDanh> createState() => _TheState();
}

class _TheState extends ConsumerState<TheTuDiemDanh> {
  late final Future<(List<Json>, Json?)> _tai = _taiDuLieu();

  /// Lỗi của từng phần (phiên đang mở, trạng thái khuôn mặt) chỉ làm phần đó biến mất.
  Future<(List<Json>, Json?)> _taiDuLieu() async {
    final api = ref.read(trainingApiProvider);
    Future<T?> thu<T>(Future<T> Function() f) async {
      try {
        return await f();
      } on ApiFailure {
        return null;
      }
    }

    final r = await Future.wait<Object?>([
      thu(() => api.getList('/attendance/open-sessions/')),
      thu(() => api.get('/attendance/face/me/')),
    ]);
    return ((r[0] as List<Json>?) ?? const <Json>[], r[1] as Json?);
  }

  /// Nhãn trạng thái khuôn mặt cạnh lối vào đăng ký.
  Widget? _chipMat(Json? m) {
    if (m == null) return null;
    final tt = m.str('trang_thai');
    if (tt == 'DUYET') {
      return m['can_dang_ky_lai'] == true
          ? StatusChip.of('Cần đăng ký lại', StatusChip.yellow)
          : StatusChip.of('Đã duyệt', StatusChip.green);
    }
    return switch (tt) {
      'CHO_DUYET' => StatusChip.of('Chờ duyệt', StatusChip.yellow),
      'TU_CHOI' => StatusChip.of('Bị từ chối', StatusChip.red),
      _ => StatusChip.of('Chưa đăng ký', StatusChip.gray),
    };
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(List<Json>, Json?)>(
    future: _tai,
    builder: (context, snap) {
      final ds = snap.data?.$1 ?? const <Json>[];
      final chip = _chipMat(snap.data?.$2);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in ds) ...[
            PhienCard(s: s, onDiemDanh: () => widget.onDiemDanh(s)),
            const SizedBox(height: 12),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => context.go('/student/face'),
                  icon: const Icon(Icons.face_outlined),
                  label: const Text('Khuôn mặt điểm danh'),
                ),
                ?chip,
              ],
            ),
          ),
        ],
      );
    },
  );
}

class PhienCard extends ConsumerWidget {
  const PhienCard({super.key, required this.s, required this.onDiemDanh});

  final Json s;
  final VoidCallback onDiemDanh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coMat = s.str('trang_thai') == 'CO_MAT';
    final con = s.num0('luot_con_lai');
    final hetHan = DateTime.tryParse(s.str('het_han_luc'));
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${s.str('ma_lop')} · ${s.str('ten_mon')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              tuDiemDanhChip(s.str('trang_thai'), s['dang_ngo'] == true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ngayDayDu(s.str('ngay_hoc'))} · ${buoiText(s.str('buoi'))} · '
            'đóng lúc ${hetHan == null ? '—' : formatDateTime(hetHan)} · còn $con lượt',
            style: const TextStyle(color: AppColors.muted),
          ),
          if (s['dang_ngo'] == true) ...[
            const SizedBox(height: 8),
            const Text('Lượt của bạn đang chờ giảng viên xác nhận.'),
          ],
          const SizedBox(height: 12),
          AppButton(
            label: coMat ? 'Đã có mặt' : 'Điểm danh',
            onPressed: coMat || con == 0 ? null : onDiemDanh,
          ),
          if (!coMat && con == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Bạn đã hết lượt. Hãy báo giảng viên để điểm danh thủ công.',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Buoc { batDau, maPhong, gps, chup, gui, ketQua }

/// Luồng một lượt điểm danh. Thử thách hết hạn sau 60 giây (server kiểm lại).
class SvLuong extends ConsumerStatefulWidget {
  const SvLuong({super.key, required this.phien, required this.onXong});

  final Json phien;
  final VoidCallback onXong;

  @override
  ConsumerState<SvLuong> createState() => _LuongState();
}

class _LuongState extends ConsumerState<SvLuong> {
  _Buoc _buoc = _Buoc.batDau;
  Json? _thuThach;
  Json? _ketQua;
  String? _loi;
  final _ma = TextEditingController();
  int _soMau = 0;
  double? _saiSo;
  Timer? _timer;

  int get _id => widget.phien.id;
  TrainingApi get _api => ref.read(trainingApiProvider);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _thuThach != null && _buoc != _Buoc.ketQua) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ma.dispose();
    super.dispose();
  }

  Future<void> _batDau() async {
    setState(() {
      _loi = null;
      _ketQua = null;
      _thuThach = null;
    });
    try {
      final t = await _api.post('/attendance/sessions/$_id/challenge/');
      setState(() => _thuThach = t);
      if (t['kiem_tra_phong'] == true) {
        setState(() => _buoc = _Buoc.maPhong);
      } else {
        await _tiep();
      }
    } on ApiFailure catch (f) {
      setState(() {
        _buoc = _Buoc.batDau;
        _loi = f.message ?? failureText(f, 'Không xin được thử thách.');
      });
    }
  }

  /// GPS → chụp → gửi.
  Future<void> _tiep() async {
    final t = _thuThach!;
    try {
      setState(() {
        _buoc = _Buoc.gps;
        _soMau = 0;
        _saiSo = null;
      });
      final mau = await ref.read(layMauGpsProvider)(6, (m) {
        if (mounted) {
          setState(() {
            _soMau++;
            _saiSo = (m['acc'] as num).toDouble();
          });
        }
      });
      if (!mounted) return;
      setState(() => _buoc = _Buoc.chup);
      final hanhDong = hanhDongText[t.str('hanh_dong')] ?? t.str('hanh_dong');
      final khung = await ref.read(faceBurstProvider)(context, [
        ('Nhìn thẳng vào camera', 2),
        (hanhDong, 4),
      ]);
      if (!mounted) return;
      if (khung == null) {
        setState(() {
          _buoc = _Buoc.batDau;
          _loi = 'Bạn đã hủy chụp. Lượt này vẫn bị tính.';
        });
        return;
      }
      setState(() => _buoc = _Buoc.gui);
      final deviceId = await ref.read(deviceIdProvider.future);
      final kq = await _api.postFiles(
        '/attendance/sessions/$_id/checkin/',
        'khung',
        khung,
        fields: {
          'nonce': t.str('nonce'),
          'mau_gps': jsonEncode(mau),
          'ma_phong': _ma.text.trim(),
          'device_id': deviceId,
          'nen_tang': nenTang,
        },
      );
      setState(() {
        _ketQua = kq;
        _buoc = _Buoc.ketQua;
      });
    } on GpsLoi catch (e) {
      setState(() {
        _buoc = _Buoc.batDau;
        _loi = e.message;
      });
    } on ApiFailure catch (f) {
      setState(() {
        _buoc = _Buoc.batDau;
        _loi = f.message ?? failureText(f, 'Gửi lượt điểm danh thất bại.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.phien;
    final t = _thuThach;
    final hetHan = t == null ? null : DateTime.tryParse(t.str('het_han_luc'));
    final now = ref.read(clockProvider)();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  _buoc == _Buoc.gps ||
                      _buoc == _Buoc.chup ||
                      _buoc == _Buoc.gui
                  ? null
                  : widget.onXong,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Danh sách phiên'),
            ),
          ),
          SectionCard(
            title: '${p.str('ma_lop')} · ${p.str('ten_mon')}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loi != null) ...[
                  AlertBanner(kind: BannerKind.error, message: _loi!),
                  const SizedBox(height: 12),
                ],
                if (t != null && _buoc != _Buoc.ketQua && hetHan != null)
                  Text(
                    'Hành động: ${hanhDongText[t.str('hanh_dong')]} · '
                    'còn ${conLai(hetHan, now)} · còn ${t.num0('luot_con_lai')} lượt sau lượt này',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 12),
                ...switch (_buoc) {
                  _Buoc.batDau => [
                    const Text(
                      'Mỗi lần bấm Bắt đầu tính 1 lượt (tối đa 5 lượt mỗi phiên). '
                      'Chuẩn bị: bật định vị, đứng trong lớp, đủ sáng.',
                      style: TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    AppButton(label: 'Bắt đầu', onPressed: _batDau),
                  ],
                  _Buoc.maPhong => [
                    LabeledField(
                      label: 'Mã phòng (8 ký tự trên màn chiếu)',
                      controller: _ma,
                      hint: 'Vd: K7Q2M9XA',
                      onSubmitted: (_) => _tiep(),
                    ),
                    const SizedBox(height: 12),
                    AppButton(label: 'Tiếp tục', onPressed: _tiep),
                  ],
                  _Buoc.gps => [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'Đang lấy vị trí… $_soMau mẫu'
                      '${_saiSo == null ? '' : ', sai số ${_saiSo!.round()} m'}',
                    ),
                  ],
                  _Buoc.chup => [const Text('Đang mở camera…')],
                  _Buoc.gui => [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Text('Đang kiểm tra khuôn mặt và vị trí…'),
                  ],
                  _Buoc.ketQua => _ketQuaWidgets(_ketQua!),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _ketQuaWidgets(Json kq) {
    final (tieuDe, mau) = switch (kq.str('ket_qua')) {
      'CO_MAT' => ('Đã ghi nhận có mặt.', AppColors.success),
      'DANG_NGO' => (
        'Đã ghi nhận, chờ giảng viên xác nhận.',
        AppColors.warnBannerText,
      ),
      _ => ('Chưa điểm danh được.', AppColors.danger),
    };
    final lyDo = (kq['ly_do'] as Map?)?['thong_bao'] as String?;
    final con = kq.num0('luot_con_lai');
    final thuLai = kq.str('ket_qua') == 'KHONG_DAT' && con > 0;
    return [
      Text(
        tieuDe,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: mau),
      ),
      if (lyDo != null) ...[const SizedBox(height: 8), Text(lyDo)],
      const SizedBox(height: 8),
      Text(
        con > 0
            ? 'Còn $con lượt.'
            : 'Đã hết lượt. Nếu chưa được ghi nhận, hãy báo giảng viên.',
      ),
      const SizedBox(height: 12),
      if (thuLai) AppButton(label: 'Thử lại', onPressed: _batDau),
      if (!thuLai) AppButton(label: 'Xong', onPressed: widget.onXong),
    ];
  }
}
