import 'package:dang_ky_mon_hoc/core/router/router_app.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

Future<void> openForgot(WidgetTester t) async {
  await t.tap(find.text('Quên mật khẩu?'));
  await t.pumpAndSettle();
}

Future<void> sendEmail(WidgetTester t, String email) async {
  await t.enterText(find.byType(TextField).first, email);
  await t.tap(find.widgetWithText(FilledButton, 'Gửi mã xác thực'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('3 bước: email → mã + mật khẩu mới → hoàn tất', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) =>
          reply(200, {'detail': 'ok', 'code': '123456'}),
      'POST /auth/reset-password/': (_) => reply(204, {}),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);

    expect(find.text('Quên mật khẩu'), findsWidgets);
    await sendEmail(t, 'nam@truong.edu.vn');

    // Bước 2: báo đã gửi tới email + mã dev được điền sẵn.
    expect(
      find.textContaining('đã được gửi tới nam@truong.edu.vn'),
      findsOneWidget,
    );
    expect(
      t.widget<TextField>(find.byType(TextField).first).controller!.text,
      '123456',
    );
    await t.enterText(find.byType(TextField).at(1), 'MatKhauMoi99');
    await t.enterText(find.byType(TextField).at(2), 'MatKhauMoi99');
    await t.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await t.pumpAndSettle();

    expect(find.text('Đã đặt lại mật khẩu'), findsOneWidget);
    expect(adapter.bodies['POST /auth/reset-password/'], {
      'email': 'nam@truong.edu.vn',
      'code': '123456',
      'new_password': 'MatKhauMoi99',
    });

    await t.tap(find.text('Về trang đăng nhập'));
    await t.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);
  });

  testWidgets(
    'prod (không có mã trong response): ô mã để trống cho người dùng nhập',
    (t) async {
      final adapter = FakeAdapter({
        'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
      });
      await pumpApp(t, router: webRouterProvider, adapter: adapter);
      await openForgot(t);

      await sendEmail(t, 'nam@truong.edu.vn');

      expect(find.textContaining('đã được gửi tới'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
    },
  );

  testWidgets('bước 2: "Gửi lại mã" gọi lại API và báo đã gửi', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);
    await sendEmail(t, 'nam@truong.edu.vn');

    await t.tap(find.text('Gửi lại mã'));
    await t.pumpAndSettle();

    expect(find.textContaining('Đã gửi lại mã xác thực mới'), findsOneWidget);
    expect(
      adapter.log.where((l) => l.startsWith('POST /auth/forgot-password/')),
      hasLength(2),
    );
  });

  testWidgets('email không có trong hệ thống: lỗi dưới ô, ở lại bước 1', (
    t,
  ) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => reply(400, {
        'email': ['Email này không có trong hệ thống.'],
      }),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);

    await sendEmail(t, 'khong-ton-tai@truong.edu.vn');

    expect(find.text('Email này không có trong hệ thống.'), findsOneWidget);
    expect(find.text('Gửi mã xác thực'), findsOneWidget);
  });

  testWidgets('email sai định dạng: báo ngay, không gọi API', (t) async {
    final adapter = FakeAdapter();
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);

    await sendEmail(t, 'khong-phai-email');

    expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
    expect(adapter.log, isEmpty);
  });

  testWidgets('quá 3 lần/15 phút → banner rate limit, ở lại bước 1', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => apiError(429, 'QUA_NHIEU_YEU_CAU'),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);

    await sendEmail(t, 'nam@truong.edu.vn');

    expect(find.textContaining('quá 3 lần trong 15 phút'), findsOneWidget);
    expect(find.text('Gửi mã xác thực'), findsOneWidget);
  });

  testWidgets('mật khẩu yếu / không khớp: lỗi dưới từng ô', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);
    await sendEmail(t, 'nam@truong.edu.vn');

    await t.enterText(find.byType(TextField).at(0), '12345');
    await t.enterText(find.byType(TextField).at(1), 'yeu');
    await t.enterText(find.byType(TextField).at(2), 'khac');
    await t.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await t.pumpAndSettle();

    expect(
      find.text('Mật khẩu cần ít nhất 8 ký tự, có cả chữ và số.'),
      findsOneWidget,
    );
    expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
    expect(find.text('Nhập đủ 6 chữ số của mã xác thực.'), findsOneWidget);
    expect(adapter.bodies.containsKey('POST /auth/reset-password/'), isFalse);
  });

  testWidgets('server từ chối mã: lỗi hiện dưới ô "Mã xác thực"', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
      'POST /auth/reset-password/': (_) => reply(400, {
        'code': ['Mã xác thực không đúng hoặc đã hết hạn.'],
      }),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);
    await sendEmail(t, 'nam@truong.edu.vn');

    await t.enterText(find.byType(TextField).at(0), '000000');
    await t.enterText(find.byType(TextField).at(1), 'MatKhauMoi99');
    await t.enterText(find.byType(TextField).at(2), 'MatKhauMoi99');
    await t.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await t.pumpAndSettle();

    expect(
      find.text('Mã xác thực không đúng hoặc đã hết hạn.'),
      findsOneWidget,
    );
    expect(find.text('Đã đặt lại mật khẩu'), findsNothing);
  });

  testWidgets('App (hẹp): header "Quên mật khẩu" + nút quay lại', (t) async {
    await pumpApp(
      t,
      router: appRouterProvider,
      adapter: FakeAdapter(),
      size: const Size(390, 844),
    );
    await openForgot(t);

    expect(find.text('Đặt lại qua email'), findsOneWidget);
    expect(find.text('Email'), findsWidgets);

    await t.tap(find.byTooltip('Quay lại'));
    await t.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
