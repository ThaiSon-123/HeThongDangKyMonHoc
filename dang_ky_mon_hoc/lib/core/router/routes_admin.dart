import 'package:flutter/material.dart';

import '../../features/admin/accounts/accounts_screen.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const adminRoutes = RoleRoutes(
  UserRole.admin,
  [
    RouteDef(
      '/admin',
      'Tổng quan',
      subtitle: 'Tình trạng hệ thống, tài khoản và sao lưu',
    ),
    RouteDef(
      '/admin/accounts',
      'Tài khoản',
      subtitle: 'Tạo, khóa và quản lý tài khoản người dùng',
      builder: AccountsScreen.new,
    ),
    RouteDef('/admin/permissions', 'Ma trận quyền'),
    RouteDef('/admin/config', 'Cấu hình'),
    RouteDef('/admin/backups', 'Sao lưu'),
    RouteDef('/admin/logs', 'Nhật ký'),
    RouteDef('/admin/notifications', 'Thông báo'),
  ],
  brandSub: 'Quản trị',
  groups: [
    NavGroup('TỔNG QUAN', [
      NavItem('Tổng quan', '/admin', Icons.home_outlined),
    ]),
    NavGroup('NGƯỜI DÙNG', [
      NavItem('Tài khoản', '/admin/accounts', Icons.people_outline),
      NavItem('Ma trận quyền', '/admin/permissions', Icons.shield_outlined),
    ]),
    NavGroup('HỆ THỐNG', [
      NavItem('Cấu hình', '/admin/config', Icons.settings_outlined),
      NavItem('Sao lưu', '/admin/backups', Icons.backup_outlined),
      NavItem('Nhật ký', '/admin/logs', Icons.history),
    ]),
    NavGroup('KHÁC', [
      NavItem(
        'Thông báo',
        '/admin/notifications',
        Icons.notifications_none_outlined,
      ),
    ]),
  ],
);
