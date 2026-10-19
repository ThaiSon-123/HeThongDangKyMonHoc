import 'package:dang_ky_mon_hoc/features/registration/curriculum_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> mon(
  int id,
  String ma,
  String ten,
  int ky, {
  bool daDat = false,
  String khoi = 'chung',
  String loai = 'bat_buoc',
  List<String> tq = const [],
}) => {
  'mon_hoc': id,
  'ma_mon': ma,
  'ten_mon': ten,
  'tong_tin_chi': 3,
  'khoi_kien_thuc': khoi,
  'loai_mon': loai,
  'hoc_ky_goi_y': ky,
  'da_dat': daDat,
  'tien_quyet': tq,
};

Map<String, dynamic> ctdt() => {
  'id': 1,
  'ma_ctdt': 'CNTT-K23',
  'nganh_ten': 'Công nghệ thông tin',
  'khoa_tuyen_sinh': 'K2023',
  'tong_tin_chi_yeu_cau': 130,
  'mon': [
    mon(1, 'MAT101', 'Giải tích 1', 1, daDat: true),
    mon(2, 'MAT102', 'Giải tích 2', 2, tq: ['MAT101']), // F, chưa học lại
    mon(3, 'PED101', 'Giáo dục thể chất', 2, daDat: true),
    mon(4, 'CNTT101', 'Lập trình hướng đối tượng', 3, khoi: 'co_so_nganh'),
    mon(
      5,
      'CNTT402',
      'Học máy',
      3,
      khoi: 'tu_chon',
      loai: 'tu_chon',
      tq: ['CNTT401', 'MAT101'],
    ),
    mon(6, 'CNTT500', 'Khóa luận', 4, khoi: 'tot_nghiep'),
  ],
};

Map<String, dynamic> diem(String ma, int hk, String tk, String chu) => {
  'hoc_ky': hk,
  'ma_mon': ma,
  'diem_tong_ket': tk,
  'diem_chu': chu,
};

Map<String, dynamic> grades() => {
  'gpa': '3.00',
  'tin_chi_tich_luy': 6,
  'diem': [
    diem('MAT101', 1, '9.00', 'A'),
    diem('MAT102', 2, '3.35', 'F'),
    diem('PED101', 2, '6.00', 'P'),
  ],
};

Map<String, dynamic> dk(String ma, String lop, {String tt = 'DA_DANG_KY'}) => {
  'ma_mon': ma,
  'lop_trang_thai': lop,
  'trang_thai': tt,
  'ten_hk': 'Học kỳ 1, 2026–2027',
};

