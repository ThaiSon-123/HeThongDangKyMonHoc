import '../auth/auth_user.dart';

/// Một route của vai trò. Màn hình thật gắn ở các pha sau (hiện là placeholder).
class RouteDef {
  const RouteDef(this.path, this.title);

  final String path;
  final String title;
}

/// Toàn bộ route của một vai trò — mỗi vai trò 1 file `routes_<role>.dart`
/// để bản App chỉ import file của SV/GV (mục 10.2 plan.md).
class RoleRoutes {
  const RoleRoutes(this.role, this.routes);

  final UserRole role;
  final List<RouteDef> routes;
}
