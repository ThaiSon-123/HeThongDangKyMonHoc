import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_user.dart';
import 'admin_user.dart';

/// Gọi API quản lý tài khoản của Admin (ADM-02). Lỗi luôn được đổi thành [ApiFailure].
class AccountsRepository {
  AccountsRepository(this._dio);

  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiFailure.from(e);
    }
  }

  Future<PageResult<AdminUser>> list(AccountsFilter f) => _guard(() async {
    final res = await _dio.get(
      '/users/',
      queryParameters: {
        'page': f.page,
        'page_size': AccountsFilter.pageSize,
        if (f.search.trim().isNotEmpty) 'search': f.search.trim(),
        'role': ?f.role?.apiValue,
        'is_locked': ?f.locked,
      },
    );
    final data = res.data as Map;
    return PageResult(
      count: (data['count'] as num).toInt(),
      items: [
        for (final e in data['results'] as List)
          AdminUser.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
    );
  });

  Future<AdminUser> create({
    required String username,
    required String password,
    required UserRole role,
    required String email,
  }) => _guard(() async {
    final res = await _dio.post(
      '/users/',
      data: {
        'username': username,
        'password': password,
        'role': role.apiValue,
        'email': email,
      },
    );
    return AdminUser.fromJson(Map<String, dynamic>.from(res.data as Map));
  });

  Future<AdminUser> update(int id, {String? email, UserRole? role}) =>
      _guard(() async {
        final res = await _dio.patch(
          '/users/$id/',
          data: {'email': ?email, 'role': ?role?.apiValue},
        );
        return AdminUser.fromJson(Map<String, dynamic>.from(res.data as Map));
      });

  Future<void> setLocked(int id, bool locked) =>
      _guard(() => _dio.patch('/users/$id/lock/', data: {'is_locked': locked}));

  Future<void> resetPassword(int id, String newPassword) => _guard(
    () => _dio.post(
      '/users/$id/reset-password/',
      data: {'new_password': newPassword},
    ),
  );
}

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(apiClientProvider).dio),
);

class AccountsFilterNotifier extends Notifier<AccountsFilter> {
  @override
  AccountsFilter build() => const AccountsFilter();

  /// Đổi bộ lọc → quay về trang 1.
  void setSearch(String v) => state = state.copyWith(search: v, page: 1);
  void setRole(UserRole? v) => state = state.copyWith(role: v, page: 1);
  void setLocked(bool? v) => state = state.copyWith(locked: v, page: 1);
  void setPage(int p) => state = state.copyWith(page: p);
}

final accountsFilterProvider =
    NotifierProvider.autoDispose<AccountsFilterNotifier, AccountsFilter>(
      AccountsFilterNotifier.new,
    );

/// Trang tài khoản theo bộ lọc hiện tại. Tắt tự thử lại: lỗi hiện ngay kèm nút "Thử lại".
final accountsProvider = FutureProvider.autoDispose<PageResult<AdminUser>>(
  (ref) => ref
      .watch(accountsRepositoryProvider)
      .list(ref.watch(accountsFilterProvider)),
  retry: (retryCount, error) => null,
);
