import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

// package:web chưa có Web Serial → khai báo đúng phần cần dùng.
@JS('navigator.serial')
external _Serial? get _serial;

extension type _Serial._(JSObject _) implements JSObject {
  external JSPromise<_Port> requestPort();
}

extension type _Port._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(_Opts options);
  external JSPromise<JSAny?> close();
  external web.WritableStream? get writable;
}

extension type _Opts._(JSObject _) implements JSObject {
  external factory _Opts({int baudRate});
}

/// Một cổng serial tới ESP32 chạy `firmware/esp32_beacon`: mỗi dòng gửi xuống là một mã để phát qua BLE.
class Esp32Serial {
  static bool get hoTro => _serial != null;

  _Port? _port;
  bool get daKetNoi => _port != null;

  /// Trình duyệt hiện hộp chọn cổng; phải gọi từ thao tác bấm của người dùng.
  Future<void> ketNoi() async {
    final p = await _serial!.requestPort().toDart;
    await p.open(_Opts(baudRate: 115200)).toDart;
    _port = p;
  }

  /// Lỗi (rút dây, cổng bị đóng) → ném ra và coi như đã ngắt.
  Future<void> gui(String ma) async {
    final w = _port?.writable?.getWriter();
    if (w == null) return;
    try {
      await w.write(utf8.encode('$ma\n').toJS).toDart;
    } catch (_) {
      _port = null;
      rethrow;
    } finally {
      w.releaseLock();
    }
  }

  Future<void> dong() async {
    final p = _port;
    _port = null;
    try {
      await p?.close().toDart;
    } catch (_) {} // cổng đã mất (rút dây) thì không còn gì để đóng
  }
}
