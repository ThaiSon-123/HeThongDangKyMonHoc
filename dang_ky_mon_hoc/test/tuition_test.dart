import 'package:dang_ky_mon_hoc/core/download/save_file_provider.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/features/tuition/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> tuitionRow({
  int id = 5,
  String hienThi = 'CON_NO',
  String trangThai = 'DA_TINH',
  String conNo = '1000000.00',
  String canHoan = '0.00',
  bool quaHan = false,
}) => {
  'id': id,
  'sinh_vien': 21,
  'ma_sv': 'SV2023014',
  'ho_ten': 'Trần Hoàng Nam',
  'nganh_ten': 'Công nghệ thông tin',
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'tong_tin_chi': 12,
  'tong_tien': '5000000.00',
  'trang_thai': trangThai,
  'mien_giam': '500000.00',
  'phai_nop': '4500000.00',
  'thuc_thu': '3500000.00',
  'con_no': conNo,
  'can_hoan': canHoan,
  'hien_thi': hienThi,
  'han_dong': '2027-02-01',
  'qua_han': quaHan,
};

Map<String, dynamic> detail({
  List<Map<String, dynamic>> payments = const [],
  Map<String, dynamic>? row,
}) => {
  ...(row ?? tuitionRow()),
  'chi_tiet': [
    {
      'ma_mon': 'CNTT101',
      'ten_mon': 'Nhập môn lập trình',
      'ma_lop': 'L1',
      'tin_chi_ly_thuyet': 2,
      'tin_chi_thuc_hanh': 1,
      'don_gia_goc': '100000.00',
      'don_gia_th': '100000.00',
      'thanh_tien': '300000.00',
    },
  ],
  'payments': payments,
};

Map<String, dynamic> payment({int id = 9, String loai = 'THU'}) => {
  'id': id,
  'tuition': 5,
  'loai': loai,
  'so_tien': '500000.00',
  'phuong_thuc': 'TIEN_MAT',
  'ngay': '2027-01-10T09:00:00+07:00',
  'nguoi_thu_ten': 'kt01',
  'bien_lai_ma': 'BL20270110-000009',
};

FakeAdapter ktApi(Map<String, Handler> extra) => FakeAdapter({
  'GET /profiles/me/': (_) =>
      reply(200, userJson('KE_TOAN', name: 'Nguyễn Thu Hà', username: 'kt01')),
  'GET /semesters/': (_) => reply(
    200,
    pageOf([
      {'id': 7, 'ten_hk': 'Học kỳ 2'},
    ]),
  ),
  ...extra,
});

Future<void> openKt(
  WidgetTester t,
  FakeAdapter api,
  String path, {
  List<Override> overrides = const [],
}) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: bigScreen,
    overrides: overrides,
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
  await t.pumpAndSettle();
}

