import 'package:dang_ky_mon_hoc/core/auth/token_storage.dart';
import 'package:dang_ky_mon_hoc/core/router/router_app.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';

void goTo(WidgetTester t, String path) {
  GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
}

Future<void> tapButton(WidgetTester t, String label) async {
  final f = find.widgetWithText(FilledButton, label);
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

FakeAdapter studentApi({Map<String, Handler> extra = const {}}) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(200, studentProfile()),
  ...extra,
});

void main() {
  group('Hồ sơ sinh viên (Web)', () {
    testWidgets('hiện thông tin học vụ chỉ đọc đúng mockup', (t) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: studentApi(),
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      expect(find.text('THÔNG TIN HỌC VỤ · CHỈ ĐỌC'), findsOneWidget);
      for (final text in [
        'SV2023014',
        'Công nghệ thông tin',
        'K2023',
        'CNTT-K23 (130 tín chỉ)',
        '3.12',
        '96 / 130',
        'Giỏi',
        'sv2023014',
        'Thông tin liên hệ',
        'Đổi mật khẩu',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(find.text('Sinh viên'), findsWidgets); // chip vai trò
      // Trường học vụ không có ô nhập: chỉ email, sđt, 3 ô mật khẩu.
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('chưa có GPA → "Chưa có", tín chỉ 0 / tổng', (t) async {
      final api = FakeAdapter({
        'GET /profiles/me/': (_) => reply(200, {
          ...studentProfile(),
          'gpa': null,
          'xep_loai': null,
          'tin_chi_tich_luy': 0,
        }),
      });
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      expect(find.text('Chưa có'), findsOneWidget);
      expect(find.text('0 / 130'), findsOneWidget);
    });

    testWidgets('lỗi tải → hiện "Thử lại", bấm là tải lại được', (t) async {
      var calls = 0;
      final api = FakeAdapter({
        'GET /profiles/me/': (_) {
          calls++;
          // #1 khôi phục phiên (phải thành công); #2 lần tải hồ sơ đầu tiên → lỗi; #3 thử lại → OK.
          return calls == 2 ? reply(500, {}) : reply(200, studentProfile());
        },
      });
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      expect(find.text('Không tải được hồ sơ.'), findsOneWidget);
      expect(find.text('THÔNG TIN HỌC VỤ · CHỈ ĐỌC'), findsNothing);

      await t.tap(find.widgetWithText(FilledButton, 'Thử lại'));
      await t.pumpAndSettle();

      expect(find.text('THÔNG TIN HỌC VỤ · CHỈ ĐỌC'), findsOneWidget);
    });
  });

  group('Sửa email / số điện thoại', () {
    testWidgets('lưu thành công: bỏ khoảng trắng sđt, báo toast', (t) async {
      final api = studentApi(
        extra: {
          'PATCH /profiles/me/': (_) =>
              reply(200, {...studentProfile(), 'email': 'moi@truong.edu.vn'}),
        },
      );
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).at(0), 'moi@truong.edu.vn');
      await t.enterText(find.byType(TextField).at(1), '0987 654 321');
      await tapButton(t, 'Lưu thay đổi');

      expect(find.text('Đã cập nhật email và số điện thoại.'), findsOneWidget);
      expect(api.bodies['PATCH /profiles/me/'], {
        'email': 'moi@truong.edu.vn',
        'sdt': '0987654321',
      });
    });

    testWidgets('email / sđt sai: báo dưới ô, không gọi API', (t) async {
      final api = studentApi();
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).at(0), 'khong-phai-email');
      await t.enterText(find.byType(TextField).at(1), 'abc');
      await tapButton(t, 'Lưu thay đổi');

      expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
      expect(find.text('Số điện thoại không hợp lệ.'), findsOneWidget);
      expect(api.bodies.containsKey('PATCH /profiles/me/'), isFalse);
    });

    testWidgets('server báo lỗi field → hiện dưới đúng ô', (t) async {
      final api = studentApi(
        extra: {
          'PATCH /profiles/me/': (_) => reply(400, {
            'email': ['Email đã được dùng.'],
          }),
        },
      );
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField).at(0), 'trung@truong.edu.vn');
      await tapButton(t, 'Lưu thay đổi');

      expect(find.text('Email đã được dùng.'), findsOneWidget);
    });
  });

  group('Đổi mật khẩu', () {
    Future<void> fill(
      WidgetTester t,
      String old,
      String neu,
      String conf,
    ) async {
      await t.enterText(find.byType(TextField).at(2), old);
      await t.enterText(find.byType(TextField).at(3), neu);
      await t.enterText(find.byType(TextField).at(4), conf);
    }

    testWidgets('kiểm tra phía client: bỏ trống / yếu / không khớp', (t) async {
      final api = studentApi();
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      await fill(t, '', 'yeu', 'khac');
      await tapButton(t, 'Đổi mật khẩu');

      expect(find.text('Nhập mật khẩu hiện tại.'), findsOneWidget);
      expect(
        find.text('Mật khẩu cần ít nhất 8 ký tự, có cả chữ và số.'),
        findsOneWidget,
      );
      expect(find.text('Mật khẩu nhập lại không khớp.'), findsOneWidget);
      expect(api.bodies.containsKey('POST /auth/change-password/'), isFalse);
    });

    testWidgets('sai mật khẩu hiện tại: lỗi dưới ô, không đăng xuất', (
      t,
    ) async {
      final api = studentApi(
        extra: {
          'POST /auth/change-password/': (_) => reply(400, {
            'old_password': ['Mật khẩu hiện tại không đúng.'],
          }),
        },
      );
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      await fill(t, 'SaiMatKhau1', 'MatKhauMoi99', 'MatKhauMoi99');
      await tapButton(t, 'Đổi mật khẩu');

      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(await TokenStorage().readRefreshToken(), isNotNull);
    });

    testWidgets('thành công: toast → đăng xuất → về màn đăng nhập', (t) async {
      final api = studentApi(
        extra: {
          'POST /auth/change-password/': (_) => reply(204, {}),
          'POST /auth/logout/': (_) => reply(204, {}),
        },
      );
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      await fill(t, 'MatKhauCu123', 'MatKhauMoi99', 'MatKhauMoi99');
      await tapButton(t, 'Đổi mật khẩu');
      expect(find.textContaining('Đã đổi mật khẩu'), findsOneWidget);

      await t.pump(const Duration(milliseconds: 1300));
      await t.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsWidgets);
      expect(await TokenStorage().readRefreshToken(), isNull);
      expect(api.bodies['POST /auth/change-password/'], {
        'old_password': 'MatKhauCu123',
        'new_password': 'MatKhauMoi99',
      });
    });
  });

  testWidgets('Hồ sơ giáo viên: mã GV, học vị, khoa / viện', (t) async {
    final api = FakeAdapter({
      'GET /profiles/me/': (_) => reply(200, teacherProfile()),
    });
    await pumpApp(t, router: webRouterProvider, adapter: api, tokens: signedIn);
    goTo(t, '/teacher/profile');
    await t.pumpAndSettle();

    for (final text in [
      'Mã giáo viên',
      'GV001',
      'Học vị',
      'Thạc sĩ',
      'Khoa / viện',
      'Giáo viên',
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.text('Mã sinh viên'), findsNothing);
  });

  group('Hồ sơ trên App (hẹp)', () {
    testWidgets('header navy + danh sách dòng + Đăng xuất cuối trang', (
      t,
    ) async {
      final api = studentApi(
        extra: {'POST /auth/logout/': (_) => reply(204, {})},
      );
      await pumpApp(
        t,
        router: appRouterProvider,
        adapter: api,
        tokens: signedIn,
        size: const Size(390, 844),
      );
      goTo(t, '/student/profile');
      await t.pumpAndSettle();

      expect(find.text('Thông tin cá nhân và bảo mật'), findsOneWidget);
      expect(find.text('Khóa'), findsOneWidget); // nhãn ngắn của App
      expect(find.text('3.12 · Giỏi'), findsOneWidget);

      final logout = find.widgetWithText(OutlinedButton, 'Đăng xuất');
      await t.ensureVisible(logout);
      await t.tap(logout);
      await t.pumpAndSettle();
      expect(find.text('Đăng nhập'), findsWidgets);
    });
  });
}
