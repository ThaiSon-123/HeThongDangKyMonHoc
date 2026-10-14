import 'package:flutter/material.dart';

import '../../features/notifications/audit_log_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/tuition/tuition_config_screen.dart';
import '../../features/tuition/tuition_ledger_screens.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const accountantRoutes = RoleRoutes(
  UserRole.accountant,
  [
    RouteDef('/accountant', 'Tổng quan'),
    RouteDef(
      '/accountant/config',
      'Cấu hình học phí',
      subtitle: 'Hạn đóng, đơn giá tín chỉ, miễn giảm và học bổng',
      builder: TuitionConfigScreen.new,
    ),
    RouteDef(
      '/accountant/tuition',
      'Học phí',
      subtitle: 'Tính học phí, ghi thu và ghi hoàn theo từng sinh viên',
      builder: AccountantTuitionScreen.new,
    ),
    RouteDef(
      '/accountant/debts',
      'Công nợ',
      subtitle: 'Sinh viên còn nợ học phí và sinh viên đang chờ hoàn tiền',
      builder: DebtsScreen.new,
    ),
    RouteDef('/accountant/reports', 'Báo cáo'),
    RouteDef(
      '/accountant/notifications',
      'Thông báo',
      subtitle: 'Nhận thông báo và soạn gửi theo vai trò, lớp hoặc từng người',
      builder: NotificationsScreen.new,
    ),
    RouteDef(
      '/accountant/logs',
      'Nhật ký thao tác',
      subtitle: 'Lịch sử thao tác tài chính — bấm một dòng để xem chi tiết',
      builder: AuditLogScreen.new,
    ),
  ],
  brandSub: 'Cổng kế toán',
  groups: [
    NavGroup('TỔNG QUAN', [
      NavItem('Tổng quan', '/accountant', Icons.home_outlined),
    ]),
    NavGroup('HỌC PHÍ', [
      NavItem('Cấu hình học phí', '/accountant/config', Icons.tune),
      NavItem('Học phí', '/accountant/tuition', Icons.payments_outlined),
      NavItem('Công nợ', '/accountant/debts', Icons.request_quote_outlined),
    ]),
    NavGroup('KHÁC', [
      NavItem('Báo cáo', '/accountant/reports', Icons.bar_chart_outlined),
      NavItem(
        'Thông báo',
        '/accountant/notifications',
        Icons.notifications_none_outlined,
      ),
      NavItem('Nhật ký', '/accountant/logs', Icons.history),
    ]),
  ],
);
