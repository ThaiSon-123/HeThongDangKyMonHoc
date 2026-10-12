import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';

/// Ô nhập có nhãn phía trên (design.md 1.4/1.9): viền 1px, bo 8 (Web) / 12 (App), cao ≥ 48/52,
/// lỗi hiện ngay dưới ô và viền đỏ. Dùng chung cho mọi form.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
    this.inputFormatters,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;
  final String? error;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final radius = BorderRadius.circular(compact ? 12 : 8);
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: c, width: w),
    );
    final hasError = error != null && error!.isNotEmpty;
    final base = hasError ? AppColors.danger : AppColors.border;

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
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          style: TextStyle(fontSize: compact ? 16 : 15),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surface,
            suffixIcon: suffix,
            constraints: BoxConstraints(minHeight: compact ? 52 : 48),
            contentPadding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 12,
              vertical: 14,
            ),
            enabledBorder: border(base, 1),
            disabledBorder: border(AppColors.divider, 1),
            focusedBorder: border(
              hasError ? AppColors.danger : AppColors.primary,
              1.5,
            ),
            border: border(base, 1),
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
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.danger,
              ),
            ),
          ),
      ],
    );
  }
}

/// [LabeledField] cho mật khẩu có nút hiện/ẩn (vùng chạm ≥ 44px).
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.error,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? error;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      controller: widget.controller,
      hint: widget.hint,
      helper: widget.helper,
      error: widget.error,
      obscure: !_show,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      enabled: widget.enabled,
      suffix: IconButton(
        tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () => setState(() => _show = !_show),
        icon: Icon(
          _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: AppColors.muted,
        ),
      ),
    );
  }
}
