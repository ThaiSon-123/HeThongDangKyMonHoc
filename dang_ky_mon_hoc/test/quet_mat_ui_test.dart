import 'package:dang_ky_mon_hoc/features/attendance/face/quet_mat_ui.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mo(WidgetTester t, Widget w, {DateTime? now}) => t.pumpWidget(
  ProviderScope(
    overrides: [if (now != null) clockProvider.overrideWithValue(() => now)],
    child: MaterialApp(home: Scaffold(body: w)),
  ),
);

void main() {
  group('Màn quét mặt — phần giao diện', () {
    testWidgets('mũi tên theo hướng quay đầu; nhìn thẳng thì không có', (
      t,
    ) async {
      for (final (tuThe, key) in [
        ('turn_left', 'mui-ten-trai'),
        ('hoi_trai', 'mui-ten-trai'),
        ('turn_right', 'mui-ten-phai'),
        ('hoi_phai', 'mui-ten-phai'),
      ]) {
        await _mo(t, HuongQuay(key: ValueKey(tuThe), tuThe: tuThe));
        await t.pump(const Duration(milliseconds: 300));
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: tuThe);
      }
      await _mo(t, const HuongQuay(tuThe: 'thang'));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('tiến độ "Bước i/n"', (t) async {
      await _mo(t, const TienDoBuoc(buoc: 1, tong: 2));
      expect(find.text('Bước 1/2'), findsOneWidget);
      final thanh = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(thanh.value, 0.5);
    });

    testWidgets('đếm ngược hạn thử thách, đỏ khi còn ≤ 10 giây', (t) async {
      final hetHan = DateTime(2027, 1, 13, 8, 1);
      await _mo(
        t,
        DemNguoc(hetHan: hetHan),
        now: DateTime(2027, 1, 13, 8, 0, 15),
      );
      expect(find.text('Còn 00:45'), findsOneWidget);
      Color nen() =>
          ((t.widget<Container>(find.byType(Container).first).decoration!
                  as BoxDecoration)
              .color)!;
      expect(nen(), Colors.black54);

      await _mo(
        t,
        DemNguoc(key: const ValueKey(2), hetHan: hetHan),
        now: DateTime(2027, 1, 13, 8, 0, 52),
      );
      expect(find.text('Còn 00:08'), findsOneWidget);
      expect(nen(), isNot(Colors.black54));
      await t.pumpWidget(const SizedBox()); // hủy Timer
    });

    testWidgets('kết quả trên màn camera: tiêu đề, chi tiết, nút Xong', (
      t,
    ) async {
      var xong = 0;
      for (final (loai, icon) in [
        (LoaiKetQua.dat, Icons.check_circle_rounded),
        (LoaiKetQua.choDuyet, Icons.hourglass_top_rounded),
        (LoaiKetQua.khongDat, Icons.cancel_rounded),
      ]) {
        await _mo(
          t,
          KetQuaQuetView(
            key: ValueKey(loai),
            ketQua: (loai: loai, tieuDe: 'Tiêu đề', chiTiet: 'Lý do'),
            onXong: () => xong++,
          ),
        );
        expect(find.byIcon(icon), findsOneWidget);
        expect(find.text('Tiêu đề'), findsOneWidget);
        expect(find.text('Lý do'), findsOneWidget);
        await t.tap(find.text('Xong'));
      }
      expect(xong, 3);
    });
  });
}
