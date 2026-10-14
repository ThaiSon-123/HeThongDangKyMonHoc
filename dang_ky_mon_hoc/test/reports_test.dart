import 'package:dang_ky_mon_hoc/core/download/save_file_provider.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/features/reports/report_widgets.dart';
import 'package:dang_ky_mon_hoc/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> lop(
  int id,
  String ma,
  String mon,
  int si,
  int toiDa, {
  String tt = 'MO',
}) => {
  'id': id,
  'ma_lop': ma,
  'ten_mon': mon,
  'giao_vien_ten': 'Nguyễn Thị Mai',
  'si_so_hien_tai': si,
  'si_so_toi_da': toiDa,
  'ty_le_lap_day': (100 * si / toiDa * 10).round() / 10,
  'trang_thai': tt,
};

Map<String, dynamic> trainingReport() => {
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'tong': {
    'so_sinh_vien': 104,
    'so_lop': 3,
    'tong_luot_dang_ky': 352,
    'lop_day': 1,
    'lop_con_cho': 1,
  },
  'theo_mon': [
    {
      'mon_hoc': 1,
      'ma_mon': 'CNTT401',
      'ten_mon': 'Trí tuệ nhân tạo',
      'luot_dang_ky': 96,
    },
    {
      'mon_hoc': 2,
      'ma_mon': 'MAT102',
      'ten_mon': 'Giải tích 2',
      'luot_dang_ky': 48,
    },
  ],
  'theo_lop': [
    lop(1, 'CNTT401-02', 'Trí tuệ nhân tạo', 44, 45),
    lop(2, 'MAT102-01', 'Giải tích 2', 20, 50),
    lop(3, 'CNTT402-01', 'Học máy', 28, 40, tt: 'DANG_HOC'),
  ],
};

Map<String, dynamic> financeReport() => {
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'tong': {
    'phai_thu': '40970000.00',
    'da_thu': '29970000.00',
    'con_no': '11500000.00',
    'cho_hoan': '500000.00',
    'so_sinh_vien': 3,
    'so_chua_tinh': 1,
    'so_con_no': 1,
    'so_qua_han': 1,
    'so_cho_hoan': 1,
  },
  'theo_nganh': [
    {
      'nganh_ma': 'CNTT',
      'nganh_ten': 'Công nghệ thông tin',
      'phai_thu': '20550000.00',
      'da_thu': '10730000.00',
    },
    {
      'nganh_ma': 'KTPM',
      'nganh_ten': 'Kỹ thuật phần mềm',
      'phai_thu': '10920000.00',
      'da_thu': '9240000.00',
    },
  ],
};

