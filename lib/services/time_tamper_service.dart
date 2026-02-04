import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/time_tamper_provider.dart';

class TimeTamperService {
  static const MethodChannel _channel = MethodChannel('alex/time_guard');
  static const String _wallKey = 'time_guard_wall_ms';
  static const String _elapsedKey = 'time_guard_elapsed_ms';
  static const String _tzKey = 'time_guard_tz_offset_min';

  Future<int?> _getElapsedRealtimeMs() async {
    if (!Platform.isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('elapsedRealtime');
    } catch (_) {
      return null;
    }
  }

  Future<void> recordBaseline() async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final elapsed = await _getElapsedRealtimeMs();
    await prefs.setInt(_wallKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_tzKey, now.timeZoneOffset.inMinutes);
    if (elapsed != null) {
      await prefs.setInt(_elapsedKey, elapsed);
    }
  }

  Future<TimeTamperStatus?> checkForTamper({
    Duration threshold = const Duration(minutes: 2),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final wallNow = now.millisecondsSinceEpoch;
    final tzNow = now.timeZoneOffset.inMinutes;
    final elapsedNow = await _getElapsedRealtimeMs();

    final lastWall = prefs.getInt(_wallKey);
    final lastElapsed = prefs.getInt(_elapsedKey);
    final lastTz = prefs.getInt(_tzKey);

    TimeTamperStatus? tamper;

    if (lastWall != null && lastElapsed != null && elapsedNow != null) {
      final elapsedDelta = elapsedNow - lastElapsed;
      if (elapsedDelta >= 0) {
        final expectedWall = lastWall + elapsedDelta;
        final drift = (wallNow - expectedWall).abs();
        if (drift > threshold.inMilliseconds) {
          tamper = TimeTamperStatus(
            reason: 'Clock drifted by ${_formatDrift(drift)}',
            detectedAt: now,
          );
        }
      }
    }

    if (tamper == null && lastTz != null && lastTz != tzNow) {
      final delta = tzNow - lastTz;
      tamper = TimeTamperStatus(
        reason: 'Time zone changed by ${_formatOffset(delta)}',
        detectedAt: now,
      );
    }

    await recordBaseline();
    return tamper;
  }

  Future<void> openDateTimeSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('openDateTimeSettings');
    } catch (_) {
      return;
    }
  }
}

String _formatDrift(int driftMs) {
  final totalSeconds = (driftMs / 1000).round();
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }
  return '${seconds}s';
}

String _formatOffset(int minutes) {
  final sign = minutes >= 0 ? '+' : '-';
  final absMinutes = minutes.abs();
  final hours = absMinutes ~/ 60;
  final mins = absMinutes % 60;
  if (hours > 0 && mins > 0) {
    return '$sign${hours}h ${mins}m';
  }
  if (hours > 0) {
    return '$sign${hours}h';
  }
  return '$sign${mins}m';
}
