import 'package:flutter/material.dart';

import '../../features/profile/profile_screen.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const teacherRoutes = RoleRoutes(
  UserRole.teacher,
  [
    RouteDef('/teacher', 'Tổng quan'),
    RouteDef(
      '/teacher/profile',
      'Hồ sơ',
      subtitle: 'Thông tin cá nhân và bảo mật',
      builder: ProfileScreen.new,
    ),
    RouteDef('/teacher/classes', 'Lớp phụ trách'),
    RouteDef('/teacher/schedule', 'Thời khóa biểu'),
    RouteDef('/teacher/attendance', 'Điểm danh'),
    RouteDef('/teacher/grades', 'Nhập điểm'),
    RouteDef('/teacher/notifications', 'Thông báo'),
  ],
  brandSub: 'Cổng giáo viên',
  groups: [
    NavGroup('TỔNG QUAN', [
      NavItem('Tổng quan', '/teacher', Icons.home_outlined),
    ]),
    NavGroup('GIẢNG DẠY', [
      NavItem('Lớp phụ trách', '/teacher/classes', Icons.menu_book_outlined),
      NavItem(
        'Thời khóa biểu',
        '/teacher/schedule',
        Icons.calendar_month_outlined,
      ),
    ]),
    NavGroup('HỌC VỤ', [
      NavItem('Điểm danh', '/teacher/attendance', Icons.task_alt_outlined),
      NavItem('Nhập điểm', '/teacher/grades', Icons.edit_outlined),
    ]),
    NavGroup('KHÁC', [
      NavItem(
        'Thông báo',
        '/teacher/notifications',
        Icons.notifications_none_outlined,
      ),
      NavItem('Hồ sơ', '/teacher/profile', Icons.person_outline),
    ]),
  ],
  bottomTabs: [
    NavItem('Tổng quan', '/teacher', Icons.home_outlined),
    NavItem('Lớp', '/teacher/classes', Icons.menu_book_outlined),
    NavItem('Điểm danh', '/teacher/attendance', Icons.task_alt_outlined),
    NavItem('TKB', '/teacher/schedule', Icons.calendar_month_outlined),
    NavItem('Nhập điểm', '/teacher/grades', Icons.edit_outlined),
  ],
);
