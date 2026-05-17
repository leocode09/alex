import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/account_provider.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

/// Form for a business owner to register a brand-new business. Submits
/// a `pendingSystemAdmin` shop document and shows the pending screen
/// when the request goes through.
class CreateBusinessPage extends ConsumerStatefulWidget {
  const CreateBusinessPage({super.key});

  @override
  ConsumerState<CreateBusinessPage> createState() =>
      _CreateBusinessPageState();
}

class _CreateBusinessPageState extends ConsumerState<CreateBusinessPage> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(accountServiceProvider);
      final result = await service.submitBusinessRegistration(
        businessName: _businessNameController.text,
        ownerName: _ownerNameController.text,
        phoneNumber: _phoneController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success) {
        context.go('/pending-approval');
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
          'Register business',
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
                      'Business owner registration',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your request goes to the system administrator. '
                      'You will be able to use the app once it is '
                      'approved.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: extras.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTokens.space3),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  hintText: 'e.g. Sunrise Mini-Market',
                ),
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Business name is required';
                  if (t.length < 2) return 'Please enter a longer name';
                  return null;
                },
              ),
              const SizedBox(height: AppTokens.space2),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  hintText: 'Full name of the business owner',
                ),
                textInputAction: TextInputAction.next,
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
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+1 555 0100',
                ),
                textInputAction: TextInputAction.done,
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'Phone number is required';
                  final hasDigits = RegExp(r'\d').hasMatch(t);
                  if (!hasDigits) {
                    return 'Please enter a valid phone number';
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
                    : const Text('Submit for approval'),
              ),
              const SizedBox(height: AppTokens.space2),
              TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
