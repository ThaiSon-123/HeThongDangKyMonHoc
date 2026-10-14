import 'package:flutter/material.dart';

import '../../features/admin/accounts/accounts_screen.dart';
import '../../features/admin/system/backups_screen.dart';
import '../../features/admin/system/config_screen.dart';
import '../../features/admin/system/permissions_screen.dart';
import '../../features/notifications/audit_log_screen.dart';
import '../../features/notifications/notifications_screen.dart';

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
    RouteDef(
      '/admin/permissions',
      'Ma trận quyền',
      subtitle: 'Quyền của từng vai trò trong hệ thống (chỉ xem)',
      builder: PermissionsScreen.new,
    ),
    RouteDef(
      '/admin/config',
      'Cấu hình hệ thống',
      subtitle: 'Các thiết lập chung của hệ thống',
      builder: ConfigScreen.new,
    ),
    RouteDef(
      '/admin/backups',
      'Sao lưu',
      subtitle: 'Sao lưu dữ liệu hệ thống',
      builder: BackupsScreen.new,
    ),
    RouteDef(
      '/admin/logs',
      'Nhật ký thao tác',
      subtitle:
          'Lịch sử thao tác của toàn hệ thống — bấm một dòng để xem chi tiết',
      builder: AuditLogScreen.new,
    ),
    RouteDef(
      '/admin/notifications',
      'Thông báo',
      subtitle: 'Nhận thông báo và soạn gửi theo vai trò, lớp hoặc từng người',
      builder: NotificationsScreen.new,
    ),
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
