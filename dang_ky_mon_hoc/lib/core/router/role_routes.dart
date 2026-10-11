import 'package:flutter/widgets.dart';

import '../auth/auth_user.dart';

/// Một route của vai trò. `builder` = màn hình thật (tear-off hằng như `ProfileScreen.new`);
/// để trống thì hiện placeholder (chức năng làm ở các pha sau). Màn hình được gắn ở đây — trong
/// file `routes_<role>.dart` — để bản App không biên dịch màn của vai trò Web-only.
class RouteDef {
  const RouteDef(this.path, this.title, {this.subtitle, this.builder});

  final String path;
  final String title;

  /// Dòng phụ dưới tiêu đề trang (vd "Thông tin cá nhân và bảo mật").
  final String? subtitle;
  final Widget Function()? builder;
}

/// Một mục menu (sidebar Web / thanh dưới App).
class NavItem {
  const NavItem(this.label, this.path, this.icon);

  final String label;
  final String path;
  final IconData icon;
}

/// Nhóm menu có tiêu đề in hoa (design.md 1.8).
class NavGroup {
  const NavGroup(this.title, this.items);

  final String title;
  final List<NavItem> items;
}

/// Toàn bộ route + menu của một vai trò — mỗi vai trò 1 file `routes_<role>.dart`
/// để bản App chỉ import file của SV/GV (mục 10.2 plan.md).
class RoleRoutes {
  const RoleRoutes(
    this.role,
    this.routes, {
    required this.brandSub,
    required this.groups,
    this.bottomTabs = const [],
  });

  final UserRole role;
  final List<RouteDef> routes;

  /// Dòng phụ thương hiệu dưới "Đăng ký môn học" ("Cổng sinh viên"…).
  final String brandSub;
  final List<NavGroup> groups;

  /// 5 tab của thanh dưới trên App (chỉ SV/GV; rỗng = dùng AppBar + Drawer).
  final List<NavItem> bottomTabs;

  String get homePath => routes.first.path;
  String get notificationsPath => '$homePath/notifications';

  /// Trang cấp 1 (có trên thanh dưới) hay màn cấp sâu.
  bool isTopLevel(String path) => bottomTabs.any((t) => t.path == path);

  RouteDef? routeFor(String path) {
    for (final r in routes) {
      if (r.path == path) return r;
    }
    return null;
  }
}
