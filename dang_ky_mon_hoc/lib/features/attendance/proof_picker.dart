import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tệp minh chứng đã chọn (ảnh jpg/png hoặc PDF, tối đa 5 MB — backend kiểm lại).
class PickedProof {
  const PickedProof(this.name, this.bytes);

  final String name;
  final List<int> bytes;
}

const maxProofBytes = 5 * 1024 * 1024;

/// Hộp chọn tệp, thay được trong test.
final proofPickerProvider = Provider<Future<PickedProof?> Function()>(
  (ref) => () async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    return f == null ? null : PickedProof(f.name, await f.readAsBytes());
  },
);
