import 'package:dio/dio.dart';

import '../auth/token_storage.dart';

/// Dio client dùng chung. Tự refresh token khi gặp 401 rồi retry 1 lần.
class ApiClient {
  ApiClient({String? baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl:
              baseUrl ??
              const String.fromEnvironment(
                'API_BASE_URL',
                defaultValue: 'http://10.0.2.2:8000/api/v1',
              ),
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          // Thông báo lỗi HTTP (4xx/5xx) để interceptor xử lý.
          validateStatus: (code) => code != null && code < 500,
        ),
      ) {
    _dio.interceptors.add(_AuthInterceptor(_dio, _tokens));
  }

  final Dio _dio;
  final TokenStorage _tokens = TokenStorage();

  Dio get dio => _dio;
}

/// Refresh token có xếp hàng (QueuedInterceptor): các request 401 đồng thời
/// chỉ kích hoạt đúng một lần gọi /auth/token/refresh/ (mục 13.2 plan.md).
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    if (response?.statusCode != 401) return handler.next(err);

    final refresh = await _tokens.readRefreshToken();
    if (refresh == null) return handler.next(err);

    try {
      final res = await _dio.post(
        '/auth/token/refresh/',
        data: {'refresh': refresh},
      );
      if (res.statusCode != 200) throw err;
      final access = res.data['access'] as String;
      await _tokens.save(accessToken: access);

      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $access';
      return handler.resolve(await _dio.fetch(opts));
    } on DioException {
      // Refresh hết hạn → xoá token, về màn login.
      await _tokens.clear();
      return handler.next(err);
    }
  }
}
