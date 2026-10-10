import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/router/router_app.dart';

/// Entrypoint APP (Android/iOS), chỉ SV + GV: `flutter build apk -t lib/main_app.dart`.
void main() {
  runApp(ProviderScope(child: DkmhApp(routerProvider: appRouterProvider)));
}
