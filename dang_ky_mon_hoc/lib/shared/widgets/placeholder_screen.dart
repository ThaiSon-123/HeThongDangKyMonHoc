import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Nội dung giữ chỗ cho trang chưa làm (chức năng thật ở các pha sau). Nằm trong khung điều hướng.
class PlaceholderBody extends StatelessWidget {
  const PlaceholderBody({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction, size: 48, color: AppColors.border),
          const SizedBox(height: 12),
          Text('$title — đang phát triển'),
        ],
      ),
    );
  }
}
