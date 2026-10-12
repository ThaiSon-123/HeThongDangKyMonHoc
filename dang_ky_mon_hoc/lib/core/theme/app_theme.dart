import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme dùng chung toàn app (design.md 1.2, 1.8). Chỉ làm light; dark có sẵn qua
/// `ColorScheme.fromSeed` nhưng thiết kế chưa có.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
      primary: isLight ? AppColors.primary : null,
      secondary: const Color(0xFF009688), // teal
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme),
      scaffoldBackgroundColor: isLight ? AppColors.bg : null,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.surface : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: GoogleFonts.beVietnamPro(
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
