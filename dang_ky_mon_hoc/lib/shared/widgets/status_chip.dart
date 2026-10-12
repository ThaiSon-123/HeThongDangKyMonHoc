import 'package:flutter/material.dart';

/// Chip trạng thái / vai trò (design.md 1.3): nền nhạt + chữ đậm, bo tròn.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  // Bảng màu dùng chung (khớp mockup).
  static const green = (Color(0xFFE6F4EA), Color(0xFF2E7D32));
  static const gray = (Color(0xFFECEFF1), Color(0xFF455A64));
  static const darkGray = (Color(0xFFCFD8DC), Color(0xFF263238));
  static const indigo = (Color(0xFFE8EAF6), Color(0xFF2C3A7A));
  static const yellow = (Color(0xFFFFF4D6), Color(0xFF8A5A00));
  static const red = (Color(0xFFFDECEA), Color(0xFF8C1D18));
  static const teal = (Color(0xFFE0F2F1), Color(0xFF00695C));
  static const orange = (Color(0xFFFFF1E6), Color(0xFF9A3412));

  factory StatusChip.of(String label, (Color, Color) color, {Key? key}) =>
      StatusChip(label, key: key, bg: color.$1, fg: color.$2);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
