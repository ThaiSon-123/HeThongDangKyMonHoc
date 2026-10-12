import '../training/training_api.dart';

/// `1500000`, `"1500000.00"` → `1.500.000 ₫` (làm tròn đồng; ngăn nghìn bằng dấu chấm).
String formatVnd(Object? v) {
  final n = double.tryParse('${v ?? 0}') ?? 0;
  final s = n.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$buf ₫';
}

/// Số tiền (đồng) của một trường API, 0 nếu thiếu.
double vnd(Json j, String key) => double.tryParse(j.str(key)) ?? 0;

String hienThiLabel(String h) => switch (h) {
  'CHUA_TINH' => 'Chưa tính',
  'CON_NO' => 'Còn nợ',
  'CHO_HOAN_TIEN' => 'Chờ hoàn tiền',
  _ => 'Đã đóng đủ',
};

const phuongThucOptions = <(Object, String)>[
  ('TIEN_MAT', 'Tiền mặt'),
  ('CHUYEN_KHOAN', 'Chuyển khoản'),
  ('KHAC', 'Khác'),
];

String phuongThucLabel(String p) =>
    phuongThucOptions.firstWhere((o) => o.$1 == p, orElse: () => (p, p)).$2;
