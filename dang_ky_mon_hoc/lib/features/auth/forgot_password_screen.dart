import 'package:flutter/material.dart';

/// Quên mật khẩu — Pha sau sẽ gọi API gửi email đặt lại mật khẩu.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _sent
                ? const Text(
                    'Nếu email tồn tại trong hệ thống, '
                    'bạn sẽ nhận được link đặt lại mật khẩu.',
                    textAlign: TextAlign.center,
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (v) => (v == null ||
                                  !v.contains('@'))
                              ? 'Nhập email hợp lệ'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _sent = true);
                            }
                          },
                          child: const Text('Gửi link đặt lại'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
