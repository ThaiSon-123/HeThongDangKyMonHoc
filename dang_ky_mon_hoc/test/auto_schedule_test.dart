import 'package:dang_ky_mon_hoc/features/registration/auto_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> lich(
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
  int mon,
  String ten,
  List<Map<String, dynamic>> lichHoc, {
  int gv = 1,
  String gvTen = 'Nguyễn Thị Mai',
  String loai = 'bat_buoc',
  int ky = 8,
}) => {
  'id': id,
  'ma_lop': ma,
  'mon_hoc': mon,
  'ma_mon': 'M$mon',
  'ten_mon': ten,
  'tong_tin_chi': 3,
  'hoc_ky': 7,
  'giao_vien': gv,
  'giao_vien_ten': gvTen,
  'si_so_toi_da': 45,
  'si_so_hien_tai': 10,
  'trang_thai': 'MO',
  'lich_hoc': lichHoc,
  'loai_mon': loai,
  'khoi_kien_thuc': 'chuyen_nganh',
  'hoc_ky_goi_y': ky,
};

final _lop = [
  // Môn 1: Trí tuệ nhân tạo — hai giáo viên
  lop(11, 'CNTT401-01', 1, 'Trí tuệ nhân tạo', [lich(2, 1, 3)]),
  lop(
    12,
    'CNTT401-03',
    1,
    'Trí tuệ nhân tạo',
    [lich(5, 6, 3)],
    gv: 2,
    gvTen: 'Vũ Đức Anh',
  ),
  // Môn 2: Học máy
  lop(21, 'CNTT402-01', 2, 'Học máy', [lich(3, 1, 3)]),
  lop(22, 'CNTT402-02', 2, 'Học máy', [lich(7, 1, 3)]),
  // Môn 3: An toàn thông tin — tự chọn
  lop(31, 'CNTT410-01', 3, 'An toàn thông tin', [
    lich(4, 1, 3),
  ], loai: 'tu_chon'),
  // Môn 4: Giải tích — đã đạt
  lop(41, 'MAT102-01', 4, 'Giải tích 2', [lich(6, 1, 3)]),
  // Môn 5: đã đăng ký rồi → không được hiện
  lop(51, 'CNTT500-01', 5, 'Môn đã đăng ký', [lich(2, 6, 3)]),
];

FakeAdapter api({
  List<Map<String, dynamic>>? lops,
  Map<String, Handler> extra = const {},
}) => svApi({
  'GET /auto-schedule/available-courses/': (_) => reply(200, {
    ...pageOf(lops ?? _lop),
    'meta': {
      'hoc_ky': 7,
      'ten_hk': 'Học kỳ 2, 2026–2027',
      'trong_cua_so': true,
      'tin_chi_toi_thieu': 12,
      'tin_chi_toi_da': 24,
      'tin_chi_toi_da_canh_bao': 14,
      'tin_chi_da_dang_ky': 3,
      'bi_canh_bao_hoc_vu': false,
    },
  }),
  'GET /curriculums/my/': (_) => reply(200, {
    'mon': [
      {'mon_hoc': 1, 'da_dat': false},
      {'mon_hoc': 4, 'da_dat': true},
    ],
  }),
  'GET /timetable/my/': (_) => reply(200, {
    'lop_hoc_phan': [
      lop(51, 'CNTT500-01', 5, 'Môn đã đăng ký', [lich(2, 6, 3)]),
    ],
  }),
  ...extra,
});

Future<void> open(WidgetTester t, FakeAdapter a, {Size size = bigScreen}) =>
    openStudent(
      t,
      a,
      '/student/auto-schedule',
      size: size,
      overrides: [autoScheduleDelayProvider.overrideWithValue(Duration.zero)],
    );

