import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'auth_user.dart';
import 'token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

enum AuthStatus { unknown, authenticated, unauthenticated }

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
      final res = await _dio.get('/auth/me/');
      state = AuthState(
        status: AuthStatus.authenticated,
        user: AuthUser.fromJson(Map<String, dynamic>.from(res.data as Map)),
      );
    } on DioException {
      await _tokens.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// POST /auth/login/ → {access, refresh, user}.
  Future<String?> login(String username, String password) async {
    try {
      final res = await _dio.post(
        '/auth/login/',
        data: {'username': username, 'password': password},
      );
      if (res.statusCode != 200) {
        return 'Sai tên đăng nhập hoặc mật khẩu';
      }
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
    } on DioException {
      return 'Không thể kết nối máy chủ';
    }
  }

  Future<void> logout() async {
    await _tokens.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
