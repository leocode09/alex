import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/cloud/cloud_sync_service.dart';

/// Lifecycle companion for [CloudSyncService].
///
/// Mirrors [LanSyncWatcher]: starts the service on widget mount, triggers a
/// sync on app_start and on lifecycle resume, and cleanly stops listeners
/// when the host widget is torn down (the singleton itself persists).
class CloudSyncWatcher extends StatefulWidget {
  const CloudSyncWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<CloudSyncWatcher> createState() => _CloudSyncWatcherState();
}

class _CloudSyncWatcherState extends State<CloudSyncWatcher>
    with WidgetsBindingObserver {
  final CloudSyncService _service = CloudSyncService();
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_service.triggerSync(reason: 'app_resumed'));
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await _service.start();
      await _service.triggerSync(reason: 'app_start');
    } catch (_) {
      // Cloud sync is best-effort; never crash startup.
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