void main() {
  testWidgets(
    'bước 1: môn bắt buộc chọn sẵn, môn đã đăng ký không hiện, môn đã đạt bị khóa',
    (t) async {
      await open(t, api());
      expect(find.text('Chọn môn và ưu tiên'), findsOneWidget);
      expect(find.text('Trí tuệ nhân tạo'), findsOneWidget);
      expect(find.text('Học máy'), findsOneWidget);
      expect(find.text('An toàn thông tin'), findsOneWidget);
      expect(find.text('Môn đã đăng ký'), findsNothing);
      expect(find.text('Đã đạt'), findsOneWidget);
      // Bắt buộc & chưa đạt = Trí tuệ nhân tạo + Học máy.
      expect(find.text('Đã chọn 2 môn · 6 tín chỉ'), findsOneWidget);
      expect(
        find.text(
          'Học kỳ 2, 2026–2027 · môn bắt buộc theo học kỳ gợi ý được chọn sẵn',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'chọn giáo viên mong muốn thì tự tick môn; tick/bỏ tick đổi tổng tín chỉ',
    (t) async {
      await open(t, api());
      await t.tap(find.byType(Checkbox).at(2)); // An toàn thông tin
      await t.pumpAndSettle();
      expect(find.text('Đã chọn 3 môn · 9 tín chỉ'), findsOneWidget);
      await t.tap(find.byType(Checkbox).at(2));
      await t.pumpAndSettle();
      expect(find.text('Đã chọn 2 môn · 6 tín chỉ'), findsOneWidget);

      await t.tap(find.byType(Checkbox).first); // bỏ Trí tuệ nhân tạo
      await t.pumpAndSettle();
      expect(find.text('Đã chọn 1 môn · 3 tín chỉ'), findsOneWidget);
      await tapText(t, 'Trí tuệ nhân tạo'); // mở rộng môn
      await tapText(t, 'Vũ Đức Anh'); // chọn giáo viên → tự tick
      expect(find.text('Đã chọn 2 môn · 6 tín chỉ'), findsOneWidget);
      expect(
        find.text('Đã chọn'),
        findsOneWidget,
      ); // nhãn trên lớp của giáo viên đó
    },
  );

  testWidgets('ngày muốn học và ngày tránh loại trừ nhau', (t) async {
    await open(t, api());
    final tranh = find.widgetWithText(FilterChip, 'T7');
    await t.ensureVisible(tranh.first);
    await t.tap(tranh.first); // tránh T7
    await t.pumpAndSettle();
    expect(t.widget<FilterChip>(tranh.at(0)).selected, isTrue);
    await t.tap(tranh.at(1)); // muốn học T7 → tự bỏ khỏi "tránh"
    await t.pumpAndSettle();
    expect(t.widget<FilterChip>(tranh.at(0)).selected, isFalse);
    expect(t.widget<FilterChip>(tranh.at(1)).selected, isTrue);
  });

  testWidgets(
    'bước 2: tổ hợp không trùng lịch với lớp đã đăng ký, tránh T7, điểm + lý do',
    (t) async {
      await open(t, api());
      final tranh = find.widgetWithText(FilterChip, 'T7').first;
      await t.ensureVisible(tranh);
      await t.tap(tranh);
      await t.pumpAndSettle();
      await tapText(t, 'Gợi ý tổ hợp');

      expect(find.text('Xem tổ hợp gợi ý'), findsOneWidget);
      expect(find.textContaining('tổ hợp không trùng lịch'), findsOneWidget);
      expect(find.text('Tổ hợp 1'), findsOneWidget);
      expect(find.text('Điểm cao nhất'), findsOneWidget);
      expect(
        find.text('Không có buổi nào vào Thứ 7 như bạn muốn tránh.'),
        findsWidgets,
      );
      expect(find.text('Vì sao có điểm này'), findsWidgets);
      // Tổ hợp tốt nhất tránh CNTT402-02 (Thứ 7).
      expect(find.textContaining('CNTT402-01'), findsWidgets);
      expect(find.text('Tổng 6 tín chỉ'), findsWidgets);
      expect(
        find.text(
          'Gợi ý chỉ để tham khảo — chưa đăng ký. Điểm tính theo ưu tiên bạn đã chọn.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'đăng ký tổ hợp: xác nhận, POST từng môn kèm Idempotency-Key, môn lỗi không chặn môn khác',
    (t) async {
      var lan = 0;
      final a = api(
        extra: {
          'POST /registrations/': (_) => ++lan == 1
              ? reply(201, {'id': 1, 'warnings': []})
              : apiError(409, 'LOP_DAY', 'Lớp vừa hết chỗ, hãy chọn lớp khác'),
        },
      );
      await open(t, a);
      await tapText(t, 'Gợi ý tổ hợp');
      expect(find.text('Đăng ký tổ hợp đã chọn'), findsOneWidget);
      // Chưa chọn tổ hợp thì nút bị khóa.
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Đăng ký tổ hợp đã chọn'),
            )
            .onPressed,
        isNull,
      );
      await tapText(t, 'Chọn tổ hợp này', index: 0);
      expect(find.text('Đã chọn tổ hợp này'), findsOneWidget);
      await tapText(t, 'Đăng ký tổ hợp đã chọn');

      expect(find.text('Đăng ký tổ hợp này?'), findsOneWidget);
      expect(find.textContaining('đăng ký lần lượt 2 lớp'), findsOneWidget);
      await tapText(t, 'Đăng ký');
      await t.pumpAndSettle();

      expect(find.text('Kết quả đăng ký'), findsWidgets);
      expect(find.text('Đăng ký thành công'), findsOneWidget);
      expect(find.text('Lớp vừa hết chỗ, hãy chọn lớp khác'), findsOneWidget);
      expect(
        find.textContaining('Môn lỗi không làm hủy các môn đã đăng ký'),
        findsOneWidget,
      );
      expect(find.text('Xem lớp đã đăng ký'), findsOneWidget);
      expect(lan, 2);
      expect(
        a.log.where((l) => l.startsWith('POST /registrations/')).length,
        2,
      );
    },
  );

  testWidgets(
    'đổi lớp một môn trong tổ hợp: danh sách lớp thay thế và chấm lại điểm',
    (t) async {
      // Chỉ môn 1 (hai lớp: Thứ 2 và Thứ 5) → tổ hợp 1 và 2 là hai lớp đó.
      await open(t, api());
      await t.tap(find.byType(Checkbox).at(1)); // bỏ Học máy
      await t.pumpAndSettle();
      await tapText(t, 'Gợi ý tổ hợp');
      expect(find.text('Tổ hợp 2'), findsOneWidget);
      final truoc = find.textContaining('CNTT401-01 · GV').evaluate().length;
      expect(truoc, 1); // lớp Thứ 2 nằm ở đúng một tổ hợp
      final dropdown = find.byType(DropdownButton<int>).first;
      await t.ensureVisible(dropdown);
      await t.tap(dropdown);
      await t.pumpAndSettle();
      await t.tap(find.textContaining('CNTT401-03 · Vũ Đức Anh').last);
      await t.pumpAndSettle();
      // Sau khi đổi, hai tổ hợp cùng xếp lớp CNTT401-03.
      expect(
        find.textContaining('CNTT401-03 · GV Vũ Đức Anh'),
        findsNWidgets(2),
      );
      expect(find.textContaining('CNTT401-01 · GV'), findsNothing);
    },
  );

  testWidgets('không xếp được tổ hợp nào → thông báo và nút quay lại', (
    t,
  ) async {
    // Môn duy nhất chỉ có một lớp trùng đúng lớp đã đăng ký (Thứ 2, tiết 6–8).
    final a = api(
      lops: [
        lop(61, 'X-01', 6, 'Môn vướng', [lich(2, 7, 2)]),
      ],
    );
    await open(t, a);
    await tapText(t, 'Gợi ý tổ hợp');
    expect(find.text('Không xếp được tổ hợp nào'), findsOneWidget);
    expect(find.textContaining('vướng lịch'), findsWidgets);
    await tapText(t, 'Đổi môn / ưu tiên');
    expect(find.text('2. Ưu tiên cá nhân'), findsOneWidget);
  });

  testWidgets('App (màn hẹp) dựng được cả ba bước', (t) async {
    await open(t, api(), size: const Size(390, 900));
    expect(find.text('1. Chọn môn muốn học'), findsOneWidget);
    await t.ensureVisible(find.text('Gợi ý tổ hợp'));
    await tapText(t, 'Gợi ý tổ hợp');
    expect(find.text('Tổ hợp 1'), findsOneWidget);
  });
}
