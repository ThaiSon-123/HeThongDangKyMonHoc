import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/shell/app_chrome.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/labeled_field.dart';
import '../profile/change_password_card.dart';

/// Quên & đặt lại mật khẩu, 3 bước (design.md 4.2; mockup `Web-QuenMatKhau`, `App-QuenMatKhau`):
/// email → mã xác thực 6 số gửi qua email + mật khẩu mới → hoàn tất.
/// Email không có trong hệ thống / tài khoản bị khóa → backend báo lỗi dưới ô Email.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  int _step = 1;
  bool _loading = false;
  String? _emailError;
  String? _codeError;
  String? _passwordError;
  String? _confirmError;
  String? _banner;
  String? _notice; // sau khi bấm "Gửi lại mã"

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String _failureMessage(ApiFailure f) => f.isRateLimited
      ? 'Bạn đã yêu cầu mã quá 3 lần trong 15 phút. Vui lòng đợi rồi thử lại.'
      : f.isNetwork
      ? 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.'
      : 'Có lỗi xảy ra, vui lòng thử lại.';

  Future<void> _sendEmail() async {
    final email = _email.text.trim();
    final resend = _step == 2;
    setState(() {
      _banner = null;
      _notice = null;
      _emailError = email.contains('@') ? null : 'Nhập email hợp lệ.';
    });
    if (_emailError != null) return;
    setState(() => _loading = true);
    try {
      final devCode = await ref
          .read(authRepositoryProvider)
          .forgotPassword(email);
      if (!mounted) return;
      // Dev: backend trả kèm mã → điền sẵn (prod không có, người dùng nhập mã từ email).
      if (devCode != null) _code.text = devCode;
      setState(() {
        _loading = false;
        _step = 2;
        if (resend) {
          _notice = 'Đã gửi lại mã xác thực mới. Mã cũ không còn dùng được.';
        }
      });
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _emailError = f.fields['email'];
        if (_emailError == null) _banner = _failureMessage(f);
      });
    }
  }

  Future<void> _reset() async {
    setState(() {
      _banner = null;
      _notice = null;
      _codeError = _code.text.trim().length == 6
          ? null
          : 'Nhập đủ 6 chữ số của mã xác thực.';
      _passwordError = passwordMeetsPolicy(_password.text)
          ? null
          : passwordPolicyError;
      _confirmError = _confirm.text == _password.text
          ? null
          : 'Mật khẩu nhập lại không khớp.';
    });
    if (_codeError != null || _passwordError != null || _confirmError != null) {
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(_email.text.trim(), _code.text.trim(), _password.text);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _step = 3;
      });
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeError = f.fields['code'];
        _passwordError = f.fields['new_password'];
        if (_codeError == null && _passwordError == null) {
          _banner = _failureMessage(f);
        }
      });
    }
  }

  Widget _steps(bool compact) {
    final labels = compact
        ? const ['Email', 'Mã xác thực', 'Xong']
        : const ['Nhập email', 'Mã xác thực', 'Hoàn tất'];
    final dot = compact ? 24.0 : 26.0;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < 3; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: dot,
                height: dot,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i + 1 < _step
                      ? AppColors.success
                      : i + 1 == _step
                      ? AppColors.primary
                      : const Color(0xFFECEFF1),
                ),
                child: Text(
                  i + 1 < _step ? '✓' : '${i + 1}',
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: i + 1 > _step ? AppColors.muted : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                labels[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: i + 1 == _step
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: i + 1 > _step ? AppColors.muted : AppColors.text,
                ),
              ),
              if (i < 2)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Text('›', style: TextStyle(color: Color(0xFFC4C9D4))),
                ),
            ],
          ),
      ],
    );
  }

  Widget _stepBody(bool compact) {
    switch (_step) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              const Text(
                'Quên mật khẩu',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
            ],
            const Text(
              'Nhập email gắn với tài khoản. Chúng tôi sẽ gửi mã xác thực 6 số để bạn đặt lại mật khẩu.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (_banner != null) ...[
              AlertBanner(kind: BannerKind.warning, message: _banner!),
              const SizedBox(height: 16),
            ],
            LabeledField(
              label: 'Email',
              controller: _email,
              hint: 'ten@truong.edu.vn',
              error: _emailError,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _sendEmail(),
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Gửi mã xác thực',
              loading: _loading,
              onPressed: _sendEmail,
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              const Text(
                'Đặt lại mật khẩu',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
            ],
            AlertBanner(
              kind: BannerKind.info,
              message:
                  _notice ??
                  'Mã xác thực 6 số đã được gửi tới ${_email.text.trim()}. '
                      'Mã có hiệu lực 30 phút và chỉ dùng một lần.',
            ),
            const SizedBox(height: 16),
            if (_banner != null) ...[
              AlertBanner(kind: BannerKind.warning, message: _banner!),
              const SizedBox(height: 16),
            ],
            LabeledField(
              label: 'Mã xác thực',
              controller: _code,
              hint: 'Gồm 6 chữ số trong email',
              error: _codeError,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              enabled: !_loading,
            ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _loading ? null : _sendEmail,
                  child: const Text('Gửi lại mã'),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                          _step = 1;
                          _banner = null;
                          _notice = null;
                          _code.clear();
                        }),
                  child: const Text('Đổi email'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 16),
            PasswordField(
              label: 'Mật khẩu mới',
              controller: _password,
              helper: passwordPolicyHint,
              error: _passwordError,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            PasswordField(
              label: 'Nhập lại mật khẩu mới',
              controller: _confirm,
              error: _confirmError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _reset(),
              enabled: !_loading,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Đặt lại mật khẩu',
              loading: _loading,
              onPressed: _reset,
            ),
          ],
        );
      default:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 32 : 16),
          child: Column(
            children: [
              Container(
                width: compact ? 72 : 64,
                height: compact ? 72 : 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successBg,
                ),
                child: const Icon(
                  Icons.check,
                  size: 34,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Đã đặt lại mật khẩu',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              const Text(
                'Các phiên đăng nhập cũ đã bị đăng xuất. Hãy đăng nhập bằng mật khẩu mới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Về trang đăng nhập',
                onPressed: () => context.go('/login'),
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _steps(compact),
        const SizedBox(height: 20),
        _stepBody(compact),
        if (_step != 3) ...[
          const SizedBox(height: 8),
          if (!compact)
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text(
                'Quay lại đăng nhập',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ],
    );

    if (compact) {
      return Scaffold(
        body: Column(
          children: [
            CompactAppHeader(
              title: 'Quên mật khẩu',
              subtitle: 'Đặt lại qua email',
              onBack: () => context.go('/login'),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: content,
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3E6EE)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F101828),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
