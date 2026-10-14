/// Tổng kết và thang chữ ở client (xem trước khi nhập, plan.md BR-10/11). Điểm lưu theo **phần trăm
/// điểm** (số nguyên, 8.45 → 845) để làm tròn nửa lên đúng như server, không dính sai số số thực.
library;

/// Kết quả đọc một ô điểm: [value] null khi để trống; [invalid] khi sai định dạng / ngoài 0–10.
class ScoreParse {
  const ScoreParse(this.value, {this.invalid = false});

  final int? value;
  final bool invalid;
}

/// `"8.5"`, `"8,25"`, `"10"` → phần trăm điểm. Rỗng → null; quá 2 chữ số thập phân hoặc ngoài 0–10 → lỗi.
ScoreParse parseScore(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return const ScoreParse(null);
  final m = RegExp(r'^(\d{1,2})(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return const ScoreParse(null, invalid: true);
  final v =
      int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
  return v > 1000 ? const ScoreParse(null, invalid: true) : ScoreParse(v);
}

/// `845` → `8.45`; `800` → `8.00`.
String formatScore(int h) =>
    '${h ~/ 100}.${(h % 100).toString().padLeft(2, '0')}';

/// API trả `"8.10"` (chuỗi thập phân) hoặc null.
int? scoreFromApi(Object? v) =>
    v == null ? null : parseScore(v.toString()).value;

/// BR-10: `QT×0.1 + GK×0.4 + CK×0.5`; thiếu GK → QT/CK = 20%/80%; thiếu CK → CK = 0; QT trống = 0;
/// chưa nhập gì → null. Làm tròn 2 chữ số, nửa lên.
int? tinhTongKet(int? qt, int? gk, int? ck) {
  if (qt == null && gk == null && ck == null) return null;
  final q = qt ?? 0;
  final c = ck ?? 0;
  final tuSo = gk == null ? q * 20 + c * 80 : q * 10 + gk * 40 + c * 50;
  return (tuSo + 50) ~/ 100;
}

/// BR-11: `(điểm chữ, GPA thang 4)`. Môn Đạt/Không đạt: ≥ 5.00 → `P` (không vào GPA), ngược lại `F`.
(String, double?) xepLoai(int? tongKet, {bool datKhongDat = false}) {
  if (tongKet == null) return ('', null);
  if (datKhongDat) return tongKet >= 500 ? ('P', null) : ('F', 0.0);
  if (tongKet >= 850) return ('A', 4.0);
  if (tongKet >= 700) return ('B', 3.0);
  if (tongKet >= 550) return ('C', 2.0);
  if (tongKet >= 400) return ('D', 1.0);
  return ('F', 0.0);
}
