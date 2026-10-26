import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> lop(
  int id,
  String ma,
  int monId,
  String ten, {
  int ky = 1,
  String gv = 'Trần Minh Quân',
}) => {
  'id': id,
  'ma_lop': ma,
  'mon_hoc': monId,
  'ma_mon': 'M$monId',
  'ten_mon': ten,
  'tong_tin_chi': 3,
  'hoc_ky': 7,
  'giao_vien': 4,
  'giao_vien_ten': gv,
  'si_so_toi_da': 45,
  'si_so_hien_tai': 40,
  'trang_thai': 'MO',
  'lich_hoc': [
    {
      'id': id,
      'thu': 2,
      'tiet_bat_dau': 1,
      'so_tiet_moi_buoi': 3,
      'tiet_ket_thuc': 3,
      'buoi': 'SANG',
      'phong': 'A101',
    },
  ],
  'ngay_bat_dau': '2026-09-07',
  'ngay_ket_thuc': '2027-01-17',
  'khoi_kien_thuc': 'co_so_nganh',
  'loai_mon': 'bat_buoc',
  'hoc_ky_goi_y': ky,
};

Map<String, dynamic> available(
  List<Map<String, dynamic>> rows, {
  bool trongCuaSo = true,
  int da = 3,
}) => {
  'count': rows.length,
  'next': null,
  'previous': null,
  'results': rows,
  'meta': {
    'hoc_ky': 7,
    'ten_hk': 'Học kỳ 2, 2026–2027',
    'ngay_bat_dau': '2026-08-31',
    'ngay_ket_thuc': '2027-01-10',
    'trong_cua_so': trongCuaSo,
    'tin_chi_toi_thieu': 12,
    'tin_chi_toi_da': 24,
    'tin_chi_toi_da_canh_bao': 14,
    'tin_chi_da_dang_ky': da,
    'bi_canh_bao_hoc_vu': false,
  },
};

Map<String, dynamic> lichSu(
  int id,
  String ma,
  String ten, {
  String tt = 'DA_DANG_KY',
  String ly = '',
}) => {
  'id': id,
  'lop_hoc_phan': 3,
  'ma_lop': ma,
  'ma_mon': 'M9',
  'ten_mon': ten,
  'tong_tin_chi': 3,
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'giao_vien_ten': 'Trần Minh Quân',
  'lop_trang_thai': 'MO',
  'lich_hoc': [
    {
      'id': 1,
      'thu': 4,
      'tiet_bat_dau': 6,
      'so_tiet_moi_buoi': 3,
      'tiet_ket_thuc': 8,
      'buoi': 'CHIEU',
      'phong': 'B2',
    },
  ],
  'trang_thai': tt,
  'ngay_dang_ky': '2027-01-10T08:30:00+07:00',
  'ngay_huy': tt == 'DA_HUY' ? '2027-01-11T09:00:00+07:00' : null,
  'ly_do_huy': ly,
};

Map<String, dynamic> ctdt() => {
  'id': 1,
  'ma_ctdt': 'CNTT-K23',
  'nganh_ten': 'CNTT',
  'khoa_tuyen_sinh': 'K2023',
  'tong_tin_chi_yeu_cau': 130,
  'mon': [
    {
      'mon_hoc': 1,
      'ma_mon': 'M1',
      'ten_mon': 'Lập trình cơ bản',
      'tong_tin_chi': 3,
      'khoi_kien_thuc': 'chung',
      'loai_mon': 'bat_buoc',
      'hoc_ky_goi_y': 1,
      'da_dat': true,
    },
    {
      'mon_hoc': 2,
      'ma_mon': 'M2',
      'ten_mon': 'Cấu trúc dữ liệu',
      'tong_tin_chi': 3,
      'khoi_kien_thuc': 'co_so_nganh',
      'loai_mon': 'bat_buoc',
      'hoc_ky_goi_y': 3,
      'da_dat': false,
    },
  ],
};

