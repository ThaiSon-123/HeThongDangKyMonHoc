import 'package:flutter/widgets.dart';

/// Breakpoint (design.md 2.2): < 600 dạng App, 600–1024 thanh icon, > 1024 sidebar cố định.
const double kCompactMax = 600;
const double kWideMin = 1024;

bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kCompactMax;

bool isWide(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kWideMin;
