import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/features/admin/system/backups_screen.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

// "Hôm nay" cố định: 12/01/2027 09:00 (giờ máy).
final _homNay = DateTime(2027, 1, 12, 9);

FakeAdapter adminApi(Map<String, Handler> extra) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('ADMIN', name: 'Quản trị hệ thống', username: 'admin'),
  ),
  ...extra,
});

Future<void> openAdmin(WidgetTester t, FakeAdapter api, String path) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: bigScreen,
    overrides: [clockProvider.overrideWithValue(() => _homNay)],
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
  await t.pumpAndSettle();
}

Map<String, dynamic> o(bool co, [String? gioiHan]) => {
  'co': co,
  'gioi_han': gioiHan,
};

Map<String, dynamic> quyen(
  String nhom,
  String ten,
  List<Map<String, dynamic>> cells,
) => {
  'nhom': nhom,
  'quyen': ten,
  'ADMIN': cells[0],
  'PHONG_DAO_TAO': cells[1],
  'SINH_VIEN': cells[2],
  'GIAO_VIEN': cells[3],
  'KE_TOAN': cells[4],
};

Map<String, dynamic> cauHinh({
  String maxVang = '20',
  String nganHang = '',
  Map<String, dynamic>? sua,
}) => {
  'items': [
    {
      'khoa': 'max_absent_pct',
      'nhom': 'Điểm danh',
      'mo_ta': '',
      'mac_dinh': '20',
      'gia_tri': maxVang,
      'cap_nhat_luc': null,
    },
    {
      'khoa': 'so_ngay_cho_phep_nhap_diem',
      'nhom': 'Nhập điểm',
      'mo_ta': '',
      'mac_dinh': '14',
      'gia_tri': '14',
      'cap_nhat_luc': null,
    },
    {
      'khoa': 'backup_retention_days',
      'nhom': 'Sao lưu',
      'mo_ta': '',
      'mac_dinh': '30',
      'gia_tri': '30',
      'cap_nhat_luc': null,
    },
    for (final k in ['ck_ngan_hang', 'ck_so_tai_khoan', 'ck_chu_tai_khoan'])
      {
        'khoa': k,
        'nhom': 'Nhận chuyển khoản học phí',
        'mo_ta': '',
        'mac_dinh': '',
        'gia_tri': k == 'ck_ngan_hang' ? nganHang : '',
        'cap_nhat_luc': null,
      },
  ],
  'sua_lan_cuoi': sua,
};

Map<String, dynamic> file(String ten, String luc, int bytes) => {
  'ten': ten,
  'dung_luong': bytes,
  'tao_luc': luc,
};

