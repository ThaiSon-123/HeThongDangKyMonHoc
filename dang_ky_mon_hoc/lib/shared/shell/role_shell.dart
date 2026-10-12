import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_user.dart';
import '../../core/layout.dart';
import '../../core/router/role_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/my_profile.dart';
import 'app_chrome.dart';
import 'bell_badge.dart';
import 'sidebar.dart';

/// Khung điều hướng theo vai trò (design.md 1.8 + 2.2):
/// - ≥ 1024px: sidebar navy 260 + header trang (breadcrumb, tiêu đề, chuông).
/// - 600–1024px: thanh icon 76 + header trang.
/// - < 600px: SV/GV = header navy + thanh dưới nổi; Admin/PĐT/KT = AppBar + Drawer.
class RoleShell extends ConsumerWidget {
  const RoleShell({
    super.key,
    required this.config,
    required this.path,
    required this.child,
  });

  final RoleRoutes config;
  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final route = config.routeFor(path);
    final title = route?.title ?? '';
    final subtitle = route?.subtitle;

    if (width >= kCompactMax) {
      final collapsed = width < kWideMin;
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: collapsed ? 76 : 260,
              child: SidebarContent(
                config: config,
                path: path,
                collapsed: collapsed,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeader(config: config, title: title, subtitle: subtitle),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (config.bottomTabs.isEmpty) {
      // Admin / PĐT / KT trên cửa sổ hẹp: AppBar + Drawer (design.md 2.2).
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        drawer: Drawer(
          width: 280,
          child: Builder(
            builder: (ctx) => SidebarContent(
              config: config,
              path: path,
              onNavigate: () => Navigator.of(ctx).maybePop(),
            ),
          ),
        ),
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      );
    }

    final id = currentIdentity(ref);
    final topLevel = config.isTopLevel(path);
    return Scaffold(
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topLevel)
                AppHeader(
                  config: config,
                  title: title,
                  subtitle: subtitle,
                  initials: initialsOf(id.name),
                  onAvatar: () => openAccount(context, config),
                )
              else
                CompactAppHeader(
                  title: title,
                  subtitle: subtitle,
                  onBack: () => context.go(config.homePath),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, topLevel ? 100 : 16),
                  child: child,
                ),
              ),
            ],
          ),
          if (topLevel)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FloatingBottomNav(tabs: config.bottomTabs, path: path),
            ),
        ],
      ),
    );
  }
}

/// Header trang Web: breadcrumb `Vai trò › Trang`, tiêu đề 28px navy, dòng phụ, chuông (design.md 1.9).
class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.config,
    required this.title,
    required this.subtitle,
  });

  final RoleRoutes config;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Đường dẫn',
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => context.go(config.homePath),
                        child: Text(
                          config.role.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.breadcrumb,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '›',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.breadcrumb,
                          ),
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.subtitle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Thông báo',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.go(config.notificationsPath),
              child: BellBadge(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: const Icon(
                    Icons.notifications_none_outlined,
                    color: AppColors.navy,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
