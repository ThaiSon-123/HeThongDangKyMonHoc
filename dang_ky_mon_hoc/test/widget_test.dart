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

  test('mọi mục menu và tab dưới trỏ tới route có thật của đúng vai trò', () {
    for (final r in [
      adminRoutes,
      pdtRoutes,
      studentRoutes,
      teacherRoutes,
      accountantRoutes,
    ]) {
      final paths = r.routes.map((e) => e.path).toSet();
      final nav = [for (final g in r.groups) ...g.items, ...r.bottomTabs];
      for (final item in nav) {
        expect(
          paths,
          contains(item.path),
          reason: '${r.role.name}: ${item.label}',
        );
      }
      expect(
        r.bottomTabs.length,
        anyOf(0, 5),
        reason: 'thanh dưới có đúng 5 mục',
      );
    }
    // Chỉ SV/GV có thanh dưới (App); 3 vai trò Web-only dùng AppBar + Drawer.
    expect(studentRoutes.bottomTabs, isNotEmpty);
    expect(teacherRoutes.bottomTabs, isNotEmpty);
    expect(adminRoutes.bottomTabs, isEmpty);
  });
}
