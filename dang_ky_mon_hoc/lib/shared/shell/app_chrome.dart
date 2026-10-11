import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/role_routes.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/avatar.dart';

/// Header navy bo đáy 28 của App (design.md 1.8): hàng trên gồm logo "ĐK" + cổng, chuông, avatar;
/// dưới là tiêu đề 28px + dòng phụ.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.config,
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.onAvatar,
  });

  final RoleRoutes config;
  final String title;
  final String? subtitle;
  final String initials;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.fromLTRB(20, 20 + top, 20, 22),
      decoration: const BoxDecoration(
        gradient: AppColors.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
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
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  config.brandSub,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              _BellButton(onTap: () => context.go(config.notificationsPath)),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Hồ sơ cá nhân',
                child: InkResponse(
                  onTap: onAvatar,
                  child: Avatar(initials: initials, size: 44),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Header gọn cho màn cấp sâu: nút Back + tiêu đề + dòng phụ.
class CompactAppHeader extends StatelessWidget {
  const CompactAppHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, 14 + top, 16, 18),
      decoration: const BoxDecoration(
        gradient: AppColors.navyGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            color: Colors.white,
            icon: const Icon(Icons.chevron_left, size: 28),
            onPressed: onBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Thông báo',
      child: InkResponse(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x24FFFFFF),
          ),
          child: const Icon(
            Icons.notifications_none_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// Thanh dưới nổi (design.md 1.8): trắng, cách mép 16, bo 34, 5 mục đều nhau; mục đang chọn là
/// viên thuốc navy chứa icon + nhãn trắng.
class FloatingBottomNav extends StatelessWidget {
  const FloatingBottomNav({super.key, required this.tabs, required this.path});

  final List<NavItem> tabs;
  final String path;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2E1F2A5C),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final t in tabs)
              Expanded(
                child: _Tab(
                  item: t,
                  selected: t.path == path,
                  onTap: () => context.go(t.path),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        child: Center(
          child: Container(
            // Viên thuốc rộng tối thiểu 62 và nới theo nhãn ("Trang chủ", "Nhập điểm").
            constraints: const BoxConstraints(minWidth: 62),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            height: 54,
            decoration: BoxDecoration(
              gradient: selected ? AppColors.navyGradient : null,
              borderRadius: BorderRadius.circular(27),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x4D1F2A5C),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 22, color: color),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
