import 'dart:async';
import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'esp32_loi.dart';

/// App Android: quét ngầm quảng bá `DD-<mã>` của ESP32 (firmware/esp32_beacon), lấy mã từ tên,
/// không cần kết nối, không hiện hộp chọn. Nền tảng khác (desktop, test) không hỗ trợ.
class Esp32Ble {
  static bool get hoTro => Platform.isAndroid;

  /// Tự quét được, không cần sinh viên bấm chọn thiết bị.
  static bool get tuDong => hoTro;

  /// Bật Bluetooth nếu đang tắt (Android hiện hộp hỏi), quét tối đa [thoiGian]. Không thấy ESP32 → null.
  static Future<String?> docMa({
    Duration thoiGian = const Duration(seconds: 8),
  }) async {
    if (!await FlutterBluePlus.isSupported) {
      throw const Esp32Loi('Máy này không có Bluetooth.');
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      try {
        await FlutterBluePlus.turnOn(timeout: 20);
      } catch (_) {
        // sinh viên từ chối bật hoặc chưa cấp quyền: báo bên dưới
      }
    }
    try {
      await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      throw const Esp32Loi(
        'Bluetooth đang tắt hoặc chưa được cấp quyền. Hãy bật Bluetooth rồi thử lại.',
      );
    }

    final thay = Completer<String?>();
    final sub = FlutterBluePlus.onScanResults.listen((ds) {
      for (final r in ds) {
        final ten = r.advertisementData.advName;
        if (!ten.startsWith('DD-')) continue;
        final ma = ten.substring(3).trim();
        // "CHUACO" = ESP32 chưa nhận mã từ máy giảng viên.
        if (ma.length == 8 && ma != 'CHUACO' && !thay.isCompleted) {
          thay.complete(ma);
        }
      }
    });
    try {
      await FlutterBluePlus.startScan(withKeywords: ['DD-'], timeout: thoiGian);
      // Quét dừng (hết thoiGian) mà chưa thấy ESP32 → null.
      final hetGio = FlutterBluePlus.isScanning
          .firstWhere((dangQuet) => !dangQuet)
          .then((_) => null);
      return await Future.any([thay.future, hetGio]);
    } finally {
      await sub.cancel();
      await FlutterBluePlus.stopScan();
    }
  }
}
