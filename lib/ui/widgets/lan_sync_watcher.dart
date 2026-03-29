import 'dart:async';

import 'package:flutter/material.dart';

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
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = _service.connectionEvents.listen(_onConnectionEvent);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.onNetworkResume();
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
