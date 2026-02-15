import 'dart:convert';
import 'dart:math';

class SyncMessageUtils {
  static final Random _random = Random.secure();

  static int utf8Size(String value) => utf8.encode(value).length;

  static String nextMessageId(String deviceId) {
    final normalizedDeviceId = deviceId.trim().isEmpty ? 'unknown' : deviceId;
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(0x7fffffff).toRadixString(16);
    return '$normalizedDeviceId-$timestamp-$randomPart';
  }

  static String buildMessageKey({
    String? messageId,
    required String payload,
  }) {
    final id = messageId?.trim();
    if (id != null && id.isNotEmpty) {
      return 'msg:$id';
    }
    return 'hash:${_fnv1a32(payload)}';
  }

  static String _fnv1a32(String value) {
    const int fnvPrime = 0x01000193;
    const int offsetBasis = 0x811c9dc5;
    var hash = offsetBasis;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * fnvPrime) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}

class RecentMessageCache {
  RecentMessageCache({required this.ttl});

  final Duration ttl;
  final Map<String, DateTime> _seen = <String, DateTime>{};

  bool isDuplicate(String key) {
    final now = DateTime.now();
    prune(now);
    final seenAt = _seen[key];
    if (seenAt == null) {
      return false;
    }
    return now.difference(seenAt) <= ttl;
  }

  void remember(String key) {
    _seen[key] = DateTime.now();
  }

  void prune([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final stale = _seen.entries
        .where((entry) => reference.difference(entry.value) > ttl)
        .map((entry) => entry.key)
        .toList();
    for (final key in stale) {
      _seen.remove(key);
    }
  }

  void clear() {
    _seen.clear();
  }
}
