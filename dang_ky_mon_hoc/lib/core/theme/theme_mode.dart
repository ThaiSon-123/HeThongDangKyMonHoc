import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Chế độ Sáng / Tối / Theo hệ thống, lưu cùng kho với token (flutter_secure_storage).
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';
  static const _storage = FlutterSecureStorage();

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final saved = await _storage.read(key: _key);
      state = ThemeMode.values.firstWhere(
        (m) => m.name == saved,
        orElse: () => state,
      );
    } catch (_) {
      // Không đọc được kho (trình duyệt chặn lưu trữ…): giữ theo hệ thống.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }
}

/// Nút chọn chế độ hiển thị (sidebar, header App).
class ThemeModeButton extends ConsumerWidget {
  const ThemeModeButton({super.key, required this.color});

  final Color color;

  static const _items = [
    (ThemeMode.light, Icons.light_mode_outlined, 'Sáng'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Tối'),
    (ThemeMode.system, Icons.brightness_auto_outlined, 'Theo hệ thống'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return PopupMenuButton<ThemeMode>(
      tooltip: 'Giao diện',
      initialValue: mode,
      onSelected: ref.read(themeModeProvider.notifier).set,
      icon: Icon(_items.firstWhere((e) => e.$1 == mode).$2, color: color),
      itemBuilder: (_) => [
        for (final (m, icon, label) in _items)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 12),
                Text(label),
              ],
            ),
          ),
      ],
    );
  }
}
