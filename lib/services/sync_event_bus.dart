import 'dart:async';

class SyncEvent {
  final String? reason;
  final DateTime timestamp;

  SyncEvent({this.reason}) : timestamp = DateTime.now();
}

class SyncEventBus {
  SyncEventBus._();

  static final SyncEventBus instance = SyncEventBus._();

  final StreamController<SyncEvent> _controller =
      StreamController<SyncEvent>.broadcast();

  Stream<SyncEvent> get stream => _controller.stream;

  void emit({String? reason}) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(SyncEvent(reason: reason));
  }
}
