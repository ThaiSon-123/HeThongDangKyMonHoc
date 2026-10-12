import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';

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
      routerConfig: router,
    );
  }
}