void main() {
  test('định dạng dung lượng', () {
    expect(formatBytes(412 * 1024 * 1024), '412 MB');
    expect(formatBytes(163051), '159 KB');
    expect(formatBytes(900), '900 B');
  });

  group('Ma trận quyền', () {
    FakeAdapter api() => adminApi({
      'GET /admin/permissions/': (_) => reply(200, {
        'vai_tro': [
          'ADMIN',
          'PHONG_DAO_TAO',
          'SINH_VIEN',
          'GIAO_VIEN',
          'KE_TOAN',
        ],
        'results': [
          quyen('Tài khoản và hệ thống', 'Tạo/khóa tài khoản', [
            o(true),
            o(false),
            o(false),
            o(false),
            o(false),
          ]),
          quyen('Tài khoản và hệ thống', 'Audit log', [
            o(true, 'tất cả'),
            o(true, 'đào tạo'),
            o(false),
            o(false),
            o(true, 'tài chính'),
          ]),
          quyen('Tài chính', 'Xem học phí', [
            o(false),
            o(false),
            o(true, 'của mình'),
            o(false),
            o(true),
          ]),
        ],
      }),
    });

    testWidgets('bảng chỉ đọc: nhóm, vai trò, ✓ ✕ và ô giới hạn', (t) async {
      await openAdmin(t, api(), '/admin/permissions');
      expect(find.text('QUẢN TRỊ'), findsOneWidget);
      expect(find.text('PHÒNG ĐÀO TẠO'), findsOneWidget);
      expect(find.text('TÀI KHOẢN VÀ HỆ THỐNG'), findsOneWidget);
      expect(find.text('TÀI CHÍNH'), findsOneWidget);
      expect(find.text('Audit log'), findsOneWidget);
      expect(
        find.text('Tất cả'),
        findsOneWidget,
      ); // ô giới hạn viết hoa chữ đầu
      expect(find.text('Đào tạo'), findsOneWidget);
      expect(find.text('Của mình'), findsWidgets);
      expect(find.text('✓'), findsWidgets);
      expect(find.text('✕'), findsWidgets);
      // Chỉ đọc: không có ô nhập, công tắc hay nút Lưu.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Lưu'), findsNothing);
    });

    testWidgets('nút Mở trang Tài khoản chuyển sang /admin/accounts', (
      t,
    ) async {
      final a = adminApi({
        ...api().routes,
        'GET /users/': (_) => reply(200, pageOf([])),
      });
      await openAdmin(t, a, '/admin/permissions');
      await tapText(t, 'Mở trang Tài khoản');
      expect(a.log.any((l) => l.startsWith('GET /users/')), isTrue);
    });
  });

  group('Cấu hình hệ thống', () {
    testWidgets('4 nhóm, 6 ô; lưu từng nhóm chỉ gửi khóa của nhóm đó', (
      t,
    ) async {
      var daLuu = false;
      final api = adminApi({
        'GET /admin/config/': (_) => reply(
          200,
          daLuu
              ? cauHinh(
                  maxVang: '25',
                  sua: {'boi': 'admin', 'luc': '2027-01-06T09:05:00+07:00'},
                )
              : cauHinh(),
        ),
        'PATCH /admin/config/': (_) {
          daLuu = true;
          return reply(200, cauHinh(maxVang: '25'));
        },
      });
      await openAdmin(t, api, '/admin/config');
      for (final s in [
        'Điểm danh',
        'Nhập điểm',
        'Sao lưu',
        'Nhận chuyển khoản học phí',
      ]) {
        expect(find.text(s), findsWidgets);
      }
      expect(find.text('Tỷ lệ vắng tối đa (%)'), findsOneWidget);
      expect(find.text('Từ 0 đến 100. Mặc định 20.'), findsOneWidget);
      expect(
        find.text('Đặt lại mặc định'),
        findsNWidgets(3),
      ); // nhóm QR không có
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.textContaining('Sửa lần cuối'), findsNothing);

      await t.enterText(find.byType(TextField).first, '25');
      await tapText(t, 'Lưu nhóm này', index: 0);
      expect(api.bodies['PATCH /admin/config/'], {'max_absent_pct': '25'});
      expect(find.textContaining('Đã lưu cấu hình'), findsOneWidget);
      expect(
        find.textContaining('Sửa lần cuối bởi admin · 06/01/2027 09:05'),
        findsOneWidget,
      );
    });

    testWidgets('Đặt lại mặc định điền lại giá trị mặc định, chưa lưu', (
      t,
    ) async {
      final api = adminApi({
        'GET /admin/config/': (_) => reply(200, cauHinh(maxVang: '35')),
      });
      await openAdmin(t, api, '/admin/config');
      expect(find.text('35'), findsOneWidget);
      await tapText(t, 'Đặt lại mặc định', index: 0);
      expect(find.text('35'), findsNothing);
      expect(find.text('20'), findsOneWidget);
      expect(api.log.any((l) => l.startsWith('PATCH')), isFalse);
    });

    testWidgets('lỗi kiểm tra của server hiện ngay dưới ô nhập', (t) async {
      final api = adminApi({
        'GET /admin/config/': (_) => reply(200, cauHinh()),
        'PATCH /admin/config/': (_) => reply(400, {
          'ck_so_tai_khoan': ['Chỉ gồm chữ số.'],
        }),
      });
      await openAdmin(t, api, '/admin/config');
      final oSoTk = find.byType(TextField).at(4);
      await t.ensureVisible(oSoTk);
      await t.enterText(oSoTk, '12a');
      await tapText(t, 'Lưu nhóm này', index: 3);
      expect(find.text('Chỉ gồm chữ số.'), findsWidgets);
      expect(find.textContaining('Đã lưu cấu hình'), findsNothing);
    });
  });

  group('Sao lưu', () {
    Map<String, dynamic> ds({
      bool chay = false,
      List<Map<String, dynamic>>? f,
    }) => {
      'dang_chay': chay,
      'so_ngay_giu': 14,
      'results':
          f ??
          [
            file(
              'hpsv_20270112_020000.dump',
              '2027-01-12T02:00:00+07:00',
              412 * 1024 * 1024,
            ),
            file(
              'hpsv_20270111_020000.dump',
              '2027-01-11T02:00:00+07:00',
              409 * 1024 * 1024,
            ),
          ],
    };

    testWidgets(
      'thẻ gần nhất, lịch tự động, danh sách; không có Phục hồi/Tải xuống',
      (t) async {
        await openAdmin(
          t,
          adminApi({'GET /admin/backups/': (_) => reply(200, ds())}),
          '/admin/backups',
        );
        expect(
          find.text('12/01/2027 02:00'),
          findsNWidgets(2),
        ); // thẻ + dòng đầu bảng
        expect(find.text('02:00 hằng ngày'), findsOneWidget);
        expect(find.text('Giữ các bản sao lưu trong 14 ngày'), findsOneWidget);
        expect(find.text('hpsv_20270111_020000.dump'), findsOneWidget);
        expect(find.text('409 MB'), findsOneWidget);
        expect(find.text('2 bản ghi'), findsOneWidget);
        expect(find.textContaining('chưa có bản sao lưu mới'), findsNothing);
        expect(find.text('Phục hồi'), findsNothing);
        expect(find.text('Tải xuống'), findsNothing);
        expect(
          find.textContaining('hãy liên hệ bộ phận kỹ thuật'),
          findsOneWidget,
        );
      },
    );

    testWidgets('quá 48 giờ chưa có bản mới → cảnh báo vàng', (t) async {
      await openAdmin(
        t,
        adminApi({
          'GET /admin/backups/': (_) => reply(
            200,
            ds(
              f: [
                file(
                  'hpsv_20270108_020000.dump',
                  '2027-01-08T02:00:00+07:00',
                  1024,
                ),
              ],
            ),
          ),
        }),
        '/admin/backups',
      );
      expect(
        find.textContaining('Đã 103 giờ chưa có bản sao lưu mới'),
        findsOneWidget,
      );
    });

    testWidgets('chưa có bản sao lưu nào → cảnh báo và bảng trống', (t) async {
      await openAdmin(
        t,
        adminApi({'GET /admin/backups/': (_) => reply(200, ds(f: []))}),
        '/admin/backups',
      );
      expect(find.text('Chưa có bản sao lưu nào.'), findsWidgets);
      expect(find.textContaining('Hãy kiểm tra lịch tự động'), findsOneWidget);
      expect(find.text('0 bản ghi'), findsOneWidget);
    });

    testWidgets('Tạo bản sao lưu ngay → POST rồi tải lại danh sách', (t) async {
      var daTao = false;
      final api = adminApi({
        'GET /admin/backups/': (_) => reply(
          200,
          daTao
              ? ds()
              : ds(
                  f: [
                    file(
                      'hpsv_20270112_020000.dump',
                      '2027-01-12T02:00:00+07:00',
                      1024 * 1024,
                    ),
                  ],
                ),
        ),
        'POST /admin/backups/': (_) {
          daTao = true;
          return reply(202, {'trang_thai': 'DANG_CHAY'});
        },
      });
      await openAdmin(t, api, '/admin/backups');
      expect(find.text('1 bản ghi'), findsOneWidget);
      await tapText(t, 'Tạo bản sao lưu ngay');
      expect(api.log.any((l) => l.startsWith('POST /admin/backups/')), isTrue);
      expect(find.text('2 bản ghi'), findsOneWidget);
    });

    testWidgets(
      'bấm tạo: lần tải ngay sau đó chưa thấy file mới → hỏi lại sau 3 giây cho tới khi có',
      (t) async {
        var lanGet = 0;
        final api = adminApi({
          'GET /admin/backups/': (_) {
            lanGet++; // 1: mở trang · 2: ngay sau POST (worker chưa kịp chạy) · 3: sau 3 giây
            return reply(
              200,
              lanGet < 3
                  ? ds(
                      f: [
                        file(
                          'hpsv_20270111_020000.dump',
                          '2027-01-11T02:00:00+07:00',
                          1024 * 1024,
                        ),
                      ],
                    )
                  : ds(),
            );
          },
          'POST /admin/backups/': (_) =>
              reply(202, {'trang_thai': 'DANG_CHAY'}),
        });
        await openAdmin(t, api, '/admin/backups');
        await tapText(t, 'Tạo bản sao lưu ngay');
        expect(find.text('1 bản ghi'), findsOneWidget);
        await t.pump(const Duration(seconds: 3));
        await t.pumpAndSettle();
        expect(lanGet, 3);
        expect(find.text('2 bản ghi'), findsOneWidget);
      },
    );

    testWidgets('đang chạy: nút bị khóa, tự hỏi lại tới khi xong', (t) async {
      var lan = 0;
      final api = adminApi({
        'GET /admin/backups/': (_) => reply(200, ds(chay: ++lan < 2)),
      });
      await openAdmin(t, api, '/admin/backups');
      expect(find.text('Đang sao lưu…'), findsOneWidget);
      await t.pump(const Duration(seconds: 3));
      await t.pumpAndSettle();
      expect(lan, 2);
      expect(find.text('Tạo bản sao lưu ngay'), findsOneWidget);
    });

    testWidgets('đang chạy mà server trả 409 khi bấm tạo → hiện thông điệp', (
      t,
    ) async {
      final api = adminApi({
        'GET /admin/backups/': (_) => reply(200, ds()),
        'POST /admin/backups/': (_) => apiError(
          409,
          'TRANG_THAI_KHONG_HOP_LE',
          'Đang có một lần sao lưu chạy, hãy đợi nó xong.',
        ),
      });
      await openAdmin(t, api, '/admin/backups');
      await tapText(t, 'Tạo bản sao lưu ngay');
      expect(
        find.textContaining('Đang có một lần sao lưu chạy'),
        findsOneWidget,
      );
    });
  });
}
