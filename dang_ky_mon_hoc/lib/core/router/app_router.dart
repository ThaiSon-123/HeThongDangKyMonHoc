import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/web_only_screen.dart';
import '../../shared/shell/role_shell.dart';
import '../../shared/widgets/placeholder_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const _publicRoutes = {'/login', '/forgot-password'};

/// Vai trò không có route trong router hiện tại (vd Admin đăng nhập trên App)
/// bị đưa tới màn này thay vì lỗi route.
const _webOnlyPath = '/web-only';

/// Dựng router từ danh sách route theo vai trò (mục 10.2–10.3 plan.md).
/// Web truyền đủ 5 vai trò, App chỉ truyền SV + GV. Mỗi vai trò nằm trong một [ShellRoute]
/// để giữ khung điều hướng khi chuyển trang.
Provider<GoRouter> createRouterProvider(List<RoleRoutes> roleRoutes) {
  final pathsByRole = {
    for (final r in roleRoutes) r.role: {for (final d in r.routes) d.path},
  };

  return Provider<GoRouter>((ref) {
    // Đổi auth state → tăng counter → GoRouter đánh giá lại redirect.
    final refresh = ValueNotifier(0);
    ref.listen(authControllerProvider, (_, _) => refresh.value++);
    ref.onDispose(refresh.dispose);

    return GoRouter(
      initialLocation: '/login',
      refreshListenable: refresh,
      redirect: (context, state) {
        final auth = ref.read(authControllerProvider);
        final path = state.uri.path;

        // Đang khôi phục phiên → đứng yên.
        if (auth.status == AuthStatus.unknown) return null;

        if (!auth.isAuthenticated) {
          return _publicRoutes.contains(path) ? null : '/login';
        }

        final role = auth.user!.role;
        final allowed = pathsByRole[role];
        if (allowed == null) return path == _webOnlyPath ? null : _webOnlyPath;
        if (_publicRoutes.contains(path) || path == _webOnlyPath) {
          return role.homePath;
        }
        return allowed.contains(path) ? null : role.homePath;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: _webOnlyPath,
          builder: (context, state) => const WebOnlyScreen(),
        ),
        for (final r in roleRoutes)
          ShellRoute(
            builder: (context, state, child) =>
                RoleShell(config: r, path: state.uri.path, child: child),
            routes: [
              for (final d in r.routes)
                GoRoute(
                  path: d.path,
                  pageBuilder: (context, state) => NoTransitionPage(
                    key: state.pageKey,
                    child: d.builder?.call() ?? PlaceholderBody(title: d.title),
                  ),
                ),
            ],
          ),
      ],
    );
  });
}
