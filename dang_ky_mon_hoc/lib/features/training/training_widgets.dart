import 'package:flutter/material.dart';

import '../../core/api/api_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;

/// Chip trạng thái theo nhãn tiếng Việt của mockup (không lộ tên enum).
Widget trangThaiChip(String trangThai) {
  final (label, color) = switch (trangThai) {
    'HOAT_DONG' => ('Hoạt động', StatusChip.green),
    'NGUNG' => ('Ngừng', StatusChip.gray),
    'NGUNG_SU_DUNG' => ('Ngừng sử dụng', StatusChip.gray),
    'MO' => ('Đang mở', StatusChip.green),
    'DONG' => ('Đã đóng', StatusChip.gray),
    'KE_HOACH' => ('Kế hoạch', StatusChip.yellow),
    'DANG_HOC' => ('Đang học', StatusChip.indigo),
    'DA_DONG' => ('Đã đóng', StatusChip.gray),
    _ => (trangThai, StatusChip.gray),
  };
  return Align(
    alignment: Alignment.centerLeft,
    child: StatusChip.of(label, color),
  );
}

/// Tab dạng gạch chân (mockup `CTDT`, `MonHoc`).
class TabsRow extends StatelessWidget {
  const TabsRow({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      children: [
        for (final (i, l) in labels.indexed)
          Semantics(
            button: true,
            selected: i == index,
            child: InkWell(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 2,
                      color: i == index
                          ? AppColors.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Text(
                  l,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: i == index ? AppColors.primary : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Chạy một thao tác gọi API: thành công → toast + [onDone]; lỗi → toast thông điệp của server.
Future<bool> runAction(
  BuildContext context,
  Future<void> Function() call, {
  required String success,
  String fallback = 'Không thể thực hiện thao tác này.',
  VoidCallback? onDone,
}) async {
  try {
    await call();
  } on ApiFailure catch (f) {
    if (context.mounted) showAppToast(context, failureText(f, fallback));
    return false;
  }
  if (!context.mounted) return true;
  onDone?.call();
  showAppToast(context, success);
  return true;
}

/// Hỏi xác nhận rồi chạy [call] (ngừng khoa/ngành/môn, bỏ môn khỏi CTĐT…).
Future<void> confirmAndRun(
  BuildContext context, {
  required String title,
  required String message,
  required String actionLabel,
  required Future<void> Function() call,
  required String success,
  VoidCallback? onDone,
  bool danger = true,
}) async {
  final ok = await showConfirmDialog(
    context,
    title: title,
    message: message,
    actionLabel: actionLabel,
    danger: danger,
  );
  if (!ok || !context.mounted) return;
  await runAction(context, call, success: success, onDone: onDone);
}

/// Khung một khối nội dung trắng bo 16 (dùng cho phần chi tiết bên dưới bảng).
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.padding = 24});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

const sectionTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: AppColors.navy,
);

const monoStyle = TextStyle(
  fontFamily: 'monospace',
  fontWeight: FontWeight.w600,
  fontSize: 13,
);
