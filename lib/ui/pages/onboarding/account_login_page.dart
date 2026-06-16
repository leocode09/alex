import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/account_provider.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';

/// Phone + password login. This is the account/identity gate (distinct
/// from the local PIN screen). On success the router resolves the user's
/// shop membership and routes them onward.
class AccountLoginPage extends ConsumerStatefulWidget {
  const AccountLoginPage({super.key});

  @override
  ConsumerState<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends ConsumerState<AccountLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(accountServiceProvider).loginAccount(
            phone: _phoneController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message)),
        );
      }
      // On success the router redirect takes over automatically.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _forgotPassword() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot password?'),
        content: const Text(
          'For security, passwords can only be reset by support. Contact '
          'your system administrator with your phone number and they will '
          'reset it for you.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AppPageScaffold(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.point_of_sale_rounded,
                            size: 32, color: theme.colorScheme.primary),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome back',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Log in with your phone number and password.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: extras.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space4),
                    const AppSectionHeader(title: 'Log in'),
                    AppPanel(
                      padding: const EdgeInsets.all(AppTokens.space3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) {
                              if ((v ?? '').isEmpty) {
                                return 'Password is required';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _busy ? null : _submit(),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _forgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                          const SizedBox(height: AppTokens.space1),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Log in'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: TextStyle(color: extras.muted),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.push('/account-register'),
                          child: const Text('Create one'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space2),
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onLongPress: () => context.push('/admin-login'),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.space2,
                            vertical: AppTokens.space1,
                          ),
                          child: Icon(Icons.support_agent,
                              size: 18, color: extras.muted),
                        ),
                      ),
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
