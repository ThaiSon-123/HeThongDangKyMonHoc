import 'package:dang_ky_mon_hoc/core/router/router_app.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';

void goTo(WidgetTester t, String path) {
  GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
}

FakeAdapter api(Map<String, dynamic> profile) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(200, profile),
  'POST /auth/logout/': (_) => reply(204, {}),
});

String currentPath(WidgetTester t) =>
    GoRouter.of(t.element(find.byType(Scaffold).first)).state.uri.path;

void main() {
  group('Sidebar Web (≥ 1024px)', () {
    testWidgets('Sinh viên: nhóm menu theo mockup + khối người dùng ghim đáy', (
      t,
    ) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
      );

      for (final text in [
        'TỔNG QUAN',
        'ĐĂNG KÝ HỌC',
        'HỌC VỤ',
        'KHÁC',
        'Đăng ký môn học',
        'Tạo TKB tự động',
        'Chương trình đào tạo',
        'Học phí',
        'Cổng sinh viên',
        'Trần Hoàng Nam',
        'SV2023014 · CNTT · K2023',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Đăng xuất'), findsWidgets);
    });

    testWidgets('bấm mục menu → đổi trang, giữ nguyên khung', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
      );

      await t.tap(find.text('Học phí').first);
      await t.pumpAndSettle();

      expect(currentPath(t), '/student/tuition');
      expect(find.text('Học phí — đang phát triển'), findsOneWidget);
      expect(find.text('Cổng sinh viên'), findsOneWidget); // sidebar còn nguyên
    });

    testWidgets('breadcrumb "Vai trò › Trang" ở đầu trang', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
      );
      goTo(t, '/student/grades');
      await t.pumpAndSettle();

      expect(find.text('›'), findsOneWidget);
      expect(find.text('Điểm'), findsWidgets); // tiêu đề trang + mục menu
    });

    testWidgets('Đăng xuất ở sidebar → về màn đăng nhập', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
      );

      await t.tap(find.text('Đăng xuất').first);
      await t.pumpAndSettle();

      expect(find.text('Dùng tài khoản do nhà trường cấp.'), findsOneWidget);
    });

    testWidgets('không vào được trang của vai trò khác', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
      );

      goTo(t, '/admin/accounts');
      await t.pumpAndSettle();

      expect(currentPath(t), '/student');
    });

    testWidgets('Giáo viên: nhóm GIẢNG DẠY + Nhập điểm', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(teacherProfile()),
        tokens: signedIn,
      );

      for (final text in [
        'GIẢNG DẠY',
        'Lớp phụ trách',
        'Nhập điểm',
        'Cổng giáo viên',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
    });

    testWidgets('Admin / PĐT / KT có menu riêng', (t) async {
      for (final (role, user, texts) in [
        (
          'ADMIN',
          'admin',
          ['NGƯỜI DÙNG', 'Ma trận quyền', 'Sao lưu', 'Quản trị'],
        ),
        (
          'PHONG_DAO_TAO',
          'pdt1',
          ['DANH MỤC', 'Hồ sơ SV / GV', 'TỔ CHỨC ĐÀO TẠO', 'Duyệt điểm'],
        ),
        ('KE_TOAN', 'kt1', ['HỌC PHÍ', 'Công nợ', 'Cấu hình học phí']),
      ]) {
        await pumpApp(
          t,
          router: webRouterProvider,
          adapter: api(userJson(role, name: 'Người dùng', username: user)),
          tokens: signedIn,
        );
        for (final text in texts) {
          expect(find.text(text), findsWidgets, reason: '$role: $text');
        }
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  testWidgets(
    'Admin: bấm avatar mở hộp thoại tài khoản (không có trang hồ sơ)',
    (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(
          userJson('ADMIN', name: 'Quản trị hệ thống', username: 'admin'),
        ),
        tokens: signedIn,
      );

      await t.tap(find.byTooltip('Tài khoản'));
      await t.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Tên đăng nhập'), findsOneWidget);
      expect(find.text('admin'), findsWidgets);
      expect(find.text('Đổi mật khẩu'), findsWidgets);
      // Admin không có số điện thoại: chỉ email + 3 ô mật khẩu.
      expect(find.byType(TextField), findsNWidgets(4));

      await t.tap(find.byTooltip('Đóng'));
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );

  group('Thanh icon (600–1024px)', () {
    testWidgets('thu gọn: chỉ icon, nhãn thành tooltip', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
        size: const Size(800, 900),
      );

      expect(find.text('ĐĂNG KÝ HỌC'), findsNothing); // tiêu đề nhóm ẩn
      expect(find.byTooltip('Đăng ký môn học'), findsOneWidget);
    });
  });

  group('App SV/GV (< 600px)', () {
    testWidgets('SV: header navy + thanh dưới 5 mục, chọn mục = đổi trang', (
      t,
    ) async {
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
        size: const Size(390, 844),
      );

      for (final label in ['Trang chủ', 'Đăng ký', 'TKB', 'Học phí', 'Hồ sơ']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Cổng sinh viên'), findsOneWidget);

      await t.tap(find.text('Đăng ký'));
      await t.pumpAndSettle();
      expect(currentPath(t), '/student/register');
    });

    testWidgets('GV: tab Tổng quan · Lớp · Điểm danh · TKB · Nhập điểm', (
      t,
    ) async {
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: api(teacherProfile()),
        tokens: signedIn,
        size: const Size(390, 844),
      );

      for (final label in [
        'Tổng quan',
        'Lớp',
        'Điểm danh',
        'TKB',
        'Nhập điểm',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('Cổng giáo viên'), findsOneWidget);
    });

    testWidgets('màn cấp sâu: header gọn có nút quay lại, ẩn thanh dưới', (
      t,
    ) async {
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
        size: const Size(390, 844),
      );
      goTo(t, '/student/grades');
      await t.pumpAndSettle();

      expect(find.byTooltip('Quay lại'), findsOneWidget);
      expect(find.text('Trang chủ'), findsNothing);

      await t.tap(find.byTooltip('Quay lại'));
      await t.pumpAndSettle();
      expect(currentPath(t), '/student');
    });

    testWidgets('bấm avatar → trang Hồ sơ', (t) async {
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: api(studentProfile()),
        tokens: signedIn,
        size: const Size(390, 844),
      );

      await t.tap(find.text('HN')); // avatar cam ở header
      await t.pumpAndSettle();

      expect(currentPath(t), '/student/profile');
    });
  });

  testWidgets('Admin trên Web hẹp (< 600px): AppBar + Drawer chứa menu', (
    t,
  ) async {
    await pumpApp(
      t,
      router: webRouterProvider,
      adapter: api(userJson('ADMIN', username: 'admin')),
      tokens: signedIn,
      size: const Size(420, 800),
    );

    expect(find.byType(AppBar), findsOneWidget);
    await t.tap(find.byTooltip('Open navigation menu'));
    await t.pumpAndSettle();

    expect(find.text('Ma trận quyền'), findsOneWidget);
  });
}
