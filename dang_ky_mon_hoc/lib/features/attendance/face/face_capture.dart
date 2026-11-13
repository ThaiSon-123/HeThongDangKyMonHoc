import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';

/// Mở màn chụp, mỗi phần tử [buoc] là một lời nhắc (vd "Nhìn thẳng"); trả ảnh JPEG theo thứ tự,
/// `null` nếu hủy. Thay được trong test (camera không chạy trong widget test).
typedef FaceCapture = Future<List<Uint8List>?> Function(
  BuildContext context,
  List<String> buoc,
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

/// Camera trước + khung oval. Chụp lần lượt từng tư thế, xem lại rồi mới dùng.
class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({super.key, required this.buoc});

  final List<String> buoc;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cam;
  String? _loi;
  bool _dangChup = false;
  final _anh = <Uint8List>[];

  @override
  void initState() {
    super.initState();
    _moCamera();
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
    } on CameraException catch (e) {
      setState(
        () => _loi = e.code.contains('Denied') || e.code.contains('denied')
            ? 'Bạn chưa cho phép dùng camera. Hãy bật quyền camera cho ứng dụng / trang web rồi thử lại.'
            : 'Không mở được camera (${e.description ?? e.code}).',
      );
    }
  }

  @override
  void dispose() {
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _chup() async {
    final cam = _cam;
    if (cam == null || _dangChup) return;
    setState(() => _dangChup = true);
    try {
      final f = await cam.takePicture();
      final bytes = await f.readAsBytes();
      setState(() => _anh.add(bytes));
    } on CameraException catch (e) {
      setState(() => _loi = 'Chụp lỗi (${e.description ?? e.code}).');
    } finally {
      if (mounted) setState(() => _dangChup = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final xong = _anh.length >= widget.buoc.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          xong ? 'Xem lại ảnh' : 'Ảnh ${_anh.length + 1}/${widget.buoc.length}',
        ),
      ),
      body: SafeArea(
        child: _loi != null
            ? _ThongBao(_loi!)
            : xong
            ? _XemLai(
                anh: _anh,
                onChupLai: () => setState(_anh.clear),
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
                        const IgnorePointer(child: _KhungOval()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          widget.buoc[_anh.length],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Đưa khuôn mặt vào khung, đủ sáng, không đeo khẩu trang.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'Chụp',
                          loading: _dangChup,
                          onPressed: _chup,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Phủ tối quanh một khung oval ở giữa.
class _KhungOval extends StatelessWidget {
  const _KhungOval();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _OvalPainter());
}

class _OvalPainter extends CustomPainter {
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
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
