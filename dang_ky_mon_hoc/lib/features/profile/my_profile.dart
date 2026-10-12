import '../../core/auth/auth_user.dart';

/// Payload `GET/PATCH /api/profiles/me/` (plan.md mục 8.1). Trường học vụ chỉ có ở SV/GV.
class MyProfile {
  const MyProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.email,
    this.sdt = '',
    this.maSv,
    this.maGv,
    this.maNganh,
    this.tenNganh,
    this.khoaNhapHoc,
    this.maCtdt,
    this.tongTinChiYeuCau,
    this.gpa,
    this.tinChiTichLuy,
    this.xepLoai,
    this.khoaBoMon,
    this.hocVi,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String email;
  final String sdt;

  // Sinh viên
  final String? maSv;
  final String? maNganh;
  final String? tenNganh;
  final String? khoaNhapHoc;
  final String? maCtdt;
  final int? tongTinChiYeuCau;
  final String? gpa;
  final int? tinChiTichLuy;
  final String? xepLoai;

  // Giáo viên
  final String? maGv;
  final String? khoaBoMon;
  final String? hocVi;

  /// Có dòng "số điện thoại" để sửa không (chỉ SV/GV có hồ sơ).
  bool get hasPhone => role == UserRole.student || role == UserRole.teacher;

  /// Mã hiển thị dưới tên: `SV2023014 · CNTT · K2023` (SV), `GV001 · Khoa` (GV), `Vai trò · username`.
  String get subtitle => switch (role) {
    UserRole.student => [
      maSv,
      maNganh,
      khoaNhapHoc,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
    UserRole.teacher => [
      maGv,
      khoaBoMon,
    ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
    _ => '${role.label} · $username',
  };

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    final nganh = json['nganh'];
    final ctdt = json['ctdt'];
    return MyProfile(
      id: json['id'].toString(),
      username: json['username'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      role: UserRole.fromApi(json['role'] as String),
      email: (json['email'] as String?) ?? '',
      sdt: (json['sdt'] as String?) ?? '',
      maSv: json['ma_sv'] as String?,
      maGv: json['ma_gv'] as String?,
      maNganh: nganh is Map ? nganh['ma_nganh'] as String? : null,
      tenNganh: nganh is Map ? nganh['ten_nganh'] as String? : null,
      khoaNhapHoc: json['khoa_nhap_hoc'] as String?,
      maCtdt: ctdt is Map ? ctdt['ma_ctdt'] as String? : null,
      tongTinChiYeuCau: ctdt is Map
          ? (ctdt['tong_tin_chi_yeu_cau'] as num?)?.toInt()
          : null,
      gpa: json['gpa'] as String?,
      tinChiTichLuy: (json['tin_chi_tich_luy'] as num?)?.toInt(),
      xepLoai: json['xep_loai'] as String?,
      khoaBoMon: json['khoa'] as String?,
      hocVi: json['hoc_vi'] as String?,
    );
  }
}

/// Chữ cái đầu của 2 từ cuối ("Trần Hoàng Nam" → "HN"); một từ → 1 chữ; rỗng → "?".
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) return '?';
  final last = list.length >= 2 ? list.sublist(list.length - 2) : list;
  return last
      .map((p) => String.fromCharCode(p.runes.first).toUpperCase())
      .join();
}
