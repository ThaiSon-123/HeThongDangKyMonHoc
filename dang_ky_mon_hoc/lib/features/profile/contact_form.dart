import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/auth/auth_repository.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_field.dart';
import 'my_profile.dart';

/// Form sửa email / số điện thoại (PATCH /profiles/me/ — chỉ hai trường này).
class ContactForm extends ConsumerStatefulWidget {
  const ContactForm({super.key, required this.profile});

  final MyProfile profile;

  @override
  ConsumerState<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<ContactForm> {
  late final _email = TextEditingController(text: widget.profile.email);
  late final _sdt = TextEditingController(text: widget.profile.sdt);
  String? _emailError;
  String? _sdtError;
  String? _banner;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _sdt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final email = _email.text.trim();
    final sdt = _sdt.text.replaceAll(RegExp(r'\s+'), '');
    setState(() {
      _banner = null;
      _emailError = email.contains('@') ? null : 'Nhập email hợp lệ.';
      _sdtError = sdt.isEmpty || RegExp(r'^\+?[0-9]{8,14}$').hasMatch(sdt)
          ? null
          : 'Số điện thoại không hợp lệ.';
    });
    if (_emailError != null || (widget.profile.hasPhone && _sdtError != null)) {
      return;
    }

    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateContact(
            email: email,
            sdt: widget.profile.hasPhone ? sdt : null,
          );
      if (!mounted) return;
      ref.invalidate(myProfileProvider);
      setState(() => _loading = false);
      showAppToast(
        context,
        widget.profile.hasPhone
            ? 'Đã cập nhật email và số điện thoại.'
            : 'Đã cập nhật email.',
      );
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _emailError = f.fields['email'];
        _sdtError = f.fields['sdt'];
        if (_emailError == null && _sdtError == null) {
          _banner = f.isRateLimited
              ? 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.'
              : 'Không thể lưu thay đổi, vui lòng thử lại.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_banner != null) ...[
          AlertBanner(kind: BannerKind.error, message: _banner!),
          const SizedBox(height: 16),
        ],
        LabeledField(
          label: 'Email',
          controller: _email,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          enabled: !_loading,
        ),
        if (widget.profile.hasPhone) ...[
          const SizedBox(height: 16),
          LabeledField(
            label: 'Số điện thoại',
            controller: _sdt,
            error: _sdtError,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            enabled: !_loading,
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: AppButton(
              label: 'Lưu thay đổi',
              height: 48,
              loading: _loading,
              onPressed: _save,
            ),
          ),
        ),
      ],
    );
  }
}
