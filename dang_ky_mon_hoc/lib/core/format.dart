/// Định dạng hiển thị (design.md 1.5): ngày `dd/MM/yyyy`, giờ theo Asia/Ho_Chi_Minh (UTC+7).
String _two(int n) => n.toString().padLeft(2, '0');

/// `12/01/2027 07:20` — luôn theo múi giờ Việt Nam bất kể múi giờ thiết bị.
String formatDateTime(DateTime d) {
  final v = d.toUtc().add(const Duration(hours: 7));
  return '${_two(v.day)}/${_two(v.month)}/${v.year} ${_two(v.hour)}:${_two(v.minute)}';
}

/// `2027-01-12` (ngày của API) → `12/01/2027`; rỗng/null → `—`.
String formatYmd(String? ymd) {
  if (ymd == null || ymd.length < 10) return '—';
  return '${ymd.substring(8, 10)}/${ymd.substring(5, 7)}/${ymd.substring(0, 4)}';
}

/// Thời điểm ISO của API → `12/01/2027 07:20` (giờ Việt Nam); lỗi/rỗng → `—`.
String formatIso(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '—' : formatDateTime(d);
}
