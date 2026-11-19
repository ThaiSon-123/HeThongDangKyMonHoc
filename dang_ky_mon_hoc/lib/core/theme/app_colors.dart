import 'package:flutter/material.dart';

/// Token màu (design.md mục 1.2 + 1.8: Navy + cam). Chỉ khai báo ở đây — đổi màu sửa một chỗ.
///
/// Màu nền/chữ đổi theo chế độ sáng/tối qua [isDark] (do `DkmhApp` đặt theo theme đang dùng):
/// getter trả giá trị sáng như cũ, hoặc giá trị tối. Màu thương hiệu cố định (sidebar, header navy,
/// cam) vẫn là `const`.
// ponytail: cờ toàn cục thay vì ThemeExtension + context ở ~800 chỗ dùng; đổi chế độ thì app
// đánh dấu dựng lại toàn cây (xem app.dart). Cần nhiều theme cùng lúc thì chuyển sang ThemeExtension.
class AppColors {
  AppColors._();

  static bool isDark = false;

  static Color _c(Color light, Color dark) => isDark ? dark : light;

  static Color get primary => _c(
    const Color(0xFF3F51B5),
    const Color(0xFF7986CB),
  ); // nút chính, mục menu đang chọn
  static Color get primaryDark =>
      _c(const Color(0xFF2C3A7A), const Color(0xFFC5CAE9));

  /// Navy dùng làm màu chữ tiêu đề (sáng lên ở chế độ tối).
  static Color get navy => _c(navyBrand, const Color(0xFFE3E6F5));

  /// Navy thương hiệu cố định: nền sidebar/header/AppBar, chữ "ĐK" trên ô logo trắng.
  static const navyBrand = Color(0xFF1F2A5C);
  static const navyEnd = Color(0xFF26357A); // đáy sidebar
  static const accent = Color(
    0xFFD9480F,
  ); // cam: avatar, chấm/huy hiệu thông báo
  static const bgLight = Color(0xFFF4F5FA);
  static const bgDark = Color(0xFF121420);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1C1F2B);
  static Color get bg => _c(bgLight, bgDark);
  static Color get surface => _c(surfaceLight, surfaceDark);

  /// Nền/viền nhạt viết cứng ở từng màn (vd `0xFFF7F8FC`): chế độ sáng giữ nguyên, chế độ tối
  /// pha 12% màu đó vào [surfaceDark] để còn sắc nhẹ mà chữ sáng vẫn đọc được.
  static Color tint(Color light) =>
      isDark ? Color.lerp(surfaceDark, light, 0.12)! : light;

  static Color get text => _c(const Color(0xFF212121), const Color(0xFFE4E6EF));
  static Color get muted =>
      _c(const Color(0xFF6B7280), const Color(0xFF9CA3AF));
  static Color get label =>
      _c(const Color(0xFF374151), const Color(0xFFC9CDD6)); // nhãn ô nhập
  static Color get border =>
      _c(const Color(0xFF9AA1B2), const Color(0xFF5B6275)); // viền ô nhập
  static Color get divider =>
      _c(const Color(0xFFEEF0F5), const Color(0xFF2C3040));
  static const breadcrumb = Color(0xFF8A93B8);
  static Color get subtitle =>
      _c(const Color(0xFF5B6488), const Color(0xFFA3ABCF));

  static Color get success =>
      _c(const Color(0xFF2E7D32), const Color(0xFF81C784));
  static Color get successBg =>
      _c(const Color(0xFFE6F4EA), const Color(0xFF1F3324));
  static Color get danger =>
      _c(const Color(0xFFC62828), const Color(0xFFEF5350));
  static const warning = Color(0xFFF9A825);

  // Banner (nền, chữ, viền)
  static Color get errorBannerBg =>
      _c(const Color(0xFFFDECEA), const Color(0xFF3A1F1F));
  static Color get errorBannerText =>
      _c(const Color(0xFF8C1D18), const Color(0xFFF5B7B1));
  static Color get errorBannerBorder =>
      _c(const Color(0xFFF3B8B3), const Color(0xFF6B2E2A));
  static Color get warnBannerBg =>
      _c(const Color(0xFFFFF4D6), const Color(0xFF3A3018));
  static Color get warnBannerText =>
      _c(const Color(0xFF6B4700), const Color(0xFFF3D98B));
  static Color get warnBannerBorder =>
      _c(const Color(0xFFF3D98B), const Color(0xFF6B5A2A));
  static Color get infoBannerBg =>
      _c(const Color(0xFFE8EAF6), const Color(0xFF252B4A));
  static Color get infoBannerText =>
      _c(const Color(0xFF2C387E), const Color(0xFFC5CAE9));

  // Sidebar
  static const sidebarText = Color(0xFFC9D0F2);
  static const sidebarMuted = Color(0xFFAEB8E6);
  static const sidebarGroup = Color(0xFF8E9AD6);

  /// Gradient navy 160° dùng cho header / panel thương hiệu (giữ nguyên ở cả hai chế độ).
  static const navyGradient = LinearGradient(
    begin: Alignment(-0.34, -0.94),
    end: Alignment(0.34, 0.94),
    colors: [navyBrand, Color(0xFF2C3A7A)],
  );

  static const cardShadow = [
    BoxShadow(color: Color(0x141F2A5C), blurRadius: 10, offset: Offset(0, 2)),
  ];
}
