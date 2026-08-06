import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/account_provider.dart';
import '../../../services/pin_service.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class ShopPinWaitingPage extends ConsumerStatefulWidget {
  const ShopPinWaitingPage({super.key});

  @override
  ConsumerState<ShopPinWaitingPage> createState() =>
      _ShopPinWaitingPageState();
}

class _ShopPinWaitingPageState extends ConsumerState<ShopPinWaitingPage> {
  bool _checking = false;

  Future<void> _checkAgain() async {
    setState(() => _checking = true);
    final account = ref.read(accountServiceProvider).current;
    final ready = await PinService().ensurePinReady(account: account);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ready) {
      context.go('/');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('The shop PIN has not been set yet.')),
    );
  }

  Future<void> _logOut() async {
    setState(() => _checking = true);
    await ref.read(accountServiceProvider).logoutAccount();
    if (mounted) {
      context.go('/account-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(currentAccountStateProvider);
    final extras = context.appExtras;
    return AppPageScaffold(
      padding: const EdgeInsets.all(AppTokens.space4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AppPanel(
            emphasized: true,
            padding: const EdgeInsets.all(AppTokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_clock_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppTokens.space3),
                Text(
                  'Waiting for the shop PIN',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppTokens.space2),
                Text(
                  'The owner of ${account.shopName ?? 'this shop'} must set '
                  'the shared PIN before staff can use the POS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: extras.muted),
                ),
                const SizedBox(height: AppTokens.space3),
                FilledButton.icon(
                  onPressed: _checking ? null : _checkAgain,
                  icon: _checking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: const Text('Check again'),
                ),
                const SizedBox(height: AppTokens.space1),
                TextButton(
                  onPressed: _checking ? null : _logOut,
                  child: const Text('Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
