import '../auth/auth_user.dart';
import 'role_routes.dart';

const accountantRoutes = RoleRoutes(UserRole.accountant, [
  RouteDef('/accountant', 'Kế toán'),
  RouteDef('/accountant/config', 'Cấu hình học phí'),
  RouteDef('/accountant/tuition', 'Học phí'),
  RouteDef('/accountant/debts', 'Công nợ'),
  RouteDef('/accountant/reports', 'Báo cáo'),
  RouteDef('/accountant/notifications', 'Quản lý thông báo'),
]);
