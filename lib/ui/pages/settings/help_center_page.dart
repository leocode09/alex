import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/app_share_config.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

const List<_Faq> _faqs = [
  _Faq(
    'How do I create a sale?',
    'Open the Sales tab, tap any product card to add it to the cart, '
        'adjust quantities in the Cart tab, then tap Charge to finish.',
  ),
  _Faq(
    'How do I add or edit a product?',
    'Go to Inventory, tap the + button to add a new item, or tap any product '
        'to edit it. You can also configure multi-pack packages with their own '
        'price, cost and stock.',
  ),
  _Faq(
    'Where is stock tracked?',
    'Stock lives on each product as loose units plus any package boxes. Sales '
        'automatically decrement the right pool, and you can adjust stock '
        'manually from the product details screen.',
  ),
  _Faq(
    'How do I share data with another device?',
    'Use Settings to open LAN Manager for offline Wi-Fi peers, or Cloud Sync '
        'to mirror data through Firestore. Both use the same backup format and '
        'can run together.',
  ),
  _Faq(
    'I forgot my PIN. What do I do?',
    'Tap the device-admin icon during PIN entry to contact the owner, or '
        'clear app data from system settings to reset. Cloud Sync will restore '
        'your records after a fresh sign-in with the shop code.',
  ),
  _Faq(
    'How do I update the app?',
    'Settings → Check for Updates fetches the latest build from the release '
        'server. Long-press the tile to change the manifest URL. Dart-only '
        'patches are delivered silently through Shorebird on next launch.',
  ),
  _Faq(
    'Does ALEX work offline?',
    'Yes. Sales, inventory and money are stored locally as JSON. Cloud Sync '
        'only activates when a network is available and resumes on its own.',
  ),
  _Faq(
    'How do I protect sensitive actions with a PIN?',
    'Go to Settings → Security → PIN Preferences and toggle which actions '
        'require a PIN (discounts, deletes, reports, etc.). Admins can also '
        'force these from the admin panel.',
  ),
];

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  static const String _supportEmail = 'support@alex-pos.app';
  static const String _supportWebsite = AppShareConfig.downloadUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;

    return AppPageScaffold(
      title: 'Help Center',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPanel(
            padding: const EdgeInsets.all(AppTokens.space3),
            child: Row(
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: AppTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How can we help?',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Answers to common questions and ways to reach us.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: extras.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          const _SectionHeader(label: 'Frequently asked'),
          const SizedBox(height: AppTokens.space2),
          AppPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < _faqs.length; i++) ...[
                  _FaqTile(faq: _faqs[i]),
                  if (i != _faqs.length - 1)
                    Divider(
                      height: 1,
                      thickness: AppTokens.border,
                      color: extras.border,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          const _SectionHeader(label: 'Contact support'),
          const SizedBox(height: AppTokens.space2),
          AppPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ContactTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email support',
                  subtitle: _supportEmail,
                  onTap: () => _copyAndNotify(
                    context,
                    _supportEmail,
                    'Support email copied',
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: AppTokens.border,
                  color: extras.border,
                ),
                _ContactTile(
                  icon: Icons.public_rounded,
                  title: 'Website',
                  subtitle: _supportWebsite,
                  onTap: () => _copyAndNotify(
                    context,
                    _supportWebsite,
                    'Website link copied',
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: AppTokens.border,
                  color: extras.border,
                ),
                _ContactTile(
                  icon: Icons.share_outlined,
                  title: 'Share feedback',
                  subtitle: 'Open your share sheet to send us a note',
                  onTap: () => _shareFeedback(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
          const _SectionHeader(label: 'Quick actions'),
          const SizedBox(height: AppTokens.space2),
          AppPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ContactTile(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Share this app',
                  subtitle: 'QR code and download link',
                  onTap: () => context.push('/share-app'),
                ),
                Divider(
                  height: 1,
                  thickness: AppTokens.border,
                  color: extras.border,
                ),
                _ContactTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About ALEX',
                  subtitle: 'Version and legal info',
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space4),
        ],
      ),
    );
  }

  Future<void> _copyAndNotify(
    BuildContext context,
    String value,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _shareFeedback(BuildContext context) async {
    const message =
        'Hey ALEX team — here is some feedback from the app:\n\n';
    final canNativeShare = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (canNativeShare) {
      await Share.share(message, subject: 'ALEX feedback');
      return;
    }
    await _copyAndNotify(
      context,
      message,
      'Feedback template copied',
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.appExtras.muted,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});
  final _Faq faq;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: extras.muted,
        title: Text(
          faq.question,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          Text(
            faq.answer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: extras.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: extras.muted,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: extras.muted,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
    );
  }
}
