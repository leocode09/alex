import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/account_state.dart';
import '../../../providers/account_provider.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

/// Status screen shown to a device while its account request is
/// awaiting (or after being rejected by) the approver. The router
/// keeps the user on this route until the request is approved.
class PendingApprovalPage extends ConsumerWidget {
  const PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(currentAccountStateProvider);
    final extras = context.appExtras;
    final theme = Theme.of(context);

    final spec = _resolveSpec(state, extras);

    return PopScope(
      canPop: false,
      child: AppPageScaffold(
        padding: const EdgeInsets.all(AppTokens.space4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: AppPanel(
                emphasized: true,
                padding: const EdgeInsets.all(AppTokens.space4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(spec.icon, size: 28, color: spec.tone),
                        const SizedBox(width: AppTokens.space2),
                        Expanded(
                          child: Text(
                            spec.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space3),
                    Text(spec.message, style: theme.textTheme.bodyMedium),
                    if (state.shopName != null) ...[
                      const SizedBox(height: AppTokens.space3),
                      _DetailRow(
                          label: 'Business', value: state.shopName ?? '—'),
                    ],
                    if (state.shopCode != null && state.shopCode!.isNotEmpty)
                      _DetailRow(label: 'Code', value: state.shopCode!),
                    if (state.displayName != null &&
                        state.displayName!.isNotEmpty)
                      _DetailRow(
                          label: 'Your name', value: state.displayName!),
                    if (state.phone != null && state.phone!.isNotEmpty)
                      _DetailRow(label: 'Phone', value: state.phone!),
                    if (state.rejectionReason != null &&
                        state.rejectionReason!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppTokens.space3),
                      AppPanel(
                        color: extras.danger.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(AppTokens.space2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reason',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: extras.danger,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(state.rejectionReason!.trim()),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space4),
                    Wrap(
                      spacing: AppTokens.space2,
                      runSpacing: AppTokens.space2,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.read(accountServiceProvider).refresh(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh status'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _startOver(context, ref),
                          icon: const Icon(Icons.replay, size: 18),
                          label: const Text('Start over'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space3),
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
      ),
    );
  }

  Future<void> _startOver(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text(
          'This will remove the current request from this device so '
          'you can submit a new one. Existing data on the server is '
          'kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start over'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await ref.read(accountServiceProvider).startOver();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
  }

  _PendingSpec _resolveSpec(AccountState state, AppThemeExtras extras) {
    switch (state.stage) {
      case AccountStage.businessPending:
        return _PendingSpec(
          icon: Icons.hourglass_top,
          tone: extras.warning,
          title: 'Waiting for system admin',
          message:
              'Your business registration was submitted. The system '
              'administrator will review and approve it. The app will '
              'unlock automatically once you are approved.',
        );
      case AccountStage.staffPending:
        return _PendingSpec(
          icon: Icons.hourglass_top,
          tone: extras.warning,
          title: 'Waiting for business owner',
          message:
              'Your join request was sent. The business owner will see '
              'it and approve or reject it. The app will unlock '
              'automatically once you are approved.',
        );
      case AccountStage.businessRejected:
        return _PendingSpec(
          icon: Icons.cancel_outlined,
          tone: extras.danger,
          title: 'Business request rejected',
          message:
              'The system administrator rejected this business '
              'registration. Start over to submit a corrected request, '
              'or contact support for help.',
        );
      case AccountStage.staffRejected:
        return _PendingSpec(
          icon: Icons.cancel_outlined,
          tone: extras.danger,
          title: 'Join request rejected',
          message:
              'The business owner rejected your join request. Start '
              'over to pick a different business or try again.',
        );
      case AccountStage.unknown:
      case AccountStage.noAccount:
      case AccountStage.approved:
        // The router would normally redirect away from this page in
        // these states. Show a safe fallback.
        return _PendingSpec(
          icon: Icons.info_outline,
          tone: extras.muted,
          title: 'Account status',
          message:
              'Loading your account status… If this screen stays open, '
              'try Refresh status or Start over.',
        );
    }
  }
}

class _PendingSpec {
  final IconData icon;
  final Color tone;
  final String title;
  final String message;
  const _PendingSpec({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
  });
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: extras.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
