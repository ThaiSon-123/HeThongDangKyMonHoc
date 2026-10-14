import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/features/dashboard/dashboard_widgets.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

// "Hôm nay" cố định: Thứ 7, 10/10/2026 09:00.
final _homNay = DateTime(2026, 10, 10, 9);

Future<void> open(
  WidgetTester t,
  FakeAdapter api,
  String path, {
  Size size = bigScreen,
}) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: size,
    overrides: [clockProvider.overrideWithValue(() => _homNay)],
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
  await t.pumpAndSettle();
}

Map<String, dynamic> buoi(
  int thu,
  int bd,
  int soTiet, [
  String phong = 'A101',
]) => {
  'id': thu * 100 + bd,
  'thu': thu,
  'tiet_bat_dau': bd,
  'so_tiet_moi_buoi': soTiet,
  'tiet_ket_thuc': bd + soTiet - 1,
  'buoi': 'SANG',
  'phong': phong,
};

Map<String, dynamic> lop(
  int id,
  String ma,
  String ten,
  List<Map<String, dynamic>> lich, {
  String tt = 'DANG_HOC',
  String han = '2027-01-23',
  int si = 40,
  String? tu,
  String? den,
}) => {
  'id': id,
  'ma_lop': ma,
  'ten_mon': ten,
  'tong_tin_chi': 3,
  'giao_vien_ten': 'Trần Minh Quân',
  'hoc_ky': 7,
  'trang_thai': tt,
  'si_so_hien_tai': si,
  'si_so_toi_da': 45,
  'han_nhap_diem_hieu_luc': han,
  'ngay_bat_dau': tu,
  'ngay_ket_thuc': den,
  'lich_hoc': lich,
};

Map<String, dynamic> tkb(List<Map<String, dynamic>> lops) => {
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 1, 2026–2027',
  'ngay_bat_dau': '2026-08-17',
  'ngay_ket_thuc': '2027-01-09',
  'lop_hoc_phan': lops,
};

