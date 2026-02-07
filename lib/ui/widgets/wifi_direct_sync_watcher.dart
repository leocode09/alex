import 'package:flutter/material.dart';

import '../../services/wifi_direct_sync_service.dart';
import '../../services/data_sync_triggers.dart';

class WifiDirectSyncWatcher extends StatefulWidget {
  final Widget child;
  final bool hostPreferred;

  const WifiDirectSyncWatcher({
    super.key,
    required this.child,
    this.hostPreferred = false,
  });

  @override
  State<WifiDirectSyncWatcher> createState() => _WifiDirectSyncWatcherState();
}

class _WifiDirectSyncWatcherState extends State<WifiDirectSyncWatcher>
    with WidgetsBindingObserver {
  final WifiDirectSyncService _service = WifiDirectSyncService();
  bool _starting = false;
  bool _didTriggerInitialSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _service.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    }
  }

  Future<void> _start() async {
    if (_starting) {
      return;
    }
    _starting = true;
    try {
      await _service.start(hostPreferred: widget.hostPreferred);
      if (!_didTriggerInitialSync) {
        _didTriggerInitialSync = true;
        await DataSyncTriggers.trigger(reason: 'app_start');
      }
    } finally {
      _starting = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
