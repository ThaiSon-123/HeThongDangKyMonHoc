import '../auth/auth_user.dart';
import 'role_routes.dart';

const pdtRoutes = RoleRoutes(UserRole.pdt, [
  RouteDef('/pdt', 'Phòng đào tạo'),
  RouteDef('/pdt/majors', 'Ngành'),
  RouteDef('/pdt/curriculums', 'Chương trình đào tạo'),
  RouteDef('/pdt/courses', 'Học phần'),
  RouteDef('/pdt/semesters', 'Học kỳ'),
  RouteDef('/pdt/classes', 'Lớp học phần'),
  RouteDef('/pdt/registrations', 'Đăng ký môn học'),
  RouteDef('/pdt/grade-sheets', 'Duyệt điểm'),
  RouteDef('/pdt/reports', 'Báo cáo'),
  RouteDef('/pdt/notifications', 'Quản lý thông báo'),
]);
