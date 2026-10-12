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
      expect(find.textContaining('Thứ 2 · tiết 1–3 · A101'), findsWidgets);

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

  testWidgets('bộ lọc Theo CTĐT + kỳ và Môn chưa học (kết hợp được)', (
    t,
  ) async {
    await openStudent(t, api0(), '/student/register');
    expect(find.text('2 môn · 3 lớp học phần đang mở'), findsOneWidget);

    await tapText(t, 'Môn chưa học'); // M1 đã đạt → ẩn
    expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);
    await tapText(t, 'Môn chưa học');

    await tapText(t, 'Theo CTĐT');
    await tapText(t, 'Tất cả các kỳ');
    await t.tap(find.text('Kỳ 3').last);
    await t.pumpAndSettle();
    expect(find.text('1 môn · 1 lớp học phần đang mở'), findsOneWidget);
    expect(find.text('Cấu trúc dữ liệu'), findsOneWidget);
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
      expect(find.text('Đã hủy'), findsOneWidget);
    },
  );

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
