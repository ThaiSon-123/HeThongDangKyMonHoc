import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Khung hộp thoại chuẩn (design.md 1.4): bo 16, tiêu đề navy 18px, nút phải thẳng hàng phải.
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.maxWidth = 520,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              child,
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút trong hộp thoại: [filled] = chính (indigo, hoặc đỏ khi [danger]); ngược lại viền xám.
class DialogButton extends StatelessWidget {
  const DialogButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final bool danger;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    const text = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final onTap = loading ? null : onPressed;
    final child = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: filled ? Colors.white : AppColors.primary,
            ),
          )
        : Text(label);
    return SizedBox(
      height: 44,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                shape: shape,
                textStyle: text,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                backgroundColor: danger ? AppColors.danger : AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                shape: shape,
                textStyle: text,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.border),
              ),
              child: child,
            ),
    );
  }
}

/// Hộp thoại xác nhận: trả `true` nếu bấm nút hành động. [danger] = nút đỏ (thao tác khó hoàn tác).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialog(
      title: title,
      maxWidth: 440,
      actions: [
        DialogButton('Hủy', onPressed: () => Navigator.of(ctx).pop(false)),
        DialogButton(
          actionLabel,
          filled: true,
          danger: danger,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.label,
          height: 1.5,
        ),
      ),
    ),
  );
  return result ?? false;
}
