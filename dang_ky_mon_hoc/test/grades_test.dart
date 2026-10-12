import 'package:dang_ky_mon_hoc/features/grades/grade_calc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> row(
  int sv,
  String ma,
  String ten, {
  String? tt,
  String? qt,
  String? gk,
  String? ck,
  String? tk,
  String chu = '',
}) => {
  'sinh_vien': sv,
  'ma_sv': ma,
  'ho_ten': ten,
  'diem_qua_trinh': qt,
  'diem_giua_ky': gk,
  'diem_cuoi_ky': ck,
  'diem_tong_ket': tk,
  'diem_chu': chu,
  'gpa_thang_4': null,
  'trang_thai': tt,
};

Map<String, dynamic> sheet(
  List<Map<String, dynamic>> rows, {
  bool nhap = true,
  bool khoa = false,
  bool moKhoa = false,
  bool duyet = false,
  bool quaHan = false,
  String lopTt = 'DANG_HOC',
}) => {
  'lop_hoc_phan': 3,
  'ma_lop': 'CNTT101-01',
  'ten_mon': 'Nhập môn lập trình',
  'loai_danh_gia': 'DIEM',
  'lop_trang_thai': lopTt,
  'han_nhap_diem': '2027-05-14',
  'qua_han': quaHan,
  'co_the_nhap': nhap,
  'co_the_khoa': khoa,
  'co_the_mo_khoa': moKhoa,
  'co_the_duyet': duyet,
  'records': rows,
};

Map<String, dynamic> lopMy() => {
  'id': 3,
  'ma_lop': 'CNTT101-01',
  'ten_mon': 'Nhập môn lập trình',
  'trang_thai': 'DANG_HOC',
  'lich_hoc': [],
};

