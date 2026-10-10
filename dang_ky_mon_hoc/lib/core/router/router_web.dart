import 'app_router.dart';
import 'routes_accountant.dart';
import 'routes_admin.dart';
import 'routes_pdt.dart';
import 'routes_student.dart';
import 'routes_teacher.dart';

/// Router của entrypoint Web (`lib/main.dart`) — đủ 5 vai trò.
final webRouterProvider = createRouterProvider([
  adminRoutes,
  pdtRoutes,
  studentRoutes,
  teacherRoutes,
  accountantRoutes,
]);
