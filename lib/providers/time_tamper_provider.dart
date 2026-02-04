import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimeTamperStatus {
  final String reason;
  final DateTime detectedAt;

  const TimeTamperStatus({
    required this.reason,
    required this.detectedAt,
  });
}

final timeTamperProvider = StateProvider<TimeTamperStatus?>((_) => null);
