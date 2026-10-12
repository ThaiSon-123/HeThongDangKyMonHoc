import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/router_web.dart';

/// Entrypoint WEB — đủ 5 vai trò: `flutter build web -t lib/main.dart`.
void main() {
  runApp(ProviderScope(child: DkmhApp(routerProvider: webRouterProvider)));
}
