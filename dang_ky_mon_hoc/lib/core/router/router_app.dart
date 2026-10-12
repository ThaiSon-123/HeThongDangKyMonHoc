import 'app_router.dart';
import 'routes_student.dart';
import 'routes_teacher.dart';

/// Router của entrypoint App (`lib/main_app.dart`) — chỉ SV + GV.
/// KHÔNG import routes_admin/pdt/accountant để màn hình 3 vai trò Web-only
/// không bị biên dịch vào bản App.
final appRouterProvider = createRouterProvider([studentRoutes, teacherRoutes]);
