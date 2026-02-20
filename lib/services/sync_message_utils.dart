import 'dart:convert';
import 'dart:math';

class SyncMessageUtils {
  static final Random _random = Random.secure();
  static const int maxFramePayloadBytes = 1024 * 1024;
  static const int chunkRawBytes = 192 * 1024;
  static const int maxAssembledPayloadBytes = 20 * 1024 * 1024;
  static const Duration chunkAssemblyTtl = Duration(minutes: 2);
  static const String syncChunkType = 'sync_chunk';
  static const String syncChunkEncoding = 'base64_utf8';

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

  static List<String> splitPayloadToBase64Chunks(
    String payload, {
    int chunkRawSize = chunkRawBytes,
  }) {
    if (chunkRawSize <= 0) {
      throw ArgumentError.value(chunkRawSize, 'chunkRawSize');
    }
    final bytes = utf8.encode(payload);
    if (bytes.isEmpty) {
      return const <String>[];
    }
    if (bytes.length > maxAssembledPayloadBytes) {
      throw StateError(
        'Payload exceeded ${_formatMaxMb(maxAssembledPayloadBytes)} MB limit.',
      );
    }

    final chunks = <String>[];
    for (var index = 0; index < bytes.length; index += chunkRawSize) {
      final end = (index + chunkRawSize < bytes.length)
          ? index + chunkRawSize
          : bytes.length;
      chunks.add(base64Encode(bytes.sublist(index, end)));
    }
    return chunks;
  }

  static bool isValidChunkEnvelope(Map<String, dynamic> json) {
    if (json['type'] != syncChunkType) {
      return false;
    }

    final messageId = json['messageId'];
    final chunkIndex = _toInt(json['chunkIndex']);
    final chunkCount = _toInt(json['chunkCount']);
    final payload = json['payload'];
    final encoding = json['encoding']?.toString();

    if (messageId is! String || messageId.trim().isEmpty) {
      return false;
    }
    if (chunkIndex == null || chunkCount == null) {
      return false;
    }
    if (chunkCount <= 0 || chunkIndex < 0 || chunkIndex >= chunkCount) {
      return false;
    }
    if (payload is! String || payload.isEmpty) {
      return false;
    }
    if (encoding != syncChunkEncoding) {
      return false;
    }
    return true;
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String _formatMaxMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    if (mb == mb.roundToDouble()) {
      return mb.toInt().toString();
    }
    return mb.toStringAsFixed(1);
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

class SyncChunkAssemblyResult {
  const SyncChunkAssemblyResult._({
    required this.isComplete,
    this.payload,
    this.error,
  });

  final bool isComplete;
  final String? payload;
  final String? error;

  bool get hasError => error != null;

  static SyncChunkAssemblyResult pending() =>
      const SyncChunkAssemblyResult._(isComplete: false);

  static SyncChunkAssemblyResult complete(String payload) =>
      SyncChunkAssemblyResult._(
        isComplete: true,
        payload: payload,
      );

  static SyncChunkAssemblyResult failed(String error) =>
      SyncChunkAssemblyResult._(
        isComplete: false,
        error: error,
      );
}

class SyncChunkAssembler {
  SyncChunkAssembler({
    this.maxPayloadBytes = SyncMessageUtils.maxAssembledPayloadBytes,
    this.ttl = SyncMessageUtils.chunkAssemblyTtl,
  });

  final int maxPayloadBytes;
  final Duration ttl;
  final Map<String, _ChunkBuffer> _buffers = <String, _ChunkBuffer>{};

  SyncChunkAssemblyResult addEnvelope(Map<String, dynamic> envelope) {
    if (!SyncMessageUtils.isValidChunkEnvelope(envelope)) {
      return SyncChunkAssemblyResult.failed('Invalid sync chunk envelope.');
    }

    final messageId = envelope['messageId'].toString().trim();
    final chunkCount = (envelope['chunkCount'] as num).toInt();
    final chunkIndex = (envelope['chunkIndex'] as num).toInt();
    final chunkData = envelope['payload'].toString();

    final buffer = _buffers.putIfAbsent(
      messageId,
      () => _ChunkBuffer(expectedChunks: chunkCount),
    );

    if (buffer.expectedChunks != chunkCount) {
      _buffers.remove(messageId);
      return SyncChunkAssemblyResult.failed('Chunk count mismatch.');
    }

    if (buffer.containsIndex(chunkIndex)) {
      return SyncChunkAssemblyResult.pending();
    }

    List<int> decodedBytes;
    try {
      decodedBytes = base64Decode(chunkData);
    } catch (_) {
      _buffers.remove(messageId);
      return SyncChunkAssemblyResult.failed('Invalid base64 chunk payload.');
    }

    final nextSize = buffer.totalBytes + decodedBytes.length;
    if (nextSize > maxPayloadBytes) {
      _buffers.remove(messageId);
      return SyncChunkAssemblyResult.failed(
        'Assembled payload exceeded ${SyncMessageUtils._formatMaxMb(maxPayloadBytes)} MB limit.',
      );
    }

    buffer.addChunk(chunkIndex, decodedBytes);
    if (!buffer.isComplete) {
      return SyncChunkAssemblyResult.pending();
    }

    final assembled = <int>[];
    for (var i = 0; i < buffer.expectedChunks; i++) {
      final chunk = buffer.chunks[i];
      if (chunk == null) {
        _buffers.remove(messageId);
        return SyncChunkAssemblyResult.failed('Missing chunk segment.');
      }
      assembled.addAll(chunk);
    }
    _buffers.remove(messageId);

    try {
      return SyncChunkAssemblyResult.complete(utf8.decode(assembled));
    } catch (_) {
      return SyncChunkAssemblyResult.failed(
          'Chunk payload was not valid UTF-8.');
    }
  }

  void prune([DateTime? now]) {
    final reference = now ?? DateTime.now();
    final staleKeys = _buffers.entries
        .where((entry) => reference.difference(entry.value.lastUpdated) > ttl)
        .map((entry) => entry.key)
        .toList();
    for (final key in staleKeys) {
      _buffers.remove(key);
    }
  }

  void clear() {
    _buffers.clear();
  }

  int get pendingAssemblies => _buffers.length;
}

class _ChunkBuffer {
  _ChunkBuffer({required this.expectedChunks})
      : chunks = <int, List<int>>{},
        lastUpdated = DateTime.now();

  final int expectedChunks;
  final Map<int, List<int>> chunks;
  DateTime lastUpdated;
  int totalBytes = 0;

  bool get isComplete => chunks.length == expectedChunks;

  bool containsIndex(int index) => chunks.containsKey(index);

  void addChunk(int index, List<int> value) {
    chunks[index] = value;
    totalBytes += value.length;
    lastUpdated = DateTime.now();
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
