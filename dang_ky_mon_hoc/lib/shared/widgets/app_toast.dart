import 'package:flutter/material.dart';

/// Toast ngắn dưới màn hình (nền #1F2937, tự ẩn sau ~2.6s) — design.md 1.4.
void showAppToast(BuildContext context, String message) {
  final width = MediaQuery.sizeOf(context).width;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 2600),
      width: width >= 600 ? 420 : null,
      margin: width >= 600 ? null : const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ),
  );
}
