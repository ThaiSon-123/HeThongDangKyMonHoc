import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Dựng iframe ẩn chứa [html] rồi gọi `print()` của nó — tách khỏi canvas Flutter nên in đúng bố cục.
Future<void> printHtml(String html) async {
  final frame = web.document.createElement('iframe') as web.HTMLIFrameElement;
  frame.style
    ..position = 'fixed'
    ..width = '0'
    ..height = '0'
    ..border = '0';
  frame.srcdoc = html.toJS;
  final loaded = Completer<void>();
  frame.addEventListener('load', ((web.Event _) => loaded.complete()).toJS);
  web.document.body!.append(frame);
  await loaded.future;
  frame.contentWindow?.print();
  Timer(const Duration(minutes: 1), () => frame.remove());
}
