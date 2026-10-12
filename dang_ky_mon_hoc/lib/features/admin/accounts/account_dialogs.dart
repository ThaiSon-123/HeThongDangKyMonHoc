import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/auth/auth_user.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/labeled_field.dart';
import 'accounts_repository.dart';
import 'admin_user.dart';

/// Thứ tự + nhãn vai trò trong ô chọn (mockup `AD-Web-TaiKhoan`).
const accountRoleOptions = <(UserRole, String)>[
  (UserRole.admin, 'Quản trị'),
  (UserRole.pdt, 'Phòng đào tạo'),
  (UserRole.teacher, 'Giáo viên'),
  (UserRole.student, 'Sinh viên'),
  (UserRole.accountant, 'Kế toán'),
];

bool needsProfile(UserRole r) => r == UserRole.student || r == UserRole.teacher;

/// Thông điệp lỗi hiển thị trong hộp thoại: ưu tiên lỗi field của server, không lộ mã kỹ thuật.
String failureText(ApiFailure f, String fallback) {
  if (f.isNetwork) {
    return 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.';
  }
  if (f.isRateLimited) {
    return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
  }
  if (f.code == 'KHONG_CO_QUYEN') {
    return 'Bạn không có quyền thực hiện thao tác này.';
  }
  if (f.fields.isNotEmpty) return f.fields.values.first;
  // Lỗi nghiệp vụ (envelope) đã có thông điệp tiếng Việt hướng người dùng — hiện nguyên văn.
  if (f.code != null && f.message != null) return f.message!;
  return fallback;
}

/// Hai ô cạnh nhau, xếp dọc khi hộp thoại hẹp.
class _TwoUp extends StatelessWidget {
  const _TwoUp(this.a, this.b);

  final Widget a;
  final Widget b;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < 400
        ? Column(children: [a, const SizedBox(height: 14), b])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 14),
              Expanded(child: b),
            ],
          ),
  );
}

// ---------------------------------------------------------------- Tạo tài khoản
class CreateAccountDialog extends ConsumerStatefulWidget {
  const CreateAccountDialog({super.key});

  @override
  ConsumerState<CreateAccountDialog> createState() =>
      _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<CreateAccountDialog> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.teacher;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _username.text.trim();
    final email = _email.text.trim();
    if (username.isEmpty || email.isEmpty) {
      setState(() => _error = 'Nhập tên đăng nhập và email.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Mật khẩu ban đầu phải có ít nhất 8 ký tự.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref
          .read(accountsRepositoryProvider)
          .create(
            username: username,
            password: _password.text,
            role: _role,
            email: email,
          );
      if (mounted) Navigator.of(context).pop(username);
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failureText(f, 'Không thể tạo tài khoản, vui lòng thử lại.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Tạo tài khoản',
      actions: [
        DialogButton('Hủy', onPressed: () => Navigator.of(context).pop()),
        DialogButton(
          'Tạo tài khoản',
          filled: true,
          loading: _loading,
          onPressed: _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TwoUp(
            LabeledField(
              label: 'Tên đăng nhập',
              controller: _username,
              hint: 'VD: gv006',
              enabled: !_loading,
            ),
            LabeledDropdown<UserRole>(
              label: 'Vai trò',
              value: _role,
              options: [for (final (r, l) in accountRoleOptions) (r, l)],
              onChanged: _loading ? null : (r) => setState(() => _role = r),
            ),
          ),
          const SizedBox(height: 14),
          LabeledField(
            label: 'Email',
            controller: _email,
            hint: 'ten@truong.edu.vn',
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
          ),
          const SizedBox(height: 14),
          PasswordField(
            label: 'Mật khẩu ban đầu',
            controller: _password,
            hint: 'Ít nhất 8 ký tự',
            enabled: !_loading,
          ),
          if (needsProfile(_role)) ...[
            const SizedBox(height: 14),
            const AlertBanner(
              kind: BannerKind.info,
              message: 'Phòng đào tạo sẽ tạo hồ sơ học vụ cho tài khoản này.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            AlertBanner(kind: BannerKind.error, message: _error!),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Sửa tài khoản
class EditAccountDialog extends ConsumerStatefulWidget {
  const EditAccountDialog({
    super.key,
    required this.user,
    required this.isSelf,
  });

  final AdminUser user;

  /// Đang sửa chính tài khoản của mình: không đổi được vai trò.
  final bool isSelf;

  @override
  ConsumerState<EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends ConsumerState<EditAccountDialog> {
  late final _email = TextEditingController(text: widget.user.email);
  late UserRole _role = widget.user.role;
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String _roleLabel(UserRole r) =>
      accountRoleOptions.firstWhere((o) => o.$1 == r).$2;

  Future<void> _save() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Email là bắt buộc.');
      return;
    }
    final roleChanged = _role != widget.user.role;
    if (roleChanged) {
      final ok = await showConfirmDialog(
        context,
        title: 'Đổi vai trò?',
        message:
            'Đổi vai trò của ${widget.user.username} từ ${_roleLabel(widget.user.role)} sang ${_roleLabel(_role)}? Quyền truy cập của tài khoản sẽ thay đổi ngay.',
        actionLabel: 'Đổi vai trò',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref
          .read(accountsRepositoryProvider)
          .update(
            widget.user.id,
            email: email,
            role: roleChanged ? _role : null,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failureText(
          f,
          'Không thể cập nhật tài khoản, vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Sửa tài khoản ${widget.user.username}',
      maxWidth: 520,
      actions: [
        DialogButton('Hủy', onPressed: () => Navigator.of(context).pop()),
        DialogButton('Lưu', filled: true, loading: _loading, onPressed: _save),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: 'Email',
            controller: _email,
            hint: 'ten@truong.edu.vn',
            keyboardType: TextInputType.emailAddress,
            enabled: !_loading,
          ),
          const SizedBox(height: 14),
          LabeledDropdown<UserRole>(
            label: 'Vai trò',
            value: _role,
            options: [for (final (r, l) in accountRoleOptions) (r, l)],
            helper: widget.isSelf
                ? 'Bạn không thể đổi vai trò của chính mình.'
                : 'Đổi vai trò sẽ thay đổi quyền truy cập của tài khoản.',
            onChanged: (widget.isSelf || _loading)
                ? null
                : (r) => setState(() => _role = r),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AlertBanner(kind: BannerKind.error, message: _error!),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- Đặt lại mật khẩu
class ResetPasswordDialog extends ConsumerStatefulWidget {
  const ResetPasswordDialog({super.key, required this.user});

  final AdminUser user;

  @override
  ConsumerState<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<ResetPasswordDialog> {
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Mật khẩu mới phải có ít nhất 8 ký tự.');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref
          .read(accountsRepositoryProvider)
          .resetPassword(widget.user.id, _password.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = failureText(
          f,
          'Không thể đặt lại mật khẩu, vui lòng thử lại.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Đặt lại mật khẩu — ${widget.user.username}',
      maxWidth: 480,
      actions: [
        DialogButton('Hủy', onPressed: () => Navigator.of(context).pop()),
        DialogButton(
          'Đặt lại mật khẩu',
          filled: true,
          loading: _loading,
          onPressed: _save,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordField(
            label: 'Mật khẩu mới',
            controller: _password,
            hint: 'Ít nhất 8 ký tự',
            helper: 'Hãy chuyển mật khẩu mới cho người dùng; họ nên đổi lại sau lần đăng nhập đầu tiên.',
            enabled: !_loading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AlertBanner(kind: BannerKind.error, message: _error!),
          ],
        ],
      ),
    );
  }
}
