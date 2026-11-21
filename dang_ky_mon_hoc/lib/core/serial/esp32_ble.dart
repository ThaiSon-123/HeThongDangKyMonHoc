// Đọc mã phòng ESP32 đang phát qua Bluetooth (docs/ke-hoach-gps-khuon-vien-va-esp32.md §4.4):
// - app Android: quét ngầm tự động (flutter_blue_plus), Esp32Ble.tuDong == true;
// - web Chrome/Edge: Web Bluetooth, phải bấm chọn thiết bị (tuDong == false);
// - nền tảng khác (Safari, Firefox, desktop): Esp32Ble.hoTro == false, sinh viên gõ tay.
export 'esp32_ble_io.dart' if (dart.library.js_interop) 'esp32_ble_web.dart';
export 'esp32_loi.dart';
