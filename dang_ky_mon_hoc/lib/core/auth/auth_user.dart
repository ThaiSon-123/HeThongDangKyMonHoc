/// Vai trò người dùng phía Flutter (khóa route: `/admin`, `/pdt`, `/accountant`, `/student`, `/teacher`).
enum UserRole {
  admin,
  pdt,
  accountant,
  student,
  teacher;

  /// Giá trị `role` của backend (enum `User.role`, plan.md mục 5) — ngược lại với [fromApi].
  String get apiValue => switch (this) {
    UserRole.admin => 'ADMIN',
    UserRole.pdt => 'PHONG_DAO_TAO',
    UserRole.accountant => 'KE_TOAN',
    UserRole.student => 'SINH_VIEN',
    UserRole.teacher => 'GIAO_VIEN',
  };

  /// Giá trị `role` backend trả về (enum `User.role`, plan.md mục 5).
  static UserRole fromApi(String role) => switch (role) {
    'ADMIN' => UserRole.admin,
    'PHONG_DAO_TAO' => UserRole.pdt,
    'KE_TOAN' => UserRole.accountant,
    'SINH_VIEN' => UserRole.student,
    'GIAO_VIEN' => UserRole.teacher,
    _ => throw FormatException('Vai trò không hợp lệ: $role'),
  };
}

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.admin => 'Quản trị',
    UserRole.pdt => 'Phòng đào tạo',
    UserRole.accountant => 'Kế toán',
    UserRole.student => 'Sinh viên',
    UserRole.teacher => 'Giáo viên',
  };

  /// Prefix route gốc của vai trò (mục 10.3 plan.md).
  String get homePath => '/$name';
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.email = '',
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;
  final String email;

  /// Khớp payload `user` của `POST /api/auth/login/` và `GET /api/profiles/me/`.
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'].toString(),
    username: json['username'] as String,
    fullName: (json['full_name'] as String?) ?? '',
    role: UserRole.fromApi(json['role'] as String),
    email: (json['email'] as String?) ?? '',
  );
}
