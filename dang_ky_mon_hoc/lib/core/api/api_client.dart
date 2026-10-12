import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// Dio client dùng chung (plan.md mục 10.1): tự gắn Bearer token, khi gặp 401 thì refresh
/// (backend xoay vòng refresh token) rồi retry 1 lần.
///
/// Android emulator không thấy `localhost` của máy host → chạy với
/// `--dart-define=API_BASE_URL=http://10.0.2.2:8010/api`.
class ApiClient {
  ApiClient({
    String? baseUrl,
    TokenStorage? tokens,
    HttpClientAdapter? adapter,
    this.onSessionExpired,
  }) : _tokens = tokens ?? TokenStorage() {
    final options = BaseOptions(
      baseUrl:
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:8010/api',
          ),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    );
    _dio = Dio(options);
    // Dio thứ hai KHÔNG có interceptor: dùng để refresh + retry, tránh bị QueuedInterceptor
    // của chính nó chặn (deadlock).
    _plain = Dio(options.copyWith());
    if (adapter != null) {
      _dio.httpClientAdapter = adapter;
      _plain.httpClientAdapter = adapter;
    }
    _dio.interceptors.add(_AuthInterceptor(_plain, _tokens, onSessionExpired));
  }

  /// Gọi khi refresh token bị từ chối (hết hạn / bị thu hồi / tài khoản khóa).
  final void Function()? onSessionExpired;

  final TokenStorage _tokens;
  late final Dio _dio;
  late final Dio _plain;

  Dio get dio => _dio;
}

/// Các endpoint không gắn token và không được kích hoạt refresh khi trả 401
/// (401 ở login nghĩa là sai mật khẩu).
const _publicPaths = [
  '/auth/login/',
  '/auth/refresh/',
  '/auth/forgot-password/',
  '/auth/reset-password/',
];

bool _isPublic(String path) => _publicPaths.any(path.endsWith);

/// Refresh có xếp hàng (QueuedInterceptor): các request 401 đồng thời được xử lý lần lượt.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._plain, this._tokens, this._onSessionExpired);

  final Dio _plain;
  final TokenStorage _tokens;
  final void Function()? _onSessionExpired;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final access = await _tokens.readAccessToken();
      if (access != null) options.headers['Authorization'] = 'Bearer $access';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 || _isPublic(err.requestOptions.path)) {
      return handler.next(err);
    }
    final refresh = await _tokens.readRefreshToken();
    if (refresh == null) return handler.next(err);

    // Request đồng thời trước đó đã refresh xong → chỉ cần retry với access mới.
    final current = await _tokens.readAccessToken();
    final used = err.requestOptions.headers['Authorization'];
    if (current != null && used != 'Bearer $current') {
      return _retry(err, current, handler);
    }

    try {
      final res = await _plain.post(
        '/auth/refresh/',
        data: {'refresh': refresh},
      );
      final access = res.data['access'] as String;
      // Backend xoay vòng: refresh cũ bị blacklist → bắt buộc lưu refresh mới.
      await _tokens.save(
        accessToken: access,
        refreshToken: res.data['refresh'] as String?,
      );
      await _retry(err, access, handler);
      return;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (e.requestOptions.path.endsWith('/auth/refresh/') &&
          (code == 400 || code == 401 || code == 403)) {
        await _tokens.clear();
        _onSessionExpired?.call();
        return handler.next(err);
      }
      return handler.next(e);
    }
  }

  Future<void> _retry(
    DioException err,
    String access,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;
    opts.headers['Authorization'] = 'Bearer $access';
    try {
      handler.resolve(await _plain.fetch(opts));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
