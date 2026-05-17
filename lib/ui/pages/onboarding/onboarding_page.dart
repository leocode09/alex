import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';
import '../../design_system/widgets/app_section_header.dart';

/// Entry screen of the new account workflow. Lets a fresh install
/// choose between registering a brand-new business or joining one that
/// already exists. Reachable only when the device has no shop binding
/// (the router redirects here automatically).
class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = context.appExtras;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AppPageScaffold(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: AppTokens.space2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to ALEX',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Before you can use the app, set up your '
                              'business account.',
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
                  const AppSectionHeader(title: 'Choose how to start'),
                  _ChoiceTile(
                    icon: Icons.add_business_outlined,
                    title: 'Register a new business',
                    description:
                        'I am the business owner. I will submit my '
                        'business name and phone number for system '
                        'administrator approval.',
                    actionLabel: 'Continue',
                    onTap: () => context.push('/onboarding/create-business'),
                  ),
                  const SizedBox(height: AppTokens.space2),
                  _ChoiceTile(
                    icon: Icons.group_add_outlined,
                    title: 'Join an existing business',
                    description:
                        'I work for a business that is already on '
                        'ALEX. I will look up the business and the '
                        'owner will approve me.',
                    actionLabel: 'Continue',
                    onTap: () => context.push('/onboarding/join-business'),
                  ),
                  const SizedBox(height: AppTokens.space4),
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

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final theme = Theme.of(context);
    return AppPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: theme.colorScheme.primary),
          const SizedBox(width: AppTokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: extras.muted,
                  ),
                ),
                const SizedBox(height: AppTokens.space2),
                Row(
                  children: [
                    Icon(Icons.arrow_forward,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
