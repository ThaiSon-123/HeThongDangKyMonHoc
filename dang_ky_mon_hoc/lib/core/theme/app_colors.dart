import 'package:flutter/material.dart';

/// Token màu (design.md mục 1.2 + 1.8: Navy + cam). Chỉ khai báo ở đây — đổi màu sửa một chỗ.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF3F51B5); // nút chính, mục menu đang chọn
  static const primaryDark = Color(0xFF2C3A7A);
  static const navy = Color(0xFF1F2A5C);
  static const navyEnd = Color(0xFF26357A); // đáy sidebar
  static const accent = Color(
    0xFFD9480F,
  ); // cam: avatar, chấm/huy hiệu thông báo
  static const bg = Color(0xFFF4F5FA);
  static const surface = Color(0xFFFFFFFF);

  static const text = Color(0xFF212121);
  static const muted = Color(0xFF6B7280);
  static const label = Color(0xFF374151); // nhãn ô nhập
  static const border = Color(0xFF9AA1B2); // viền ô nhập
  static const divider = Color(0xFFEEF0F5);
  static const breadcrumb = Color(0xFF8A93B8);
  static const subtitle = Color(0xFF5B6488);

  static const success = Color(0xFF2E7D32);
  static const successBg = Color(0xFFE6F4EA);
  static const danger = Color(0xFFC62828);
  static const warning = Color(0xFFF9A825);

  // Banner (nền, chữ, viền)
  static const errorBannerBg = Color(0xFFFDECEA);
  static const errorBannerText = Color(0xFF8C1D18);
  static const errorBannerBorder = Color(0xFFF3B8B3);
  static const warnBannerBg = Color(0xFFFFF4D6);
  static const warnBannerText = Color(0xFF6B4700);
  static const warnBannerBorder = Color(0xFFF3D98B);
  static const infoBannerBg = Color(0xFFE8EAF6);
  static const infoBannerText = Color(0xFF2C387E);

  // Sidebar
  static const sidebarText = Color(0xFFC9D0F2);
  static const sidebarMuted = Color(0xFFAEB8E6);
  static const sidebarGroup = Color(0xFF8E9AD6);

  /// Gradient navy 160° dùng cho header / panel thương hiệu.
  static const navyGradient = LinearGradient(
    begin: Alignment(-0.34, -0.94),
    end: Alignment(0.34, 0.94),
    colors: [navy, primaryDark],
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x141F2A5C), blurRadius: 10, offset: Offset(0, 2)),
  ];
}
