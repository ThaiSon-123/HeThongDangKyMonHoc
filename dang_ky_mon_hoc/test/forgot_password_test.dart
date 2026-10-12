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
  await t.tap(find.widgetWithText(FilledButton, 'Gửi yêu cầu'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('3 bước: email → mã + mật khẩu mới → hoàn tất', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) =>
          reply(200, {'detail': 'ok', 'token': 'MQ.abc-123'}),
      'POST /auth/reset-password/': (_) => reply(204, {}),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);

    expect(find.text('Quên mật khẩu'), findsWidgets);
    await sendEmail(t, 'nam@truong.edu.vn');

    // Bước 2: thông điệp trung tính + mã dev được điền sẵn.
    expect(find.textContaining('Nếu email tồn tại'), findsOneWidget);
    expect(
      t.widget<TextField>(find.byType(TextField).first).controller!.text,
      'MQ.abc-123',
    );
    await t.enterText(find.byType(TextField).at(1), 'MatKhauMoi99');
    await t.enterText(find.byType(TextField).at(2), 'MatKhauMoi99');
    await t.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await t.pumpAndSettle();

    expect(find.text('Đã đặt lại mật khẩu'), findsOneWidget);
    expect(adapter.bodies['POST /auth/reset-password/'], {
      'token': 'MQ.abc-123',
      'new_password': 'MatKhauMoi99',
    });

    await t.tap(find.text('Về trang đăng nhập'));
    await t.pumpAndSettle();
    expect(find.text('Đăng nhập'), findsWidgets);
  });

  testWidgets(
    'prod (không có token trong response): ô mã để trống cho người dùng dán',
    (t) async {
      final adapter = FakeAdapter({
        'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
      });
      await pumpApp(t, router: webRouterProvider, adapter: adapter);
      await openForgot(t);

      await sendEmail(t, 'khong-ton-tai@truong.edu.vn');

      expect(find.textContaining('Nếu email tồn tại'), findsOneWidget);
      expect(
        t.widget<TextField>(find.byType(TextField).first).controller!.text,
        '',
      );
    },
  );

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

    expect(find.textContaining('thao tác quá nhanh'), findsOneWidget);
    expect(find.text('Gửi yêu cầu'), findsOneWidget);
  });

  testWidgets('mật khẩu yếu / không khớp: lỗi dưới từng ô', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);
    await sendEmail(t, 'nam@truong.edu.vn');

    await t.enterText(find.byType(TextField).at(0), 'MQ.xyz');
    await t.enterText(find.byType(TextField).at(1), 'yeu');
    await t.enterText(find.byType(TextField).at(2), 'khac');
    await t.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await t.pumpAndSettle();

    expect(
      find.text('Mật khẩu cần ít nhất 8 ký tự, có cả chữ và số.'),
      findsOneWidget,
    );
    expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
    expect(adapter.bodies.containsKey('POST /auth/reset-password/'), isFalse);
  });

  testWidgets('server từ chối mã: lỗi hiện dưới ô "Mã đặt lại"', (t) async {
    final adapter = FakeAdapter({
      'POST /auth/forgot-password/': (_) => reply(200, {'detail': 'ok'}),
      'POST /auth/reset-password/': (_) => reply(400, {
        'token': ['Token không hợp lệ hoặc đã hết hạn.'],
      }),
    });
    await pumpApp(t, router: webRouterProvider, adapter: adapter);
    await openForgot(t);
    await sendEmail(t, 'nam@truong.edu.vn');

    await t.enterText(find.byType(TextField).at(0), 'het-han');
    await t.enterText(find.byType(TextField).at(1), 'MatKhauMoi99');
    await t.enterText(find.byType(TextField).at(2), 'MatKhauMoi99');
    await t.tap(find.widgetWithText(FilledButton, 'Đặt lại mật khẩu'));
    await t.pumpAndSettle();

    expect(find.text('Token không hợp lệ hoặc đã hết hạn.'), findsOneWidget);
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
