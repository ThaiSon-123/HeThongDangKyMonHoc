import '../../../core/auth/auth_user.dart';

/// Một tài khoản trong danh sách của Admin (`GET /api/users/`, plan.md mục 8.1).
class AdminUser {
  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.isLocked,
    this.lastLogin,
    this.hasProfile,
    this.profile,
  });

  final int id;
  final String username;
  final String email;
  final String fullName;
  final UserRole role;
  final bool isLocked;
  final DateTime? lastLogin;

  /// `null` = vai trò không cần hồ sơ (Admin, PĐT, KT).
  final bool? hasProfile;
  final Map<String, dynamic>? profile;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final last = json['last_login'] as String?;
    return AdminUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      role: UserRole.fromApi(json['role'] as String),
      isLocked: json['is_locked'] as bool? ?? false,
      lastLogin: last == null ? null : DateTime.parse(last),
      hasProfile: json['has_profile'] as bool?,
      profile: json['profile'] is Map
          ? Map<String, dynamic>.from(json['profile'] as Map)
          : null,
    );
  }

  /// Các dòng "Hồ sơ học vụ" ở ngăn chi tiết (chỉ đọc).
  List<(String, String)> get profileRows {
    final p = profile;
    if (p == null) return const [];
    String v(String key) =>
        (p[key]?.toString().isNotEmpty ?? false) ? p[key].toString() : '—';
    return role == UserRole.student
        ? [
            ('Mã sinh viên', v('ma_sv')),
            ('Ngành', v('nganh')),
            ('Khóa', v('khoa_nhap_hoc')),
            ('Chương trình đào tạo', v('ctdt')),
            ('GPA', p['gpa'] == null ? 'Chưa có' : v('gpa')),
            ('Tín chỉ tích lũy', v('tin_chi_tich_luy')),
          ]
        : [
            ('Mã giáo viên', v('ma_gv')),
            ('Khoa / viện', v('khoa_bo_mon')),
            ('Học vị', v('hoc_vi')),
          ];
  }
}

/// Một trang kết quả phân trang của DRF (`count` + `results`).
class PageResult<T> {
  const PageResult({required this.count, required this.items});

  final int count;
  final List<T> items;

  int pages(int pageSize) => count == 0 ? 1 : (count / pageSize).ceil();
}

/// Bộ lọc danh sách tài khoản.
class AccountsFilter {
  const AccountsFilter({
    this.search = '',
    this.role,
    this.locked,
    this.page = 1,
  });

  final String search;
  final UserRole? role;

  /// `true` = đang khóa, `false` = hoạt động, `null` = tất cả.
  final bool? locked;
  final int page;

  static const pageSize = 25;

  AccountsFilter copyWith({
    String? search,
    Object? role = _keep,
    Object? locked = _keep,
    int? page,
  }) => AccountsFilter(
    search: search ?? this.search,
    role: identical(role, _keep) ? this.role : role as UserRole?,
    locked: identical(locked, _keep) ? this.locked : locked as bool?,
    page: page ?? this.page,
  );

  static const _keep = Object();
}
