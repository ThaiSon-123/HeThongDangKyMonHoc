import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../training/training_api.dart';

/// Mở màn chụp đăng ký: mỗi phần tử [buoc] là (lời nhắc, mã tư thế: `thang` / `hoi_trai` / `hoi_phai`);
/// trả ảnh JPEG theo thứ tự, `null` nếu hủy. Thay được trong test (camera không chạy trong widget test).
typedef FaceCapture = Future<List<Uint8List>?> Function(
  BuildContext context,
  List<(String, String)> buoc,
);

final faceCaptureProvider = Provider<FaceCapture>(
  (ref) =>
      (context, buoc) =>
          Navigator.of(
            context,
            // Toàn màn hình, không lọt trong khung nội dung của shell.
            rootNavigator: true,
          ).push<List<Uint8List>>(
            MaterialPageRoute(builder: (_) => FaceCaptureScreen(buoc: buoc)),
          ),
);

/// Chụp chuỗi khung lúc điểm danh: mỗi phần tử là (lời nhắc, số khung, mã tư thế: `thang` / `turn_left` /
/// `turn_right`); chờ khung đạt rồi chụp tự động.
typedef FaceBurst = Future<List<Uint8List>?> Function(
  BuildContext context,
  List<(String, int, String)> chuoi,
);

final faceBurstProvider = Provider<FaceBurst>(
  (ref) =>
      (context, chuoi) =>
          Navigator.of(context, rootNavigator: true).push<List<Uint8List>>(
            MaterialPageRoute(
              builder: (_) => FaceCaptureScreen(buoc: const [], chuoi: chuoi),
            ),
          ),
);

/// Server kiểm tra một khung lúc quét real time (dò mặt, gần/xa, sáng, mờ, tư thế): `(đạt, lời nhắc)`.
typedef KiemTraKhung = Future<(bool, String)> Function(
  Uint8List anh,
  String tuThe,
);

final kiemTraKhungProvider = Provider<KiemTraKhung>(
  (ref) => (anh, tuThe) async {
    final r = await ref
        .read(trainingApiProvider)
        .postFiles(
          '/attendance/face/kiem-tra-khung/',
          'anh',
          [anh],
          fields: {'tu_the': tuThe},
        );
    return (r['ok'] == true, r.str('thong_bao'));
  },
);

/// Màn đã đóng giữa lúc đang quét.
class _DaDong implements Exception {}

/// Camera trước + vòng oval đổi màu theo kết quả quét real time (trắng: đang kiểm tra, xanh: đạt, đỏ: chưa đạt)
/// kèm lời nhắc. Khung đạt 2 lần liên tiếp thì tự chụp.
/// - Đăng ký ([buoc]): tự chụp lần lượt từng tư thế, xem lại rồi mới dùng; có nút "Chụp ngay" dự phòng.
/// - Điểm danh ([chuoi]): tự bắt đầu; mỗi bước chờ khung đạt (tối đa 12 giây để kịp hạn thử thách) rồi chụp
///   đủ số khung, trả về ngay.
class FaceCaptureScreen extends ConsumerStatefulWidget {
  const FaceCaptureScreen({super.key, required this.buoc, this.chuoi});

  final List<(String, String)> buoc;
  final List<(String, int, String)>? chuoi;