void main() {
  test('formatVnd: ngăn nghìn bằng dấu chấm, làm tròn đồng, số âm', () {
    expect(formatVnd('1500000.00'), '1.500.000 ₫');
    expect(formatVnd(0), '0 ₫');
    expect(formatVnd(null), '0 ₫');
    expect(formatVnd(999), '999 ₫');
    expect(formatVnd(-2500), '-2.500 ₫');
  });

  group('Kế toán — học phí', () {
    testWidgets(
      'bảng: các cột dẫn xuất, trạng thái, Quá hạn; tính hàng loạt thiếu giá → banner + link cấu hình',
      (t) async {
        final api = ktApi({
          'GET /tuition/': (_) => reply(
            200,
            pageOf([
              tuitionRow(quaHan: true),
              tuitionRow(
                id: 6,
                hienThi: 'CHUA_TINH',
                trangThai: 'CHUA_TINH',
                conNo: '0.00',
              ),
            ]),
          ),
          'POST /tuition/calculate/': (_) => apiError(
            400,
            'CHUA_CAU_HINH_GIA',
            'Chưa cấu hình giá cho môn CNTT101.',
          ),
        });
        await openKt(t, api, '/accountant/tuition');
        expect(find.text('5.000.000 ₫'), findsWidgets);
        expect(find.text('1.000.000 ₫'), findsWidgets);
        expect(find.text('Còn nợ'), findsWidgets);
        expect(find.text('Quá hạn'), findsOneWidget);
        expect(find.text('Chưa tính'), findsWidgets);

        await tapText(t, 'Tính học phí hàng loạt');
        expect(find.textContaining('Chưa cấu hình đủ đơn giá'), findsOneWidget);
        expect(find.text('Mở cấu hình giá →'), findsOneWidget);
      },
    );

    testWidgets(
      'tính hàng loạt thành công → toast số SV và tải lại danh sách',
      (t) async {
        final api = ktApi({
          'GET /tuition/': (_) => reply(200, pageOf([tuitionRow()])),
          'POST /tuition/calculate/': (_) => reply(200, {'so_sinh_vien': 42}),
        });
        await openKt(t, api, '/accountant/tuition');
        await tapText(t, 'Tính học phí hàng loạt');
        expect(find.text('Đã tính học phí cho 42 sinh viên.'), findsOneWidget);
        expect(api.log.where((l) => l.startsWith('GET /tuition/ ')).length, 2);
      },
    );

    testWidgets(
      'chi tiết: Ghi thu gửi Idempotency-Key + body; thu vượt công nợ bị server chặn → hiện lỗi; biên lai',
      (t) async {
        final saved = <String>[];
        var daThu = false;
        final api = ktApi({
          'GET /tuition/': (_) => reply(200, pageOf([tuitionRow()])),
          'GET /tuition/5/': (_) =>
              reply(200, detail(payments: daThu ? [payment()] : [])),
          'POST /tuition/payments/': (o) {
            final so = (o.data as Map)['so_tien'];
            if (so > 1000000) {
              return apiError(
                400,
                'SO_TIEN_KHONG_HOP_LE',
                'Số tiền thu vượt công nợ còn lại (1000000.00).',
              );
            }
            daThu = true;
            return reply(201, payment());
          },
          'GET /tuition/payments/9/receipt/': (_) => reply(200, 'XLSX'),
        });
        await openKt(
          t,
          api,
          '/accountant/tuition',
          overrides: [
            saveFileProvider.overrideWithValue(
              (name, bytes, {mime}) async => saved.add(name),
            ),
          ],
        );
        await tapText(t, 'SV2023014');
        expect(find.text('Chi tiết học phí'), findsOneWidget);
        expect(find.text('Chưa có giao dịch nào.'), findsOneWidget);
        expect(find.text('Nhập môn lập trình (CNTT101)'), findsOneWidget);

        await tapText(t, 'Ghi thu');
        expect(find.textContaining('Còn nợ 1.000.000 ₫'), findsOneWidget);
        await enterField(t, 'Số tiền (₫)', '2000000');
        await tapText(t, 'Ghi giao dịch');
        expect(
          find.text('Số tiền thu vượt công nợ còn lại (1000000.00).'),
          findsOneWidget,
        );

        await enterField(t, 'Số tiền (₫)', '500000');
        await tapText(t, 'Ghi giao dịch');
        expect(api.bodies['POST /tuition/payments/'], {
          'so_tien': 500000,
          'phuong_thuc': 'TIEN_MAT',
          'tuition': 5,
          'loai': 'THU',
        });
        expect(find.text('Đã ghi thu học phí.'), findsOneWidget);
        expect(
          find.textContaining('Biên lai BL20270110-000009'),
          findsOneWidget,
        );

        await tapText(t, 'Biên lai Excel');
        expect(saved.single, 'BL20270110-000009.xlsx');
      },
    );

    testWidgets(
      'chưa tính: không ghi thu/hoàn được; Ghi hoàn chỉ bật khi có cần hoàn',
      (t) async {
        final api = ktApi({
          'GET /tuition/': (_) => reply(
            200,
            pageOf([tuitionRow(hienThi: 'CHUA_TINH', trangThai: 'CHUA_TINH')]),
          ),
          'GET /tuition/5/': (_) => reply(
            200,
            detail(
              row: tuitionRow(hienThi: 'CHUA_TINH', trangThai: 'CHUA_TINH'),
            ),
          ),
        });
        await openKt(t, api, '/accountant/tuition');
        await tapText(t, 'SV2023014');
        expect(
          find.text('Cần tính học phí trước khi ghi thu / hoàn.'),
          findsOneWidget,
        );
        expect(find.text('Ghi thu'), findsNothing);
      },
    );

    testWidgets('chờ hoàn tiền: Ghi hoàn bật, Ghi thu tắt', (t) async {
      final row = tuitionRow(
        hienThi: 'CHO_HOAN_TIEN',
        conNo: '0.00',
        canHoan: '200000.00',
      );
      final api = ktApi({
        'GET /tuition/': (_) => reply(200, pageOf([row])),
        'GET /tuition/5/': (_) => reply(200, detail(row: row)),
      });
      await openKt(t, api, '/accountant/tuition');
      await tapText(t, 'SV2023014');
      final thu = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Ghi thu'),
      );
      final hoan = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Ghi hoàn'),
      );
      expect(thu.onPressed, isNull);
      expect(hoan.onPressed, isNotNull);
    });
  });

  group('Kế toán — công nợ', () {
    testWidgets(
      'tab Còn nợ / Chờ hoàn tiền đổi bộ lọc; tổng trang; Chỉ hiện quá hạn gửi qua_han=1',
      (t) async {
        final api = ktApi({
          'GET /tuition/debts/': (o) => reply(
            200,
            pageOf(
              o.queryParameters['hien_thi'] == 'CHO_HOAN_TIEN'
                  ? [
                      tuitionRow(
                        id: 8,
                        hienThi: 'CHO_HOAN_TIEN',
                        conNo: '0.00',
                        canHoan: '300000.00',
                      ),
                    ]
                  : [
                      tuitionRow(quaHan: true),
                      tuitionRow(id: 6, conNo: '500000.00'),
                    ],
            ),
          ),
        });
        await openKt(t, api, '/accountant/debts');
        expect(api.queries['GET /tuition/debts/']!['hien_thi'], 'CON_NO');
        expect(find.text('Tổng (trang này): 1.500.000 ₫'), findsOneWidget);
        expect(find.textContaining('Quá hạn'), findsOneWidget);

        await tapText(t, 'Chỉ hiện quá hạn');
        expect(api.queries['GET /tuition/debts/']!['qua_han'], '1');

        await tapText(t, 'Chờ hoàn tiền');
        expect(
          api.queries['GET /tuition/debts/']!['hien_thi'],
          'CHO_HOAN_TIEN',
        );
        expect(find.text('Tổng (trang này): 300.000 ₫'), findsOneWidget);
        expect(find.text('Ghi hoàn'), findsOneWidget);
      },
    );
  });

  group('Kế toán — cấu hình học phí', () {
    testWidgets(
      'đơn giá: thêm giá theo ngành gửi pham_vi + mã ngành; hạn đóng; miễn giảm xóa có xác nhận',
      (t) async {
        final api = ktApi({
          'GET /tuition/config/': (_) => reply(
            200,
            pageOf([
              {
                'id': 1,
                'hoc_ky': 7,
                'ten_hk': 'Học kỳ 2',
                'han_dong': '2027-02-01',
                'ghi_chu': '',
              },
            ]),
          ),
          'GET /tuition/pricing/': (_) => reply(
            200,
            pageOf([
              {
                'id': 3,
                'hoc_ky': null,
                'ten_hk': null,
                'pham_vi': 'MAC_DINH',
                'tham_chieu': null,
                'don_gia': '100000.00',
              },
            ]),
          ),
          'POST /tuition/pricing/': (_) => reply(201, {'id': 4}),
          'GET /tuition/discounts/': (_) => reply(
            200,
            pageOf([
              {
                'id': 2,
                'sinh_vien': 21,
                'ma_sv': 'SV1',
                'ho_ten': 'Trần Hoàng Nam',
                'hoc_ky': 7,
                'ten_hk': 'Học kỳ 2',
                'loai': 'HOC_BONG',
                'so_tien': null,
                'ty_le': '25.00',
                'ly_do': 'Học bổng',
              },
            ]),
          ),
          'DELETE /tuition/discounts/2/': (_) => reply(204, {}),
        });
        await openKt(t, api, '/accountant/config');
        expect(find.text('14/02/2027'), findsNothing);
        expect(find.text('01/02/2027'), findsOneWidget);

        await tapText(t, 'Đơn giá');
        expect(find.text('Mọi học kỳ'), findsOneWidget);
        expect(find.text('100.000 ₫'), findsOneWidget);
        await tapText(t, '+ Giá ngành');
        await enterField(t, 'Mã ngành', 'CNTT');
        await enterField(t, 'Đơn giá mỗi tín chỉ (₫)', '120000');
        await tapText(t, 'Lưu');
        expect(api.bodies['POST /tuition/pricing/'], {
          'hoc_ky': null,
          'tham_chieu': 'CNTT',
          'don_gia': 120000,
          'pham_vi': 'NGANH',
        });

        await tapText(t, 'Miễn giảm / học bổng');
        expect(find.text('25%'), findsOneWidget);
        await tapText(t, 'Xóa');
        await tapText(t, 'Xóa', index: 1);
        expect(
          api.log.any((l) => l.startsWith('DELETE /tuition/discounts/2/')),
          isTrue,
        );
      },
    );
  });

  group('Sinh viên — học phí', () {
    Map<String, dynamic> my({
      String conNo = '1000000.00',
      String hienThi = 'CON_NO',
      bool cauHinh = true,
    }) => {
      ...detail(
        row: tuitionRow(conNo: conNo, hienThi: hienThi),
        payments: [payment()],
      ),
      'thanh_toan': {
        'ngan_hang': cauHinh ? 'Vietcombank' : '',
        'so_tai_khoan': cauHinh ? '0123456789' : '',
        'chu_tai_khoan': cauHinh ? 'TRUONG DAI HOC X' : '',
        'noi_dung_ck': 'HOCPHI SV2023014 HK7',
      },
    };

    testWidgets(
      'tổng hợp: số tiền, công nợ, chi tiết môn, giao dịch; nút Thanh toán dẫn tới trang QR',
      (t) async {
        await openStudent(
          t,
          svApi({'GET /tuition/my/': (_) => reply(200, my())}),
          '/student/tuition',
        );
        expect(find.text('Học kỳ 2'), findsOneWidget);
        expect(find.text('Còn nợ'), findsWidgets);
        expect(find.text('4.500.000 ₫'), findsOneWidget);
        expect(find.text('Nhập môn lập trình (CNTT101)'), findsOneWidget);
        expect(find.textContaining('BL20270110-000009'), findsOneWidget);

        await tapText(t, 'Thanh toán học phí');
        expect(find.text('Công nợ hiện tại'), findsOneWidget);
      },
    );

    testWidgets('đã đóng đủ: không có nút Thanh toán', (t) async {
      await openStudent(
        t,
        svApi({
          'GET /tuition/my/': (_) =>
              reply(200, my(conNo: '0.00', hienThi: 'DA_DONG')),
        }),
        '/student/tuition',
      );
      expect(find.text('Thanh toán học phí'), findsNothing);
    });

    testWidgets(
      'trang QR: toàn bộ công nợ sinh QR; một phần vượt công nợ → lỗi, không QR; sao chép',
      (t) async {
        await openStudent(
          t,
          svApi({'GET /tuition/my/': (_) => reply(200, my())}),
          '/student/tuition/pay',
        );
        expect(find.text('1.000.000 ₫'), findsWidgets);
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('HOCPHI SV2023014 HK7'), findsOneWidget);

        await tapText(t, 'Một phần');
        expect(find.text('Nhập số tiền hợp lệ để tạo mã QR.'), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
        await enterField(t, 'Số tiền muốn thanh toán (₫)', '2000000');
        expect(find.textContaining('không vượt quá công nợ'), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);

        await enterField(t, 'Số tiền muốn thanh toán (₫)', '400000');
        expect(find.byType(QrImageView), findsOneWidget);
        expect(find.text('400.000 ₫'), findsWidgets);
      },
    );

    testWidgets('chưa cấu hình tài khoản nhận tiền: cảnh báo thay cho QR', (
      t,
    ) async {
      await openStudent(
        t,
        svApi({'GET /tuition/my/': (_) => reply(200, my(cauHinh: false))}),
        '/student/tuition/pay',
      );
      expect(find.textContaining('chưa cấu hình tài khoản'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('không còn công nợ: thông báo, không QR', (t) async {
      await openStudent(
        t,
        svApi({
          'GET /tuition/my/': (_) =>
              reply(200, my(conNo: '0.00', hienThi: 'DA_DONG')),
        }),
        '/student/tuition/pay',
      );
      expect(find.text('Bạn không còn công nợ học phí.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });
  });
}
