import 'dart:math';

import '../../core/format.dart';
import '../training/training_api.dart';

/// UUID v4 cho header `Idempotency-Key` (mỗi lần bấm "Đăng ký" một key mới).
String newIdempotencyKey() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String hex(int from, int to) => b
      .sublist(from, to)
      .map((x) => x.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// `07/09/2026 – 17/01/2027`: thời gian học của lớp. Lớp chưa có ngày riêng thì lấy ngày của học kỳ
/// ([macDinhBatDau]/[macDinhKetThuc]); thiếu cả hai → `null`.
String? thoiGianHoc(
  Object? batDau,
  Object? ketThuc, {
  Object? macDinhBatDau,
  Object? macDinhKetThuc,
}) {
  final bd = batDau ?? macDinhBatDau;
  final kt = ketThuc ?? macDinhKetThuc;
  if (bd == null || kt == null) return null;
  return '${formatYmd('$bd')} – ${formatYmd('$kt')}';
}

String thuText(int thu) => thu == 8 ? 'CN' : 'Thứ $thu';

/// `Thứ 2 · tiết 1–3; Thứ 4 · tiết 6–8`
String lichText(List<dynamic> lich) => lich.isEmpty
    ? 'Chưa có lịch'
    : lich
          .map((e) => Json.from(e as Map))
          .map(
            (l) =>
                '${thuText(l.num0('thu'))} · tiết ${l.num0('tiet_bat_dau')}–${l.num0('tiet_ket_thuc')}',
          )
          .join('; ');

String phongText(List<dynamic> lich) {
  final phong = lich.map((e) => (e as Map)['phong'].toString()).toSet();
  return phong.isEmpty ? '—' : phong.join(', ');
}

String khoiText(String k) => switch (k) {
  'chung' => 'Chung',
  'co_so_nganh' => 'Cơ sở ngành',
  'chuyen_nganh' => 'Chuyên ngành',
  'tu_chon' => 'Tự chọn',
  'tot_nghiep' => 'Tốt nghiệp',
  _ => k,
};

String loaiMonText(String l) => l == 'bat_buoc' ? 'Bắt buộc' : 'Tự chọn';
