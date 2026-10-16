import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';

/// Ô chọn có nhãn phía trên, cùng kiểu viền với [LabeledField].
class LabeledDropdown<T> extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final T value;

  /// (giá trị, nhãn hiển thị). `onChanged == null` = vô hiệu hóa.
  final List<(T, String)> options;
  final ValueChanged<T>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final compact = isCompact(context);
    final radius = BorderRadius.circular(compact ? 12 : 8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 6),
        // Tự vẽ khung (không dùng InputDecorator) để viền cố định, khớp LabeledField.
        Container(
          constraints: BoxConstraints(minHeight: compact ? 52 : 48),
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 12),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surface : const Color(0xFFF1F3F9),
            borderRadius: radius,
          ),
          // Viền vẽ đè (không chiếm chỗ) để chiều cao bằng đúng ô nhập bên cạnh.
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: enabled ? AppColors.border : AppColors.divider,
            ),
          ),
          alignment: Alignment.center,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: false,
              borderRadius: BorderRadius.circular(12),
              style: TextStyle(
                fontSize: compact ? 16 : 15,
                color: AppColors.text,
              ),
              items: [
                for (final (v, text) in options)
                  DropdownMenuItem<T>(value: v, child: Text(text)),
              ],
              onChanged: enabled ? (v) => onChanged!(v as T) : null,
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              helper!,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
      ],
    );
  }
}