  @override
  ConsumerState<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends ConsumerState<FaceCaptureScreen> {
  CameraController? _cam;
  String? _loi;
  String? _loiNhac; // tư thế / hành động đang yêu cầu
  String _goiY = 'Đang kiểm tra khuôn mặt…';
  Color _mau = Colors.white;
  bool _chupNgay = false;
  bool _dangQuet = false;
  final _anh = <Uint8List>[];

  bool get _laChuoi => widget.chuoi != null;

  @override
  void initState() {
    super.initState();
    _moCamera();
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _moCamera() async {
    try {
      final ds = await availableCameras();
      if (ds.isEmpty) throw CameraException('none', 'Không có camera');
      final truoc = ds.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => ds.first,
      );
      final cam = CameraController(
        truoc,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await cam.initialize();
      if (!mounted) {
        await cam.dispose();
        return;
      }
      setState(() => _cam = cam);
      _laChuoi ? _quetChuoi() : _quetDangKy();
    } on CameraException catch (e) {
      setState(
        () => _loi = e.code.contains('Denied') || e.code.contains('denied')
            ? 'Bạn chưa cho phép dùng camera. Hãy bật quyền camera cho ứng dụng / trang web rồi thử lại.'
            : 'Không mở được camera (${e.description ?? e.code}).',
      );
    }
  }

  Future<Uint8List> _chup() async {
    if (!mounted || _cam == null) throw _DaDong();
    final b = await (await _cam!.takePicture()).readAsBytes();
    if (!mounted) throw _DaDong();
    return b;
  }

  /// Chụp liên tục và gửi server kiểm tra; trả khung khi đạt 2 lần liên tiếp, khi bấm "Chụp ngay",
  /// hoặc khi quá [han] (server vẫn chấm và báo lý do nếu khung chưa đạt).
  Future<Uint8List> _choKhungDat(String tuThe, {Duration? han}) async {
    final dongHo = Stopwatch()..start();
    var dat = 0;
    while (true) {
      final b = await _chup();
      if (_chupNgay) {
        _chupNgay = false;
        return b;
      }
      var (ok, goiY) = (false, '');
      try {
        (ok, goiY) = await ref.read(kiemTraKhungProvider)(b, tuThe);
      } catch (_) {
        goiY =
            'Chưa kiểm tra được khung (mạng chậm?). Bạn có thể bấm Chụp ngay.';
      }
      if (!mounted) throw _DaDong();
      setState(() {
        _goiY = goiY;
        _mau = ok ? AppColors.success : AppColors.danger;
      });
      dat = ok ? dat + 1 : 0;
      if (dat >= 2 || (han != null && dongHo.elapsed > han)) return b;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  void _batDauBuoc(String loiNhac) => setState(() {
    _loiNhac = loiNhac;
    _mau = Colors.white;
    _goiY = 'Đang kiểm tra khuôn mặt…';
  });

  Future<void> _quetDangKy() async {
    setState(() => _dangQuet = true);
    try {
      while (_anh.length < widget.buoc.length) {
        final (loiNhac, tuThe) = widget.buoc[_anh.length];
        _batDauBuoc(loiNhac);
        final b = await _choKhungDat(tuThe);
        setState(() => _anh.add(b));
      }
    } on _DaDong {
      return;
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _loi = 'Chụp lỗi (${e.description ?? e.code}).');
      }
    }
    if (mounted) setState(() => _dangQuet = false);
  }

  Future<void> _quetChuoi() async {
    setState(() => _dangQuet = true);
    try {
      for (final (loiNhac, soKhung, tuThe) in widget.chuoi!) {
        _batDauBuoc(loiNhac);
        _anh.add(await _choKhungDat(tuThe, han: const Duration(seconds: 12)));
        // Các khung sau cách nhau 0,4 giây để bắt trọn lúc giữ tư thế / quay đầu.
        for (var i = 1; i < soKhung; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          _anh.add(await _chup());
        }
      }
      if (mounted) Navigator.of(context).pop(List.of(_anh));
    } on _DaDong {
      return;
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _loi = 'Chụp lỗi (${e.description ?? e.code}).');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final xong = !_laChuoi && _anh.length >= widget.buoc.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _laChuoi
              ? 'Quét khuôn mặt'
              : xong
              ? 'Xem lại ảnh'
              : 'Ảnh ${_anh.length + 1}/${widget.buoc.length}',
        ),
      ),
      body: SafeArea(
        child: _loi != null
            ? _ThongBao(_loi!)
            : xong
            ? _XemLai(
                anh: _anh,
                onChupLai: () {
                  setState(_anh.clear);
                  _quetDangKy();
                },
                onDung: () => Navigator.of(context).pop(List.of(_anh)),
              )
            : _cam == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(child: CameraPreview(_cam!)),
                        IgnorePointer(
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: _mau),
                            duration: const Duration(milliseconds: 250),
                            builder: (_, c, _) => CustomPaint(
                              painter: _OvalPainter(c ?? Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          _loiNhac ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _goiY,
                            style: TextStyle(
                              color: _mau == Colors.white
                                  ? Colors.white70
                                  : _mau == AppColors.success
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (!_laChuoi && _dangQuet) ...[
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'Chụp ngay',
                            outlined: true,
                            onPressed: () => _chupNgay = true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Phủ tối quanh một khung oval ở giữa; viền oval mang màu kết quả quét.
class _OvalPainter extends CustomPainter {
  _OvalPainter(this.mau);

  final Color mau;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.shortestSide * 0.62;
    final oval = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w,
      height: w * 1.3,
    );
    final nen = Path()..addRect(Offset.zero & size);
    final lo = Path()..addOval(oval);
    canvas.drawPath(
      Path.combine(PathOperation.difference, nen, lo),
      Paint()..color = Colors.black54,
    );
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = mau,
    );
  }

  @override
  bool shouldRepaint(covariant _OvalPainter old) => old.mau != mau;
}

class _XemLai extends StatelessWidget {
  const _XemLai({
    required this.anh,
    required this.onChupLai,
    required this.onDung,
  });

  final List<Uint8List> anh;
  final VoidCallback onChupLai;
  final VoidCallback onDung;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            childAspectRatio: 3 / 4,
            children: [
              for (final a in anh)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(a, fit: BoxFit.cover),
                ),
            ],
          ),
        ),
        AppButton(label: 'Dùng các ảnh này', onPressed: onDung),
        const SizedBox(height: 8),
        AppButton(label: 'Chụp lại', outlined: true, onPressed: onChupLai),
      ],
    ),
  );
}

class _ThongBao extends StatelessWidget {
  const _ThongBao(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: AppColors.warning,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
