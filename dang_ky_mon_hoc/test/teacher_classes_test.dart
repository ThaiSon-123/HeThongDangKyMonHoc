import 'package:dang_ky_mon_hoc/core/download/save_file_provider.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/core/theme/app_colors.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:dang_ky_mon_hoc/features/training/training_widgets.dart'
    show PanelCard;
import 'package:dang_ky_mon_hoc/features/teacher/teacher_classes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

// "Hôm nay" cố định 13/01/2027.
final _homNay = DateTime(2027, 1, 13, 9);

Map<String, dynamic> lich(
  int id,
  int thu,
  int tiet,
  int soTiet,
  String phong,
) => {
  'id': id,
  'thu': thu,
  'tiet_bat_dau': tiet,
  'so_tiet_moi_buoi': soTiet,
  'tiet_ket_thuc': tiet + soTiet - 1,
  'buoi': 'SANG',
  'phong': phong,
};

Map<String, dynamic> lop(
  int id,
  String ma,
  String mon, {
  String tt = 'DANG_HOC',
  int si = 42,
  int toiDa = 45,
  String han = '2027-01-23',
  bool duyet = false,
}) => {
  'id': id,
  'ma_lop': ma,
  'ten_mon': mon,
  'ten_hk': 'HK1 2026–2027',
  'trang_thai': tt,
  'si_so_hien_tai': si,
  'si_so_toi_da': toiDa,
  'han_nhap_diem_hieu_luc': han,
  'diem_da_duyet': duyet,
  'lich_hoc': [lich(1, 3, 1, 3, 'A101'), lich(2, 7, 1, 3, 'A102')],
};

Map<String, dynamic> chiTiet() => {
  ...lop(3, 'CNTT101-01', 'Lập trình hướng đối tượng'),
  'ngay_bat_dau': null,
  'ngay_ket_thuc': null,
  'ngay_bat_dau_hieu_luc': '2026-08-17',
  'ngay_ket_thuc_hieu_luc': '2027-01-09',
  'tong_tin_chi': 3,
  'tin_chi_ly_thuyet': 2,
  'tin_chi_thuc_hanh': 1,
  'tong_so_buoi': 42,
};

FakeAdapter gvApi([Map<String, Handler> extra = const {}]) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
  ),
  'GET /class-sections/my/': (_) => reply(
    200,
    pageOf([
      lop(3, 'CNTT101-01', 'Lập trình hướng đối tượng'),
      lop(
        4,
        'CNTT320-01',
        'Kỹ thuật phần mềm',
        si: 34,
        toiDa: 40,
        han: '2027-01-12',
      ),
      lop(
        5,
        'CNTT110-03',
        'Cấu trúc dữ liệu và giải thuật',
        tt: 'DA_DONG',
        si: 40,
        toiDa: 40,
        han: '2026-07-01',
        duyet: true,
      ),
    ]),
  ),
  'GET /class-sections/3/': (_) => reply(200, chiTiet()),
  'GET /class-sections/3/students/': (_) => reply(200, {
    'lop_hoc_phan': 3,
    'si_so': 2,
    'si_so_toi_da': 45,
    'records': [
      {
        'sinh_vien': 1,
        'ma_sv': 'SV2026001',
        'ho_ten': 'Nguyễn Văn An',
        'nganh_ten': 'Công nghệ thông tin',
      },
      {
        'sinh_vien': 2,
        'ma_sv': 'SV2026002',
        'ho_ten': 'Trần Thị Bình',
        'nganh_ten': 'Công nghệ thông tin',
      },
    ],
  }),
  'GET /class-sections/3/export/': (_) => reply(200, 'XLSX'),
  'GET /timetable/my/': (_) => reply(200, {'lop_hoc_phan': []}),
  'GET /attendance/sessions/': (_) =>
      reply(200, {...pageOf([]), 'tong_so_buoi': 0}),
  'GET /attendance/requests/': (_) => reply(200, pageOf([])),
  ...extra,
});

Future<void> openClasses(
  WidgetTester t,
  FakeAdapter api, {
  Size size = bigScreen,
  List<Override> overrides = const [],
}) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: size,
    overrides: [clockProvider.overrideWithValue(() => _homNay), ...overrides],
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go('/teacher/classes');
  await t.pumpAndSettle();
}