void main() {
  group('hàm dùng chung', () {
    test('ngayDayDu: thứ trong tuần, Chủ nhật', () {
      expect(ngayDayDu(DateTime(2026, 10, 10)), 'Thứ 7, 10/10/2026');
      expect(ngayDayDu(DateTime(2026, 10, 11)), 'Chủ nhật, 11/10/2026');
      expect(ngayDayDu(DateTime(2026, 10, 5)), 'Thứ 2, 05/10/2026');
    });

    test('soNgayDen: dương = còn, âm = đã qua, lỗi → null', () {
      expect(soNgayDen('2026-10-13', _homNay), 3);
      expect(soNgayDen('2026-10-09', _homNay), -1);
      expect(soNgayDen('2026-10-10', _homNay), 0);
      expect(soNgayDen('', _homNay), isNull);
    });

    test('lichHomNay: đúng thứ, trong khoảng ngày của lớp, sắp theo tiết', () {
      final d = tkb([
        lop(1, 'B', 'Chiều', [buoi(7, 6, 3)]),
        lop(2, 'A', 'Sáng', [buoi(7, 1, 3), buoi(3, 1, 3)]),
        lop(
          3,
          'Đã hết',
          'Hết',
          [buoi(7, 1, 3)],
          tu: '2026-08-17',
          den: '2026-10-01',
        ),
        lop(
          4,
          'Chưa bắt đầu',
          'Chưa',
          [buoi(7, 1, 3)],
          tu: '2026-10-12',
          den: '2027-01-01',
        ),
      ]);
      final r = lichHomNay(d, _homNay);
      expect(r.map((e) => e.lop['ma_lop']), ['A', 'B']);
      // Chủ nhật = thu 8
      expect(
        lichHomNay(
          tkb([
            lop(1, 'CN', 'CN', [buoi(8, 1, 3)]),
          ]),
          DateTime(2026, 10, 11),
        ).length,
        1,
      );
    });
  });

  group('Sinh viên', () {
    FakeAdapter api({Map<String, Handler> extra = const {}}) => svApi({
      'GET /timetable/my/': (_) => reply(
        200,
        tkb([
          lop(1, 'CNTT101-01', 'Lập trình hướng đối tượng', [
            buoi(7, 1, 3),
            buoi(3, 1, 3),
          ]),
          lop(2, 'CNTT203-02', 'Cơ sở dữ liệu', [buoi(4, 6, 3, 'B203')]),
        ]),
      ),
      'GET /tuition/my/': (_) => reply(200, {
        'con_no': '4320000.00',
        'can_hoan': '0.00',
        'han_dong': '2026-10-31',
        'qua_han': false,
      }),
      'GET /attendance/my/': (_) => reply(200, {
        'lop_hoc_phan': [
          {'ten_mon': 'Mạng máy tính', 'canh_bao_vang': true},
          {'ten_mon': 'Cơ sở dữ liệu', 'canh_bao_vang': false},
        ],
      }),
      'GET /notifications/': (_) => reply(
        200,
        pageOf([
          {
            'id': 1,
            'tieu_de': 'Lớp CNTT203-02 đổi phòng học',
            'nguoi_gui_ten': 'pdt01',
            'ngay_gui': '2026-10-09T09:05:00+07:00',
            'da_doc': false,
          },
        ]),
      ),
      ...extra,
    });

    testWidgets('lời chào, 4 thẻ, lịch hôm nay, thông báo, lối tắt', (t) async {
      await open(t, api(), '/student');
      expect(find.text('Xin chào, Trần Hoàng Nam'), findsOneWidget);
      expect(
        find.text(
          'SV2023014 · Công nghệ thông tin · K2023 · Thứ 7, 10/10/2026',
        ),
        findsOneWidget,
      );
      expect(find.text('6'), findsOneWidget); // 2 lớp × 3 tín chỉ
      expect(find.text('3.12'), findsOneWidget);
      expect(find.text('96 tín chỉ tích lũy · Giỏi'), findsOneWidget);
      expect(find.text('1 môn'), findsOneWidget);
      expect(find.text('Mạng máy tính — nguy cơ cấm thi'), findsOneWidget);
      expect(find.text('4.320.000 ₫'), findsOneWidget);
      expect(find.text('Hạn đóng 31/10/2026'), findsOneWidget);
      // Hôm nay (thứ 7) chỉ có lớp CNTT101-01.
      expect(find.text('Tiết 1–3 · Sáng · P.A101'), findsOneWidget);
      expect(find.text('CNTT101-01 · GV Trần Minh Quân'), findsOneWidget);
      expect(find.text('CNTT203-02 · GV Trần Minh Quân'), findsNothing);
      expect(find.text('Lớp CNTT203-02 đổi phòng học'), findsOneWidget);
      expect(find.text('Đăng ký môn học'), findsWidgets);
    });

    testWidgets('một khối lỗi không làm trắng cả trang; lối tắt chuyển trang', (
      t,
    ) async {
      final a = api(
        extra: {'GET /tuition/my/': (_) => apiError(500, 'LOI', 'Lỗi')},
      );
      await open(t, a, '/student');
      expect(find.text('Xin chào, Trần Hoàng Nam'), findsOneWidget);
      expect(
        find.text('0 ₫'),
        findsOneWidget,
      ); // học phí không tải được → coi như 0
      await tapText(t, 'Xem điểm');
      expect(
        GoRouter.of(t.element(find.byType(Scaffold).first)).state.uri.path,
        '/student/grades',
      );
    });

    testWidgets(
      'cảnh báo vắng / nợ quá hạn / chờ hoàn tiền / ngày không có lớp',
      (t) async {
        final a = api(
          extra: {
            'GET /timetable/my/': (_) => reply(200, tkb([])),
            'GET /attendance/my/': (_) => reply(200, {'lop_hoc_phan': []}),
            'GET /tuition/my/': (_) => reply(200, {
              'con_no': '0.00',
              'can_hoan': '500000.00',
              'han_dong': '2026-10-31',
              'qua_han': false,
            }),
          },
        );
        await open(t, a, '/student');
        expect(find.text('Không có môn nguy cơ cấm thi'), findsOneWidget);
        expect(find.text('Chờ hoàn tiền 500.000 ₫'), findsOneWidget);
        expect(find.text('Hôm nay bạn không có lớp.'), findsOneWidget);
      },
    );
  });

  group('Giáo viên', () {
    FakeAdapter api() => FakeAdapter({
      'GET /profiles/me/': (_) => reply(200, teacherProfile()),
      'GET /class-sections/my/': (_) => reply(
        200,
        pageOf([
          lop(1, 'CNTT101-01', 'Lập trình hướng đối tượng', [
            buoi(7, 1, 3),
          ], si: 42),
          lop(
            2,
            'CNTT305-01',
            'Mạng máy tính',
            [buoi(5, 11, 3)],
            han: '2026-10-13',
            si: 36,
          ),
          lop(
            3,
            'CNTT320-01',
            'Kỹ thuật phần mềm',
            [buoi(6, 1, 3)],
            han: '2026-10-09',
            si: 34,
          ),
          lop(4, 'CNTT110-03', 'Đã đóng', [buoi(6, 1, 3)], tt: 'DA_DONG'),
        ]),
      ),
      'GET /timetable/my/': (_) => reply(
        200,
        tkb([
          lop(1, 'CNTT101-01', 'Lập trình hướng đối tượng', [buoi(7, 1, 3)]),
        ]),
      ),
      'GET /attendance/sessions/': (o) => reply(200, {
        ...pageOf(
          o.queryParameters['lop_hoc_phan'] == 1
              ? [
                  {
                    'id': 1,
                    'ngay_hoc': '2026-10-08',
                    'trang_thai': 'DA_DIEM_DANH',
                  },
                  {'id': 2, 'ngay_hoc': '2026-10-10', 'trang_thai': 'MO'},
                  {
                    'id': 3,
                    'ngay_hoc': '2026-09-26',
                    'trang_thai': 'DA_DIEM_DANH',
                  }, // ngoài tuần
                ]
              : [],
        ),
        'tong_so_buoi': 3,
      }),
    });

    testWidgets(
      'cảnh báo hạn nhập điểm, 4 thẻ, lịch dạy hôm nay, lối tắt ?lop=',
      (t) async {
        await open(t, api(), '/teacher');
        expect(find.text('Xin chào, Trần Minh Quân'), findsOneWidget);
        expect(
          find.textContaining(
            'CNTT320-01 · Kỹ thuật phần mềm đã quá hạn nhập điểm 1 ngày',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'CNTT305-01 · Mạng máy tính còn 3 ngày nhập điểm',
          ),
          findsOneWidget,
        );
        expect(find.text('3'), findsWidgets); // lớp đang dạy
        expect(find.text('42 + 36 + 34 sinh viên'), findsOneWidget);
        expect(
          find.text('1 sắp đến hạn · 1 quá hạn nhập điểm'),
          findsOneWidget,
        );
        expect(find.text('Đã chốt 1 · Còn mở 1'), findsOneWidget);
        expect(
          find.text('CNTT101-01 · 40 sinh viên'),
          findsOneWidget,
        ); // lịch dạy hôm nay (lớp trong timetable/my)
        expect(find.text('Kỹ thuật phần mềm'), findsWidgets);
        expect(
          find.text('Đã đóng'),
          findsNothing,
        ); // lớp đã đóng không nằm trong "Lớp của tôi"
        await tapText(
          t,
          'Nhập điểm',
          index: 1,
        ); // nút của lớp đầu tiên (index 0 là menu)
        expect(
          GoRouter.of(t.element(find.byType(Scaffold).first)).state.uri
              .toString(),
          '/teacher/grades?lop=1',
        );
      },
    );
  });

  group('Phòng đào tạo', () {
    FakeAdapter api({String cuaSoDong = '2026-10-15T23:59:00+07:00'}) => pdtApi(
      {
        'GET /reports/training/': (_) => reply(200, {
          'hoc_ky': 7,
          'ten_hk': 'Học kỳ 2 · 2026–2027',
          'tong': {
            'so_sinh_vien': 104,
            'so_lop': 5,
            'tong_luot_dang_ky': 352,
            'lop_day': 1,
            'lop_con_cho': 2,
          },
          'theo_mon': [],
          'theo_lop': [],
        }),
        'GET /semesters/7/': (_) => reply(200, {
          'id': 7,
          'ten_hk': 'Học kỳ 2 · 2026–2027',
          'ngay_bat_dau': '2026-08-17',
          'ngay_ket_thuc': '2027-01-09',
          'cua_so_dk_bat_dau': '2026-10-01T00:00:00+07:00',
          'cua_so_dk_ket_thuc': cuaSoDong,
          'trang_thai': 'MO',
        }),
        'GET /class-sections/': (_) => reply(
          200,
          pageOf([
            lop(1, 'CNTT360-01', 'A', [], tt: 'KE_HOACH'),
            lop(2, 'CNTT370-01', 'B', [], tt: 'KE_HOACH'),
            lop(3, 'CNTT380-01', 'C', [
              buoi(2, 1, 3),
            ], tt: 'KE_HOACH'), // đủ lịch → không tính
            lop(4, 'CNTT401-01', 'D', [buoi(2, 1, 3)], tt: 'MO'),
            lop(
              5,
              'CNTT320-01',
              'E',
              [buoi(2, 1, 3)],
              tt: 'DANG_HOC',
              han: '2026-10-09',
            ),
          ]),
        ),
        'GET /grade-sheets/': (_) => reply(
          200,
          pageOf([
            {'id': 9, 'ma_lop': 'X', 'chinh_thuc': 40, 'khoa': 0},
            {'id': 10, 'ma_lop': 'Y', 'chinh_thuc': 0, 'khoa': 40}, // đã duyệt
          ]),
        ),
      },
    );

    testWidgets(
      'lớp theo trạng thái, đăng ký, việc cần làm và thông tin học kỳ',
      (t) async {
        await open(t, api(), '/pdt');
        expect(find.text('Kế hoạch'), findsOneWidget);
        expect(find.text('352'), findsOneWidget);
        expect(
          find.text('2 lớp chưa đủ điều kiện mở'),
          findsNothing,
        ); // số và chữ nằm ở hai Text
        expect(find.text('lớp chưa đủ điều kiện mở'), findsOneWidget);
        expect(
          find.textContaining('CNTT360-01 (thiếu lịch học)'),
          findsOneWidget,
        );
        expect(find.text('lớp quá hạn nhập điểm'), findsOneWidget);
        expect(find.text('lớp chờ duyệt điểm'), findsOneWidget);
        expect(
          find.text('ngày nữa đóng cửa sổ đăng ký'),
          findsOneWidget,
        ); // còn 5 ngày
        expect(find.text('17/08/2026 – 09/01/2027'), findsOneWidget);
        expect(find.text('Đang mở'), findsWidgets);
      },
    );

    testWidgets('không có việc nào → thông báo trống', (t) async {
      final a = api(cuaSoDong: '2027-01-15T23:59:00+07:00');
      a.routes['GET /class-sections/'] = (_) => reply(200, pageOf([]));
      a.routes['GET /grade-sheets/'] = (_) => reply(200, pageOf([]));
      await open(t, a, '/pdt');
      expect(
        find.textContaining('Không có việc nào cần xử lý'),
        findsOneWidget,
      );
    });
  });

  group('Kế toán', () {
    testWidgets('4 thẻ tiền, nhắc việc, biểu đồ theo ngành', (t) async {
      final a = FakeAdapter({
        'GET /profiles/me/': (_) => reply(
          200,
          userJson('KE_TOAN', name: 'Nguyễn Thu Hà', username: 'kt01'),
        ),
        'GET /reports/finance/': (_) => reply(200, {
          'hoc_ky': 7,
          'ten_hk': 'Học kỳ 2',
          'tong': {
            'phai_thu': '40970000.00',
            'da_thu': '29970000.00',
            'con_no': '11500000.00',
            'cho_hoan': '500000.00',
            'so_sinh_vien': 10,
            'so_chua_tinh': 1,
            'so_con_no': 4,
            'so_qua_han': 4,
            'so_cho_hoan': 1,
          },
          'theo_nganh': [
            {
              'nganh_ma': 'CNTT',
              'nganh_ten': 'CNTT',
              'phai_thu': '20550000.00',
              'da_thu': '10730000.00',
            },
          ],
        }),
      });
      await open(t, a, '/accountant');
      expect(find.text('40.970.000 ₫'), findsOneWidget);
      expect(find.text('9 sinh viên đã tính học phí'), findsOneWidget);
      expect(find.text('4 sinh viên còn nợ'), findsOneWidget);
      expect(find.text('4 sinh viên quá hạn đóng học phí.'), findsOneWidget);
      expect(
        find.text('1 sinh viên đóng dư, đang chờ hoàn tiền.'),
        findsOneWidget,
      );
      expect(find.text('1 sinh viên chưa được tính học phí.'), findsOneWidget);
      expect(find.text('20.550.000 ₫'), findsOneWidget);
      await tapText(t, 'Xem công nợ');
      expect(
        GoRouter.of(t.element(find.byType(Scaffold).first)).state.uri.path,
        '/accountant/debts',
      );
    });
  });

  group('Quản trị', () {
    FakeAdapter api({
      bool worker = true,
      List<Map<String, dynamic>>? backups,
    }) => FakeAdapter({
      'GET /profiles/me/': (_) => reply(
        200,
        userJson('ADMIN', name: 'Quản trị hệ thống', username: 'admin'),
      ),
      'GET /health/': (_) => reply(200, {
        'status': worker ? 'ok' : 'degraded',
        'db': true,
        'redis': true,
        'worker': worker,
      }),
      'GET /users/': (o) {
        final q = o.queryParameters;
        final n = q['is_locked'] == 'true'
            ? 2
            : {
                    'ADMIN': 1,
                    'PHONG_DAO_TAO': 2,
                    'SINH_VIEN': 6,
                    'GIAO_VIEN': 5,
                    'KE_TOAN': 2,
                  }[q['role']] ??
                  0;
        return reply(200, pageOf([], count: n));
      },
      'GET /admin/backups/': (_) => reply(200, {
        'dang_chay': false,
        'so_ngay_giu': 14,
        'results':
            backups ??
            [
              {
                'ten': 'hpsv_20261010_020000.dump',
                'dung_luong': 412 * 1024 * 1024,
                'tao_luc': '2026-10-10T02:00:00+07:00',
              },
            ],
      }),
      'GET /admin/audit-logs/': (_) => reply(
        200,
        pageOf([
          {
            'id': 1,
            'thoi_gian': '2026-10-10T08:41:00+07:00',
            'nguoi_thuc_hien': 'pdt01',
            'hanh_dong': 'UPDATE',
            'doi_tuong': 'ClassSection',
            'chi_tiet': {'hanh_dong': 'gia_han_nhap_diem'},
          },
        ]),
      ),
    });

    testWidgets(
      'sức khỏe hệ thống, tài khoản theo vai trò, sao lưu, hoạt động gần đây',
      (t) async {
        await open(t, api(), '/admin');
        for (final s in [
          'Máy chủ ứng dụng',
          'Cơ sở dữ liệu',
          'Bộ nhớ đệm',
          'Tác vụ chạy nền',
        ]) {
          expect(find.text(s), findsOneWidget);
        }
        expect(find.text('Hoạt động'), findsNWidgets(4));
        expect(find.text('2 tài khoản đang khóa'), findsOneWidget);
        expect(find.text('Sinh viên'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('hpsv_20261010_020000.dump'), findsOneWidget);
        expect(find.text('412 MB'), findsOneWidget);
        expect(find.textContaining('chưa có bản sao lưu mới'), findsNothing);
        expect(find.text('pdt01'), findsOneWidget);
        expect(find.textContaining('ClassSection'), findsOneWidget);
      },
    );

    testWidgets(
      'worker không chạy → thẻ báo sự cố; sao lưu cũ > 48 giờ → cảnh báo',
      (t) async {
        final a = api(
          worker: false,
          backups: [
            {
              'ten': 'hpsv_old.dump',
              'dung_luong': 1024,
              'tao_luc': '2026-10-05T02:00:00+07:00',
            },
          ],
        );
        await open(t, a, '/admin');
        expect(find.text('Có sự cố'), findsOneWidget);
        expect(find.text('Không thấy tiến trình nền'), findsOneWidget);
        expect(
          find.textContaining('Đã hơn 48 giờ chưa có bản sao lưu mới'),
          findsOneWidget,
        );
      },
    );
  });
}
