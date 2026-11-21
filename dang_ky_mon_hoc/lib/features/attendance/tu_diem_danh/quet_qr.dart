import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';

/// Quét QR mã phòng trên màn chiếu của giảng viên. Hủy → null. Thay được trong test.
typedef QuetQr = Future<String?> Function(BuildContext context);

final quetQrProvider = Provider<QuetQr>(
  (ref) =>
      (context) => showDialog<String>(
        context: context,
        builder: (_) => const _HopQuetQr(),
      ),
);

class _HopQuetQr extends StatefulWidget {
  const _HopQuetQr();

  @override
  State<_HopQuetQr> createState() => _HopQuetQrState();
}

class _HopQuetQrState extends State<_HopQuetQr> {
  final _camera = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _xong = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _thay(BarcodeCapture c) {
    final ma = c.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (ma.isEmpty || _xong) return;
    _xong = true;
    Navigator.of(context).pop(ma);
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Quét QR trên màn chiếu',
    maxWidth: 400,
    actions: [
      DialogButton('Hủy', onPressed: () => Navigator.of(context).pop()),
    ],
    child: SizedBox(
      height: 320,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: MobileScanner(
          controller: _camera,
          onDetect: _thay,
          errorBuilder: (context, _) => Center(
            child: Text(
              'Không mở được camera. Hãy cho phép dùng camera, hoặc gõ mã hiện dưới QR.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ),
      ),
    ),
  );
}
