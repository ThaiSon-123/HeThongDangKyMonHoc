import 'package:flutter/material.dart';

import '../../features/profile/profile_screen.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const studentRoutes = RoleRoutes(
  UserRole.student,
  [
    RouteDef('/student', 'Tổng quan'),
    RouteDef(
      '/student/profile',
      'Hồ sơ',
      subtitle: 'Thông tin cá nhân và bảo mật',
      builder: ProfileScreen.new,
    ),
    RouteDef('/student/register', 'Đăng ký môn học'),
    RouteDef('/student/auto-schedule', 'Tạo TKB tự động'),
    RouteDef('/student/schedule', 'Thời khóa biểu'),
    RouteDef('/student/curriculum', 'Chương trình đào tạo'),
    RouteDef('/student/grades', 'Điểm'),
    RouteDef('/student/attendance', 'Điểm danh'),
    RouteDef('/student/tuition', 'Học phí'),
    RouteDef('/student/tuition/pay', 'Thanh toán học phí'),
    RouteDef('/student/notifications', 'Thông báo'),
  ],
  brandSub: 'Cổng sinh viên',
  groups: [
    NavGroup('TỔNG QUAN', [
      NavItem('Tổng quan', '/student', Icons.home_outlined),
    ]),
    NavGroup('ĐĂNG KÝ HỌC', [
      NavItem(
        'Đăng ký môn học',
        '/student/register',
        Icons.format_list_bulleted,
      ),
      NavItem(
        'Tạo TKB tự động',
        '/student/auto-schedule',
        Icons.auto_awesome_outlined,
      ),
      NavItem(
        'Thời khóa biểu',
        '/student/schedule',
        Icons.calendar_month_outlined,
      ),
    ]),
    NavGroup('HỌC VỤ', [
      NavItem(
        'Chương trình đào tạo',
        '/student/curriculum',
        Icons.menu_book_outlined,
      ),
      NavItem('Điểm', '/student/grades', Icons.star_outline),
      NavItem('Điểm danh', '/student/attendance', Icons.task_alt_outlined),
      NavItem(
        'Học phí',
        '/student/tuition',
        Icons.account_balance_wallet_outlined,
      ),
    ]),
    NavGroup('KHÁC', [
      NavItem(
        'Thông báo',
        '/student/notifications',
        Icons.notifications_none_outlined,
      ),
      NavItem('Hồ sơ', '/student/profile', Icons.person_outline),
    ]),
  ],
  bottomTabs: [
    NavItem('Trang chủ', '/student', Icons.home_outlined),
    NavItem('Đăng ký', '/student/register', Icons.format_list_bulleted),
    NavItem('TKB', '/student/schedule', Icons.calendar_month_outlined),
    NavItem(
      'Học phí',
      '/student/tuition',
      Icons.account_balance_wallet_outlined,
    ),
    NavItem('Hồ sơ', '/student/profile', Icons.person_outline),
  ],
);
