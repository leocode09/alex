import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:alex/services/sync_message_utils.dart';

void main() {
  group('SyncMessageUtils', () {
    test('buildMessageKey prefers message id when present', () {
      final key = SyncMessageUtils.buildMessageKey(
        messageId: 'abc-123',
        payload: '{"type":"sync_data"}',
      );
      expect(key, 'msg:abc-123');
    });

    test('buildMessageKey falls back to deterministic hash', () {
      final keyA = SyncMessageUtils.buildMessageKey(
        messageId: null,
        payload: '{"a":1}',
      );
      final keyB = SyncMessageUtils.buildMessageKey(
        messageId: null,
        payload: '{"a":1}',
      );
      expect(keyA, keyB);
      expect(keyA.startsWith('hash:'), isTrue);
    });

    test('nextMessageId includes device id prefix', () {
      final messageId = SyncMessageUtils.nextMessageId('device-1');
      expect(messageId.startsWith('device-1-'), isTrue);
    });
  });

  group('RecentMessageCache', () {
    test('detects duplicates while message is still fresh', () {
      final cache = RecentMessageCache(ttl: const Duration(minutes: 1));
      cache.remember('key-1');
      expect(cache.isDuplicate('key-1'), isTrue);
      expect(cache.isDuplicate('key-2'), isFalse);
    });
  });

  group('Chunked sync payloads', () {
    test('splits and reassembles large payloads without data loss', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 160000; i++) {
        buffer.write('row_$i|');
      }
      final payload = buffer.toString();
      expect(
        SyncMessageUtils.utf8Size(payload),
        greaterThan(SyncMessageUtils.maxFramePayloadBytes),
      );

      final chunks = SyncMessageUtils.splitPayloadToBase64Chunks(payload);
      expect(chunks.length, greaterThan(1));

      final assembler = SyncChunkAssembler();
      SyncChunkAssemblyResult result = SyncChunkAssemblyResult.pending();
      for (var i = chunks.length - 1; i >= 0; i--) {
        result = assembler.addEnvelope({
          'type': SyncMessageUtils.syncChunkType,
          'messageId': 'msg-1',
          'chunkIndex': i,
          'chunkCount': chunks.length,
          'encoding': SyncMessageUtils.syncChunkEncoding,
          'payload': chunks[i],
        });
      }

      expect(result.isComplete, isTrue);
      expect(result.payload, payload);
    });

    test('validates chunk envelopes', () {
      final valid = {
        'type': SyncMessageUtils.syncChunkType,
        'messageId': 'msg-2',
        'chunkIndex': 0,
        'chunkCount': 2,
        'encoding': SyncMessageUtils.syncChunkEncoding,
        'payload': base64Encode(utf8.encode('abc')),
      };
      expect(SyncMessageUtils.isValidChunkEnvelope(valid), isTrue);

      final missingMessageId = Map<String, dynamic>.from(valid)
        ..remove('messageId');
      expect(SyncMessageUtils.isValidChunkEnvelope(missingMessageId), isFalse);

      final outOfBoundsIndex = Map<String, dynamic>.from(valid)
        ..['chunkIndex'] = 3;
      expect(SyncMessageUtils.isValidChunkEnvelope(outOfBoundsIndex), isFalse);

      final wrongEncoding = Map<String, dynamic>.from(valid)
        ..['encoding'] = 'gzip';
      expect(SyncMessageUtils.isValidChunkEnvelope(wrongEncoding), isFalse);
    });

    test('rejects malformed base64 chunk payload', () {
      final assembler = SyncChunkAssembler();
      final result = assembler.addEnvelope({
        'type': SyncMessageUtils.syncChunkType,
        'messageId': 'msg-3',
        'chunkIndex': 0,
        'chunkCount': 1,
        'encoding': SyncMessageUtils.syncChunkEncoding,
        'payload': '%not_base64%',
      });

      expect(result.hasError, isTrue);
      expect(result.error, contains('Invalid base64'));
    });

    test('enforces 20 MB payload cap before chunking', () {
      final bytes =
          Uint8List(SyncMessageUtils.maxAssembledPayloadBytes + 1);
      final oversizedPayload = utf8.decode(bytes);

      expect(
        () => SyncMessageUtils.splitPayloadToBase64Chunks(oversizedPayload),
        throwsA(isA<StateError>()),
      );
    });
  });
}
