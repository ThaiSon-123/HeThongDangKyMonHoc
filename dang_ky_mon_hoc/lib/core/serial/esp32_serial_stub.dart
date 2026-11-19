class Esp32Serial {
  static bool get hoTro => false;
  bool get daKetNoi => false;
  Future<void> ketNoi() async => throw UnsupportedError(
    'Chỉ kết nối ESP32 được trên Chrome/Edge máy tính.',
  );
  Future<void> gui(String ma) async {}
  Future<void> dong() async {}
}
