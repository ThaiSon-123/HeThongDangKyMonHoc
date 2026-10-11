import 'package:flutter/material.dart';

import '../auth/auth_user.dart';
import 'role_routes.dart';

const accountantRoutes = RoleRoutes(
  UserRole.accountant,
  [
    RouteDef('/accountant', 'Tổng quan'),
    RouteDef('/accountant/config', 'Cấu hình học phí'),
    RouteDef('/accountant/tuition', 'Học phí'),
    RouteDef('/accountant/debts', 'Công nợ'),
    RouteDef('/accountant/reports', 'Báo cáo'),
    RouteDef('/accountant/notifications', 'Thông báo'),
    RouteDef('/accountant/logs', 'Nhật ký'),
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
