/// Vai trò người dùng — khớp với `role` backend trả về (mục 13 plan.md).
enum UserRole { admin, pdt, accountant, student, teacher }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.admin => 'Quản trị',
        UserRole.pdt => 'Phòng đào tạo',
        UserRole.accountant => 'Kế toán',
        UserRole.student => 'Sinh viên',
        UserRole.teacher => 'Giáo viên',
      };

  /// Prefix route gốc của vai trò (mục 15.3 plan.md).
  String get homePath => '/$name';
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
  });

  final String id;
  final String username;
  final String fullName;
  final UserRole role;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        username: json['username'] as String,
        fullName: (json['full_name'] as String?) ?? '',
        role: UserRole.values.byName(json['role'] as String),
      );
}
