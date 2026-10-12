import 'package:dio/dio.dart';
import 'package:dang_ky_mon_hoc/core/auth/token_storage.dart';
import 'package:dang_ky_mon_hoc/core/router/router_app.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

Future<void> signIn(WidgetTester tester, String user, String pass) async {
  await tester.enterText(find.byType(TextField).at(0), user);
  await tester.enterText(find.byType(TextField).at(1), pass);
  await tester.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> loginOk(String role, {String name = 'Trần Hoàng Nam'}) => {
  'access': 'a-new',
  'refresh': 'r-new',
  'user': userJson(role, name: name),
};

void main() {
  group('Bố cục', () {
    testWidgets('rộng ≥ 900px: panel thương hiệu + thẻ đăng nhập (Web)', (
      t,
    ) async {
      await pumpApp(t, router: webRouterProvider, adapter: FakeAdapter());

      expect(find.textContaining('Quản lý học tập gọn gàng'), findsOneWidget);
      expect(find.text('Dùng tài khoản do nhà trường cấp.'), findsOneWidget);
      expect(find.text('Quên mật khẩu?'), findsOneWidget);
    });

    testWidgets('hẹp: header điện thoại, không có panel (App)', (t) async {
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: FakeAdapter(),
        size: const Size(390, 844),
      );

      expect(find.textContaining('ngay trên điện thoại'), findsOneWidget);
      expect(find.textContaining('Quản lý học tập gọn gàng'), findsNothing);
    });
  });

  group('Lỗi đăng nhập hiển thị đúng banner (không lộ mã kỹ thuật)', () {
    Future<void> expectBanner(
      WidgetTester t,
      ResponseBody Function(RequestOptions) res,
      String text,
    ) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: FakeAdapter({'POST /auth/login/': res}),
      );
      await signIn(t, 'sv01', 'Matkhau123');
      expect(find.textContaining(text), findsOneWidget);
      expect(find.textContaining('TAI_KHOAN'), findsNothing);
      expect(find.textContaining('401'), findsNothing);
    }

    testWidgets('sai thông tin', (t) async {
      await expectBanner(
        t,
        (_) => reply(401, {'detail': 'x'}),
        'Tên đăng nhập hoặc mật khẩu không đúng.',
      );
    });

    testWidgets('tài khoản bị khóa', (t) async {
      await expectBanner(
        t,
        (_) => apiError(403, 'TAI_KHOAN_BI_KHOA'),
        'Tài khoản đã bị khóa.',
      );
    });

    testWidgets('quá nhiều lần thử (429)', (t) async {
      await expectBanner(
        t,
        (_) => apiError(429, 'QUA_NHIEU_YEU_CAU'),
        'Bạn thao tác quá nhanh.',
      );
    });

    testWidgets('mất kết nối', (t) async {
      await expectBanner(
        t,
        (o) => throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        ),
        'Không thể kết nối máy chủ',
      );
    });
  });

  testWidgets('bỏ trống: báo lỗi dưới từng ô, không gọi API', (t) async {
    final adapter = FakeAdapter();
    await pumpApp(t, router: webRouterProvider, adapter: adapter);

    await t.tap(find.widgetWithText(FilledButton, 'Đăng nhập'));
    await t.pumpAndSettle();

    expect(find.text('Nhập tên đăng nhập.'), findsOneWidget);
    expect(find.text('Nhập mật khẩu.'), findsOneWidget);
    expect(adapter.log, isEmpty);
  });

  testWidgets('nút hiện/ẩn mật khẩu', (t) async {
    await pumpApp(t, router: webRouterProvider, adapter: FakeAdapter());
    TextField pass() => t.widget<TextField>(find.byType(TextField).at(1));
    expect(pass().obscureText, isTrue);

    await t.tap(find.byTooltip('Hiện mật khẩu'));
    await t.pump();

    expect(pass().obscureText, isFalse);
  });

  group('Đăng nhập thành công → vào trang chủ đúng vai trò', () {
    testWidgets('sinh viên: lưu token, vào khung Sinh viên', (t) async {
      final adapter = FakeAdapter({
        'POST /auth/login/': (_) => reply(200, loginOk('SINH_VIEN')),
        'GET /profiles/me/': (_) => reply(200, studentProfile()),
      });
      await pumpApp(t, router: webRouterProvider, adapter: adapter);

      await signIn(t, 'sv2023014', 'Matkhau123');

      expect(find.text('Tổng quan'), findsWidgets);
      expect(find.text('Cổng sinh viên'), findsOneWidget);
      expect(await TokenStorage().readRefreshToken(), 'r-new');
      expect(adapter.bodies['POST /auth/login/'], {
        'username': 'sv2023014',
        'password': 'Matkhau123',
      });
    });

    testWidgets('Admin trên App → màn "chỉ dùng trên trình duyệt"', (t) async {
      final adapter = FakeAdapter({
        'POST /auth/login/': (_) => reply(200, loginOk('ADMIN', name: 'QT')),
        'GET /profiles/me/': (_) => reply(200, userJson('ADMIN')),
      });
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: adapter,
        size: const Size(390, 844),
      );

      await signIn(t, 'admin', 'Matkhau123');

      expect(
        find.text('Vai trò này chỉ dùng trên trình duyệt'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Đăng xuất'), findsOneWidget);
    });
  });
}
