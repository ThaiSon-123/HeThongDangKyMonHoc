import 'package:flutter/material.dart';

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
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled ? AppColors.surface : const Color(0xFFF1F3F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            constraints: const BoxConstraints(minHeight: 44),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              isDense: false,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(fontSize: 14, color: AppColors.text),
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
