import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/account_provider.dart';
import '../../../services/cloud/user_auth_service.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

/// Creates a phone + password account. After registering, the router
/// sends the user to onboarding to register or join a business.
class AccountRegisterPage extends ConsumerStatefulWidget {
  const AccountRegisterPage({super.key});

  @override
  ConsumerState<AccountRegisterPage> createState() =>
      _AccountRegisterPageState();
}

class _AccountRegisterPageState extends ConsumerState<AccountRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(accountServiceProvider).registerAccount(
            phone: _phoneController.text,
            password: _passwordController.text,
            displayName: _nameController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) {
        // Router redirect resolves the next screen (onboarding choice).
        context.go('/onboarding');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final theme = Theme.of(context);

    return AppPageScaffold(
      appBar: AppBar(
        title: const Text(
          'Create account',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      padding: const EdgeInsets.all(AppTokens.space3),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPanel(
                padding: const EdgeInsets.all(AppTokens.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your account',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your phone number is your login. Keep your password '
                      'safe — it can only be reset by support.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: extras.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Your name is required';
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space2),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Phone number is required';
                  if (!RegExp(r'\d').hasMatch(t)) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space2),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  final t = v ?? '';
                  if (t.length < UserAuthService.minPasswordLength) {
                    return 'At least ${UserAuthService.minPasswordLength} '
                        'characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space2),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (v) {
                  if (v != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _busy ? null : _submit(),
              ),
              const SizedBox(height: AppTokens.space4),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: AppTokens.space2),
              TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
