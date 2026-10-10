import '../auth/auth_user.dart';
import 'role_routes.dart';

const adminRoutes = RoleRoutes(UserRole.admin, [
  RouteDef('/admin', 'Quản trị hệ thống'),
  RouteDef('/admin/accounts', 'Tài khoản'),
  RouteDef('/admin/permissions', 'Ma trận quyền'),
  RouteDef('/admin/config', 'Cấu hình hệ thống'),
  RouteDef('/admin/logs', 'Audit log'),
  RouteDef('/admin/backups', 'Sao lưu'),
  RouteDef('/admin/notifications', 'Quản lý thông báo'),
]);
