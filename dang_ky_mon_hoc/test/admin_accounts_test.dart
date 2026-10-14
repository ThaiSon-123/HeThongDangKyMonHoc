import 'package:dang_ky_mon_hoc/core/auth/auth_user.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';

const _big = Size(1920, 1080);

Map<String, dynamic> row(
  int id,
  String username,
  String role, {
  String fullName = '',
  String? email,
  bool locked = false,
  String? lastLogin,
  bool? hasProfile,
  Map<String, dynamic>? profile,
}) => {
  'id': id,
  'username': username,
  'email': email ?? '$username@truong.edu.vn',
  'full_name': fullName,
  'role': role,
  'is_locked': locked,
  'is_active': true,
  'last_login': lastLogin,
  'date_joined': '2026-01-01T00:00:00+07:00',
  'has_profile': hasProfile,
  'profile': profile,
};

Map<String, dynamic> page(List<Map<String, dynamic>> rows, {int? count}) => {
  'count': count ?? rows.length,
  'next': null,
  'previous': null,
  'results': rows,
};

final _rows = [
  // id 9 = chính Admin đang đăng nhập (userJson dùng id 9).
  row(
    9,
    'admin',
    'ADMIN',
    fullName: 'Quản trị hệ thống',
    lastLogin: '2027-01-12T07:20:00+07:00',
  ),
  row(
    12,
    'sv2023014',
    'SINH_VIEN',
    fullName: 'Trần Hoàng Nam',
    hasProfile: true,
    lastLogin: '2027-01-12T06:50:00+07:00',
    profile: {
      'ma_sv': 'SV2023014',
      'ho_ten': 'Trần Hoàng Nam',
      'nganh': 'Công nghệ thông tin',
      'khoa_nhap_hoc': 'K2023',
      'ctdt': 'CNTT-K23',
      'gpa': '3.21',
      'tin_chi_tich_luy': 96,
    },
  ),
  row(13, 'sv2025011', 'SINH_VIEN', hasProfile: false),
  row(
    14,
    'gv005',
    'GIAO_VIEN',
    fullName: 'Nguyễn Thị Mai',
    locked: true,
    hasProfile: true,
  ),
];

FakeAdapter adminApi({Map<String, Handler> extra = const {}}) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('ADMIN', name: 'Quản trị hệ thống', username: 'admin'),
  ),
  'GET /users/': (_) => reply(200, page(_rows)),
  ...extra,
});

