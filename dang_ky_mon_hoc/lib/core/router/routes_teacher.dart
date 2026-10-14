import 'package:flutter/material.dart';

import '../../features/attendance/teacher_attendance_screen.dart';
import '../../features/grades/teacher_grades_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/registration/timetable_screen.dart';
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
    RouteDef(
      '/teacher/schedule',
      'Thời khóa biểu',
      subtitle: 'Lịch dạy theo tuần của các lớp phụ trách',
      builder: TimetableScreen.new,
    ),
    RouteDef(
      '/teacher/attendance',
      'Điểm danh',
      subtitle: 'Chọn lớp, điểm danh cả lớp và duyệt yêu cầu sửa của sinh viên',
      builder: TeacherAttendanceScreen.new,
    ),
    RouteDef(
      '/teacher/grades',
      'Nhập điểm',
      subtitle: 'Nhập điểm cả lớp, xem trước tổng kết, khóa điểm',
      builder: TeacherGradesScreen.new,
    ),
    RouteDef(
      '/teacher/notifications',
      'Thông báo',
      subtitle: 'Nhận thông báo và gửi cho các lớp bạn phụ trách',
      builder: NotificationsScreen.new,
    ),
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
