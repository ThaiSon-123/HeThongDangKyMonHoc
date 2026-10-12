import 'package:dang_ky_mon_hoc/core/api/api_client.dart';
import 'package:dang_ky_mon_hoc/core/auth/auth_user.dart';
import 'package:dang_ky_mon_hoc/core/auth/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';

void main() {
  late TokenStorage tokens;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    tokens = TokenStorage();
  });

  test(
    'gắn Bearer token vào request thường, không gắn vào /auth/login/',
    () async {
      await tokens.save(accessToken: 'a1', refreshToken: 'r1');
      final adapter = FakeAdapter.catchAll((_) => reply(200, {}));
      final api = ApiClient(
        baseUrl: 'http://x/api',
        tokens: tokens,
        adapter: adapter,
      );

      await api.dio.get('/profiles/me/');
      await api.dio.post('/auth/login/', data: {});

      expect(adapter.log, [
        'GET /profiles/me/ Bearer a1',
        'POST /auth/login/ null',
      ]);
    },
  );

  test('401 → refresh, LƯU refresh token mới (backend xoay vòng) → retry thành công', () async {
    await tokens.save(accessToken: 'cu', refreshToken: 'r1');
    final adapter = FakeAdapter.catchAll((o) {
      if (o.path == '/auth/refresh/') {
        return reply(200, {'access': 'moi', 'refresh': 'r2'});
      }
      return o.headers['Authorization'] == 'Bearer moi'
          ? reply(200, {'ok': true})
          : reply(401, {'detail': 'het han'});
    });
    final api = ApiClient(
      baseUrl: 'http://x/api',
      tokens: tokens,
      adapter: adapter,
    );

    final res = await api.dio.get('/profiles/me/');

    expect(res.statusCode, 200);
    expect(await tokens.readRefreshToken(), 'r2');
    expect(await tokens.readAccessToken(), 'moi');
    expect(adapter.log, [
      'GET /profiles/me/ Bearer cu',
      'POST /auth/refresh/ null',
      'GET /profiles/me/ Bearer moi',
    ]);
  });

  test('refresh bị từ chối → xóa token và báo phiên hết hạn', () async {
    await tokens.save(accessToken: 'cu', refreshToken: 'r1');
    var expired = 0;
    final adapter = FakeAdapter.catchAll((o) => reply(401, {'detail': 'x'}));
    final api = ApiClient(
      baseUrl: 'http://x/api',
      tokens: tokens,
      adapter: adapter,
      onSessionExpired: () => expired++,
    );

    await expectLater(
      api.dio.get('/profiles/me/'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );

    expect(expired, 1);
    expect(await tokens.readRefreshToken(), isNull);
  });

  test('401 ở /auth/login/ (sai mật khẩu) KHÔNG kích hoạt refresh', () async {
    await tokens.save(accessToken: 'a1', refreshToken: 'r1');
    final adapter = FakeAdapter.catchAll((o) => reply(401, {'detail': 'sai'}));
    final api = ApiClient(
      baseUrl: 'http://x/api',
      tokens: tokens,
      adapter: adapter,
    );

    await expectLater(
      api.dio.post('/auth/login/', data: {}),
      throwsA(isA<DioException>()),
    );

    expect(adapter.log, ['POST /auth/login/ null']);
    expect(await tokens.readRefreshToken(), 'r1');
  });

  test('mất mạng khi refresh KHÔNG xóa token (chỉ lỗi tạm thời)', () async {
    await tokens.save(accessToken: 'cu', refreshToken: 'r1');
    final adapter = FakeAdapter.catchAll((o) {
      if (o.path == '/auth/refresh/') {
        throw DioException(
          requestOptions: o,
          type: DioExceptionType.connectionError,
        );
      }
      return reply(401, {});
    });
    var expired = 0;
    final api = ApiClient(
      baseUrl: 'http://x/api',
      tokens: tokens,
      adapter: adapter,
      onSessionExpired: () => expired++,
    );

    await expectLater(
      api.dio.get('/profiles/me/'),
      throwsA(isA<DioException>()),
    );

    expect(expired, 0);
    expect(await tokens.readRefreshToken(), 'r1');
  });

  group('AuthUser.fromJson', () {
    test('map role của backend sang UserRole', () {
      const cases = {
        'ADMIN': UserRole.admin,
        'PHONG_DAO_TAO': UserRole.pdt,
        'KE_TOAN': UserRole.accountant,
        'SINH_VIEN': UserRole.student,
        'GIAO_VIEN': UserRole.teacher,
      };
      cases.forEach((api, role) {
        final u = AuthUser.fromJson({'id': 1, 'username': 'u', 'role': api});
        expect(u.role, role);
        expect(u.role.homePath, '/${role.name}');
      });
    });

    test('đọc đủ payload login', () {
      final u = AuthUser.fromJson({
        'id': 9,
        'username': 'sv01',
        'full_name': 'Nguyễn Văn An',
        'role': 'SINH_VIEN',
        'email': 'sv01@university.edu.vn',
      });
      expect(
        (u.id, u.fullName, u.email),
        ('9', 'Nguyễn Văn An', 'sv01@university.edu.vn'),
      );
    });

    test('role lạ → lỗi rõ ràng', () {
      expect(
        () => AuthUser.fromJson({'id': 1, 'username': 'u', 'role': 'ROOT'}),
        throwsFormatException,
      );
    });
  });
}