void main() {
  group('Tính điểm ở client (khớp BR-10/11 của server)', () {
    test('parseScore: dấu phẩy, tối đa 2 số thập phân, ngoài 0–10 là lỗi, rỗng là null', () {
      expect(parseScore('8.5').value, 850);
      expect(parseScore('8,25').value, 825);
      expect(parseScore('10').value, 1000);
      expect(parseScore('0').value, 0);
      expect(parseScore('').value, isNull);
      expect(parseScore(' ').invalid, isFalse);
      for (final bad in ['10.01', '11', '-1', 'abc', '8.555']) {
        expect(parseScore(bad).invalid, isTrue, reason: bad);
      }
    });

    test('tổng kết: 10/40/50, thiếu GK → 20/80, thiếu CK → 0, NULL khác 0, làm tròn nửa lên', () {
      expect(tinhTongKet(800, 700, 900), 810);
      expect(tinhTongKet(800, null, 600), 640);
      expect(tinhTongKet(800, 0, 600), 380); // GK = 0 vẫn tính 40%
      expect(tinhTongKet(1000, 500, null), 300);
      expect(tinhTongKet(null, null, null), isNull);
      expect(tinhTongKet(700, 700, 705), 703); // 7.025 → 7.03
    });

    test('thang chữ band liên tục + P/F môn Đạt/Không đạt', () {
      expect(xepLoai(845).$1, 'B');
      expect(xepLoai(695).$1, 'C');
      expect(xepLoai(545).$1, 'D');
      expect(xepLoai(850), ('A', 4.0));
      expect(xepLoai(700).$1, 'B');
      expect(xepLoai(550).$1, 'C');
      expect(xepLoai(400).$1, 'D');
      expect(xepLoai(399), ('F', 0.0));
      expect(xepLoai(500, datKhongDat: true), ('P', null));
      expect(xepLoai(499, datKhongDat: true), ('F', 0.0));
      expect(xepLoai(null).$1, '');
    });

    test('formatScore', () {
      expect(formatScore(845), '8.45');
      expect(formatScore(800), '8.00');
      expect(formatScore(5), '0.05');
      expect(scoreFromApi('8.10'), 810);
      expect(scoreFromApi(null), isNull);
    });
  });

  group('Giáo viên nhập điểm', () {
    FakeAdapter gv(
      Map<String, dynamic> Function() sheetFn, {
      Map<String, Handler> extra = const {},
    }) => FakeAdapter({
      'GET /profiles/me/': (_) => reply(
        200,
        userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
      ),
      'GET /class-sections/my/': (_) => reply(200, pageOf([lopMy()])),
      'GET /class-sections/3/grades/': (_) => reply(200, sheetFn()),
      ...extra,
    });

    Future<void> open(
      WidgetTester t,
      FakeAdapter api, {
      Size size = bigScreen,
    }) async {
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: api,
        tokens: signedIn,
        size: size,
      );
      GoRouter.of(t.element(find.byType(Scaffold).first)).go('/teacher/grades');
      await t.pumpAndSettle();
      await tapText(t, '— Chọn lớp để nhập điểm —');
      await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
      await t.pumpAndSettle();
    }

    testWidgets(
      'gõ điểm → xem trước tổng kết + chữ ngay; Lưu nháp gửi chuỗi 2 chữ số, chỉ dòng sửa được',
      (t) async {
        final api = gv(
          () => sheet([
            row(
              21,
              'SV1',
              'Trần Hoàng Nam',
              tt: 'NHAP_TAM',
              qt: '8.00',
              gk: '7.00',
              ck: '9.00',
              tk: '8.10',
              chu: 'B',
            ),
            row(22, 'SV2', 'Lê Văn Bình'),
            row(
              23,
              'SV3',
              'Phạm Thu Hà',
              tt: 'CHINH_THUC',
              qt: '9.00',
              gk: '9.00',
              ck: '9.00',
              tk: '9.00',
              chu: 'A',
            ),
          ], khoa: true),
          extra: {
            'PUT /class-sections/3/grades/': (_) => reply(200, sheet([])),
          },
        );
        await open(t, api);
        expect(
          find.textContaining('Tổng kết 8.10 · B'),
          findsOneWidget,
        ); // dữ liệu server
        expect(find.text('Chính thức'), findsOneWidget);

        Future<void> nhap(String label, int idx, String v) async {
          await t.enterText(find.widgetWithText(TextField, label).at(idx), v);
          await t.pump();
        }

        // dòng 2 (chưa nhập): QT 8, CK 6, thiếu GK → 20/80 = 6.40 → C
        await nhap('QT (10%)', 1, '8');
        await nhap('CK (50%)', 1, '6');
        expect(find.textContaining('Tổng kết 6.40 · C'), findsOneWidget);
        await nhap(
          'GK (40%)',
          1,
          '0',
        ); // GK = 0 đã nhập → công thức thường = 3.80 → F
        expect(find.textContaining('Tổng kết 3.80 · F'), findsOneWidget);
        await nhap('GK (40%)', 1, '');
        await nhap('QT (10%)', 0, '10.5'); // sai định dạng
        expect(find.text('0–10'), findsOneWidget);
        await tapText(t, 'Lưu nháp');
        expect(api.bodies['PUT /class-sections/3/grades/'], isNull);
        await nhap('QT (10%)', 0, '8.5');

        await tapText(t, 'Lưu nháp');
        final recs =
            (api.bodies['PUT /class-sections/3/grades/'] as Map)['records']
                as List;
        expect(recs, hasLength(2)); // dòng CHINH_THUC không gửi
        expect(recs[0], {
          'sinh_vien': 21,
          'diem_qua_trinh': '8.50',
          'diem_giua_ky': '7.00',
          'diem_cuoi_ky': '9.00',
        });
        expect(recs[1], {
          'sinh_vien': 22,
          'diem_qua_trinh': '8.00',
          'diem_giua_ky': null,
          'diem_cuoi_ky': '6.00',
        });
        expect(find.text('Đã lưu điểm nháp.'), findsOneWidget);
      },
    );

    testWidgets('Khóa điểm / Mở khóa gọi lock; quá hạn: banner và khóa nhập', (
      t,
    ) async {
      var khoa = false;
      final api = gv(
        () => khoa
            ? sheet(
                [
                  row(
                    21,
                    'SV1',
                    'Trần Hoàng Nam',
                    tt: 'CHINH_THUC',
                    tk: '8.00',
                    chu: 'B',
                  ),
                ],
                moKhoa: true,
                nhap: true,
              )
            : sheet([
                row(
                  21,
                  'SV1',
                  'Trần Hoàng Nam',
                  tt: 'NHAP_TAM',
                  qt: '8',
                  gk: '8',
                  ck: '8',
                ),
              ], khoa: true),
        extra: {
          'POST /class-sections/3/grades/lock/': (o) {
            khoa = (o.data as Map)['action'] == 'lock';
            return reply(200, {});
          },
        },
      );
      await open(t, api);
      await tapText(t, 'Khóa điểm');
      expect(api.bodies['POST /class-sections/3/grades/lock/'], {
        'action': 'lock',
      });
      expect(find.text('Đã khóa điểm cả lớp.'), findsOneWidget);
      expect(find.text('Mở khóa'), findsOneWidget);
      await tapText(t, 'Mở khóa');
      expect(api.bodies['POST /class-sections/3/grades/lock/'], {
        'action': 'unlock',
      });
    });

    testWidgets('quá hạn: cảnh báo, ô nhập bị khóa, không có nút Lưu', (
      t,
    ) async {
      final api = gv(
        () => sheet(
          [row(21, 'SV1', 'Trần Hoàng Nam')],
          nhap: false,
          quaHan: true,
        ),
      );
      await open(t, api);
      expect(
        find.textContaining('Đã quá hạn nhập điểm.', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Lưu nháp'), findsNothing);
      final f = t.widget<TextField>(find.widgetWithText(TextField, 'QT (10%)'));
      expect(f.enabled, isFalse);
    });

    testWidgets(
      'lỗi server khi lưu (quá hạn) → toast thông điệp, không mất dữ liệu đã gõ',
      (t) async {
        final api = gv(
          () => sheet([row(21, 'SV1', 'Trần Hoàng Nam')]),
          extra: {
            'PUT /class-sections/3/grades/': (_) => apiError(
              409,
              'QUA_HAN_NHAP_DIEM',
              'Đã quá hạn nhập điểm của lớp.',
            ),
          },
        );
        await open(t, api);
        await t.enterText(find.widgetWithText(TextField, 'QT (10%)'), '7');
        await tapText(t, 'Lưu nháp');
        expect(
          find.text('Không thực hiện được, vui lòng thử lại.'),
          findsNothing,
        );
        expect(find.textContaining('quá hạn'), findsWidgets);
      },
    );
  });

  group('PĐT duyệt điểm', () {
    testWidgets(
      'bảng lớp + trạng thái điểm; chọn lớp → bảng điểm; duyệt cả lớp có xác nhận',
      (t) async {
        var daDuyet = false;
        final api = pdtApi({
          'GET /grade-sheets/': (_) => reply(
            200,
            pageOf([
              {
                'id': 3,
                'ma_lop': 'CNTT101-01',
                'ten_mon': 'Nhập môn lập trình',
                'ten_hk': 'HK2',
                'giao_vien_ten': 'Trần Minh Quân',
                'trang_thai': 'DA_DONG',
                'so_sv': 2,
                'nhap_tam': 0,
                'chinh_thuc': daDuyet ? 0 : 2,
                'khoa': daDuyet ? 2 : 0,
              },
            ]),
          ),
          'GET /class-sections/3/grades/': (_) => reply(
            200,
            sheet(
              [
                row(
                  21,
                  'SV1',
                  'Trần Hoàng Nam',
                  tt: daDuyet ? 'KHOA' : 'CHINH_THUC',
                  qt: '9',
                  gk: '9',
                  ck: '9',
                  tk: '9.00',
                  chu: 'A',
                ),
                row(
                  22,
                  'SV2',
                  'Lê Văn Bình',
                  tt: daDuyet ? 'KHOA' : 'CHINH_THUC',
                  qt: '5',
                  gk: '5',
                  ck: '5',
                  tk: '5.00',
                  chu: 'D',
                ),
              ],
              nhap: false,
              duyet: !daDuyet,
              lopTt: 'DA_DONG',
            ),
          ),
          'POST /class-sections/3/grades/approve/': (_) {
            daDuyet = true;
            return reply(200, {'so_sinh_vien': 2});
          },
        });
        await openPdt(t, api, '/pdt/grade-sheets');
        expect(
          find.textContaining('Chính thức 2 · Đã khóa 0 · Chưa nhập 0'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Chọn một lớp ở bảng trên để xem bảng điểm cả lớp và các thao tác.',
          ),
          findsOneWidget,
        );

        await tapText(t, 'Nhập môn lập trình');
        expect(find.text('Duyệt cả lớp'), findsOneWidget);
        await tapText(t, 'Duyệt cả lớp');
        expect(find.textContaining('không sửa được nữa'), findsOneWidget);
        await tapText(t, 'Duyệt cả lớp', index: 1);
        expect(
          api.log.any(
            (l) => l.startsWith('POST /class-sections/3/grades/approve/'),
          ),
          isTrue,
        );
        expect(find.text('Đã duyệt điểm cả lớp.'), findsOneWidget);
        expect(find.text('Duyệt cả lớp'), findsNothing); // đã KHOA: hết nút
        expect(find.textContaining('Đã khóa 2'), findsOneWidget);
      },
    );

    testWidgets(
      'lớp đang học: nhập hộ lưu điểm chính thức; Gia hạn gọi grade-deadline',
      (t) async {
        final api = pdtApi({
          'GET /grade-sheets/': (_) => reply(
            200,
            pageOf([
              {
                'id': 3,
                'ma_lop': 'CNTT101-01',
                'ten_mon': 'Nhập môn lập trình',
                'ten_hk': 'HK2',
                'giao_vien_ten': 'Trần Minh Quân',
                'trang_thai': 'DANG_HOC',
                'so_sv': 1,
                'nhap_tam': 0,
                'chinh_thuc': 0,
                'khoa': 0,
              },
            ]),
          ),
          'GET /class-sections/3/grades/': (_) => reply(
            200,
            sheet([row(21, 'SV1', 'Trần Hoàng Nam')], quaHan: true),
          ),
          'PUT /class-sections/3/grades/': (_) => reply(200, {}),
          'POST /class-sections/3/grade-deadline/': (_) => reply(200, {}),
        });
        await openPdt(t, api, '/pdt/grade-sheets');
        await tapText(t, 'Nhập môn lập trình');
        expect(find.text('Lưu điểm chính thức'), findsOneWidget);
        await t.enterText(find.widgetWithText(TextField, 'CK (50%)'), '6');
        await tapText(t, 'Lưu điểm chính thức');
        expect(
          ((api.bodies['PUT /class-sections/3/grades/'] as Map)['records']
                  as List)
              .single['diem_cuoi_ky'],
          '6.00',
        );
        expect(find.text('Đã lưu điểm chính thức (nhập hộ).'), findsOneWidget);

        await tapText(t, 'Gia hạn');
        expect(
          find.textContaining('Hạn mới phải sau hạn hiện tại (14/05/2027)'),
          findsOneWidget,
        );
      },
    );
  });

  group('Sinh viên xem điểm', () {
    Map<String, dynamic> my({bool trong = false}) => {
      'gpa': trong ? null : '3.21',
      'tin_chi_tich_luy': trong ? 0 : 96,
      'xep_loai': trong ? null : 'Giỏi',
      'thong_ke': trong
          ? []
          : [
              {
                'hoc_ky': 1,
                'ten_hk': 'Học kỳ 1, 2025–2026',
                'so_mon': 1,
                'tin_chi_hoc': 3,
                'tin_chi_dat': 3,
                'diem_tb': '8.10',
                'gpa': '3.00',
                'xep_loai': 'Giỏi',
              },
              {
                'hoc_ky': 2,
                'ten_hk': 'Học kỳ 2, 2025–2026',
                'so_mon': 1,
                'tin_chi_hoc': 4,
                'tin_chi_dat': 0,
                'diem_tb': '3.00',
                'gpa': '0.00',
                'xep_loai': 'Kém',
              },
            ],
      'diem': trong
          ? []
          : [
              {
                'hoc_ky': 2,
                'ten_hk': 'Học kỳ 2, 2025–2026',
                'ma_lop': 'L2',
                'ma_mon': 'M2',
                'ten_mon': 'Giải tích',
                'tin_chi': 4,
                'diem_qua_trinh': '3.00',
                'diem_giua_ky': null,
                'diem_cuoi_ky': '3.00',
                'diem_tong_ket': '3.00',
                'diem_chu': 'F',
                'gpa_thang_4': '0.00',
              },
              {
                'hoc_ky': 1,
                'ten_hk': 'Học kỳ 1, 2025–2026',
                'ma_lop': 'L1',
                'ma_mon': 'M1',
                'ten_mon': 'Nhập môn lập trình',
                'tin_chi': 3,
                'diem_qua_trinh': '8.00',
                'diem_giua_ky': '7.00',
                'diem_cuoi_ky': '9.00',
                'diem_tong_ket': '8.10',
                'diem_chu': 'B',
                'gpa_thang_4': '3.00',
              },
            ],
    };

    testWidgets('GPA tích lũy, thống kê từng học kỳ, lọc học kỳ', (t) async {
      await openStudent(
        t,
        svApi({'GET /grades/my/': (_) => reply(200, my())}),
        '/student/grades',
      );
      expect(find.text('3.21'), findsOneWidget);
      expect(find.text('96'), findsOneWidget);
      expect(find.text('Giỏi'), findsWidgets);
      expect(find.text('Nhập môn lập trình'), findsOneWidget);
      expect(find.text('Giải tích'), findsOneWidget);
      expect(
        find.textContaining('Tín chỉ đạt: 0', findRichText: true),
        findsOneWidget,
      );

      await tapText(t, 'Học kỳ 1, 2025–2026');
      expect(find.text('Giải tích'), findsNothing);
      expect(find.text('Nhập môn lập trình'), findsOneWidget);
    });

    testWidgets('chưa có điểm KHOA: thông báo thay vì bảng trống', (t) async {
      await openStudent(
        t,
        svApi({'GET /grades/my/': (_) => reply(200, my(trong: true))}),
        '/student/grades',
      );
      expect(find.text('Chưa có'), findsWidgets);
      expect(find.textContaining('Chưa có điểm chính thức'), findsOneWidget);
    });
  });
}
