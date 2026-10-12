import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_failure.dart';
import 'auth_user.dart';
import 'token_storage.dart';

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    onSessionExpired: () =>
        ref.read(authControllerProvider.notifier).sessionExpired(),
  ),
);

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Lý do đăng nhập thất bại — màn hình tự chọn banner/câu chữ (không lộ mã kỹ thuật).
enum LoginError { invalid, locked, rateLimited, network, other }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Điều khiển phiên đăng nhập: restore khi mở app, login, logout.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState();
  }

  Dio get _dio => ref.read(apiClientProvider).dio;
  TokenStorage get _tokens => ref.read(tokenStorageProvider);

  /// Khôi phục phiên từ token đã lưu (mở lại app).
  Future<void> _restore() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final res = await _dio.get('/profiles/me/');
      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser.fromJson(Map<String, dynamic>.from(res.data as Map)),
      );
    } on DioException {
      await _tokens.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// POST /auth/login/ → {access, refresh, user}. Trả `null` nếu thành công, ngược lại là lý do
  /// thất bại (sai tên đăng nhập và sai mật khẩu cùng là [LoginError.invalid] — plan.md mục 8.4).
  Future<LoginError?> login(String username, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login/',
        data: {'username': username, 'password': password},
      );
      final data = res.data as Map;
      await _tokens.save(
        accessToken: data['access'] as String?,
        refreshToken: data['refresh'] as String?,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser.fromJson(Map<String, dynamic>.from(data['user'] as Map)),
      );
      return null;
    } on DioException catch (e) {
      final f = ApiFailure.from(e);
      if (f.isNetwork) return LoginError.network;
      if (f.isLocked) return LoginError.locked;
      if (f.isRateLimited) return LoginError.rateLimited;
      return f.status == 401 ? LoginError.invalid : LoginError.other;
    } on FormatException {
      return LoginError.other; // role lạ từ server
    }
  }

  /// Đăng xuất: thu hồi refresh token ở server (best effort) rồi xóa token cục bộ.
  Future<void> logout() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh != null) {
      try {
        await _dio.post('/auth/logout/', data: {'refresh': refresh});
      } on DioException {
        // Offline / token đã hết hạn: vẫn đăng xuất cục bộ.
      }
    }
    await _tokens.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Refresh bị từ chối (hết hạn / thu hồi / tài khoản bị khóa) → về màn đăng nhập.
  void sessionExpired() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
