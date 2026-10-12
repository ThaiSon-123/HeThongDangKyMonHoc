import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';

/// Thẻ trắng bo 16, không viền, bóng nhẹ (design.md 1.8).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pad = isCompact(context) ? 16.0 : 24.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
