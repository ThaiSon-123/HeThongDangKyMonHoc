import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode.dart';

/// Root widget: MaterialApp + GoRouter + Material 3 theme.
/// `routerProvider` do entrypoint chọn: `webRouterProvider` (Web) hoặc `appRouterProvider` (App).
class DkmhApp extends ConsumerWidget {
  const DkmhApp({super.key, required this.routerProvider});

  final Provider<GoRouter> routerProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Hệ thống đăng ký môn học',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        if (AppColors.isDark != dark) {
          AppColors.isDark = dark;
          // AppColors không phải InheritedWidget nên widget dùng nó không tự dựng lại: đánh dấu cả cây.
          final root = context as Element;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            void mark(Element e) {
              e.markNeedsBuild();
              e.visitChildren(mark);
            }

            if (root.mounted) root.visitChildren(mark);
          });
        }
        return child!;
      },
    );
  }
}
