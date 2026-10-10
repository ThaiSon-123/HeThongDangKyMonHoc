import '../auth/auth_user.dart';
import 'role_routes.dart';

const teacherRoutes = RoleRoutes(UserRole.teacher, [
  RouteDef('/teacher', 'Giáo viên'),
  RouteDef('/teacher/profile', 'Hồ sơ giáo viên'),
  RouteDef('/teacher/classes', 'Lớp giảng dạy'),
  RouteDef('/teacher/attendance', 'Điểm danh'),
  RouteDef('/teacher/grades', 'Nhập điểm'),
  RouteDef('/teacher/notifications', 'Thông báo'),
]);
