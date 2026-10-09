import 'package:flutter/material.dart';

/// Material 3 theme dùng chung toàn app (checklist 1.4).
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF1A56DB);

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
      ),
    );
  }
}
