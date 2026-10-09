import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';

/// Màn hình đăng nhập — gọi POST /auth/login/.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final error = await ref.read(authControllerProvider.notifier).login(
          _username.text.trim(),
          _password.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
    // Thành công → AuthState đổi → router redirect vào trang chủ theo role.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Đăng nhập',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Nhập tên đăng nhập' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Đăng nhập'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),
                      child: const Text('Quên mật khẩu?'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
