import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/download/save_file_provider.dart';
import '../../core/layout.dart';
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
    this.width,
  });

  final String label;
  final String value;
  final String? note;
  final Color? accent;
  final Color? valueColor;

  /// Mặc định: 200 trên Web, nửa bề ngang (2 thẻ/hàng) trên điện thoại.
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
    width: width ?? (isCompact(context) ? soCot2(context, 16) : 200),
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
        // Số tiền dài (vd 40.970.000 ₫) thu nhỏ vừa thẻ thay vì xuống dòng.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.navy,
            ),
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

/// Lưới thẻ số liệu: xếp hàng theo bề rộng từng thẻ (điện thoại: 2 thẻ/hàng, chia đều) và
/// kéo mọi thẻ trong một hàng cao bằng nhau dù ghi chú dài ngắn khác nhau.
class LuoiStat extends StatelessWidget {
  const LuoiStat({super.key, required this.children});

  final List<Widget> children;

  static const _khoang = 16.0;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    // Web: thẻ giãn đều hết bề ngang thay vì giữ bề rộng cố định (Android giữ nguyên).
    final gian = compact || kIsWeb;
    return LayoutBuilder(
      builder: (context, c) {
        final hang = <List<Widget>>[];
        var dong = <Widget>[];
        var rong = 0.0;
        for (final w in children) {
          final cua = w is StatCard ? (w.width ?? 200) : 200.0;
          final can = dong.isEmpty ? cua : rong + _khoang + cua;
          if (dong.isNotEmpty &&
              (compact ? dong.length == 2 : can > c.maxWidth)) {
            hang.add(dong);
            dong = [];
            rong = 0;
          }
          rong = dong.isEmpty ? cua : rong + _khoang + cua;
          dong.add(w);
        }
        if (dong.isNotEmpty) hang.add(dong);
        // Web nhiều hàng: chia đều số thẻ mỗi hàng (7 thẻ → 4 + 3) thay vì để một thẻ lẻ loi ở hàng cuối.
        if (kIsWeb && !compact && hang.length > 1) {
          final moi = (children.length / hang.length).ceil();
          hang.clear();
          for (var i = 0; i < children.length; i += moi) {
            hang.add(children.sublist(i, (i + moi).clamp(0, children.length)));
          }
        }
        // Số ô mỗi hàng: điện thoại 2; web theo hàng đầy nhất, hàng thiếu chừa ô trống cho cùng bề rộng.
        final cot = compact
            ? 2
            : hang.fold<int>(1, (m, h) => h.length > m ? h.length : m);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, h) in hang.indexed) ...[
              if (i > 0) const SizedBox(height: _khoang),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: gian ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    for (final (j, w) in h.indexed) ...[
                      if (j > 0) const SizedBox(width: _khoang),
                      if (gian) Expanded(child: w) else w,
                    ],
                    if (gian)
                      for (var k = h.length; k < cot; k++) ...[
                        const SizedBox(width: _khoang),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
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