void main() {
  group('gopMonCtdt', () {
    test('trạng thái cá nhân và điểm hiển thị', () {
      final r = {
        for (final m in gopMonCtdt(ctdt(), grades(), [
          dk('CNTT101', 'DANG_HOC'),
          dk('CNTT402', 'MO', tt: 'DA_HUY'), // đã hủy → không tính đang học
        ]))
          m.ma: m,
      };
      expect(r['MAT101']!.trangThai, TrangThaiMon.daDat);
      expect(r['MAT101']!.diem, '9.00');
      expect(r['PED101']!.diem, 'P'); // môn đạt/không đạt hiện P
      expect(r['MAT102']!.trangThai, TrangThaiMon.chuaDat);
      expect(r['MAT102']!.diem, '3.35');
      expect(r['MAT102']!.tienQuyet, ['MAT101']);
      expect(r['CNTT101']!.trangThai, TrangThaiMon.dangHoc);
      expect(r['CNTT101']!.diem, isNull);
      expect(r['CNTT402']!.trangThai, TrangThaiMon.chuaHoc);
      expect(r['CNTT500']!.trangThai, TrangThaiMon.chuaHoc);
    });

    test(
      'học lại môn F: đăng ký lớp đang mở → Đang học (ưu tiên hơn Chưa đạt)',
      () {
        final r = gopMonCtdt(ctdt(), grades(), [dk('MAT102', 'MO')]);
        expect(
          r.firstWhere((m) => m.ma == 'MAT102').trangThai,
          TrangThaiMon.dangHoc,
        );
      },
    );

    test('nhiều lần học: lấy điểm của học kỳ mới nhất', () {
      final g = {
        ...grades(),
        'diem': [
          diem('MAT102', 2, '3.35', 'F'),
          diem('MAT102', 5, '6.10', 'C'),
        ],
      };
      final c = {
        ...ctdt(),
        'mon': [mon(2, 'MAT102', 'Giải tích 2', 2, daDat: true)],
      };
      final m = gopMonCtdt(c, g, const []).single;
      expect(m.trangThai, TrangThaiMon.daDat);
      expect(m.diem, '6.10');
    });
  });

  test('nhanKy: năm học tính từ khóa tuyển sinh', () {
    expect(nhanKy(1, 'K2023'), 'Học kỳ 1 · Năm học 2023–2024');
    expect(nhanKy(2, 'K2023'), 'Học kỳ 2 · Năm học 2023–2024');
    expect(nhanKy(3, 'K2023'), 'Học kỳ 1 · Năm học 2024–2025');
    expect(nhanKy(8, 'K2023'), 'Học kỳ 2 · Năm học 2026–2027');
    expect(nhanKy(1, 'K22'), 'Học kỳ 1 · Năm học 2022–2023'); // khóa 2 chữ số
    expect(nhanKy(3, 'không rõ'), 'Học kỳ 3');
  });

  FakeAdapter api({Map<String, Handler> extra = const {}}) => svApi({
    'GET /curriculums/my/': (_) => reply(200, ctdt()),
    'GET /grades/my/': (_) => reply(200, grades()),
    'GET /registrations/history/': (_) =>
        reply(200, pageOf([dk('CNTT101', 'DANG_HOC')])),
    ...extra,
  });

  testWidgets(
    'tiến độ, phân bổ theo khối, các kỳ với trạng thái và tiên quyết',
    (t) async {
      await openStudent(t, api(), '/student/curriculum');
      expect(find.text('Công nghệ thông tin · Khóa 2023'), findsOneWidget);
      expect(
        find.text('Mã CTĐT: CNTT-K23 · Yêu cầu 130 tín chỉ'),
        findsOneWidget,
      );
      expect(
        find.text('6 / 130 tín chỉ (5%)'),
        findsOneWidget,
      ); // tín chỉ tích lũy lấy từ server
      expect(find.text('Tổng số môn'), findsOneWidget);
      expect(find.text('1 môn chưa đạt cần học lại'), findsOneWidget);
      expect(find.text('Học kỳ 1, 2026–2027'), findsOneWidget);
      for (final khoi in [
        'Chung',
        'Cơ sở ngành',
        'Chuyên ngành',
        'Tự chọn',
        'Tốt nghiệp',
      ]) {
        expect(find.text(khoi), findsWidgets);
      }
      expect(
        find.text('6 / 9 TC'),
        findsOneWidget,
      ); // khối Chung: 2/3 môn đạt (3 TC mỗi môn)
      expect(find.text('Học kỳ 1 · Năm học 2023–2024'), findsOneWidget);
      expect(find.text('Học kỳ 2 · Năm học 2023–2024'), findsOneWidget);
      expect(find.text('Học kỳ hiện tại'), findsOneWidget);
      expect(find.text('Tiên quyết: MAT101'), findsOneWidget);
      expect(find.text('Tiên quyết: CNTT401, MAT101'), findsOneWidget);
      expect(find.text('Chưa đạt (F)'), findsWidgets);
      expect(find.text('P'), findsOneWidget);
    },
  );

  testWidgets('bộ lọc trạng thái ẩn học kỳ không còn môn phù hợp', (t) async {
    await openStudent(t, api(), '/student/curriculum');
    await tapText(
      t,
      'Đang học',
      index: 1,
    ); // chip lọc (thẻ số liệu cũng có chữ "Đang học")
    expect(find.text('Lập trình hướng đối tượng'), findsOneWidget);
    expect(find.text('Giải tích 1'), findsNothing);
    expect(
      find.text('Học kỳ 1 · Năm học 2023–2024'),
      findsNothing,
    ); // kỳ 1 hết môn phù hợp
    await tapText(t, 'Tất cả');
    expect(find.text('Giải tích 1'), findsOneWidget);
  });

  testWidgets('chưa gán CTĐT (404) → thông báo thay cho lỗi', (t) async {
    await openStudent(
      t,
      api(
        extra: {
          'GET /curriculums/my/': (_) => reply(404, {'detail': 'Chưa gán'}),
        },
      ),
      '/student/curriculum',
    );
    expect(
      find.textContaining('chưa được gán chương trình đào tạo'),
      findsOneWidget,
    );
  });

  testWidgets('App (màn hẹp): mỗi môn là một thẻ', (t) async {
    await openStudent(
      t,
      api(),
      '/student/curriculum',
      size: const Size(390, 900),
    );
    expect(
      find.text('Tiên quyết: MAT101'),
      findsNothing,
    ); // dạng thẻ gộp vào dòng mã môn
    expect(
      find.textContaining('MAT102 · 3 TC · Tiên quyết: MAT101'),
      findsOneWidget,
    );
  });
}
