import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Avatar tròn chứa chữ cái đầu. Mặc định nền cam (khung điều hướng); [soft] = nền indigo nhạt (Hồ sơ).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initials,
    this.size = 40,
    this.soft = false,
  });

  final String initials;
  final double size;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: soft ? const Color(0xFFE8EAF6) : AppColors.accent,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: soft ? AppColors.primary : Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Nhãn vai trò nhỏ ("Sinh viên") dưới tên.
class RoleChip extends StatelessWidget {
  const RoleChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EAF6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
