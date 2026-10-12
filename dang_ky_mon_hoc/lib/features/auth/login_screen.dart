import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/labeled_field.dart';

/// Đăng nhập (design.md 4.1; mockup `Web-DangNhap`, `App-DangNhap`).
/// ≥ 900px: hai cột (panel thương hiệu navy + thẻ form). Hẹp: header navy + tấm trắng bo trên.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  LoginError? _error;
  String? _userError;
  String? _passError;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _userError = _username.text.trim().isEmpty ? 'Nhập tên đăng nhập.' : null;
      _passError = _password.text.isEmpty ? 'Nhập mật khẩu.' : null;
    });
    if (_userError != null || _passError != null) return;
    setState(() => _loading = true);
    final error = await ref
        .read(authControllerProvider.notifier)
        .login(_username.text.trim(), _password.text);
    if (!mounted) return;
    // Thành công: router tự chuyển sang trang chủ của vai trò.
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  Widget _banner() => switch (_error) {
    null => const SizedBox.shrink(),
    LoginError.invalid => const AlertBanner(
      kind: BannerKind.error,
      message: 'Tên đăng nhập hoặc mật khẩu không đúng.',
    ),
    LoginError.locked => const AlertBanner(
      kind: BannerKind.error,
      title: 'Tài khoản đã bị khóa.',
      message: 'Vui lòng liên hệ quản trị hệ thống.',
    ),
    LoginError.rateLimited => const AlertBanner(
      kind: BannerKind.warning,
      message: 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
    ),
    LoginError.network => const AlertBanner(
      kind: BannerKind.error,
      message: 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.',
    ),
    LoginError.other => const AlertBanner(
      kind: BannerKind.error,
      message: 'Không thể đăng nhập, vui lòng thử lại.',
    ),
  };

  Widget _form({required bool wide}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[_banner(), SizedBox(height: wide ? 20 : 18)],
        LabeledField(
          label: 'Tên đăng nhập',
          controller: _username,
          error: _userError,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          enabled: !_loading,
        ),
        SizedBox(height: wide ? 20 : 18),
        PasswordField(
          label: 'Mật khẩu',
          controller: _password,
          error: _passError,
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          enabled: !_loading,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 48),
              foregroundColor: AppColors.primary,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            onPressed: () => context.go('/forgot-password'),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        SizedBox(height: wide ? 4 : 0),
        AppButton(label: 'Đăng nhập', loading: _loading, onPressed: _submit),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) =>
            c.maxWidth >= 900 ? _wide(context) : _narrow(context),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.navyGradient),
            padding: const EdgeInsets.all(64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _LogoTile(size: 48, fontSize: 20),
                    const SizedBox(width: 14),
                    const Text(
                      'Đăng ký Môn học',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Quản lý học tập gọn gàng, mỗi học kỳ một lịch rõ ràng.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Đăng ký môn, điểm danh, nhập điểm và học phí trong một hệ thống — trên web và ứng dụng di động.',
                        style: TextStyle(
                          color: Color(0xE6FFFFFF),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Hệ thống dành cho sinh viên, giáo viên và cán bộ nhà trường.',
                  style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Dùng tài khoản do nhà trường cấp.',
                        style: TextStyle(fontSize: 14, color: AppColors.muted),
                      ),
                      const SizedBox(height: 20),
                      _form(wide: true),
                      const SizedBox(height: 20),
                      const Text(
                        'Giáo viên và sinh viên dùng được cả web lẫn ứng dụng. Quản trị, Phòng đào tạo và Kế toán chỉ dùng trên web.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: AppColors.navyGradient),
          padding: EdgeInsets.fromLTRB(24, 40 + top, 24, 48),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LogoTile(size: 56, fontSize: 22),
              SizedBox(height: 16),
              Text(
                'Đăng ký Môn học',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Điểm danh, nhập điểm và lịch dạy ngay trên điện thoại.',
                style: TextStyle(
                  color: Color(0xE6FFFFFF),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          // Tấm trắng bo trên 24 đè lên đáy header (nền sau cùng màu cuối gradient).
          child: Container(
            color: AppColors.primaryDark,
            child: Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Đăng nhập',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _form(wide: false),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.size, required this.fontSize});

  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size / 3.4),
      ),
      child: Text(
        'ĐK',
        style: TextStyle(
          color: AppColors.navy,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
