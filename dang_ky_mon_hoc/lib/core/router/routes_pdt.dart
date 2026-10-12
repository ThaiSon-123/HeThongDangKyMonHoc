import 'package:flutter/material.dart';

import '../auth/auth_user.dart';
import 'role_routes.dart';

const pdtRoutes = RoleRoutes(
  UserRole.pdt,
  [
    RouteDef('/pdt', 'Tổng quan'),
    RouteDef('/pdt/profiles', 'Hồ sơ SV / GV'),
    RouteDef('/pdt/faculties', 'Khoa / viện'),
    RouteDef('/pdt/majors', 'Ngành'),
    RouteDef('/pdt/curriculums', 'Chương trình đào tạo'),
    RouteDef('/pdt/courses', 'Môn học'),
    RouteDef('/pdt/semesters', 'Học kỳ'),
    RouteDef('/pdt/classes', 'Lớp học phần'),
    RouteDef('/pdt/registrations', 'Đăng ký'),
    RouteDef('/pdt/grade-sheets', 'Duyệt điểm'),
    RouteDef('/pdt/reports', 'Báo cáo'),
    RouteDef('/pdt/notifications', 'Thông báo'),
    RouteDef('/pdt/logs', 'Nhật ký'),
  ],
  brandSub: 'Cổng phòng đào tạo',
  groups: [
    NavGroup('TỔNG QUAN', [NavItem('Tổng quan', '/pdt', Icons.home_outlined)]),
    NavGroup('DANH MỤC', [
      NavItem('Hồ sơ SV / GV', '/pdt/profiles', Icons.badge_outlined),
      NavItem('Khoa / viện', '/pdt/faculties', Icons.apartment_outlined),
      NavItem('Ngành', '/pdt/majors', Icons.school_outlined),
      NavItem(
        'Chương trình đào tạo',
        '/pdt/curriculums',
        Icons.menu_book_outlined,
      ),
      NavItem('Môn học', '/pdt/courses', Icons.class_outlined),
    ]),
    NavGroup('TỔ CHỨC ĐÀO TẠO', [
      NavItem('Học kỳ', '/pdt/semesters', Icons.event_outlined),
      NavItem('Lớp học phần', '/pdt/classes', Icons.groups_outlined),
      NavItem('Đăng ký', '/pdt/registrations', Icons.assignment_outlined),
      NavItem('Duyệt điểm', '/pdt/grade-sheets', Icons.fact_check_outlined),
    ]),
    NavGroup('KHÁC', [
      NavItem('Báo cáo', '/pdt/reports', Icons.bar_chart_outlined),
      NavItem(
        'Thông báo',
        '/pdt/notifications',
        Icons.notifications_none_outlined,
      ),
      NavItem('Nhật ký', '/pdt/logs', Icons.history),
    ]),
  ],
);