Map<String, dynamic> hocPhi(
  String ma,
  String ten, {
  String hienThi = 'CON_NO',
  String conNo = '4320000.00',
  String canHoan = '0.00',
  bool quaHan = true,
}) => {
  'id': 5,
  'sinh_vien': 21,
  'ma_sv': ma,
  'ho_ten': ten,
  'nganh_ma': 'CNTT',
  'nganh_ten': 'Công nghệ thông tin',
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'tong_tin_chi': 12,
  'tong_tien': '6000000.00',
  'trang_thai': hienThi == 'CHUA_TINH' ? 'CHUA_TINH' : 'DA_TINH',
  'mien_giam': '0.00',
  'phai_nop': '6000000.00',
  'thuc_thu': '1680000.00',
  'con_no': conNo,
  'can_hoan': canHoan,
  'hien_thi': hienThi,
  'han_dong': '2027-02-01',
  'qua_han': quaHan,
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

/// Mở ô chọn thứ [index] trong thanh lọc rồi chọn dòng [option].
Future<void> pickOption(WidgetTester t, int index, String option) async {
  await t.tap(find.byType(TextField).at(index));
  await t.pumpAndSettle();
  await t.tap(find.text(option).last);
  await t.pumpAndSettle();
}

void main() {
  test('màu thanh lấp đầy: xanh < 70%, vàng 70–90%, đỏ > 90%', () {
    expect(lapDayColor(69.9), AppColors.success);
    expect(lapDayColor(70), AppColors.warning);
    expect(lapDayColor(90), AppColors.warning);
    expect(lapDayColor(90.1), AppColors.danger);
  });

  group('Báo cáo đào tạo (PĐT)', () {
    FakeAdapter api() => pdtApi({
      'GET /reports/training/': (_) => reply(200, trainingReport()),
      'GET /reports/training/export/': (_) => reply(200, 'XLSX'),
      'GET /majors/': (_) => reply(
        200,
        pageOf([
          {'id': 3, 'ten_nganh': 'Công nghệ thông tin'},
        ]),
      ),
      'GET /courses/': (_) => reply(200, pageOf([])),
    });

    testWidgets(
      'thẻ tổng quan, hai biểu đồ và bảng sắp theo lấp đầy giảm dần',
      (t) async {
        await openPdt(t, api(), '/pdt/reports');
        for (final s in ['104', '352', 'Lớp đầy', 'Lớp còn chỗ']) {
          expect(find.text(s), findsOneWidget);
        }
        expect(find.text('CNTT401 · Trí tuệ nhân tạo'), findsOneWidget);
        expect(find.text('96'), findsOneWidget);
        expect(find.text('Chi tiết theo lớp'), findsOneWidget);
        // CNTT401-02 (98%) xếp trên CNTT402-01 (70%) và MAT102-01 (40%) ở bảng.
        double y(String ma) =>
            t.getTopLeft(find.text(ma).last).dy; // lần xuất hiện cuối = bảng
        expect(y('CNTT401-02'), lessThan(y('CNTT402-01')));
        expect(y('CNTT402-01'), lessThan(y('MAT102-01')));
        expect(find.text('Đang học'), findsOneWidget);
      },
    );

    testWidgets('bấm tiêu đề cột để đổi chiều sắp xếp', (t) async {
      await openPdt(t, api(), '/pdt/reports');
      double y(String ma) => t.getTopLeft(find.text(ma).last).dy;
      await tapText(t, 'MÃ LỚP');
      expect(y('CNTT401-02'), lessThan(y('MAT102-01'))); // A → Z
      expect(y('CNTT402-01'), greaterThan(y('CNTT401-02')));
      await tapText(t, 'MÃ LỚP ▲');
      expect(y('MAT102-01'), lessThan(y('CNTT401-02'))); // Z → A
    });

    testWidgets('đổi bộ lọc tải lại báo cáo; Xuất Excel kèm bộ lọc', (t) async {
      final saved = <String>[];
      final a = api();
      await openPdt(
        t,
        a,
        '/pdt/reports',
        overrides: [
          saveFileProvider.overrideWithValue(
            (name, bytes, {mime}) async => saved.add(name),
          ),
        ],
      );
      expect(a.queries['GET /reports/training/'], isEmpty);

      await pickOption(t, 1, 'Công nghệ thông tin');
      expect(a.queries['GET /reports/training/']!['nganh'], 3);

      await tapText(t, 'Xuất Excel');
      expect(a.queries['GET /reports/training/export/']!['nganh'], 3);
      expect(saved, ['bao_cao_dao_tao.xlsx']);
      expect(find.text('Đã xuất tệp Excel.'), findsOneWidget);
    });

    testWidgets('lỗi tải → nút Thử lại', (t) async {
      var lan = 0;
      final a = pdtApi({
        'GET /reports/training/': (_) => ++lan == 1
            ? apiError(500, 'LOI_HE_THONG')
            : reply(200, trainingReport()),
      });
      await openPdt(t, a, '/pdt/reports');
      expect(find.text('Thử lại'), findsOneWidget);
      await tapText(t, 'Thử lại');
      expect(find.text('Chi tiết theo lớp'), findsOneWidget);
    });
  });

  group('Báo cáo tài chính (Kế toán)', () {
    FakeAdapter api() => ktApi({
      'GET /reports/finance/': (_) => reply(200, financeReport()),
      'GET /reports/finance/export/': (_) => reply(200, 'XLSX'),
      'GET /tuition/': (_) => reply(
        200,
        pageOf([
          hocPhi('SV2023014', 'Trần Hoàng Nam'),
          hocPhi(
            'SV2025007',
            'Ngô Bảo Châu',
            hienThi: 'CHUA_TINH',
            conNo: '0.00',
            quaHan: false,
          ),
          hocPhi(
            'SV2023047',
            'Lê Minh Châu',
            hienThi: 'CHO_HOAN_TIEN',
            conNo: '0.00',
            canHoan: '500000.00',
            quaHan: false,
          ),
        ]),
      ),
      'GET /majors/': (_) => reply(
        200,
        pageOf([
          {'id': 3, 'ten_nganh': 'Công nghệ thông tin'},
        ]),
      ),
      'GET /class-sections/': (_) => reply(200, pageOf([])),
      'GET /tuition/students/': (_) => reply(200, pageOf([])),
    });

    testWidgets('bốn thẻ tổng, biểu đồ theo ngành và bảng từng sinh viên', (
      t,
    ) async {
      await openKt(t, api(), '/accountant/reports');
      expect(find.text('40.970.000 ₫'), findsOneWidget);
      expect(find.text('29.970.000 ₫'), findsOneWidget);
      expect(find.text('11.500.000 ₫'), findsOneWidget);
      expect(
        find.text('500.000 ₫'),
        findsWidgets,
      ); // thẻ Chờ hoàn tiền + ô Cần hoàn
      expect(find.text('CNTT'), findsWidgets);
      expect(find.text('20.550.000 ₫'), findsOneWidget);
      expect(find.text('SV2023014'), findsOneWidget);
      expect(find.text('Quá hạn'), findsOneWidget);
      expect(find.text('Chưa tính'), findsOneWidget);
      expect(find.text('Chờ hoàn tiền'), findsWidgets);
    });

    testWidgets(
      'đổi ngành lọc cả tổng hợp lẫn bảng và chỉ tính lại tổng một lần',
      (t) async {
        final a = api();
        await openKt(t, a, '/accountant/reports');
        final truoc = a.log
            .where((l) => l.startsWith('GET /reports/finance/ '))
            .length;

        await pickOption(t, 1, 'Công nghệ thông tin');
        expect(a.queries['GET /reports/finance/']!['nganh'], 3);
        expect(a.queries['GET /tuition/']!['nganh'], 3);
        expect(
          a.log.where((l) => l.startsWith('GET /reports/finance/ ')).length,
          truoc + 1,
        );
      },
    );

    testWidgets('Xuất Excel kèm bộ lọc hiện tại', (t) async {
      final saved = <String>[];
      final a = api();
      await openKt(
        t,
        a,
        '/accountant/reports',
        overrides: [
          saveFileProvider.overrideWithValue(
            (name, bytes, {mime}) async => saved.add(name),
          ),
        ],
      );
      await pickOption(t, 1, 'Công nghệ thông tin');
      await tapText(t, 'Xuất Excel');
      expect(a.queries['GET /reports/finance/export/']!['nganh'], 3);
      expect(saved, ['bao_cao_tai_chinh.xlsx']);
    });
  });
}
