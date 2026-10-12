import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';

enum BannerKind { error, warning, info }

/// Banner thông báo (design.md 1.4): lỗi đỏ, cảnh báo vàng, thông tin indigo nhạt.
class AlertBanner extends StatelessWidget {
  const AlertBanner({
    super.key,
    required this.kind,
    this.title,
    required this.message,
  });

  final BannerKind kind;

  /// Câu đầu in đậm (vd "Tài khoản đã bị khóa.").
  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      BannerKind.error => (
        AppColors.errorBannerBg,
        AppColors.errorBannerText,
        AppColors.errorBannerBorder,
      ),
      BannerKind.warning => (
        AppColors.warnBannerBg,
        AppColors.warnBannerText,
        AppColors.warnBannerBorder,
      ),
      BannerKind.info => (
        AppColors.infoBannerBg,
        AppColors.infoBannerText,
        null,
      ),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(isCompact(context) ? 12 : 8),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Text.rich(
          TextSpan(
            style: TextStyle(fontSize: 13, color: fg, height: 1.5),
            children: [
              if (title != null)
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              TextSpan(text: message),
            ],
          ),
        ),
      ),
    );
  }
}