Future<void> openAccounts(WidgetTester t, FakeAdapter api) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: _big,
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go('/admin/accounts');
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text, {int index = 0}) async {
  final f = find.text(text).at(index);
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  group('Danh sách', () {
    testWidgets(
      'hiện bảng đúng mockup: cột, chip vai trò, hồ sơ, trạng thái, lần đăng nhập',
      (t) async {
        await openAccounts(t, adminApi());

        for (final text in [
          'TÊN ĐĂNG NHẬP',
          'ĐĂNG NHẬP GẦN NHẤT',
          'sv2023014',
          'Trần Hoàng Nam',
          'Quản trị',
          'Sinh viên',
          'Giáo viên',
          '✓ Đã có',
          'Chưa có hồ sơ',
          'Chưa đăng nhập',
          '12/01/2027 06:50', // giờ theo Asia/Ho_Chi_Minh
          'Đang khóa',
          '4 bản ghi',
          'Trang 1/1 · 25 dòng/trang',
        ]) {
          expect(find.text(text), findsWidgets, reason: text);
        }
        expect(find.text('—'), findsWidgets); // Admin không cần hồ sơ
      },
    );

    testWidgets('trống → thông báo; lỗi tải → "Thử lại" tải lại được', (
      t,
    ) async {
      var fail = true;
      final api = adminApi(
        extra: {
          'GET /users/': (_) => fail ? reply(500, {}) : reply(200, page([])),
        },
      );
      await openAccounts(t, api);
      expect(find.text('Không tải được dữ liệu'), findsOneWidget);

      fail = false;
      await tapText(t, 'Thử lại');

      expect(
        find.text('Không có tài khoản phù hợp với bộ lọc.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'lọc theo vai trò / trạng thái / tìm kiếm gửi đúng tham số, về trang 1',
      (t) async {
        final api = adminApi();
        await openAccounts(t, api);

        await tapText(t, 'Phòng đào tạo');
        expect(api.queries['GET /users/']!['role'], 'PHONG_DAO_TAO');
        expect(api.queries['GET /users/']!['page'], 1);

        await t.enterText(find.byType(TextField).first, 'nam');
        await t.pump(const Duration(milliseconds: 400)); // debounce 300ms
        await t.pumpAndSettle();
        expect(api.queries['GET /users/']!['search'], 'nam');

        await tapText(t, 'Tất cả', index: 0);
        expect(api.queries['GET /users/']!.containsKey('role'), isFalse);

        await t.tap(find.text('Tất cả').last); // ô Trạng thái
        await t.pumpAndSettle();
        await t.tap(find.text('Đang khóa').last);
        await t.pumpAndSettle();
        expect(api.queries['GET /users/']!['is_locked'], true);
      },
    );

    testWidgets('phân trang: Trang sau gọi page=2', (t) async {
      final api = adminApi(
        extra: {'GET /users/': (_) => reply(200, page(_rows, count: 60))},
      );
      await openAccounts(t, api);
      expect(find.text('Trang 1/3 · 25 dòng/trang'), findsOneWidget);

      await t.ensureVisible(find.byTooltip('Trang sau'));
      await t.tap(find.byTooltip('Trang sau'));
      await t.pumpAndSettle();

      expect(api.queries['GET /users/']!['page'], 2);
      expect(find.text('Trang 2/3 · 25 dòng/trang'), findsOneWidget);
    });
  });

  group('Khóa / mở khóa', () {
    testWidgets('khóa: xác nhận (nút đỏ) → PATCH is_locked=true → toast', (
      t,
    ) async {
      final api = adminApi(
        extra: {'PATCH /users/12/lock/': (_) => reply(200, _rows[1])},
      );
      await openAccounts(t, api);

      final switches = find.byType(Switch);
      await t.ensureVisible(switches.at(1));
      await t.tap(switches.at(1));
      await t.pumpAndSettle();

      expect(find.text('Khóa tài khoản?'), findsOneWidget);
      expect(
        find.textContaining(
          'Người dùng sẽ bị chặn đăng nhập, kể cả phiên đang đăng nhập.',
        ),
        findsOneWidget,
      );
      await tapText(t, 'Khóa tài khoản');

      expect(api.bodies['PATCH /users/12/lock/'], {'is_locked': true});
      expect(find.text('Đã khóa sv2023014.'), findsOneWidget);
    });

    testWidgets('mở khóa tài khoản đang bị khóa', (t) async {
      final api = adminApi(
        extra: {'PATCH /users/14/lock/': (_) => reply(200, _rows[3])},
      );
      await openAccounts(t, api);

      final switches = find.byType(Switch);
      await t.ensureVisible(switches.at(3));
      await t.tap(switches.at(3));
      await t.pumpAndSettle();
      expect(find.text('Mở khóa tài khoản?'), findsOneWidget);
      await tapText(t, 'Mở khóa');

      expect(api.bodies['PATCH /users/14/lock/'], {'is_locked': false});
      expect(find.text('Đã mở khóa gv005.'), findsOneWidget);
    });

    testWidgets('không tự khóa chính mình: công tắc của dòng mình bị vô hiệu', (
      t,
    ) async {
      await openAccounts(t, adminApi());

      expect(t.widget<Switch>(find.byType(Switch).at(0)).onChanged, isNull);
      expect(t.widget<Switch>(find.byType(Switch).at(1)).onChanged, isNotNull);
    });

    testWidgets('hủy xác nhận → không gọi API', (t) async {
      final api = adminApi();
      await openAccounts(t, api);

      final switches = find.byType(Switch);
      await t.ensureVisible(switches.at(1));
      await t.tap(switches.at(1));
      await t.pumpAndSettle();
      await tapText(t, 'Hủy');

      expect(api.bodies.containsKey('PATCH /users/12/lock/'), isFalse);
    });
  });

  group('Tạo tài khoản', () {
    testWidgets('tạo thành công: gửi đúng body, toast, tải lại danh sách', (
      t,
    ) async {
      var lists = 0;
      final api = adminApi(
        extra: {
          'GET /users/': (o) {
            // Màn Tổng quan (trang chủ Admin) cũng đếm tài khoản bằng `page_size=1` — không tính.
            if (o.queryParameters['page_size'] != 1) lists++;
            return reply(200, page(_rows));
          },
          'POST /users/': (_) => reply(201, row(20, 'gv006', 'GIAO_VIEN')),
        },
      );
      await openAccounts(t, api);

      await tapText(t, '+ Tạo tài khoản');
      expect(
        find.text('Phòng đào tạo sẽ tạo hồ sơ học vụ cho tài khoản này.'),
        findsOneWidget,
      );
      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await t.enterText(fields.at(0), 'gv006');
      await t.enterText(fields.at(1), 'gv006@truong.edu.vn');
      await t.enterText(fields.at(2), 'MatKhau12345');
      await tapText(t, 'Tạo tài khoản', index: 1); // nút trong hộp thoại

      expect(api.bodies['POST /users/'], {
        'username': 'gv006',
        'password': 'MatKhau12345',
        'role': 'GIAO_VIEN',
        'email': 'gv006@truong.edu.vn',
      });
      expect(find.text('Đã tạo tài khoản gv006.'), findsOneWidget);
      expect(lists, 2); // tải lại sau khi ghi
    });

    testWidgets('kiểm tra phía client: thiếu tên/email; mật khẩu ngắn', (
      t,
    ) async {
      final api = adminApi();
      await openAccounts(t, api);
      await tapText(t, '+ Tạo tài khoản');

      await tapText(t, 'Tạo tài khoản', index: 1);
      expect(find.text('Nhập tên đăng nhập và email.'), findsOneWidget);

      final fields = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await t.enterText(fields.at(0), 'gv006');
      await t.enterText(fields.at(1), 'gv006@truong.edu.vn');
      await t.enterText(fields.at(2), 'ngan');
      await tapText(t, 'Tạo tài khoản', index: 1);
      expect(
        find.text('Mật khẩu ban đầu phải có ít nhất 8 ký tự.'),
        findsOneWidget,
      );
      expect(api.bodies.containsKey('POST /users/'), isFalse);
    });

    testWidgets(
      'server từ chối (trùng tên): hiện thông điệp trong hộp thoại, không đóng',
      (t) async {
        final api = adminApi(
          extra: {
            'POST /users/': (_) => reply(400, {
              'username': ['Tên đăng nhập đã tồn tại.'],
            }),
          },
        );
        await openAccounts(t, api);
        await tapText(t, '+ Tạo tài khoản');
        final fields = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextField),
        );
        await t.enterText(fields.at(0), 'admin');
        await t.enterText(fields.at(1), 'a@truong.edu.vn');
        await t.enterText(fields.at(2), 'MatKhau12345');

        await tapText(t, 'Tạo tài khoản', index: 1);

        expect(find.text('Tên đăng nhập đã tồn tại.'), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
      },
    );
  });

  group('Sửa tài khoản', () {
    testWidgets('đổi vai trò: hỏi xác nhận rồi PATCH email + role', (t) async {
      final api = adminApi(
        extra: {'PATCH /users/12/': (_) => reply(200, _rows[1])},
      );
      await openAccounts(t, api);

      await tapText(t, 'Sửa', index: 1);
      expect(find.text('Sửa tài khoản sv2023014'), findsOneWidget);
      await t.tap(find.byType(DropdownButton<UserRole>).last);
      await t.pumpAndSettle();
      await t.tap(find.text('Kế toán').last);
      await t.pumpAndSettle();
      await tapText(t, 'Lưu');

      expect(find.text('Đổi vai trò?'), findsOneWidget);
      expect(find.textContaining('từ Sinh viên sang Kế toán'), findsOneWidget);
      await tapText(t, 'Đổi vai trò');

      expect(api.bodies['PATCH /users/12/'], {
        'email': 'sv2023014@truong.edu.vn',
        'role': 'KE_TOAN',
      });
      expect(find.text('Đã cập nhật tài khoản.'), findsOneWidget);
    });

    testWidgets('sửa chính mình: không đổi được vai trò; email bắt buộc', (
      t,
    ) async {
      await openAccounts(t, adminApi());

      await tapText(t, 'Sửa', index: 0);

      expect(
        find.text('Bạn không thể đổi vai trò của chính mình.'),
        findsOneWidget,
      );
      await t.enterText(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(TextField),
            )
            .first,
        '',
      );
      await tapText(t, 'Lưu');
      expect(find.text('Email là bắt buộc.'), findsOneWidget);
    });
  });

  group('Đặt lại mật khẩu', () {
    testWidgets('mật khẩu ngắn bị chặn; hợp lệ → POST + toast', (t) async {
      final api = adminApi(
        extra: {'POST /users/12/reset-password/': (_) => reply(204, {})},
      );
      await openAccounts(t, api);

      await tapText(t, 'Đặt lại MK', index: 1);
      expect(find.text('Đặt lại mật khẩu — sv2023014'), findsOneWidget);
      final field = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      );
      await t.enterText(field, 'ngan');
      await tapText(t, 'Đặt lại mật khẩu');
      expect(
        find.text('Mật khẩu mới phải có ít nhất 8 ký tự.'),
        findsOneWidget,
      );

      await t.enterText(field, 'MatKhauMoi99');
      await tapText(t, 'Đặt lại mật khẩu');

      expect(api.bodies['POST /users/12/reset-password/'], {
        'new_password': 'MatKhauMoi99',
      });
      expect(find.text('Đã đặt lại mật khẩu cho sv2023014.'), findsOneWidget);
    });
  });

  testWidgets(
    'bấm dòng → ngăn chi tiết: hồ sơ học vụ chỉ đọc / chưa có hồ sơ',
    (t) async {
      await openAccounts(t, adminApi());

      await tapText(t, 'Trần Hoàng Nam');
      expect(find.text('Hồ sơ học vụ'), findsOneWidget);
      for (final text in [
        'SV2023014',
        'Công nghệ thông tin',
        'CNTT-K23',
        '3.21',
        '96',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      expect(
        find.text('Chỉ xem. Chỉnh sửa hồ sơ tại Phòng đào tạo.'),
        findsOneWidget,
      );

      await t.tap(find.byTooltip('Đóng'));
      await t.pumpAndSettle();
      await tapText(t, 'sv2025011');
      expect(
        find.text(
          'Tài khoản này chưa có hồ sơ học vụ. Phòng đào tạo sẽ tạo hồ sơ.',
        ),
        findsOneWidget,
      );
    },
  );
}
