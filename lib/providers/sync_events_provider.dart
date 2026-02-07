import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_event_bus.dart';

final syncEventsProvider = StreamProvider<SyncEvent>((ref) {
  return SyncEventBus.instance.stream;
});
