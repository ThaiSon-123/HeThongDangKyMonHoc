// Đọc mã phòng ESP32 đang phát qua Bluetooth bằng Web Bluetooth (Chrome/Edge, docs/ke-hoach-gps-khuon-vien-va-esp32.md §4.4);
// nền tảng khác (app, Safari, Firefox) không hỗ trợ → Esp32Ble.hoTro == false, sinh viên gõ tay.
export 'esp32_ble_stub.dart' if (dart.library.js_interop) 'esp32_ble_web.dart';
