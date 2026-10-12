import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'save_file.dart';

/// Hàm lưu tệp, thay được trong test (bản thật tải qua trình duyệt trên Web).
final saveFileProvider =
    Provider<Future<void> Function(String, List<int>, {String? mime})>(
      (ref) => saveFile,
    );
