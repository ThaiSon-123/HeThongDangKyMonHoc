import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_api.dart';

const bigScreen = Size(1920, 1080);

Map<String, dynamic> pageOf(List<Map<String, dynamic>> rows, {int? count}) => {
  'count': count ?? rows.length,
  'next': null,
  'previous': null,
  'results': rows,
};

/// Backend giả cho PĐT: hồ sơ đăng nhập + các route [extra].
FakeAdapter pdtApi(Map<String, Handler> extra) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('PHONG_DAO_TAO', name: 'Lê Thị Hương', username: 'pdt01'),
  ),
  ...extra,
});

Future<void> openPdt(WidgetTester t, FakeAdapter api, String path) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: bigScreen,
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go(path);
  await t.pumpAndSettle();
}

Future<void> tapText(WidgetTester t, String text, {int index = 0}) async {
  final f = find.text(text).at(index);
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

/// Gõ vào ô nhập có nhãn [label] (nhãn nằm phía trên ô trong [LabeledField]).
Future<void> enterField(WidgetTester t, String label, String text) async {
  final field = find.descendant(
    of: find
        .ancestor(of: find.text(label).last, matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );
  await t.enterText(field.first, text);
  await t.pump();
}
