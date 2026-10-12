import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_user.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/avatar.dart';
import 'change_password_card.dart';
import 'contact_form.dart';
import 'my_profile.dart';

/// Hộp thoại tài khoản cho Admin / PĐT / KT (design.md 1.4 AccountMenu): chỉ tên đăng nhập,
/// vai trò, email + đổi mật khẩu — vì plan không có route hồ sơ cho 3 vai trò này.
Future<void> showAccountDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const AccountDialog());

class AccountDialog extends ConsumerWidget {
  const AccountDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: profile.when(
            loading: () => const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không tải được thông tin tài khoản.'),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Thử lại',
                  height: 48,
                  onPressed: () => ref.invalidate(myProfileProvider),
                ),
              ],
            ),
            data: (p) => _Content(profile: p),
          ),
        ),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Avatar(
                initials: initialsOf(profile.fullName),
                size: 56,
                soft: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RoleChip(profile.role.label),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Row('Tên đăng nhập', profile.username),
          _Row('Vai trò', profile.role.label),
          const SizedBox(height: 16),
          ContactForm(profile: profile),
          const Divider(height: 32),
          const Text(
            'Đổi mật khẩu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const ChangePasswordCard(inCard: false),
          const SizedBox(height: 16),
          AppButton(
            label: 'Đăng xuất',
            outlined: true,
            height: 48,
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          Text(
            v,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
