import 'package:dang_ky_mon_hoc/app.dart';
import 'package:dang_ky_mon_hoc/core/router/router_app.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/core/router/routes_accountant.dart';
import 'package:dang_ky_mon_hoc/core/router/routes_admin.dart';
import 'package:dang_ky_mon_hoc/core/router/routes_pdt.dart';
import 'package:dang_ky_mon_hoc/core/router/routes_student.dart';
import 'package:dang_ky_mon_hoc/core/router/routes_teacher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Web khởi động và hiển thị màn đăng nhập', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: DkmhApp(routerProvider: webRouterProvider)),
    );
    await tester.pump();

    expect(find.text('Đăng nhập'), findsWidgets);
  });

  testWidgets('App (SV/GV) khởi động và hiển thị màn đăng nhập', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(child: DkmhApp(routerProvider: appRouterProvider)),
    );
    await tester.pump();

    expect(find.text('Đăng nhập'), findsWidgets);
  });

  test('mọi route nằm dưới prefix của vai trò (redirect dựa vào homePath)', () {
    for (final r in [
      adminRoutes,
      pdtRoutes,
      studentRoutes,
      teacherRoutes,
      accountantRoutes,
    ]) {
      expect(r.routes.first.path, '/${r.role.name}');
      for (final d in r.routes) {
        expect(d.path.startsWith('/${r.role.name}'), isTrue, reason: d.path);
      }
    }
  });
}
