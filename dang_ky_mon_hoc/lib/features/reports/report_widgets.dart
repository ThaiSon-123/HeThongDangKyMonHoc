import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/download/save_file_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_toast.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../training/training_api.dart';

const xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Màu thanh lấp đầy: xanh < 70% · vàng 70–90% · đỏ > 90% (mockup `PDT-Web-BaoCao`).
Color lapDayColor(num pct) => pct > 90
    ? AppColors.danger
    : pct >= 70
    ? AppColors.warning
    : AppColors.success;

/// Tải tệp Excel từ [path] (kèm bộ lọc [query]) rồi lưu về máy; lỗi hiện toast.
Future<void> exportXlsx(
  BuildContext context,
  WidgetRef ref, {
  required String path,
  required Map<String, Object?> query,
  required String fileName,
}) async {
  try {
    final bytes = await ref
        .read(trainingApiProvider)
        .getBytes(path, query: query);
    await ref.read(saveFileProvider)(fileName, bytes, mime: xlsxMime);
    if (context.mounted) showAppToast(context, 'Đã xuất tệp Excel.');
  } on ApiFailure catch (f) {
    if (context.mounted) {
      showAppToast(context, failureText(f, 'Không xuất được tệp Excel.'));
    }
  } on UnsupportedError {
    if (context.mounted) {
      showAppToast(context, 'Chỉ xuất được tệp trên bản Web.');
    }
  }
}

/// Thẻ số liệu: nhãn nhỏ, giá trị lớn, ghi chú; [accent] kẻ vạch màu bên trái (báo cáo tài chính).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.accent,
    this.valueColor,
    this.width = 200,
  });

  final String label;
  final String value;
  final String? note;
  final Color? accent;
  final Color? valueColor;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
      border: accent == null
          ? null
          : Border(left: BorderSide(color: accent!, width: 4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.navy,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ],
    ),
  );
}

/// Một dòng biểu đồ cột ngang: nhãn · thanh ([fraction] 0..1) · giá trị.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.fraction,
    required this.valueText,
    required this.color,
    this.labelWidth = 190,
    this.valueWidth = 48,
  });

  final String label;
  final double fraction;
  final String valueText;
  final Color color;
  final double labelWidth;
  final double valueWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction.clamp(0, 1).toDouble(),
              minHeight: 14,
              color: color,
              backgroundColor: AppColors.divider,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: valueWidth,
          child: Text(
            valueText,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
