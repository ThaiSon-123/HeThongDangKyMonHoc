/// Lỗi Bluetooth hiện thẳng cho sinh viên (tắt Bluetooth, chưa cấp quyền…).
class Esp32Loi implements Exception {
  const Esp32Loi(this.message);
  final String message;
  @override
  String toString() => message;
}
