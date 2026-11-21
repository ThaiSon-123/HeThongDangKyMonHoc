import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/format.dart';
import '../../../core/serial/esp32_ble.dart';
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
import '../face/quet_mat_ui.dart';
import 'quet_qr.dart';
import 'thiet_bi.dart';
import 'tu_diem_danh_text.dart';

/// SV: các phiên đang mở của lớp mình → điểm danh từng bước:
/// GPS (nếu bật) → QR + Bluetooth (nếu bắt mã phòng) → thử thách → chụp chuỗi khung → kết quả (KH §7.3, §11).
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
            style: TextStyle(color: AppColors.muted),
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
            Padding(
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

enum _Buoc { batDau, gps, qr, bluetooth, chup, gui, ketQua }

/// Kết quả một bước kiểm tra trước khi quét mặt (GPS / QR / Bluetooth).
typedef _KetQuaBuoc = ({bool dat, String thongBao});

/// Luồng một lượt điểm danh: GPS (nếu bật) → mã QR trên màn chiếu → Bluetooth gần ESP32 (khi phiên bắt
/// mã phòng) → thử thách → quét mặt. Mỗi bước báo kết quả ngay; chỉ qua các bước kiểm tra mới xin thử
/// thách (tính lượt) và mở camera. Không xác nhận được Bluetooth vẫn tiếp tục được nhưng lượt chờ GV duyệt.
/// Thử thách hết hạn sau 60 giây (server kiểm lại).
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
  bool _dangDoc = false;
  bool _dangChamGps = false;
  int _soMau = 0;
  double? _saiSo;
  _KetQuaBuoc? _gps;
  _KetQuaBuoc? _qr;
  _KetQuaBuoc? _ble;
  String? _maQr;
  String? _maBle;
  // Mẫu GPS đã qua bước kiểm tra: gửi kèm lượt để server chấm lại.
  List<MauGps> _mau = [];
  Timer? _timer;

  int get _id => widget.phien.id;
  TrainingApi get _api => ref.read(trainingApiProvider);
  DocEsp32 get _esp => ref.read(docEsp32Provider);

  /// Phiên tắt GPS (`kiem_tra_gps == false`) thì bỏ bước vị trí; thiếu trường (server cũ) coi như bật.
  bool get _canGps => widget.phien['kiem_tra_gps'] != false;
  bool get _canPhong => widget.phien['kiem_tra_phong'] == true;

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

  /// Bấm Điểm danh / Thử lại: chạy lại từ bước đầu.
  Future<void> _batDau() async {
    setState(() {
      _loi = null;
      _ketQua = null;
      _thuThach = null;
      _gps = null;
      _qr = null;
      _ble = null;
      _maQr = null;
      _maBle = null;
      _mau = [];
      _ma.clear();
    });
    if (_canGps && !await _kiemTraGps()) return;
    if (!mounted) return;
    if (!_canPhong) return _xinThuThach();
    setState(() => _buoc = _Buoc.qr); // đợi sinh viên quét QR hoặc gõ mã
  }

  /// Lấy mẫu GPS rồi hỏi server có trong khuôn viên không (chưa tính lượt). Trả về đã đạt chưa.
  Future<bool> _kiemTraGps() async {
    setState(() {
      _buoc = _Buoc.gps;
      _dangChamGps = false;
      _soMau = 0;
      _saiSo = null;
    });
    try {
      final mau = await ref.read(layMauGpsProvider)(6, (m) {
        if (mounted) {
          setState(() {
            _soMau++;
            _saiSo = (m['acc'] as num).toDouble();
          });
        }
      });
      if (!mounted) return false;
      setState(() => _dangChamGps = true);
      final kq = await _api.post('/attendance/sessions/$_id/kiem-tra-vi-tri/', {
        'mau_gps': mau,
      });
      final dat = kq['dat'] == true;
      setState(() {
        _gps = (dat: dat, thongBao: kq.str('thong_bao'));
        if (!dat) _buoc = _Buoc.batDau;
      });
      if (dat) _mau = mau;
      return dat;
    } on GpsLoi catch (e) {
      setState(() {
        _gps = (dat: false, thongBao: e.message);
        _buoc = _Buoc.batDau;
      });
    } on ApiFailure catch (f) {
      setState(() {
        _buoc = _Buoc.batDau;
        _loi = f.message ?? failureText(f, 'Không kiểm tra được vị trí.');
      });
    }
    return false;
  }

  /// Mở camera quét QR trên màn chiếu; hủy thì ở lại bước QR.
  Future<void> _quetQr() async {
    final ma = await ref.read(quetQrProvider)(context);
    if (!mounted || ma == null) return;
    _ma.text = ma;
    await _nhanQr(ma);
  }

  /// Có mã QR (quét hoặc gõ) → sang bước Bluetooth. Mã được server kiểm lúc xin thử thách.
  Future<void> _nhanQr(String ma) async {
    if (ma.trim().isEmpty) return;
    setState(() {
      _maQr = ma.trim();
      _qr = (dat: true, thongBao: 'Đã có mã QR.');
      _ble = null;
      _maBle = null;
      _loi = null;
      _buoc = _Buoc.bluetooth;
    });
    // App Android tự dò ESP32; web phải đợi sinh viên bấm (trình duyệt bắt buộc).
    if (_esp.hoTro && _esp.tuDong) {
      await _docEsp32();
    } else if (!_esp.hoTro) {
      setState(
        () => _ble = (
          dat: false,
          thongBao: 'Máy hoặc trình duyệt này không kiểm tra được Bluetooth.',
        ),
      );
    }
  }

  /// Đọc mã Bluetooth ESP32 đang phát rồi xin thử thách. Không thấy / lỗi thì ở lại bước này để dò lại
  /// hoặc tiếp tục không có Bluetooth. Web: sinh viên bấm Hủy hộp chọn → null, không báo gì.
  Future<void> _docEsp32() async {
    setState(() {
      _dangDoc = true;
      _ble = null;
      _loi = null;
    });
    try {
      final ma = await _esp.doc();
      if (!mounted) return;
      if (ma == null) {
        if (_esp.tuDong) {
          setState(
            () => _ble = (
              dat: false,
              thongBao:
                  'Không thấy thiết bị của giảng viên: có thể bạn đang ở ngoài phòng học. '
                  'Hãy lại gần bàn giảng viên rồi dò lại.',
            ),
          );
        }
        return;
      }
      _maBle = ma;
      await _xinThuThach();
    } catch (e) {
      if (mounted) {
        setState(
          () => _ble = (
            dat: false,
            thongBao: e is Esp32Loi
                ? e.message
                : 'Không đọc được Bluetooth từ thiết bị của giảng viên. '
                      'Hãy bật Bluetooth, lại gần bàn giảng viên rồi thử lại.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _dangDoc = false);
    }
  }

  /// Xin thử thách (kèm mã QR + mã Bluetooth nếu có; server kiểm mã trước khi tính lượt) rồi quét mặt.
  Future<void> _xinThuThach() async {
    setState(() => _loi = null);
    try {
      final t = await _api.post('/attendance/sessions/$_id/challenge/', {
        'ma_phong': _maQr ?? '',
        if (_maBle != null) 'ma_bluetooth': _maBle,
      });
      setState(() {
        _thuThach = t;
        if (_canPhong) {
          _qr = (dat: true, thongBao: 'Mã QR hợp lệ.');
          _ble = _maBle != null
              ? (dat: true, thongBao: 'Đã xác nhận bạn đang trong phòng học.')
              : (
                  dat: false,
                  thongBao: 'Không xác nhận Bluetooth: lượt này sẽ chờ giảng viên duyệt.',
                );
        }
      });
      await _quetMat();
    } on ApiFailure catch (f) {
      final thongBao =
          f.message ?? failureText(f, 'Không bắt đầu điểm danh được.');
      setState(() {
        switch (f.lyDo) {
          case 'MA_PHONG_SAI': // quét / gõ lại QR
            _qr = (dat: false, thongBao: thongBao);
            _ble = null;
            _maQr = null;
            _maBle = null;
            _buoc = _Buoc.qr;
          case 'MA_BLUETOOTH_SAI': // dò lại
            _ble = (dat: false, thongBao: thongBao);
            _maBle = null;
            _buoc = _Buoc.bluetooth;
          default:
            _buoc = _Buoc.batDau;
            _loi = thongBao;
        }
      });
    }
  }

  /// Chụp chuỗi khung → gửi lượt (kèm mẫu GPS đã kiểm tra) ngay trên màn camera, hiện kết quả ở đó;
  /// sinh viên bấm "Xong" thì quay về đây với cùng kết quả.
  Future<void> _quetMat() async {
    final t = _thuThach!;
    Json? kq;
    ApiFailure? loiGui;
    setState(() => _buoc = _Buoc.chup);
    final hanhDong = hanhDongText[t.str('hanh_dong')] ?? t.str('hanh_dong');
    final khung = await ref.read(faceBurstProvider)(
      context,
      [
        ('Nhìn thẳng vào camera', 2, 'thang'),
        (hanhDong, 4, t.str('hanh_dong')),
      ],
      hetHan: DateTime.tryParse(t.str('het_han_luc')),
      gui: (khung) async {
        if (mounted) setState(() => _buoc = _Buoc.gui);
        try {
          final deviceId = await ref.read(deviceIdProvider.future);
          kq = await _api.postFiles(
            '/attendance/sessions/$_id/checkin/',
            'khung',
            khung,
            fields: {
              'nonce': t.str('nonce'),
              'mau_gps': jsonEncode(_mau),
              'device_id': deviceId,
              'nen_tang': nenTang,
            },
          );
          return _ketQuaCamera(kq!);
        } on ApiFailure catch (f) {
          loiGui = f;
          return (
            loai: LoaiKetQua.khongDat,
            tieuDe: 'Gửi lượt điểm danh thất bại.',
            chiTiet: f.message ?? failureText(f, 'Hãy thử lại.'),
          );
        }
      },
    );
    if (!mounted) return;
    final ketQua = kq;
    setState(() {
      if (khung == null) {
        _buoc = _Buoc.batDau;
        _loi = 'Bạn đã hủy chụp. Lượt này vẫn bị tính.';
      } else if (ketQua == null) {
        final f = loiGui;
        _buoc = _Buoc.batDau;
        _loi = f == null
            ? 'Gửi lượt điểm danh thất bại.'
            : (f.message ?? failureText(f, 'Gửi lượt điểm danh thất bại.'));
      } else {
        _ketQua = ketQua;
        _buoc = _Buoc.ketQua;
      }
    });
  }

  /// Kết quả `checkin` → khung kết quả trên màn camera.
  KetQuaQuet _ketQuaCamera(Json kq) => switch (kq.str('ket_qua')) {
    'CO_MAT' => (
      loai: LoaiKetQua.dat,
      tieuDe: 'Đã ghi nhận có mặt.',
      chiTiet: null,
    ),
    'DANG_NGO' => (
      loai: LoaiKetQua.choDuyet,
      tieuDe: 'Đã ghi nhận, chờ giảng viên xác nhận.',
      chiTiet: null,
    ),
    _ => (
      loai: LoaiKetQua.khongDat,
      tieuDe: 'Chưa điểm danh được.',
      chiTiet: (kq['ly_do'] as Map?)?['thong_bao'] as String?,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.phien;
    final t = _thuThach;
    final hetHan = t == null ? null : DateTime.tryParse(t.str('het_han_luc'));
    final now = ref.read(clockProvider)();
    final dangChay =
        _buoc == _Buoc.gps ||
        _buoc == _Buoc.chup ||
        _buoc == _Buoc.gui ||
        _dangDoc;
    final daChay = _buoc != _Buoc.batDau || _gps != null || _qr != null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: dangChay ? null : widget.onXong,
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
                if (daChay) ...[..._cacBuoc(), const SizedBox(height: 12)],
                if (t != null && _buoc != _Buoc.ketQua && hetHan != null) ...[
                  Text(
                    'Hành động: ${hanhDongText[t.str('hanh_dong')]} · '
                    'còn ${conLai(hetHan, now)} · còn ${t.num0('luot_con_lai')} lượt sau lượt này',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                ],
                ...switch (_buoc) {
                  _Buoc.batDau => [
                    if (!daChay) ...[
                      Text(
                        'Các bước: ${[if (_canGps) 'kiểm tra vị trí (bật định vị)', if (_canPhong) 'quét QR trên màn chiếu', if (_canPhong) 'kiểm tra Bluetooth (bật Bluetooth)', 'quét khuôn mặt'].join(' → ')}. '
                        'Lượt chỉ bị tính khi đã qua các bước kiểm tra và bắt đầu quét mặt (tối đa 5 lượt mỗi phiên). '
                        'Chuẩn bị: đứng trong lớp, đủ sáng.',
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 12),
                    ],
                    AppButton(
                      label: daChay ? 'Thử lại' : 'Điểm danh',
                      onPressed: _batDau,
                    ),
                  ],
                  _Buoc.qr => _buocQr(),
                  _Buoc.bluetooth => _buocBluetooth(),
                  _Buoc.gps || _Buoc.chup || _Buoc.gui => const [],
                  _Buoc.ketQua => _ketQuaWidgets(_ketQua!),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Danh sách bước kiểm tra kèm trạng thái và thông báo của từng bước.
  List<Widget> _cacBuoc() {
    final gpsDang = _buoc == _Buoc.gps
        ? (_dangChamGps
              ? 'Đang kiểm tra bạn có trong khuôn viên trường…'
              : 'Đang lấy vị trí… $_soMau mẫu'
                    '${_saiSo == null ? '' : ', sai số ${_saiSo!.round()} m'}')
        : null;
    final matDang = switch (_buoc) {
      _Buoc.chup => 'Đang mở camera…',
      _Buoc.gui => 'Đang kiểm tra khuôn mặt…',
      _ => null,
    };
    return [
      if (_canGps)
        _DongBuoc(
          tieuDe: 'Vị trí (GPS)',
          ketQua: _gps,
          dangChay: gpsDang,
          ghiChu: _gps?.dat == false ? 'Chưa bị tính lượt.' : null,
        ),
      if (_canPhong) ...[
        _DongBuoc(tieuDe: 'Mã QR trên màn chiếu', ketQua: _qr),
        _DongBuoc(
          tieuDe: 'Bluetooth (gần máy giảng viên)',
          ketQua: _ble,
          dangChay: _dangDoc
              ? (_esp.tuDong
                    ? 'Đang dò thiết bị của giảng viên qua Bluetooth…'
                    : 'Đang đọc Bluetooth từ thiết bị của giảng viên…')
              : null,
        ),
      ],
      _DongBuoc(
        tieuDe: 'Quét khuôn mặt',
        dangChay: matDang,
        ketQua: _ketQuaMat(),
      ),
    ];
  }

  /// Kết quả bước khuôn mặt sau khi gửi lượt (lý do không đạt hiện ở phần kết quả bên dưới).
  _KetQuaBuoc? _ketQuaMat() {
    final kq = _ketQua;
    if (_buoc != _Buoc.ketQua || kq == null) return null;
    return switch (kq.str('ket_qua')) {
      'CO_MAT' => (dat: true, thongBao: 'Khuôn mặt khớp với tài khoản.'),
      'DANG_NGO' => (
        dat: true,
        thongBao: 'Đã ghi nhận, chờ giảng viên xác nhận.',
      ),
      _ => (dat: false, thongBao: ''),
    };
  }

  List<Widget> _buocQr() => [
    AppButton(label: 'Quét QR', onPressed: _quetQr),
    const SizedBox(height: 8),
    Text('Hoặc gõ mã hiện dưới QR:', style: TextStyle(color: AppColors.muted)),
    const SizedBox(height: 8),
    LabeledField(
      label: 'Mã phòng (8 ký tự dưới QR)',
      controller: _ma,
      hint: 'Vd: K7Q2M9XA',
      onSubmitted: _nhanQr,
    ),
    const SizedBox(height: 12),
    AppButton(
      label: 'Tiếp tục',
      outlined: true,
      onPressed: () => _nhanQr(_ma.text),
    ),
  ];

  List<Widget> _buocBluetooth() => [
    if (_esp.hoTro)
      AppButton(
        label: _dangDoc
            ? 'Đang kiểm tra Bluetooth…'
            : _esp.tuDong
            ? 'Dò lại'
            : 'Kiểm tra Bluetooth (chọn thiết bị)',
        onPressed: _dangDoc ? null : _docEsp32,
      ),
    if (!_dangDoc && (!_esp.hoTro || _ble?.dat == false)) ...[
      const SizedBox(height: 12),
      Text(
        'Không xác nhận được Bluetooth vẫn điểm danh được, nhưng lượt sẽ chờ giảng viên duyệt.',
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 8),
      AppButton(
        label: 'Tiếp tục không có Bluetooth',
        outlined: true,
        onPressed: () {
          _maBle = null;
          _xinThuThach();
        },
      ),
    ],
  ];

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

/// Một dòng trong danh sách bước: chờ / đang chạy / đạt / không đạt, kèm thông báo.
class _DongBuoc extends StatelessWidget {
  const _DongBuoc({
    required this.tieuDe,
    this.ketQua,
    this.dangChay,
    this.ghiChu,
  });

  final String tieuDe;
  final _KetQuaBuoc? ketQua;
  final String? dangChay;
  final String? ghiChu;

  @override
  Widget build(BuildContext context) {
    final kq = ketQua;
    final Widget icon;
    final String? thongBao;
    Color? mau;
    if (dangChay != null) {
      icon = const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      thongBao = dangChay;
    } else if (kq != null) {
      mau = kq.dat ? AppColors.success : AppColors.danger;
      icon = Icon(
        kq.dat ? Icons.check_circle : Icons.cancel,
        color: mau,
        size: 20,
      );
      thongBao = kq.thongBao;
    } else {
      icon = Icon(
        Icons.radio_button_unchecked,
        color: AppColors.muted,
        size: 20,
      );
      thongBao = null;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tieuDe,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (thongBao != null && thongBao.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(thongBao, style: TextStyle(color: mau, height: 1.4)),
                ],
                if (ghiChu != null)
                  Text(ghiChu!, style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
