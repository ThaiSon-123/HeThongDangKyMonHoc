import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

// "Hôm nay" cố định: thứ Tư 13/01/2027 → tuần 11/01 – 17/01/2027.
final _homNay = DateTime(2027, 1, 13);

Map<String, dynamic> lich(int thu, int bd, int so, String phong) => {
  'id': thu,
  'thu': thu,
  'tiet_bat_dau': bd,
  'so_tiet_moi_buoi': so,
  'tiet_ket_thuc': bd + so - 1,
  'buoi': 'SANG',
  'phong': phong,
};

Map<String, dynamic> tkb(List<Map<String, dynamic>> lop) => {
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2, 2026–2027',
  'ngay_bat_dau': '2027-01-04',
  'ngay_ket_thuc': '2027-05-30',
  'lop_hoc_phan': lop,
};

Map<String, dynamic> lop(
  int id,
  String ma,
  String ten,
  List<Map<String, dynamic>> l, {
  String? bd,
  String? kt,
}) => {
  'id': id,
  'ma_lop': ma,
  'ten_mon': ten,
  'giao_vien_ten': 'Trần Minh Quân',
  'ngay_bat_dau': bd,
  'ngay_ket_thuc': kt,
  'lich_hoc': l,
};

Future<void> open(
  WidgetTester t,
  Map<String, dynamic> data, {
  Size size = bigScreen,
  List<Override> extra = const [],
}) => openStudent(
  t,
  svApi({'GET /timetable/my/': (_) => reply(200, data)}),
  '/student/schedule',
  size: size,
  overrides: [clockProvider.overrideWithValue(() => _homNay), ...extra],
);

void main() {
  testWidgets(
    'lưới tuần có ngày thật; khối lớp hiện tên, mã lớp · phòng, giáo viên',
    (t) async {
      await open(
        t,
        tkb([
          lop(1, 'CNTT101-01', 'Nhập môn lập trình', [
            lich(2, 1, 3, 'A101'),
            lich(5, 6, 3, 'B202'),
          ]),
        ]),
      );

      expect(find.text('Học kỳ 2, 2026–2027'), findsOneWidget);
      expect(find.text('Tuần này · 11/01 – 17/01'), findsOneWidget);
      for (final s in ['T2', 'CN', '11/01', '17/01', 'Tiết 1', 'Tiết 15']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      expect(
        find.text('Nhập môn lập trình'),
        findsNWidgets(2),
      ); // chú giải + khối trên lưới (2 buổi)
      expect(find.text('CNTT101-01 · A101'), findsOneWidget);
      expect(find.text('CNTT101-01 · B202'), findsOneWidget);
      expect(find.text('GV Trần Minh Quân'), findsNWidgets(2));
    },
  );

  testWidgets(
    'chuyển tuần: lớp chưa bắt đầu → tuần không có tiết; Tuần này quay về',
    (t) async {
      // Lớp học từ 18/01 → tuần này (11–17/01) trống, tuần sau (18–24/01) có tiết.
      await open(
        t,
        tkb([
          lop(
            1,
            'X-01',
            'Môn X',
            [lich(3, 1, 2, 'P1')],
            bd: '2027-01-18',
            kt: '2027-03-01',
          ),
        ]),
      );
      expect(find.text('Tuần này không có tiết học'), findsOneWidget);

      await t.tap(find.byTooltip('Tuần sau'));
      await t.pumpAndSettle();
      expect(find.text('Tuần này không có tiết học'), findsNothing);
      expect(find.text('X-01 · P1'), findsOneWidget);
      expect(find.text('18/01'), findsOneWidget);

      await tapText(t, 'Tuần này · 18/01 – 24/01');
      expect(find.text('Tuần này không có tiết học'), findsOneWidget);
    },
  );

  testWidgets(
    'lớp đã kết thúc trước tuần đang xem thì không hiện; Chủ nhật (thu = 8) là cột CN',
    (t) async {
      await open(
        t,
        tkb([
          lop(
            1,
            'CU-01',
            'Môn cũ',
            [lich(2, 1, 3, 'P1')],
            bd: '2027-01-04',
            kt: '2027-01-08',
          ),
          lop(2, 'CN-01', 'Học Chủ nhật', [lich(8, 1, 3, 'P2')]),
        ]),
      );
      expect(find.text('CU-01 · P1'), findsNothing);
      expect(find.text('CN-01 · P2'), findsOneWidget);
    },
  );

  testWidgets(
    'Cả học kỳ liệt kê mọi lớp kèm lịch; trống thì hướng dẫn đăng ký',
    (t) async {
      await open(
        t,
        tkb([
          lop(1, 'CNTT101-01', 'Nhập môn lập trình', [lich(2, 1, 3, 'A101')]),
        ]),
      );
      await tapText(t, 'Cả học kỳ');
      expect(find.textContaining('Thứ 2 · tiết 1–3 · A101'), findsOneWidget);
      expect(find.text('Tuần này · 11/01 – 17/01'), findsNothing);
    },
  );

  testWidgets('chưa đăng ký lớp nào → thông báo trống', (t) async {
    await open(t, tkb([]));
    expect(find.text('Chưa có lớp nào trong thời khóa biểu'), findsOneWidget);
  });

  testWidgets('bố cục App 390 px: lưới cuộn ngang, không tràn', (t) async {
    await open(
      t,
      tkb([
        lop(1, 'CNTT101-01', 'Nhập môn lập trình', [lich(2, 1, 3, 'A101')]),
      ]),
      size: const Size(390, 844),
    );
    expect(find.text('CNTT101-01 · A101'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'nút In (Web): sinh tài liệu A4 ngang có thông tin SV, ngày thật, ô gộp theo số tiết',
    (t) async {
      final printed = <String>[];
      await open(
        t,
        tkb([
          lop(1, 'CNTT101-01', 'Nhập môn <lập trình>', [lich(2, 1, 3, 'A101')]),
        ]),
        extra: [
          printHtmlProvider.overrideWithValue(
            (html) async => printed.add(html),
          ),
        ],
      );
      await tapText(t, 'In thời khóa biểu');

      expect(printed, hasLength(1));
      final html = printed.single;
      expect(html, contains('size:A4 landscape'));
      expect(html, contains('Trần Hoàng Nam')); // từ hồ sơ đăng nhập
      expect(html, contains('Tuần 11/01 – 17/01'));
      expect(html, contains('rowspan="3"')); // 3 tiết gộp thành một ô
      expect(html, contains('Nhập môn &lt;lập trình&gt;')); // escape HTML
      expect(html, contains('CNTT101-01 · A101'));
    },
  );

  testWidgets('bản App (không in được): không có nút In', (t) async {
    await open(
      t,
      tkb([
        lop(1, 'CNTT101-01', 'Môn A', [lich(2, 1, 3, 'A101')]),
      ]),
    );
    expect(find.text('In thời khóa biểu'), findsNothing);
  });
}
