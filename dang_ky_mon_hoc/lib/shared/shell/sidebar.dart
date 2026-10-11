import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_user.dart';
import '../../core/router/role_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../features/profile/account_dialog.dart';
import '../../features/profile/my_profile.dart';
import '../widgets/avatar.dart';

/// Mở trang hồ sơ (SV/GV có route riêng) hoặc hộp thoại tài khoản (Admin/PĐT/KT — plan không có
/// route hồ sơ cho 3 vai trò này, design.md 1.4 AccountMenu).
void openAccount(BuildContext context, RoleRoutes config) {
  final profile = '${config.homePath}/profile';
  if (config.routeFor(profile) != null) {
    context.go(profile);
  } else {
    showAccountDialog(context);
  }
}

/// Họ tên + dòng phụ của người dùng đang đăng nhập (dùng cho khối người dùng ghim đáy sidebar).
({String name, String subtitle}) currentIdentity(WidgetRef ref) {
  final user = ref.watch(authControllerProvider).user;
  final profile = ref.watch(myProfileProvider).asData?.value;
  final name = profile?.fullName.isNotEmpty == true
      ? profile!.fullName
      : (user?.fullName.isNotEmpty == true
            ? user!.fullName
            : (user?.username ?? ''));
  final subtitle =
      profile?.subtitle ??
      '${user?.role.label ?? ''} · ${user?.username ?? ''}';
  return (name: name, subtitle: subtitle);
}

/// Thương hiệu + menu nhóm + khối người dùng. [collapsed] = chỉ icon (rail 600–1024px).
class SidebarContent extends ConsumerWidget {
  const SidebarContent({
    super.key,
    required this.config,
    required this.path,
    this.collapsed = false,
    this.onNavigate,
  });

  final RoleRoutes config;
  final String path;
  final bool collapsed;

  /// Gọi sau khi chọn mục (để đóng Drawer).
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = currentIdentity(ref);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navy, AppColors.navyEnd],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 10 : 14,
        vertical: 20,
      ),
      child: Column(
        children: [
          _Brand(config: config, collapsed: collapsed),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                for (final group in config.groups) ...[
                  if (!collapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        group.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                          color: AppColors.sidebarGroup,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                  for (final item in group.items)
                    _NavTile(
                      icon: item.icon,
                      label: item.label,
                      active: item.path == path,
                      collapsed: collapsed,
                      onTap: () {
                        onNavigate?.call();
                        context.go(item.path);
                      },
                    ),
                ],
                const SizedBox(height: 4),
                _NavTile(
                  icon: Icons.logout,
                  label: 'Đăng xuất',
                  active: false,
                  collapsed: collapsed,
                  onTap: () {
                    onNavigate?.call();
                    ref.read(authControllerProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x1FFFFFFF), height: 24),
          _UserBlock(
            config: config,
            name: id.name,
            subtitle: id.subtitle,
            collapsed: collapsed,
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.config, required this.collapsed});

  final RoleRoutes config;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'ĐK',
        style: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
    if (collapsed) return Center(child: logo);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 16),
          child: Row(
            children: [
              logo,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đăng ký môn học',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      config.brandSub,
                      style: const TextStyle(
                        color: AppColors.sidebarMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0x1FFFFFFF), height: 1),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white : AppColors.sidebarText;
    final tile = Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: active ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        boxShadow: active
            ? const [
                BoxShadow(
                  color: Color(0x593F51B5),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0x1AFFFFFF),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12),
              child: Row(
                mainAxisAlignment: collapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: fg),
                  if (!collapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final semantic = Semantics(
      button: true,
      selected: active,
      label: label,
      child: tile,
    );
    return collapsed ? Tooltip(message: label, child: semantic) : semantic;
  }
}

class _UserBlock extends ConsumerWidget {
  const _UserBlock({
    required this.config,
    required this.name,
    required this.subtitle,
    required this.collapsed,
  });

  final RoleRoutes config;
  final String name;
  final String subtitle;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = Tooltip(
      message: 'Tài khoản',
      child: InkResponse(
        onTap: () => openAccount(context, config),
        child: Avatar(initials: initialsOf(name)),
      ),
    );
    if (collapsed) return avatar;
    return Row(
      children: [
        avatar,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.sidebarMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Đăng xuất',
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          color: AppColors.sidebarText,
          icon: const Icon(Icons.logout, size: 20),
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        ),
      ],
    );
  }
}
