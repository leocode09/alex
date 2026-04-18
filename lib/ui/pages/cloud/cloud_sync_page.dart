import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../providers/cloud_sync_provider.dart';
import '../../../services/cloud/cloud_sync_service.dart';
import '../../../services/cloud/firebase_init.dart';
import '../../design_system/app_theme_extensions.dart';
import '../../design_system/app_tokens.dart';
import '../../design_system/widgets/app_page_scaffold.dart';
import '../../design_system/widgets/app_panel.dart';

class CloudSyncPage extends ConsumerStatefulWidget {
  const CloudSyncPage({super.key});

  @override
  ConsumerState<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<CloudSyncPage> {
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaitedStart();
  }

  void unawaitedStart() async {
    await ref.read(shopServiceProvider).loadCache();
    if (!mounted) return;
    await ref.read(cloudSyncServiceProvider).start();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(cloudSyncServiceProvider);
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return AppPageScaffold(
          title: 'Cloud Sync',
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _statusCard(service),
              const SizedBox(height: AppTokens.space3),
              if (service.shopId == null || (service.shopId?.isEmpty ?? true))
                _notJoinedCard(service)
              else
                _joinedCard(service),
              const SizedBox(height: AppTokens.space3),
              _actionsLogCard(service),
              const SizedBox(height: AppTokens.space3),
              _rawLogsCard(service),
            ],
          ),
        );
      },
    );
  }

  Widget _statusCard(CloudSyncService service) {
    final extras = context.appExtras;
    final (label, color) = _statusDisplay(service.status, extras);
    return AppPanel(
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined,
                  size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Status',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppTokens.radiusS),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: AppTokens.border,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          if (!FirebaseInit.available)
            Text(
              'Firebase is not configured on this build. Run '
              '`flutterfire configure` in the project root and rebuild the app.',
              style: TextStyle(color: extras.muted, fontSize: 12),
            )
          else if (service.lastError != null)
            Text(
              service.lastError!,
              style: TextStyle(color: extras.danger, fontSize: 12),
            )
          else
            Text(
              service.shopId == null
                  ? 'Sign in and join a shop to start backing up to the cloud.'
                  : 'Live two-way sync active. Local is the source of truth; '
                      'cloud changes from other devices merge in automatically.',
              style: TextStyle(color: extras.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  (String, Color) _statusDisplay(CloudSyncStatus status, AppThemeExtras extras) {
    switch (status) {
      case CloudSyncStatus.online:
        return ('ONLINE', extras.success);
      case CloudSyncStatus.offline:
        return ('OFFLINE', extras.warning);
      case CloudSyncStatus.connecting:
        return ('CONNECTING', Theme.of(context).colorScheme.primary);
      case CloudSyncStatus.notJoined:
        return ('NOT JOINED', extras.muted);
      case CloudSyncStatus.error:
        return ('ERROR', extras.danger);
      case CloudSyncStatus.disabled:
        return ('DISABLED', extras.muted);
    }
  }

  Widget _notJoinedCard(CloudSyncService service) {
    final extras = context.appExtras;
    final theme = Theme.of(context);

    return AppPanel(
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create or Join a Shop',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'A shop groups devices that share the same catalog, sales, and money accounts.',
            style: TextStyle(color: extras.muted, fontSize: 12),
          ),
          const SizedBox(height: AppTokens.space3),

          // Create shop
          TextField(
            controller: _shopNameController,
            enabled: FirebaseInit.available && !_busy,
            decoration: const InputDecoration(
              labelText: 'New shop name',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: FirebaseInit.available && !_busy ? _onCreate : null,
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Create shop'),
            ),
          ),

          const SizedBox(height: AppTokens.space3),
          Divider(color: extras.border, height: 1),
          const SizedBox(height: AppTokens.space3),

          // Join shop
          TextField(
            controller: _joinCodeController,
            enabled: FirebaseInit.available && !_busy,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              _UpperCaseFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: '6-character shop code',
              border: OutlineInputBorder(),
              isDense: true,
              hintText: 'e.g. A7K3QZ',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: FirebaseInit.available && !_busy ? _onJoin : null,
              icon: const Icon(Icons.group_add_outlined, size: 18),
              label: const Text('Join shop'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _joinedCard(CloudSyncService service) {
    final extras = context.appExtras;
    final theme = Theme.of(context);
    final code = service.shopCode ?? '------';
    return AppPanel(
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  service.shopName ?? 'Your shop',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          Row(
            children: [
              Text('Shop code:',
                  style: TextStyle(color: extras.muted, fontSize: 12)),
              const SizedBox(width: 6),
              SelectableText(
                code,
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop code copied')),
                  );
                },
              ),
            ],
          ),
          Text(
            'Share this code with other devices to join the same shop.',
            style: TextStyle(color: extras.muted, fontSize: 12),
          ),
          const SizedBox(height: AppTokens.space3),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _onForceSync,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Force full resync'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _onLeave,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Leave shop'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionsLogCard(CloudSyncService service) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    final actions = service.actions;
    return AppPanel(
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_outlined,
                  size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Recent activity',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          if (actions.isEmpty)
            Text(
              'No sync activity yet.',
              style: TextStyle(color: extras.muted, fontSize: 12),
            )
          else
            ...actions.take(12).map(
                  (a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          a.success ? Icons.check_circle : Icons.error_outline,
                          size: 14,
                          color: a.success ? extras.success : extras.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${DateFormat('HH:mm:ss').format(a.at)} · ${a.reason} · ${a.message}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _rawLogsCard(CloudSyncService service) {
    final theme = Theme.of(context);
    final extras = context.appExtras;
    final logs = service.logs;
    return AppPanel(
      padding: const EdgeInsets.all(AppTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Logs',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space2),
          if (logs.isEmpty)
            Text('No logs yet.',
                style: TextStyle(color: extras.muted, fontSize: 12))
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: extras.panelAlt,
                borderRadius: BorderRadius.circular(AppTokens.radiusS),
                border: Border.all(
                    color: extras.border, width: AppTokens.border),
              ),
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Text(
                    logs[index],
                    style: const TextStyle(
                      fontFamily: 'IBMPlexMono',
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onCreate() async {
    final name = _shopNameController.text.trim();
    if (name.isEmpty) {
      _toast('Enter a shop name first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final shopService = ref.read(shopServiceProvider);
      final result = await shopService.createShop(name: name);
      if (!mounted) return;
      _toast(result.message);
      if (result.success) {
        await ref.read(cloudSyncServiceProvider).refresh();
        _shopNameController.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onJoin() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      _toast('Enter the 6-character shop code.');
      return;
    }
    setState(() => _busy = true);
    try {
      final shopService = ref.read(shopServiceProvider);
      final result = await shopService.joinShop(code: code);
      if (!mounted) return;
      _toast(result.message);
      if (result.success) {
        await ref.read(cloudSyncServiceProvider).refresh();
        _joinCodeController.clear();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave shop?'),
        content: const Text(
          'This device will stop syncing with the cloud. Local data stays on '
          'this device. Cloud data stays intact for other members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(shopServiceProvider).leaveShop();
      await ref.read(cloudSyncServiceProvider).refresh();
      if (!mounted) return;
      _toast('Left shop.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onForceSync() async {
    setState(() => _busy = true);
    try {
      await ref.read(cloudSyncServiceProvider).forceFullSync();
      if (!mounted) return;
      _toast('Full resync queued.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
