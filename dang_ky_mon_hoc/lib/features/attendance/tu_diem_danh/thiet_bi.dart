import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/serial/esp32_ble.dart';

/// Đọc mã phòng ESP32 qua Bluetooth. `tuDong`: quét ngầm được (app Android); false thì phải đợi
/// sinh viên bấm (web). Thay được trong test.
typedef DocEsp32 = ({bool hoTro, bool tuDong, Future<String?> Function() doc});

final docEsp32Provider = Provider<DocEsp32>(
  (ref) =>
      (hoTro: Esp32Ble.hoTro, tuDong: Esp32Ble.tuDong, doc: Esp32Ble.docMa),
);

/// Lỗi GPS hiện thẳng cho người dùng (chưa cấp quyền, tắt định vị…).
class GpsLoi implements Exception {
  const GpsLoi(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Một mẫu GPS gửi lên server nguyên dạng thô (server tự lọc, lấy trung vị — KH §5).
typedef MauGps = Map<String, Object>;

/// Lấy mẫu GPS liên tục trong [giay] giây; [onMau] báo từng mẫu để hiện độ chính xác.
/// Thay được trong test.
typedef LayMauGps = Future<List<MauGps>> Function(
  int giay,
  void Function(MauGps mau) onMau,
);

final layMauGpsProvider = Provider<LayMauGps>((ref) => _layMauGps);

Future<List<MauGps>> _layMauGps(int giay, void Function(MauGps) onMau) async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const GpsLoi('Định vị (GPS) đang tắt. Hãy bật định vị rồi thử lại.');
  }
  var quyen = await Geolocator.checkPermission();
  if (quyen == LocationPermission.denied) {
    quyen = await Geolocator.requestPermission();
  }
  if (quyen == LocationPermission.denied ||
      quyen == LocationPermission.deniedForever) {
    throw const GpsLoi(
      'Bạn chưa cho phép truy cập vị trí. Hãy bật quyền vị trí cho ứng dụng / trang web.',
    );
  }
  final ketThuc = DateTime.now().add(Duration(seconds: giay));
  final mau = <MauGps>[];
  // Gọi lặp getCurrentPosition: trên web watchPosition chỉ báo khi vị trí đổi nên có thể quá ít mẫu.
  while (DateTime.now().isBefore(ketThuc)) {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final m = <String, Object>{
        'lat': p.latitude,
        'lng': p.longitude,
        'acc': max(p.accuracy, 0.01),
        'ts': p.timestamp.millisecondsSinceEpoch,
        'mock': p.isMocked,
      };
      mau.add(m);
      onMau(m);
    } on TimeoutException {
      // máy chưa bắt được vệ tinh: thử lại tới khi hết giờ
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }
  if (mau.isEmpty) {
    throw const GpsLoi(
      'Không lấy được vị trí. Hãy ra gần cửa sổ hoặc bật Wi-Fi rồi thử lại.',
    );
  }
  return mau;
}

/// Mã máy cố định (để server phát hiện một máy điểm danh cho nhiều người).
/// Web: nằm trong bộ nhớ trình duyệt, xóa dữ liệu trang là đổi (KH §15).
final deviceIdProvider = FutureProvider<String>((ref) async {
  const storage = FlutterSecureStorage();
  final cu = await storage.read(key: 'device_id');
  if (cu != null) return cu;
  final r = Random.secure();
  final moi = List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  await storage.write(key: 'device_id', value: moi);
  return moi;
});

String get nenTang => kIsWeb ? 'web' : 'android';
