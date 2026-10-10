import '../auth/auth_user.dart';
import 'role_routes.dart';

const studentRoutes = RoleRoutes(UserRole.student, [
  RouteDef('/student', 'Sinh viên'),
  RouteDef('/student/profile', 'Hồ sơ sinh viên'),
  RouteDef('/student/register', 'Đăng ký môn học'),
  RouteDef('/student/auto-schedule', 'Tự động xếp lịch'),
  RouteDef('/student/schedule', 'Thời khóa biểu'),
  RouteDef('/student/grades', 'Bảng điểm'),
  RouteDef('/student/attendance', 'Điểm danh'),
  RouteDef('/student/tuition', 'Học phí'),
  RouteDef('/student/notifications', 'Thông báo'),
]);
