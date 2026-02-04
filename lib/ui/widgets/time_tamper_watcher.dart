import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/time_tamper_provider.dart';
import '../../services/time_tamper_service.dart';

class TimeTamperWatcher extends ConsumerStatefulWidget {
  final Widget child;
  final Duration checkInterval;

  const TimeTamperWatcher({
    super.key,
    required this.child,
    this.checkInterval = const Duration(seconds: 30),
  });

  @override
  ConsumerState<TimeTamperWatcher> createState() => _TimeTamperWatcherState();
}

class _TimeTamperWatcherState extends ConsumerState<TimeTamperWatcher>
    with WidgetsBindingObserver {
  final TimeTamperService _service = TimeTamperService();
  Timer? _timer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.recordBaseline();
    _scheduleTimer();
    _checkForTamper();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForTamper();
    }
  }

  void _scheduleTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.checkInterval, (_) {
      _checkForTamper();
    });
  }

  Future<void> _checkForTamper() async {
    if (_checking || !mounted) {
      return;
    }
    if (ref.read(timeTamperProvider) != null) {
      return;
    }
    _checking = true;
    try {
      final result = await _service.checkForTamper();
      if (!mounted || result == null) {
        return;
      }
      ref.read(timeTamperProvider.notifier).state = result;
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
