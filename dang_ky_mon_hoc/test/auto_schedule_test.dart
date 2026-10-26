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
  'ngay_bat_dau': '2026-09-07',
  'ngay_ket_thuc': '2027-01-17',
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
      'ngay_bat_dau': '2026-08-31',
      'ngay_ket_thuc': '2027-01-10',
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

  group('thời gian học của lớp', () {
    testWidgets('bước 1: bảng lớp của môn có cột Thời gian học', (t) async {
      await open(t, api());
      await tapText(t, 'Trí tuệ nhân tạo'); // mở rộng môn
      expect(find.text('THỜI GIAN HỌC'), findsOneWidget);
      expect(find.text('07/09/2026 – 17/01/2027'), findsWidgets);
    });

    testWidgets('bước 2: mỗi lớp trong thẻ tổ hợp ghi thời gian học', (
      t,
    ) async {
      await open(t, api());
      await tapText(t, 'Gợi ý tổ hợp');
      expect(find.text('Thời gian học: 07/09/2026 – 17/01/2027'), findsWidgets);
    });

    testWidgets('lớp chưa có ngày riêng thì lấy theo học kỳ', (t) async {
      final khongNgay = {
        ...lop(11, 'A-01', 1, 'Trí tuệ nhân tạo', [lich(2, 1, 3)]),
        'ngay_bat_dau': null,
        'ngay_ket_thuc': null,
      };
      await open(t, api(lops: [khongNgay]));
      await tapText(t, 'Gợi ý tổ hợp');
      expect(find.text('Thời gian học: 31/08/2026 – 10/01/2027'), findsWidgets);
    });
  });

  group('bước 1: tìm học phần và lọc học kỳ trong CTĐT', () {
    final lopKy = [
      lop(11, 'A-01', 1, 'Trí tuệ nhân tạo', [lich(2, 1, 3)], ky: 7),
      lop(21, 'B-01', 2, 'Học máy', [lich(3, 1, 3)]),
      lop(31, 'C-01', 3, 'An toàn thông tin', [lich(4, 1, 3)], loai: 'tu_chon'),
    ];

    Future<void> chonKy(WidgetTester t, String ky) async {
      final o = find.byType(DropdownButton<int>);
      await t.ensureVisible(o);
      await t.tap(o);
      await t.pumpAndSettle();
      await t.tap(find.text(ky).last);
      await t.pumpAndSettle();
    }

    testWidgets('tìm theo tên không dấu; môn đã chọn vẫn được giữ khi bị ẩn', (
      t,
    ) async {
      await open(t, api(lops: lopKy));
      expect(find.text('Đã chọn 2 môn · 6 tín chỉ'), findsOneWidget);

      await enterField(t, 'Tìm học phần', 'hoc may');
      expect(find.text('Học máy'), findsOneWidget);
      expect(find.text('Trí tuệ nhân tạo'), findsNothing);
      expect(find.text('An toàn thông tin'), findsNothing);
      expect(
        find.text('Đã chọn 2 môn · 6 tín chỉ'),
        findsOneWidget,
      ); // không đổi

      await enterField(t, 'Tìm học phần', 'zzz');
      expect(find.text('Không có môn phù hợp với bộ lọc.'), findsOneWidget);

      await enterField(t, 'Tìm học phần', '');
      expect(find.text('Trí tuệ nhân tạo'), findsOneWidget);
    });

    testWidgets('lọc theo học kỳ trong CTĐT chỉ hiện môn của kỳ đó', (t) async {
      await open(t, api(lops: lopKy));
      await chonKy(t, 'Học kỳ 7');
      expect(find.text('Trí tuệ nhân tạo'), findsOneWidget);
      expect(find.text('Học máy'), findsNothing);
      expect(find.text('Đã chọn 2 môn · 6 tín chỉ'), findsOneWidget);

      await chonKy(t, 'Tất cả học kỳ');
      expect(find.text('Học máy'), findsOneWidget);
    });

    testWidgets('chọn bằng bộ lọc rồi gợi ý vẫn xếp đúng các môn đã chọn', (
      t,
    ) async {
      await open(t, api(lops: lopKy));
      await enterField(t, 'Tìm học phần', 'an toan'); // ẩn hai môn đã chọn sẵn
      await tapText(t, 'Gợi ý tổ hợp');
      expect(find.text('Xem tổ hợp gợi ý'), findsOneWidget);
      expect(find.textContaining('tổ hợp không trùng lịch'), findsOneWidget);
    });
  });

  group('bước 2: xem thời khóa biểu của tổ hợp (hộp thoại nổi)', () {
    // Chỉ môn 1 (hai lớp: Thứ 2 tiết 1–3 và Thứ 5 tiết 6–8) → hai tổ hợp, mỗi tổ hợp một lớp.
    Future<void> toiBuoc2(WidgetTester t, {Size size = bigScreen}) async {
      await open(t, api(), size: size);
      await t.tap(find.byType(Checkbox).at(1)); // bỏ Học máy
      await t.pumpAndSettle();
      await tapText(t, 'Gợi ý tổ hợp');
    }

    /// Khóa các ô đang vẽ trong lưới (`tkb-o-<thứ>-<tiết bắt đầu>`), đã sắp xếp.
    List<String> oHienCo() =>
        find
            .byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key! as ValueKey<String>).value.startsWith('tkb-o-'),
            )
            .evaluate()
            .map((e) => (e.widget.key! as ValueKey<String>).value)
            .toList()
          ..sort();

    Finder o(String khoa) => find.byKey(ValueKey('tkb-o-$khoa'));
    final luoi = find.byKey(const ValueKey('tkb-luoi'));

    Future<void> xemTkb(WidgetTester t, int viTri) async {
      final nut = find.text('Xem TKB').at(viTri);
      await t.ensureVisible(nut);
      await t.tap(nut);
      await t.pumpAndSettle();
    }

    testWidgets('chưa bấm Xem TKB thì không có lưới ở cuối trang', (t) async {
      await toiBuoc2(t);
      expect(find.text('Xem TKB'), findsNWidgets(2)); // mỗi tổ hợp một nút
      expect(luoi, findsNothing);
      expect(find.textContaining('Thời khóa biểu — Tổ hợp'), findsNothing);
    });

    testWidgets(
      'bấm Xem TKB mở hộp thoại đè lên màn hình: ô đúng cột/tiết, lớp đã đăng ký là ô xám',
      (t) async {
        await toiBuoc2(t);
        await xemTkb(t, 0);
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Thời khóa biểu — Tổ hợp 1'), findsOneWidget);
        expect(luoi, findsOneWidget);
        // Màn gợi ý vẫn nằm phía dưới hộp thoại (không bị thay thế).
        expect(find.text('Tổ hợp 2'), findsOneWidget);

        final khoa = oHienCo();
        // Lịch đã đăng ký (Thứ 2, tiết 6–8) luôn có; cộng đúng một lớp của tổ hợp.
        expect(khoa.length, 2);
        expect(khoa, contains('tkb-o-2-6'));
        expect(
          find.descendant(of: o('2-6'), matching: find.text('Đã đăng ký')),
          findsOneWidget,
        );
        final lop = khoa.firstWhere((k) => k != 'tkb-o-2-6').substring(6);
        expect(['2-1', '5-6'], contains(lop));
        // Cột theo thứ, hàng theo tiết.
        if (lop == '2-1') {
          expect(t.getTopLeft(o('2-1')).dx, t.getTopLeft(o('2-6')).dx);
          expect(
            t.getTopLeft(o('2-1')).dy,
            lessThan(t.getTopLeft(o('2-6')).dy),
          );
        } else {
          expect(
            t.getTopLeft(o('5-6')).dx,
            greaterThan(t.getTopLeft(o('2-6')).dx),
          );
          expect(t.getTopLeft(o('5-6')).dy, t.getTopLeft(o('2-6')).dy);
        }
      },
    );

    testWidgets(
      'Đóng thì hộp thoại biến mất; mỗi tổ hợp hiện đúng lớp của nó',
      (t) async {
        await toiBuoc2(t);
        await xemTkb(t, 0);
        final thu1 = oHienCo();
        await tapText(t, 'Đóng');
        expect(find.byType(Dialog), findsNothing);
        expect(luoi, findsNothing);

        await xemTkb(t, 1);
        expect(find.text('Thời khóa biểu — Tổ hợp 2'), findsOneWidget);
        expect(oHienCo(), isNot(thu1)); // hai tổ hợp xếp hai lớp khác nhau
        expect(oHienCo().length, 2);
      },
    );

    testWidgets('Chọn tổ hợp này không mở lưới', (t) async {
      await toiBuoc2(t);
      await tapText(t, 'Chọn tổ hợp này', index: 0);
      expect(find.text('Đã chọn tổ hợp này'), findsOneWidget);
      expect(luoi, findsNothing);
    });

    testWidgets('đổi lớp thay thế rồi xem: lưới theo lớp mới', (t) async {
      await toiBuoc2(t);
      await xemTkb(t, 0);
      final dangT2 = oHienCo().contains('tkb-o-2-1');
      await tapText(t, 'Đóng');
      final dropdown = find.byType(DropdownButton<int>).first;
      await t.ensureVisible(dropdown);
      await t.tap(dropdown);
      await t.pumpAndSettle();
      // Chọn đúng lớp mà tổ hợp 1 đang không xếp.
      await t.tap(
        find
            .textContaining(
              dangT2 ? 'CNTT401-03 · Vũ Đức Anh' : 'CNTT401-01 · Nguyễn',
            )
            .last,
      );
      await t.pumpAndSettle();
      await xemTkb(t, 0);
      expect(oHienCo().contains('tkb-o-2-1'), !dangT2);
      expect(oHienCo().contains('tkb-o-5-6'), dangT2);
    });

    testWidgets('màn hẹp: hộp thoại dựng được, không tràn', (t) async {
      await toiBuoc2(t, size: const Size(390, 900));
      await xemTkb(t, 0);
      expect(find.byType(Dialog), findsOneWidget);
      expect(luoi, findsOneWidget);
    });
  });

  group('bước 2: nhiều tổ hợp được phân trang', () {
    // 3 môn × 4 lớp, cùng tiết 1 nhưng mỗi lớp một ngày (Thứ 2..5) → phải khác ngày: 4×3×2 = 24 tổ hợp.
    final lopNhieu = [
      for (var m = 1; m <= 3; m++)
        for (var k = 0; k < 4; k++)
          lop(m * 10 + k, 'M$m-0$k', m, 'Môn $m', [lich(2 + k, 1, 3)]),
    ];

    Future<void> bam(WidgetTester t, String tooltip) async {
      final nut = find.byTooltip(tooltip);
      await t.ensureVisible(nut);
      await t.tap(nut);
      await t.pumpAndSettle();
    }

    Future<void> toiBuoc2(WidgetTester t) async {
      await open(t, api(lops: lopNhieu));
      await tapText(t, 'Gợi ý tổ hợp');
    }

    testWidgets('chỉ dựng 6 thẻ mỗi trang; chuyển trang đúng thứ tự', (
      t,
    ) async {
      await toiBuoc2(t);
      expect(find.text('Có 24 tổ hợp không trùng lịch'), findsOneWidget);
      expect(find.text('Tổ hợp 6'), findsOneWidget);
      expect(find.text('Tổ hợp 7'), findsNothing);
      expect(
        find.text('Chọn tổ hợp này'),
        findsNWidgets(6),
      ); // không dựng cả 24 thẻ
      expect(find.textContaining('Trang 1/4'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_left),
            )
            .onPressed,
        isNull,
      );

      await bam(t, 'Trang sau');
      expect(find.textContaining('Trang 2/4'), findsOneWidget);
      expect(find.text('Tổ hợp 1'), findsNothing);
      expect(find.text('Tổ hợp 7'), findsOneWidget);
      expect(find.text('Tổ hợp 12'), findsOneWidget);
      expect(find.text('Chọn tổ hợp này'), findsNWidgets(6));

      for (var i = 0; i < 2; i++) {
        await bam(t, 'Trang sau');
      }
      expect(find.textContaining('Trang 4/4'), findsOneWidget);
      expect(find.text('Tổ hợp 24'), findsOneWidget);
      expect(
        t
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('tổ hợp đã chọn được giữ khi đổi trang', (t) async {
      await toiBuoc2(t);
      await tapText(t, 'Chọn tổ hợp này', index: 2); // Tổ hợp 3
      await bam(t, 'Trang sau');
      expect(find.text('Đã chọn tổ hợp này'), findsNothing);
      await bam(t, 'Trang trước');
      expect(find.text('Đã chọn tổ hợp này'), findsOneWidget);
      expect(find.text('Đăng ký tổ hợp đã chọn'), findsOneWidget);
    });

    testWidgets('xem TKB ở trang sau mở đúng tổ hợp', (t) async {
      await toiBuoc2(t);
      await bam(t, 'Trang sau');
      await tapText(t, 'Xem TKB', index: 0);
      expect(find.text('Thời khóa biểu — Tổ hợp 7'), findsOneWidget);
    });

    testWidgets('ít tổ hợp thì không có thanh phân trang', (t) async {
      await open(t, api());
      await tapText(t, 'Gợi ý tổ hợp');
      expect(find.byTooltip('Trang sau'), findsNothing);
    });
  });

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
