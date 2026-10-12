import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_field.dart';
import '../../shared/widgets/section_card.dart';

/// Chính sách mật khẩu (plan.md 8.1): ≥ 8 ký tự, có cả chữ lẫn số.
bool passwordMeetsPolicy(String p) =>
    p.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(p) &&
    RegExp(r'[0-9]').hasMatch(p);

const passwordPolicyHint = 'Ít nhất 8 ký tự, gồm cả chữ và số.';
const passwordPolicyError = 'Mật khẩu cần ít nhất 8 ký tự, có cả chữ và số.';

/// Khối "Đổi mật khẩu" (SV-02/GV-02 và hộp thoại tài khoản). Thành công → backend thu hồi mọi
/// refresh token nên đăng xuất và quay về màn đăng nhập (design.md 4.3).
class ChangePasswordCard extends ConsumerStatefulWidget {
  const ChangePasswordCard({super.key, this.inCard = true});

  /// `false` khi nhúng trong hộp thoại (không bọc thẻ).
  final bool inCard;

  @override
  ConsumerState<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<ChangePasswordCard> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  String? _oldError;
  String? _newError;
  String? _confirmError;
  String? _banner;
  bool _loading = false;

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _banner = null;
      _oldError = _old.text.isEmpty ? 'Nhập mật khẩu hiện tại.' : null;
      _newError = passwordMeetsPolicy(_new.text) ? null : passwordPolicyError;
      _confirmError = _confirm.text == _new.text
          ? null
          : 'Mật khẩu nhập lại không khớp.';
    });
    if (_oldError != null || _newError != null || _confirmError != null) return;

    setState(() => _loading = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(_old.text, _new.text);
      if (!mounted) return;
      showAppToast(context, 'Đã đổi mật khẩu. Đang chuyển về trang đăng nhập…');
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      await auth.logout();
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _oldError = f.fields['old_password'];
        _newError = f.fields['new_password'];
        if (_oldError == null && _newError == null) {
          _banner = f.isRateLimited
              ? 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.'
              : 'Không thể đổi mật khẩu, vui lòng thử lại.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_banner != null) ...[
          AlertBanner(kind: BannerKind.error, message: _banner!),
          const SizedBox(height: 16),
        ],
        PasswordField(
          label: 'Mật khẩu hiện tại',
          controller: _old,
          error: _oldError,
          autofillHints: const [AutofillHints.password],
          enabled: !_loading,
        ),
        const SizedBox(height: 16),
        PasswordField(
          label: 'Mật khẩu mới',
          controller: _new,
          helper: passwordPolicyHint,
          error: _newError,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_loading,
        ),
        const SizedBox(height: 16),
        PasswordField(
          label: 'Nhập lại mật khẩu mới',
          controller: _confirm,
          error: _confirmError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          enabled: !_loading,
        ),
        const SizedBox(height: 16),
        const AlertBanner(
          kind: BannerKind.warning,
          message: 'Sau khi đổi mật khẩu, bạn sẽ được đăng xuất khỏi mọi thiết bị và cần đăng nhập lại.',
        ),
        const SizedBox(height: 16),
        AppButton(
          label: 'Đổi mật khẩu',
          height: 48,
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
    return widget.inCard
        ? SectionCard(title: 'Đổi mật khẩu', child: body)
        : body;
  }
}
