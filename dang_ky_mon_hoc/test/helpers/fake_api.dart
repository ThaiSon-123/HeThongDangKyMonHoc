import 'dart:convert';
import 'dart:typed_data';

import 'package:dang_ky_mon_hoc/app.dart';
import 'package:dang_ky_mon_hoc/core/api/api_client.dart';
import 'package:dang_ky_mon_hoc/core/auth/auth_provider.dart';
import 'package:dang_ky_mon_hoc/core/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

typedef Handler = ResponseBody Function(RequestOptions options);

/// Backend giả: khớp theo `"METHOD /path/"`, ghi lại mọi request để test kiểm tra.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter([Map<String, Handler>? routes])
    : routes = routes ?? {},
      _fallback = null;

  /// Một handler cho mọi request (test hạ tầng không quan tâm route).
  FakeAdapter.catchAll(Handler handler) : routes = {}, _fallback = handler;

  final Map<String, Handler> routes;
  final Handler? _fallback;
  final log = <String>[];
  final bodies = <String, dynamic>{};

  /// Query string của lần gọi gần nhất theo `"METHOD /path/"`.
  final queries = <String, Map<String, dynamic>>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    log.add('$key ${options.headers['Authorization']}');
    bodies[key] = options.data;
    queries[key] = Map.of(options.queryParameters);
    final handler = routes[key] ?? _fallback;
    return handler == null
        ? reply(404, {'detail': 'Không có route giả cho $key'})
        : handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody reply(int code, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  code,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

/// Envelope lỗi nghiệp vụ của backend (plan.md 8.4).
ResponseBody apiError(int status, String code, [String message = 'Lỗi']) =>
    reply(status, {
      'error': {'code': code, 'message': message},
    });

Map<String, dynamic> userJson(
  String role, {
  String name = 'Trần Hoàng Nam',
  String username = 'sv2023014',
}) => {
  'id': 9,
  'username': username,
  'full_name': name,
  'role': role,
  'email': '$username@truong.edu.vn',
};

Map<String, dynamic> studentProfile() => {
  ...userJson('SINH_VIEN'),
  'ma_sv': 'SV2023014',
  'ho_ten': 'Trần Hoàng Nam',
  'nganh': {'id': 1, 'ma_nganh': 'CNTT', 'ten_nganh': 'Công nghệ thông tin'},
  'khoa_nhap_hoc': 'K2023',
  'ctdt': {'id': 1, 'ma_ctdt': 'CNTT-K23', 'tong_tin_chi_yeu_cau': 130},
  'gpa': '3.12',
  'tin_chi_tich_luy': 96,
  'xep_loai': 'Giỏi',
  'sdt': '0987654321',
};

Map<String, dynamic> teacherProfile() => {
  ...userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
  'ma_gv': 'GV001',
  'ho_ten': 'Trần Minh Quân',
  'khoa_bo_mon': 'Công nghệ thông tin',
  'hoc_vi': 'Thạc sĩ',
  'sdt': '0911222333',
};

/// Dựng toàn bộ app với backend giả. [tokens] khác rỗng = đã đăng nhập từ trước (khôi phục phiên).
Future<void> pumpApp(
  WidgetTester tester, {
  required Provider<GoRouter> router,
  required FakeAdapter adapter,
  Map<String, String> tokens = const {},
  Size size = const Size(1440, 900),
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  FlutterSecureStorage.setMockInitialValues(Map.of(tokens));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWith(
          (ref) => ApiClient(
            baseUrl: 'http://x/api',
            tokens: TokenStorage(),
            adapter: adapter,
            onSessionExpired: () =>
                ref.read(authControllerProvider.notifier).sessionExpired(),
          ),
        ),
      ],
      child: DkmhApp(routerProvider: router),
    ),
  );
  await tester.pumpAndSettle();
}

const signedIn = {'access_token': 'a1', 'refresh_token': 'r1'};
