import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/account_state.dart';
import '../../services/cloud/account_service.dart';
import '../../services/lan_sync_service.dart';

class LanSyncWatcher extends StatefulWidget {
  const LanSyncWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<LanSyncWatcher> createState() => _LanSyncWatcherState();
}

class _LanSyncWatcherState extends State<LanSyncWatcher>
    with WidgetsBindingObserver {
  final LanSyncService _service = LanSyncService();
  StreamSubscription<LanConnectionEvent>? _eventSub;
  StreamSubscription<AccountState>? _accountSub;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = _service.connectionEvents.listen(_onConnectionEvent);
    // Boot may race AccountService attach; retry once the member is
    // approved so a cold-start "account_not_approved" does not stick.
    _accountSub = AccountService().watch().listen(_onAccountChanged);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    _accountSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.onNetworkResume();
    }
  }

  void _onAccountChanged(AccountState account) {
    if (!mounted) return;
    final shopId = account.shopId?.trim();
    if (account.stage != AccountStage.approved ||
        shopId == null ||
        shopId.isEmpty ||
        _service.isRunning ||
        _starting) {
      return;
    }
    // Only auto-retry cold-start races (watcher mounted before approval).
    // Auth / registration failures need an explicit user recovery path.
    final status = _service.status;
    if (status == 'stopped' || status == 'account_not_approved') {
      _start();
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _service.start();
    } catch (_) {
      // Never crash app startup.
    } finally {
      _starting = false;
    }
  }

  void _onConnectionEvent(LanConnectionEvent event) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final scheme = Theme.of(context).colorScheme;
    final isConnected = event.type == LanConnectionEventType.connected;

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isConnected ? Icons.link : Icons.link_off,
              color: scheme.onInverseSurface,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isConnected
                    ? 'Connected to ${event.peerName}'
                    : 'Disconnected from ${event.peerName}',
              ),
            ),
          ],
        ),
        duration: isConnected
            ? const Duration(seconds: 2)
            : const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