void main() {
  test('hạn nhập điểm: đếm ngược, vàng khi còn ≤ 3 ngày, đỏ khi quá hạn', () {
    final (con, mauCon) = hanNhapDiemInfo('2027-01-23', _homNay);
    expect(con, '23/01/2027 · còn 10 ngày');
    expect(mauCon, AppColors.muted);
    expect(
      hanNhapDiemInfo('2027-01-16', _homNay).$1,
      '16/01/2027 · còn 3 ngày',
    );
    expect(hanNhapDiemInfo('2027-01-16', _homNay).$2, isNot(AppColors.muted));
    expect(
      hanNhapDiemInfo('2027-01-13', _homNay).$1,
      contains('hết hạn hôm nay'),
    );
    final (qua, mauQua) = hanNhapDiemInfo('2027-01-12', _homNay);
    expect(qua, '12/01/2027 · quá hạn 1 ngày');
    expect(mauQua, AppColors.danger);
    expect(hanNhapDiemInfo('', _homNay).$1, '—');
  });

  testWidgets('danh sách lớp: thẻ lớp, hạn nhập điểm, lọc theo trạng thái', (
    t,
  ) async {
    await openClasses(t, gvApi());
    expect(find.text('Lập trình hướng đối tượng'), findsOneWidget);
    expect(find.text('CNTT101-01 · HK1 2026–2027'), findsOneWidget);
    expect(find.text('Thứ 3 · T1–3'), findsWidgets);
    expect(find.text('CN'), findsNothing);
    expect(find.text('42/45 SV'), findsOneWidget);
    expect(find.text('Hạn nhập điểm 23/01/2027 · còn 10 ngày'), findsOneWidget);
    expect(
      find.text('Hạn nhập điểm 12/01/2027 · quá hạn 1 ngày'),
      findsOneWidget,
    );
    expect(find.text('Điểm đã được duyệt'), findsOneWidget);
    expect(
      find.text('Chọn một lớp ở danh sách bên trái để xem chi tiết.'),
      findsOneWidget,
    );

    await tapText(t, 'Đã đóng', index: 0); // chip lọc
    expect(find.text('Lập trình hướng đối tượng'), findsNothing);
    expect(find.text('Cấu trúc dữ liệu và giải thuật'), findsOneWidget);
    await tapText(t, 'Tất cả');
    expect(find.text('Kỹ thuật phần mềm'), findsOneWidget);
  });

  testWidgets(
    'chi tiết lớp: thông tin (ngày theo học kỳ), lịch học, danh sách SV và Xuất Excel',
    (t) async {
      final saved = <String>[];
      final api = gvApi();
      await openClasses(
        t,
        api,
        overrides: [
          saveFileProvider.overrideWithValue(
            (name, bytes, {mime}) async => saved.add(name),
          ),
        ],
      );
      await tapText(t, 'Lập trình hướng đối tượng');
      expect(
        api.log.any((l) => l.startsWith('GET /class-sections/3/ ')),
        isTrue,
      );
      expect(find.text('3 (2 LT + 1 TH)'), findsOneWidget);
      expect(find.text('17/08/2026 (theo học kỳ)'), findsOneWidget);
      expect(find.text('09/01/2027 (theo học kỳ)'), findsOneWidget);
      expect(find.text('42 buổi theo lịch'), findsOneWidget);
      // Danh sách SV chỉ tải khi mở tab.
      expect(
        api.log.any((l) => l.startsWith('GET /class-sections/3/students/')),
        isFalse,
      );

      await tapText(t, 'Lịch học');
      expect(find.text('Tiết 1–3 · Sáng'), findsNWidgets(2));
      expect(find.text('A102'), findsOneWidget);

      await tapText(t, 'Danh sách SV');
      expect(find.text('2/45 sinh viên đã đăng ký'), findsOneWidget);
      expect(find.text('SV2026001'), findsOneWidget);
      expect(find.text('Trần Thị Bình'), findsOneWidget);

      await tapText(t, 'Xuất Excel');
      expect(saved, ['CNTT101-01.xlsx']);
      expect(find.text('Đã xuất tệp Excel.'), findsOneWidget);

      await tapText(t, 'Lịch dạy của tôi');
      expect(api.log.any((l) => l.startsWith('GET /timetable/my/')), isTrue);
    },
  );

  testWidgets('nút Điểm danh mở màn điểm danh với lớp đã chọn sẵn', (t) async {
    final api = gvApi();
    await openClasses(t, api);
    await tapText(t, 'Lập trình hướng đối tượng');
    // Chữ "Điểm danh" cũng có ở menu bên trái — bấm nút trong khung chi tiết.
    await t.tap(
      find.descendant(
        of: find.byType(PanelCard),
        matching: find.text('Điểm danh'),
      ),
    );
    await t.pumpAndSettle();
    expect(api.queries['GET /attendance/sessions/']!['lop_hoc_phan'], 3);
    expect(find.text('Chọn lớp để xem các buổi điểm danh'), findsNothing);
  });

  testWidgets(
    'App (màn hẹp): danh sách → chi tiết → quay lại; không có tab lịch dạy',
    (t) async {
      await openClasses(t, gvApi(), size: const Size(390, 844));
      expect(find.text('Lập trình hướng đối tượng'), findsOneWidget);
      await tapText(t, 'Lập trình hướng đối tượng');
      expect(find.text('Sinh viên'), findsOneWidget);
      expect(find.text('Lịch dạy của tôi'), findsNothing);
      expect(find.text('42 buổi theo lịch'), findsOneWidget);

      // "Lớp phụ trách" cũng là tiêu đề trang — bấm nút quay lại (mũi tên) trong màn chi tiết.
      await t.tap(find.byIcon(Icons.arrow_back));
      await t.pumpAndSettle();
      expect(find.text('Kỹ thuật phần mềm'), findsOneWidget);
      expect(find.text('3 (2 LT + 1 TH)'), findsNothing);
    },
  );

  testWidgets('chưa được phân công lớp nào → thông báo trống', (t) async {
    await openClasses(
      t,
      gvApi({'GET /class-sections/my/': (_) => reply(200, pageOf([]))}),
    );
    expect(find.text('Bạn chưa được phân công lớp nào.'), findsOneWidget);
  });
}
