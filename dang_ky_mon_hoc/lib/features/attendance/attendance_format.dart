import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../shared/widgets/status_chip.dart';
import '../registration/registration_format.dart';
import '../training/training_api.dart';

/// Nhãn 4 lựa chọn trên giao diện (BR-19): *Đi trễ* = `CO_MAT` + `di_tre`.
enum DiemDanhChon {
  coMat('Có mặt', 'CO_MAT', false),
  diTre('Đi trễ', 'CO_MAT', true),
  vangCoPhep('Vắng có phép', 'VANG_CO_PHEP', false),
  vangKhongPhep('Vắng không phép', 'VANG_KHONG_PHEP', false);

  const DiemDanhChon(this.label, this.trangThai, this.laDiTre);

  final String label;
  final String trangThai;
  final bool laDiTre;

  static DiemDanhChon of(String trangThai, bool diTre) => values.firstWhere(
    (c) =>
        c.trangThai == trangThai &&
        c.laDiTre == (trangThai == 'CO_MAT' && diTre),
    orElse: () => coMat,
  );
}

/// Chip trạng thái điểm danh; `null` = buổi chưa điểm danh.
Widget diemDanhChip(String? trangThai, bool diTre) {
  if (trangThai == null) {
    return StatusChip.of('Chưa điểm danh', StatusChip.gray);
  }
  final c = DiemDanhChon.of(trangThai, diTre);
  return StatusChip.of(c.label, switch (c) {
    DiemDanhChon.coMat => StatusChip.green,
    DiemDanhChon.diTre => StatusChip.yellow,
    DiemDanhChon.vangCoPhep => StatusChip.indigo,
    DiemDanhChon.vangKhongPhep => StatusChip.red,
  });
}

String buoiText(String buoi) => switch (buoi) {
  'SANG' => 'Sáng',
  'CHIEU' => 'Chiều',
  _ => 'Tối',
};

/// `Thứ 5, 01/10/2026`
String ngayDayDu(String ymd) {
  final d = DateTime.parse(ymd.substring(0, 10));
  return '${thuText(d.weekday + 1)}, ${formatYmd(ymd)}';
}

/// `Sáng · tiết 1`
String buoiTiet(Json s) =>
    '${buoiText(s.str('buoi'))} · tiết ${s.num0('tiet_bat_dau')}';

/// `Vắng không phép → Có mặt (đi trễ)` — trạng thái hiện tại đổi sang mong muốn của yêu cầu.
String doiText(Json yc) {
  final tu = DiemDanhChon.of(
    yc.str('trang_thai_hien_tai'),
    yc['di_tre_hien_tai'] == true,
  );
  final den = DiemDanhChon.of(
    yc.str('trang_thai_mong_muon'),
    yc['di_tre_mong_muon'] == true,
  );
  return '${tu.label} → ${den.label}';
}

Widget donChip(String trangThai) => switch (trangThai) {
  'CHO_DUYET' => StatusChip.of('Chờ duyệt', StatusChip.yellow),
  'DUYET' => StatusChip.of('Đã duyệt', StatusChip.green),
  _ => StatusChip.of('Từ chối', StatusChip.red),
};
