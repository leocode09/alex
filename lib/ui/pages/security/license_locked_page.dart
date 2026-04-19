import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/license_policy.dart';
import '../../../providers/license_provider.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

/// Hard-lock screen shown when the super admin has disabled this
/// install, marked it blocked, or let the license expire.
///
/// The rest of the app is inaccessible while this page is routed.
/// If the admin re-enables the install (live-listener pushes a fresh
/// policy), the router redirect clears the block automatically.
class LicenseLockedPage extends ConsumerWidget {
  const LicenseLockedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(currentLicensePolicyProvider);
    final block = policy.blockReason() ??
        const LicenseBlock(
          title: 'Application locked',
          message: 'This installation is currently locked.',
        );
    final extras = context.appExtras;

    return PopScope(
      canPop: false,
      child: AppPageScaffold(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AppPanel(
              emphasized: true,
              padding: const EdgeInsets.all(AppTokens.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_clock,
                          size: 28, color: extras.danger),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: Text(
                          block.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.space3),
                  Text(
                    block.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (policy.notice != null &&
                      policy.notice!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space3),
                    AppPanel(
                      child: Text(
                        policy.notice!.trim(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: extras.muted,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTokens.space4),
                  Text(
                    'The app will unlock automatically once the administrator '
                    'restores access.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: extras.muted,
                        ),
                  ),
                  const SizedBox(height: AppTokens.space4),
                  // Discreet entry point: long-press to open the admin
                  // sign-in. Kept unlabeled so regular users don't see
                  // it, but still reachable on a locked device (normal
                  // Settings is behind the lock).
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onLongPress: () => context.push('/admin-login'),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.space2,
                          vertical: AppTokens.space1,
                        ),
                        child: Icon(
                          Icons.support_agent,
                          size: 18,
                          color: extras.muted,
                        ),
                      ),
                    ),
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
