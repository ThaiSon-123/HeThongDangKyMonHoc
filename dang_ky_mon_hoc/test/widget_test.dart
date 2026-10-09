import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dang_ky_mon_hoc/app.dart';

void main() {
  testWidgets('App khởi động và hiển thị màn đăng nhập', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DkmhApp()));
    await tester.pump();

    expect(find.text('Đăng nhập'), findsWidgets);
  });
}
