import 'dart:js_interop';

// Trùng UUID trong firmware/esp32_beacon/esp32_beacon.ino.
const _service = '8f1c0001-5b7e-4c2a-9d3e-6a1f2b3c4d5e';
const _char = '8f1c0002-5b7e-4c2a-9d3e-6a1f2b3c4d5e';

// package:web chưa có Web Bluetooth → khai báo đúng phần cần dùng.
@JS('navigator.bluetooth')
external _Bluetooth? get _bluetooth;

extension type _Bluetooth._(JSObject _) implements JSObject {
  external JSPromise<_Device> requestDevice(JSObject options);
}

extension type _Device._(JSObject _) implements JSObject {
  external _Gatt get gatt;
}

extension type _Gatt._(JSObject _) implements JSObject {
  external JSPromise<_Gatt> connect();
  external void disconnect();
  external JSPromise<_Service> getPrimaryService(String uuid);
}

extension type _Service._(JSObject _) implements JSObject {
  external JSPromise<_Char> getCharacteristic(String uuid);
}

extension type _Char._(JSObject _) implements JSObject {
  external JSPromise<JSDataView> readValue();
}

class Esp32Ble {
  static bool get hoTro => _bluetooth != null;

  /// Trình duyệt hiện hộp chọn (chỉ liệt kê ESP32 của dự án); phải gọi từ thao tác bấm.
  /// Người dùng bấm Hủy → null; lỗi khác ném ra.
  static Future<String?> docMa() async {
    final _Device d;
    try {
      d = await _bluetooth!
          .requestDevice(
            {
                  'filters': [
                    {
                      'services': [_service],
                    },
                  ],
                }.jsify()!
                as JSObject,
          )
          .toDart;
    } catch (e) {
      if ('$e'.contains('NotFoundError')) return null;
      rethrow;
    }
    final g = await d.gatt.connect().toDart;
    try {
      final s = await g.getPrimaryService(_service).toDart;
      final c = await s.getCharacteristic(_char).toDart;
      final v = (await c.readValue().toDart).toDart;
      return String.fromCharCodes(
        v.buffer.asUint8List(v.offsetInBytes, v.lengthInBytes),
      ).trim();
    } finally {
      g.disconnect();
    }
  }
}
