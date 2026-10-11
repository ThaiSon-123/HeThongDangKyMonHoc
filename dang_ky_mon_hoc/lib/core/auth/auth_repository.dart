import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/my_profile.dart';
import '../api/api_failure.dart';
import 'auth_provider.dart';

/// Các lời gọi API xác thực / hồ sơ (plan.md mục 8.1). Lỗi luôn được đổi thành [ApiFailure].
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<MyProfile> fetchMe() => _guard(() async {
    final res = await _dio.get('/profiles/me/');
    return MyProfile.fromJson(Map<String, dynamic>.from(res.data as Map));
  });

  /// PATCH chỉ `email`, `sdt` (backend từ chối trường học vụ).
  Future<MyProfile> updateContact({String? email, String? sdt}) =>
      _guard(() async {
        final res = await _dio.patch(
          '/profiles/me/',
          data: {'email': ?email, 'sdt': ?sdt},
        );
        return MyProfile.fromJson(Map<String, dynamic>.from(res.data as Map));
      });

  Future<void> changePassword(String oldPassword, String newPassword) => _guard(
    () => _dio.post(
      '/auth/change-password/',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    ),
  );

  /// Luôn thành công với cùng một thông điệp dù email có tồn tại hay không. Ở dev backend trả
  /// kèm `token` — trả về để màn hình tự điền sẵn (prod không có).
  Future<String?> forgotPassword(String email) => _guard(() async {
    final res = await _dio.post(
      '/auth/forgot-password/',
      data: {'email': email},
    );
    final data = res.data;
    return data is Map ? data['token'] as String? : null;
  });

  Future<void> resetPassword(String token, String newPassword) => _guard(
    () => _dio.post(
      '/auth/reset-password/',
      data: {'token': token, 'new_password': newPassword},
    ),
  );
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider).dio),
);

/// Hồ sơ của người đang đăng nhập; tự tải lại khi đổi tài khoản.
/// Tắt tự thử lại của Riverpod: lỗi hiện ngay kèm nút "Thử lại" thay vì im lặng gọi lại.
final myProfileProvider = FutureProvider.autoDispose<MyProfile>((ref) {
  ref.watch(authControllerProvider.select((s) => s.user?.id));
  return ref.watch(authRepositoryProvider).fetchMe();
}, retry: (retryCount, error) => null);
