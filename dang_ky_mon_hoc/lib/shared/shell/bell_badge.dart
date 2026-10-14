import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/training/training_api.dart';

/// Số thông báo chưa đọc. Khóa theo đường dẫn hiện tại nên tải lại mỗi lần chuyển trang; lỗi mạng → 0.
final unreadCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  path,
) async {
  try {
    final r = await ref
        .read(trainingApiProvider)
        .page('/notifications/', pageSize: 1, query: {'da_doc': 'false'});
    return (r['chua_doc'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

/// Chuông thông báo kèm chấm cam số chưa đọc (design.md 1.8).
class BellBadge extends ConsumerWidget {
  const BellBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String path;
    try {
      path = GoRouterState.of(context).uri.path;
    } catch (_) {
      path = '';
    }
    final n = ref.watch(unreadCountProvider(path)).value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (n > 0)
          Positioned(
            top: -3,
            right: -3,
            child: Semantics(
              label: '$n thông báo chưa đọc',
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  n > 9 ? '9+' : '$n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
