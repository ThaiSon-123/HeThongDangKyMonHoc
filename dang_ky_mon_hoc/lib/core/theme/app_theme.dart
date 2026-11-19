import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Material 3 theme dùng chung toàn app (design.md 1.2, 1.8). Dark dựng từ cùng seed, nền/thẻ lấy
/// `AppColors.bgDark` / `surfaceDark` cho khớp các thẻ tự vẽ.
// Không dùng getter đổi theo chế độ của AppColors ở đây: MaterialApp dựng cả hai theme mỗi lần.
class AppTheme {
  AppTheme._();

  static const _primary = Color(0xFF3F51B5);

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: brightness,
      primary: isLight ? _primary : null,
      surface: isLight ? null : AppColors.surfaceDark,
      secondary: const Color(0xFF009688), // teal
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    return base.copyWith(
      textTheme: GoogleFonts.beVietnamProTextTheme(base.textTheme),
      scaffoldBackgroundColor: isLight ? AppColors.bgLight : AppColors.bgDark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Web: chip to hơn một chút cho cân với màn hình rộng; Android giữ mặc định.
      chipTheme: kIsWeb
          ? ChipThemeData(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              // labelStyle thay hẳn style mặc định (mất màu): tối phải gán màu chữ lại.
              labelStyle: TextStyle(
                fontSize: 14,
                color: isLight ? null : scheme.onSurface,
              ),
            )
          : null,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.surfaceLight : null,
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
        backgroundColor: isLight
            ? AppColors.surfaceLight
            : AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
