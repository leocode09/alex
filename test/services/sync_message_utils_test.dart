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
}
