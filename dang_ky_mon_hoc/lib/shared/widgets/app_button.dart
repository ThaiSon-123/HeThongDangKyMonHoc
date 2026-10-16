import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';

/// Nút chính (indigo). Đang chờ → disable + spinner để chống bấm đúp (design.md 1.5).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double? height;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final h = height ?? (compact ? 56 : 52);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(compact ? 14 : 12),
    );
    final text = TextStyle(
      fontSize: compact ? 16 : 15,
      fontWeight: FontWeight.w600,
    );
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: outlined ? AppColors.primary : Colors.white,
            ),
          )
        : FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1));
    final onTap = loading ? null : onPressed;
    return SizedBox(
      height: h,
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                shape: shape,
                textStyle: text,
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: child,
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                shape: shape,
                textStyle: text,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: child,
            ),
    );
  }
}
