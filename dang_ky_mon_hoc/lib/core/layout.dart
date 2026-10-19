import 'package:flutter/widgets.dart';

/// Breakpoint (design.md 2.2): < 600 dạng App, 600–1024 thanh icon, > 1024 sidebar cố định.
const double kCompactMax = 600;
const double kWideMin = 1024;

bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactMax;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideMin;

/// Bề rộng mỗi ô khi chia đôi vùng nội dung (lề 16 hai bên) với khoảng cách [khoang] giữa hai ô.
/// Trừ thêm 0,5 để sai số làm tròn không đẩy ô thứ hai xuống dòng.
double soCot2(BuildContext context, double khoang) =>
    (MediaQuery.sizeOf(context).width - 32 - khoang) / 2 - 0.5;
