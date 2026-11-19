// Gửi mã phòng xuống ESP32 qua Web Serial (Chrome/Edge máy tính, docs/ke-hoach-gps-khuon-vien-va-esp32.md §4.2);
// nền tảng khác không hỗ trợ (Esp32Serial.hoTro == false).
export 'esp32_serial_stub.dart'
    if (dart.library.js_interop) 'esp32_serial_web.dart';
