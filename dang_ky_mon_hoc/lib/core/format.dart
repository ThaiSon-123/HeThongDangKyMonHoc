/// Định dạng hiển thị (design.md 1.5): ngày `dd/MM/yyyy`, giờ theo Asia/Ho_Chi_Minh (UTC+7).
String _two(int n) => n.toString().padLeft(2, '0');

/// `12/01/2027 07:20` — luôn theo múi giờ Việt Nam bất kể múi giờ thiết bị.
String formatDateTime(DateTime d) {
  final v = d.toUtc().add(const Duration(hours: 7));
  return '${_two(v.day)}/${_two(v.month)}/${v.year} ${_two(v.hour)}:${_two(v.minute)}';
}
