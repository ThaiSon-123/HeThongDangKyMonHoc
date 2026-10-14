import 'package:flutter/material.dart';

import '../../features/attendance/student_attendance_screen.dart';
import '../../features/dashboard/student_dashboard.dart';
import '../../features/grades/student_grades_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/registration/auto_schedule_screen.dart';
import '../../features/registration/curriculum_screen.dart';
import '../../features/registration/register_screen.dart';
import '../../features/registration/timetable_screen.dart';
import '../../features/tuition/student_tuition_screen.dart';
import '../auth/auth_user.dart';
import 'role_routes.dart';

const studentRoutes = RoleRoutes(
  UserRole.student,
  [
    RouteDef(
      '/student',
      'Tổng quan',
      subtitle: 'Việc cần chú ý hôm nay',
      builder: StudentDashboard.new,
    ),
    RouteDef(
      '/student/profile',
      'Hồ sơ',
      subtitle: 'Thông tin cá nhân và bảo mật',
      builder: ProfileScreen.new,
    ),
    RouteDef(
      '/student/register',
      'Đăng ký môn học',
      subtitle:
          'Lớp học phần được gom theo môn — bấm vào môn để xem các lớp đang mở',
      builder: RegisterScreen.new,
    ),
    RouteDef(
      '/student/auto-schedule',
      'Tạo TKB tự động',
      subtitle: 'Chọn môn, giáo viên mong muốn và ưu tiên cá nhân — hệ thống gợi ý tối đa 3 thời khóa biểu không trùng lịch',
      builder: AutoScheduleScreen.new,
    ),
    RouteDef(
      '/student/schedule',
      'Thời khóa biểu',
      subtitle: 'Lịch học theo tuần của các môn đã đăng ký',
      builder: TimetableScreen.new,
    ),
    RouteDef(
      '/student/curriculum',
      'Chương trình đào tạo',
      subtitle: 'Các môn theo học kỳ gợi ý và tiến độ tích lũy của bạn',
      builder: CurriculumScreen.new,
    ),
    RouteDef(
      '/student/grades',
      'Điểm',
      subtitle: 'Chỉ hiển thị điểm đã được Phòng đào tạo duyệt',
      builder: StudentGradesScreen.new,
    ),
    RouteDef(
      '/student/attendance',
      'Điểm danh',
      subtitle: 'Tỷ lệ vắng, từng buổi học và yêu cầu sửa điểm danh',
      builder: StudentAttendanceScreen.new,
    ),
    RouteDef(
      '/student/tuition',
      'Học phí',
      subtitle: 'Tổng hợp học phí, miễn giảm, đã nộp và công nợ',
      builder: StudentTuitionScreen.new,
    ),
    RouteDef(
      '/student/tuition/pay',
      'Thanh toán học phí',
      subtitle:
          'Chuyển khoản bằng mã QR — Phòng Kế toán xác nhận sau khi nhận tiền',
      builder: StudentPayScreen.new,
    ),
    RouteDef(
      '/student/notifications',
      'Thông báo',
      subtitle: 'Nhận thông báo từ nhà trường, giáo viên và hệ thống',
      builder: NotificationsScreen.new,
    ),
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
