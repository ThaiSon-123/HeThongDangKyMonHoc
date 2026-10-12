import 'package:flutter/material.dart';

import '../../features/notifications/audit_log_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/grades/pdt_grade_sheets_screen.dart';
import '../../features/training/classes_screen.dart';
import '../../features/training/courses_screen.dart';
import '../../features/training/curriculums_screen.dart';
import '../../features/training/faculties_screen.dart';
import '../../features/training/majors_screen.dart';
import '../../features/training/profiles_screen.dart';
import '../../features/training/registrations_screen.dart';
import '../../features/training/semesters_screen.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const pdtRoutes = RoleRoutes(
  UserRole.pdt,
  [
    RouteDef('/pdt', 'Tổng quan'),
    RouteDef('/pdt/profiles', 'Hồ sơ SV / GV', builder: ProfilesScreen.new),
    RouteDef('/pdt/faculties', 'Khoa / viện', builder: FacultiesScreen.new),
    RouteDef('/pdt/majors', 'Ngành', builder: MajorsScreen.new),
    RouteDef(
      '/pdt/curriculums',
      'CTĐT & gán môn',
      builder: CurriculumsScreen.new,
    ),
    RouteDef(
      '/pdt/courses',
      'Môn học & tiên quyết',
      builder: CoursesScreen.new,
    ),
    RouteDef(
      '/pdt/semesters',
      'Học kỳ & cửa sổ đăng ký',
      builder: SemestersScreen.new,
    ),
    RouteDef('/pdt/classes', 'Lớp học phần & lịch', builder: ClassesScreen.new),
    RouteDef(
      '/pdt/registrations',
      'Theo dõi đăng ký & hủy hộ',
      builder: RegistrationsScreen.new,
    ),
    RouteDef(
      '/pdt/grade-sheets',
      'Duyệt điểm',
      subtitle: 'Duyệt điểm cả lớp, gia hạn hoặc nhập hộ khi giáo viên quá hạn',
      builder: PdtGradeSheetsScreen.new,
    ),
    RouteDef('/pdt/reports', 'Báo cáo'),
    RouteDef(
      '/pdt/notifications',
      'Thông báo',
      subtitle: 'Nhận thông báo và soạn gửi theo vai trò, lớp hoặc từng người',
      builder: NotificationsScreen.new,
    ),
    RouteDef(
      '/pdt/logs',
      'Nhật ký thao tác',
      subtitle: 'Lịch sử thao tác đào tạo — bấm một dòng để xem chi tiết',
      builder: AuditLogScreen.new,
    ),
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
