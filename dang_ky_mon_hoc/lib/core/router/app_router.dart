import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../shared/widgets/placeholder_screen.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_user.dart';

/// Route map theo vai trò — mục 15.3 plan.md.
const _publicRoutes = {'/login', '/forgot-password'};

/// Admin/PĐT/KT chỉ được dùng trên Flutter Web.
const _webOnlyRoles = {UserRole.admin, UserRole.pdt, UserRole.accountant};

const _roleRoutes = <UserRole, List<String>>{
  UserRole.admin: [
    '/admin',
    '/admin/accounts',
    '/admin/roles',
    '/admin/config',
    '/admin/logs',
    '/admin/backups',
    '/admin/notifications',
  ],
  UserRole.pdt: [
    '/pdt',
    '/pdt/majors',
    '/pdt/curriculums',
    '/pdt/courses',
    '/pdt/semesters',
    '/pdt/classes',
    '/pdt/registrations',
    '/pdt/grade-sheets',
    '/pdt/retakes',
    '/pdt/reports',
    '/pdt/notifications',
  ],
  UserRole.student: [
    '/student',
    '/student/profile',
    '/student/register',
    '/student/auto-schedule',
    '/student/schedule',
    '/student/grades',
    '/student/attendance',
    '/student/tuition',
    '/student/retakes',
    '/student/notifications',
  ],
  UserRole.teacher: [
    '/teacher',
    '/teacher/profile',
    '/teacher/classes',
    '/teacher/attendance',
    '/teacher/grades',
    '/teacher/notifications',
  ],
  UserRole.accountant: [
    '/accountant',
    '/accountant/config',
    '/accountant/tuition',
    '/accountant/debts',
    '/accountant/reports',
    '/accountant/notifications',
  ],
};

const _titles = <String, String>{
  '/login': 'Đăng nhập',
  '/forgot-password': 'Quên mật khẩu',
  '/admin': 'Quản trị hệ thống',
  '/admin/accounts': 'Tài khoản',
  '/admin/roles': 'Phân quyền',
  '/admin/config': 'Cấu hình hệ thống',
  '/admin/logs': 'Audit log',
  '/admin/backups': 'Sao lưu / phục hồi',
  '/admin/notifications': 'Quản lý thông báo',
  '/pdt': 'Phòng đào tạo',
  '/pdt/majors': 'Ngành',
  '/pdt/curriculums': 'Chương trình đào tạo',
  '/pdt/courses': 'Học phần',
  '/pdt/semesters': 'Học kỳ',
  '/pdt/classes': 'Lớp học phần',
  '/pdt/registrations': 'Đăng ký môn học',
  '/pdt/grade-sheets': 'Phân công nhập điểm',
  '/pdt/retakes': 'Đơn học lại / cải thiện',
  '/pdt/reports': 'Báo cáo',
  '/pdt/notifications': 'Quản lý thông báo',
  '/student': 'Sinh viên',
  '/student/profile': 'Hồ sơ sinh viên',
  '/student/register': 'Đăng ký môn học',
  '/student/auto-schedule': 'Tự động xếp lịch',
  '/student/schedule': 'Thời khóa biểu',
  '/student/grades': 'Bảng điểm',
  '/student/attendance': 'Điểm danh',
  '/student/tuition': 'Học phí',
  '/student/retakes': 'Đơn học lại / cải thiện',
  '/student/notifications': 'Thông báo',
  '/teacher': 'Giáo viên',
  '/teacher/profile': 'Hồ sơ giáo viên',
  '/teacher/classes': 'Lớp giảng dạy',
  '/teacher/attendance': 'Điểm danh',
  '/teacher/grades': 'Nhập điểm',
  '/teacher/notifications': 'Thông báo',
  '/accountant': 'Kế toán',
  '/accountant/config': 'Cấu hình học phí',
  '/accountant/tuition': 'Học phí',
  '/accountant/debts': 'Công nợ',
  '/accountant/reports': 'Báo cáo',
  '/accountant/notifications': 'Quản lý thông báo',
};

final appRouterProvider = Provider<GoRouter>((ref) {
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

      // Đang khôi phục phiên → đứng yên (màn hình giữ chỗ).
      if (auth.status == AuthStatus.unknown) return null;

      if (!auth.isAuthenticated) {
        return _publicRoutes.contains(path) ? null : '/login';
      }

      final role = auth.user!.role;
      if (_publicRoutes.contains(path)) return role.homePath;

      final allowed = _roleRoutes[role]?.contains(path) ?? false;
      if (!allowed) return role.homePath;
      return null;
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
      for (final entry in _roleRoutes.entries)
        for (final path in entry.value)
          GoRoute(
            path: path,
            builder: (context, state) => _screenFor(path),
          ),
    ],
  );
});

Widget _screenFor(String path) {
  final role = _roleRoutes.entries
      .firstWhere((e) => e.value.contains(path))
      .key;
  // Role web-only mở trên App → màn thông báo thay vì chặn route.
  if (_webOnlyRoles.contains(role) && !kIsWeb) {
    return const PlaceholderScreen(title: 'Chỉ khả dụng trên trình duyệt');
  }
  return PlaceholderScreen(title: _titles[path] ?? path);
}