FakeAdapter api0({
  List<Map<String, dynamic>>? classes,
  List<Map<String, dynamic>>? history,
  bool trongCuaSo = true,
  Map<String, Handler> extra = const {},
}) => svApi({
  'GET /courses/available/': (_) => reply(
    200,
    available(
      classes ??
          [
            lop(1, 'M1-01', 1, 'Lập trình cơ bản'),
            lop(2, 'M1-02', 1, 'Lập trình cơ bản'),
            lop(3, 'M2-01', 2, 'Cấu trúc dữ liệu', ky: 3),
          ],
      trongCuaSo: trongCuaSo,
    ),
  ),
  'GET /registrations/history/': (_) => reply(200, pageOf(history ?? [])),
  'GET /curriculums/my/': (_) => reply(200, ctdt()),
  ...extra,
});

void main() {
  testWidgets(
    'gom lớp theo môn; bấm môn xem các lớp; đăng ký gửi body đúng và toast',
    (t) async {
      final api = api0(
        extra: {
          'POST /registrations/': (o) => reply(201, {
            ...lichSu(9, 'M1-01', 'Lập trình cơ bản'),
            'warnings': [
              {'code': 'CHUA_CAU_HINH_GIA', 'message': 'Chưa cấu hình giá.'},
              {
                'code': 'DUOI_TIN_CHI_TOI_THIEU',
                'message': 'Hiện 3 tín chỉ, chưa đạt tối thiểu 12.',
              },
            ],
          }),
        },
      );
      await openStudent(t, api, '/student/register');

      expect(find.text('Học kỳ 2, 2026–2027'), findsOneWidget);
      expect(find.text('Đang mở đăng ký'), findsOneWidget);
      expect(find.text('2 môn · 3 lớp học phần đang mở'), findsOneWidget);
      expect(find.text('2 lớp'), findsOneWidget);

      await tapText(t, 'Lập trình cơ bản');
      expect(find.text('M1-01'), findsOneWidget);
      expect(find.text('M1-02'), findsOneWidget);
      expect(find.text('Thứ 2 · tiết 1–3'), findsWidgets); // cột Lịch học
      expect(find.text('A101'), findsWidgets); // cột Phòng
      expect(find.text('MÃ LỚP'), findsOneWidget); // tiêu đề cột của bảng lớp
      expect(find.text('40/45'), findsWidgets); // sĩ số

      await tapText(t, 'Đăng ký');
      expect(api.bodies['POST /registrations/'], {'lop_hoc_phan': 1});
      expect(find.textContaining('Đã đăng ký lớp M1-01.'), findsOneWidget);
      expect(find.textContaining('chưa đạt tối thiểu 12'), findsOneWidget);
      expect(find.textContaining('Chưa cấu hình giá'), findsNothing);
    },
  );

  testWidgets('server từ chối (trùng lịch) → toast đúng thông điệp', (t) async {
    final api = api0(
      extra: {
        'POST /registrations/': (_) =>
            apiError(409, 'TRUNG_LICH', 'Trùng lịch với lớp M2-01.'),
      },
    );
    await openStudent(t, api, '/student/register');
    await tapText(t, 'Lập trình cơ bản');
    await tapText(t, 'Đăng ký');
    expect(find.text('Trùng lịch với lớp M2-01.'), findsOneWidget);
  });

  testWidgets('bộ lọc Theo CTĐT và Môn chưa học (kết hợp được)', (t) async {
    await openStudent(t, api0(), '/student/register');
    expect(find.text('2 môn · 3 lớp học phần đang mở'), findsOneWidget);

    await tapText(t, 'Môn chưa học'); // M1 đã đạt → ẩn
    expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);
    await tapText(t, 'Môn chưa học');

    await tapText(t, 'Theo CTĐT'); // cả 2 môn đều thuộc CTĐT của sinh viên
    expect(find.text('Kỳ trong chương trình đào tạo'), findsNothing);
    expect(find.text('2 môn · 3 lớp học phần đang mở'), findsOneWidget);
    await tapText(t, 'Môn chưa học'); // kết hợp: M1 đã đạt → ẩn
    expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);
    expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);
  });

  group('thời gian học của lớp', () {
    testWidgets(
      'bảng lớp có cột Thời gian học (ngày bắt đầu – kết thúc của lớp)',
      (t) async {
        await openStudent(t, api0(), '/student/register');
        await tapText(t, 'Lập trình cơ bản');
        expect(find.text('THỜI GIAN HỌC'), findsOneWidget);
        expect(
          find.text('07/09/2026 – 17/01/2027'),
          findsNWidgets(2),
        ); // hai lớp của môn
      },
    );

    testWidgets('lớp chưa có ngày riêng thì lấy theo học kỳ', (t) async {
      final khongNgay = {
        ...lop(1, 'M1-01', 1, 'Lập trình cơ bản'),
        'ngay_bat_dau': null,
        'ngay_ket_thuc': null,
      };
      await openStudent(t, api0(classes: [khongNgay]), '/student/register');
      await tapText(t, 'Lập trình cơ bản');
      expect(find.text('31/08/2026 – 10/01/2027'), findsOneWidget);
    });

    testWidgets('App (390 px): hiện thời gian học dưới lịch học, không tràn', (
      t,
    ) async {
      await openStudent(
        t,
        api0(),
        '/student/register',
        size: const Size(390, 900),
      );
      await tapText(t, 'Lập trình cơ bản');
      expect(find.textContaining('07/09/2026 – 17/01/2027'), findsWidgets);
    });
  });

  group('tìm học phần và lọc học kỳ trong CTĐT', () {
    FakeAdapter apiBon() => api0(
      classes: [
        lop(1, 'M1-01', 1, 'Lập trình cơ bản'),
        lop(2, 'M1-02', 1, 'Lập trình cơ bản'),
        lop(3, 'M2-01', 2, 'Cấu trúc dữ liệu', ky: 3),
        lop(4, 'M3-01', 3, 'Giải tích 2', ky: 3),
      ],
    );

    Future<void> chonKy(WidgetTester t, String ky) async {
      final o = find.byType(DropdownButton<int>);
      await t.ensureVisible(o);
      await t.tap(o);
      await t.pumpAndSettle();
      await t.tap(find.text(ky).last);
      await t.pumpAndSettle();
    }

    testWidgets('tìm theo tên môn không phân biệt hoa thường và dấu', (
      t,
    ) async {
      await openStudent(t, apiBon(), '/student/register');
      expect(find.text('3 môn · 4 lớp học phần đang mở'), findsOneWidget);

      await enterField(t, 'Tìm học phần', 'cau TRUC');
      expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);
      expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);
      expect(find.text('Lập trình cơ bản'), findsNothing);

      await enterField(
        t,
        'Tìm học phần',
        'lap trinh',
      ); // giữ cả hai lớp của môn
      expect(find.text('1 môn · 2 lớp học phần đang mở'), findsOneWidget);

      await enterField(t, 'Tìm học phần', 'M1-02'); // theo mã lớp
      expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);

      await enterField(t, 'Tìm học phần', 'khong co mon nay');
      expect(find.text('Không có môn phù hợp với bộ lọc.'), findsOneWidget);

      await enterField(t, 'Tìm học phần', '');
      expect(find.text('3 môn · 4 lớp học phần đang mở'), findsOneWidget);
    });

    testWidgets('lọc theo học kỳ trong CTĐT, kết hợp với tìm kiếm', (t) async {
      await openStudent(t, apiBon(), '/student/register');
      await chonKy(t, 'Học kỳ 3');
      expect(find.text('2 môn · 2 lớp học phần đang mở'), findsOneWidget);
      expect(find.text('Lập trình cơ bản'), findsNothing);

      await enterField(t, 'Tìm học phần', 'giai tich');
      expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);
      expect(find.text('Giải tích 2'), findsOneWidget);

      await enterField(t, 'Tìm học phần', '');
      await chonKy(t, 'Tất cả học kỳ');
      expect(find.text('3 môn · 4 lớp học phần đang mở'), findsOneWidget);
    });

    testWidgets('chỉ liệt kê các học kỳ CTĐT có môn đang mở', (t) async {
      await openStudent(t, apiBon(), '/student/register');
      final o = find.byType(DropdownButton<int>);
      await t.tap(o);
      await t.pumpAndSettle();
      expect(find.text('Học kỳ 1'), findsWidgets);
      expect(find.text('Học kỳ 3'), findsWidgets);
      expect(find.text('Học kỳ 2'), findsNothing);
    });

    testWidgets('App (390 px): ô tìm và ô chọn học kỳ không tràn', (t) async {
      await openStudent(
        t,
        apiBon(),
        '/student/register',
        size: const Size(390, 900),
      );
      expect(find.text('Tìm học phần'), findsOneWidget);
      expect(find.text('Học kỳ trong CTĐT'), findsOneWidget);
    });
  });

  testWidgets(
    'ngoài thời gian đăng ký: banner, nút Đăng ký bị khóa, không hủy được',
    (t) async {
      final api = api0(
        trongCuaSo: false,
        history: [lichSu(5, 'M9-01', 'Giải tích')],
      );
      await openStudent(t, api, '/student/register');
      expect(find.text('Ngoài thời gian đăng ký'), findsOneWidget);
      expect(find.textContaining('liên hệ Phòng đào tạo'), findsOneWidget);

      await tapText(t, 'Lập trình cơ bản');
      final btn = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Đăng ký').first,
      );
      expect(btn.onPressed, isNull);

      await tapText(t, 'Đã đăng ký (1)');
      expect(find.text('Liên hệ Phòng đào tạo để hủy'), findsOneWidget);
      expect(find.text('Hủy đăng ký'), findsNothing);
    },
  );

  testWidgets(
    'tab Đã đăng ký: hủy có xác nhận → DELETE; tab Lịch sử hiện lý do hủy',
    (t) async {
      final api = api0(
        history: [
          lichSu(5, 'M9-01', 'Giải tích'),
          lichSu(6, 'M8-01', 'Vật lý', tt: 'DA_HUY', ly: 'Đổi lịch'),
        ],
        extra: {
          'DELETE /registrations/5/': (_) => reply(200, {
            ...lichSu(5, 'M9-01', 'Giải tích', tt: 'DA_HUY'),
            'warnings': [],
          }),
        },
      );
      await openStudent(t, api, '/student/register');
      await tapText(t, 'Đã đăng ký (1)');
      expect(find.text('Thứ 4 · tiết 6–8'), findsOneWidget);

      await tapText(t, 'Hủy đăng ký');
      await tapText(t, 'Hủy đăng ký', index: 1); // nút xác nhận
      expect(
        api.log.any((l) => l.startsWith('DELETE /registrations/5/')),
        isTrue,
      );
      expect(find.text('Đã hủy đăng ký lớp M9-01.'), findsOneWidget);

      await tapText(t, 'Lịch sử');
      expect(find.textContaining('Đổi lịch'), findsOneWidget);
      expect(
        find.text('Đã hủy'),
        findsNWidgets(2),
      ); // nút lọc + nhãn của đăng ký đã hủy
    },
  );

  testWidgets('tab Lịch sử: lọc theo học kỳ và trạng thái', (t) async {
    final api = api0(
      history: [
        lichSu(5, 'M9-01', 'Giải tích'),
        lichSu(6, 'M8-01', 'Vật lý', tt: 'DA_HUY', ly: 'Đổi lịch'),
        {...lichSu(7, 'M7-01', 'Hóa học'), 'hoc_ky': 6, 'ten_hk': 'Học kỳ 1'},
      ],
    );
    await openStudent(t, api, '/student/register');
    await tapText(t, 'Lịch sử');
    expect(find.text('3 đăng ký'), findsOneWidget);

    await tapText(t, 'Đã hủy'); // nút lọc (đứng trước nhãn trong danh sách)
    expect(find.text('1 đăng ký'), findsOneWidget);
    expect(find.text('Vật lý'), findsOneWidget);
    expect(find.text('Giải tích'), findsNothing);

    await tapText(t, 'Tất cả');
    await tapText(t, 'Tất cả học kỳ');
    await t.tap(find.text('Học kỳ 1').last);
    await t.pumpAndSettle();
    expect(find.text('1 đăng ký'), findsOneWidget);
    expect(find.text('Hóa học'), findsOneWidget);

    await tapText(t, 'Đã hủy'); // học kỳ 1 không có đăng ký đã hủy
    expect(
      find.text('Không có đăng ký nào phù hợp với bộ lọc.'),
      findsOneWidget,
    );
  });

  testWidgets('bố cục App (390 px): không tràn, vẫn đăng ký được', (t) async {
    final api = api0(
      extra: {
        'POST /registrations/': (_) => reply(201, {
          ...lichSu(9, 'M1-01', 'Lập trình cơ bản'),
          'warnings': [],
        }),
      },
    );
    await openStudent(t, api, '/student/register', size: const Size(390, 844));
    await tapText(t, 'Lập trình cơ bản');
    await tapText(t, 'Đăng ký');
    expect(api.bodies['POST /registrations/'], {'lop_hoc_phan': 1});
    expect(t.takeException(), isNull);
  });
}
