import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> saveFile(String name, List<int> bytes, {String? mime}) async {
  final blob = web.Blob(
    [Uint8List.fromList(bytes).toJS].toJS,
    web.BlobPropertyBag(type: mime ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..download = name
    ..click();
  web.URL.revokeObjectURL(url);
}
