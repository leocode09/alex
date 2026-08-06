import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alex/models/product.dart';
import 'package:alex/models/sync_data.dart';
import 'package:alex/repositories/product_repository.dart';
import 'package:alex/services/lan_sync_service.dart';

/// End-to-end LAN sync latency probe: talks to the real [LanSyncService]
/// over a real loopback TCP socket and measures how long each direction of
/// the pipeline takes. Exists to catch regressions where sync still "works"
/// but stops being realtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LAN sync round-trip stays realtime', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final service = LanSyncService();
    service.configureApprovedShopForTesting('test-shop');
    await service.initialize();
    await service.start();
    expect(
      service.isRunning,
      isTrue,
      reason: 'LAN service failed to start: '
          'status=${service.status} error=${service.lastError}',
    );

    // ---- fake peer over a real socket ----
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      LanSyncService.tcpPort,
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    final received = <String>[];
    final subscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(received.add);

    void sendLine(Map<String, dynamic> message) {
      socket.add(utf8.encode(jsonEncode(message)));
      socket.add(const [10]);
    }

    sendLine({
      'type': 'lan_hello',
      'id': 'fake_peer',
      'name': 'FakePeer',
      'protocolVersion': LanSyncService.protocolVersion,
      'shopId': 'test-shop',
    });

    await _waitFor(
      () async => service.connectedPeerIds.contains('fake_peer'),
      timeout: const Duration(seconds: 10),
      label: 'handshake registers peer',
    );

    // ---- inbound: peer pushes one product; measure until it is queryable ----
    final incoming = SyncData(
      products: [
        Product(id: 'inbound-1', name: 'Inbound Product', price: 1000, stock: 5),
      ],
      categories: const [],
      customers: const [],
      employees: const [],
      expenses: const [],
      sales: const [],
      stores: const [],
      deviceId: 'fake_peer',
    );
    final inboundWatch = Stopwatch()..start();
    sendLine({
      'type': 'sync_data',
      'messageId': 'fake_peer-inbound-1',
      'protocolVersion': 2,
      'fromId': 'fake_peer',
      'fromName': 'FakePeer',
      'sentAt': DateTime.now().toIso8601String(),
      'data': incoming.toJson(),
    });
    await _waitFor(
      () async {
        final products = await ProductRepository().getAllProducts();
        return products.any((p) => p.id == 'inbound-1');
      },
      timeout: const Duration(seconds: 15),
      label: 'inbound product imported',
    );
    inboundWatch.stop();

    // ---- outbound: local mutation; measure until the peer sees the frame ----
    await ProductRepository().insertProduct(
      Product(id: 'outbound-1', name: 'Outbound Product', price: 500, stock: 3),
    );
    final outboundWatch = Stopwatch()..start();
    unawaited(service.triggerSync(reason: 'test_mutation'));
    await _waitFor(
      () async => received.any(
        (line) => line.contains('"sync_data"') && line.contains('outbound-1'),
      ),
      timeout: const Duration(seconds: 15),
      label: 'outbound frame reaches peer',
    );
    outboundWatch.stop();

    // ---- outbound again immediately: exposes the min-interval floor ----
    await ProductRepository().insertProduct(
      Product(id: 'outbound-2', name: 'Second Product', price: 700, stock: 2),
    );
    final secondWatch = Stopwatch()..start();
    unawaited(service.triggerSync(reason: 'test_mutation_2'));
    await _waitFor(
      () async => received.any((line) => line.contains('outbound-2')),
      timeout: const Duration(seconds: 15),
      label: 'second outbound frame reaches peer',
    );
    secondWatch.stop();

    // ignore: avoid_print
    print('LAN latency — inbound import: ${inboundWatch.elapsedMilliseconds}ms, '
        'outbound first: ${outboundWatch.elapsedMilliseconds}ms, '
        'outbound back-to-back: ${secondWatch.elapsedMilliseconds}ms');

    // Realtime expectations: inbound should be near-instant; first outbound is
    // debounce (800ms) + encode; back-to-back outbound may wait the 3s
    // min-sync-interval but must not exceed it by much.
    expect(inboundWatch.elapsedMilliseconds, lessThan(5000),
        reason: 'inbound import too slow');
    expect(outboundWatch.elapsedMilliseconds, lessThan(5000),
        reason: 'first outbound too slow');
    expect(secondWatch.elapsedMilliseconds, lessThan(8000),
        reason: 'back-to-back outbound too slow');

    await subscription.cancel();
    socket.destroy();
    await service.stop();
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Same probe with a realistic multi-megabyte dataset: exercises the chunked
  // transport (split → N frames → reassembly → isolate parse → merge import)
  // and proves follow-up mutations ship as small deltas instead of another
  // full snapshot. Lives in this file so the two socket tests never run
  // concurrently (they share the fixed LAN ports).
  test('LAN sync stays realtime with a large chunked payload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final service = LanSyncService();
    service.configureApprovedShopForTesting('test-shop');
    await service.initialize();
    await service.start();
    expect(service.isRunning, isTrue,
        reason: 'status=${service.status} error=${service.lastError}');

    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      LanSyncService.tcpPort,
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    final received = <String>[];
    final subscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(received.add);

    void sendLine(Map<String, dynamic> message) {
      socket.add(utf8.encode(jsonEncode(message)));
      socket.add(const [10]);
    }

    sendLine({
      'type': 'lan_hello',
      'id': 'fake_peer',
      'name': 'FakePeer',
      'protocolVersion': LanSyncService.protocolVersion,
      'shopId': 'test-shop',
    });
    await _waitFor(
      () async => service.connectedPeerIds.contains('fake_peer'),
      timeout: const Duration(seconds: 10),
      label: 'handshake',
    );

    // ~6000 products with descriptions — a few MB of JSON, forcing chunking.
    // Backdated so a later delta export can prove it excludes them.
    final bulkTimestamp = DateTime.now().subtract(const Duration(hours: 1));
    final bigCatalog = List<Product>.generate(6000, (i) {
      return Product(
        id: 'bulk-$i',
        name: 'Bulk product $i with a reasonably long display name',
        price: 1000 + i.toDouble(),
        costPrice: 800 + i.toDouble(),
        stock: 10 + (i % 50),
        barcode: 'BC-00000$i',
        description:
            'Synthetic catalog entry $i used to inflate the sync payload to a '
            'realistic multi-megabyte size so the chunk pipeline is exercised.',
        category: 'Category ${i % 25}',
        createdAt: bulkTimestamp,
        updatedAt: bulkTimestamp,
      );
    });

    final incoming = SyncData(
      products: bigCatalog,
      categories: const [],
      customers: const [],
      employees: const [],
      expenses: const [],
      sales: const [],
      stores: const [],
      deviceId: 'fake_peer',
    );

    final payload = jsonEncode({
      'type': 'sync_data',
      'messageId': 'fake_peer-big-1',
      'protocolVersion': 2,
      'fromId': 'fake_peer',
      'fromName': 'FakePeer',
      'sentAt': DateTime.now().toIso8601String(),
      'data': incoming.toJson(),
    });
    final payloadBytes = utf8.encode(payload);
    // ignore: avoid_print
    print('scale test payload: '
        '${(payloadBytes.length / (1024 * 1024)).toStringAsFixed(2)} MB');

    // Send it the way a real peer does: as base64 sync_chunk frames.
    const chunkRawBytes = 192 * 1024;
    final chunkCount =
        (payloadBytes.length + chunkRawBytes - 1) ~/ chunkRawBytes;
    final inboundWatch = Stopwatch()..start();
    for (var i = 0; i < chunkCount; i++) {
      final start = i * chunkRawBytes;
      final end = (start + chunkRawBytes < payloadBytes.length)
          ? start + chunkRawBytes
          : payloadBytes.length;
      sendLine({
        'type': 'sync_chunk',
        'messageId': 'fake_peer-big-1',
        'protocolVersion': 3,
        'fromId': 'fake_peer',
        'fromName': 'FakePeer',
        'chunkIndex': i,
        'chunkCount': chunkCount,
        'encoding': 'base64_utf8',
        'payload': base64Encode(payloadBytes.sublist(start, end)),
        'sentAt': DateTime.now().toIso8601String(),
      });
    }

    await _waitFor(
      () async {
        final products = await ProductRepository().getAllProducts();
        return products.length >= 6000;
      },
      timeout: const Duration(seconds: 60),
      label: 'large inbound payload imported',
    );
    inboundWatch.stop();

    // Outbound at scale: the snapshot is chunked, so reassemble frames the
    // way a real peer does instead of grepping raw lines.
    bool peerSawOutboundProduct() {
      final chunksByMessage = <String, Map<int, String>>{};
      final countsByMessage = <String, int>{};
      for (final line in received) {
        Map<String, dynamic>? frame;
        try {
          frame = jsonDecode(line) as Map<String, dynamic>?;
        } catch (_) {
          continue;
        }
        if (frame == null) continue;
        if (frame['type'] == 'sync_data') {
          final data = jsonEncode(frame['data']);
          if (data.contains('outbound-big')) return true;
        }
        if (frame['type'] == 'sync_chunk') {
          final id = frame['messageId']?.toString() ?? '';
          chunksByMessage.putIfAbsent(id, () => <int, String>{})[
                  (frame['chunkIndex'] as num).toInt()] =
              frame['payload'] as String;
          countsByMessage[id] = (frame['chunkCount'] as num).toInt();
        }
      }
      for (final entry in chunksByMessage.entries) {
        final expected = countsByMessage[entry.key] ?? -1;
        if (entry.value.length != expected) continue;
        final bytes = <int>[];
        for (var i = 0; i < expected; i++) {
          bytes.addAll(base64Decode(entry.value[i]!));
        }
        if (utf8.decode(bytes).contains('outbound-big')) return true;
      }
      return false;
    }

    await ProductRepository().insertProduct(
      Product(
          id: 'outbound-big', name: 'Post-import product', price: 1, stock: 1),
    );
    final outboundWatch = Stopwatch()..start();
    unawaited(service.triggerSync(reason: 'test_mutation'));
    await _waitFor(
      () async => peerSawOutboundProduct(),
      timeout: const Duration(seconds: 60),
      label: 'outbound snapshot reaches peer',
    );
    outboundWatch.stop();

    // ignore: avoid_print
    print('LAN scale latency — inbound (chunked, $chunkCount chunks): '
        '${inboundWatch.elapsedMilliseconds}ms, outbound snapshot: '
        '${outboundWatch.elapsedMilliseconds}ms');

    expect(inboundWatch.elapsedMilliseconds, lessThan(20000),
        reason: 'chunked inbound too slow');
    expect(outboundWatch.elapsedMilliseconds, lessThan(20000),
        reason: 'outbound at scale too slow');

    // ---- delta path: the next mutation must go out as a small single
    // sync_data frame (not another multi-chunk snapshot), and quickly. ----
    final framesBeforeDelta = received.length;
    await ProductRepository().insertProduct(
      Product(id: 'delta-product', name: 'Delta product', price: 2, stock: 2),
    );
    final deltaWatch = Stopwatch()..start();
    unawaited(service.triggerSync(reason: 'test_delta'));
    String? deltaFrame;
    await _waitFor(
      () async {
        for (final line in received.skip(framesBeforeDelta)) {
          if (line.contains('"sync_data"') && line.contains('delta-product')) {
            deltaFrame = line;
            return true;
          }
        }
        return false;
      },
      timeout: const Duration(seconds: 30),
      label: 'delta frame reaches peer',
    );
    deltaWatch.stop();

    final newChunkFrames = received
        .skip(framesBeforeDelta)
        .where((line) => line.contains('"sync_chunk"'))
        .length;
    // ignore: avoid_print
    print('delta latency: ${deltaWatch.elapsedMilliseconds}ms, '
        'frame size: ${deltaFrame!.length} chars, '
        'chunk frames after delta trigger: $newChunkFrames');

    expect(newChunkFrames, 0,
        reason: 'delta should be a single small frame, not a chunked snapshot');
    expect(deltaFrame!.contains('bulk-1000'), isFalse,
        reason: 'delta must not carry the unchanged bulk catalog');
    expect(deltaFrame!.length, lessThan(64 * 1024),
        reason: 'delta frame unexpectedly large');
    // 3s min-sync-interval + debounce dominate this figure by design.
    expect(deltaWatch.elapsedMilliseconds, lessThan(8000),
        reason: 'delta too slow');

    await subscription.cancel();
    socket.destroy();
    await service.stop();
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('LAN hello rejects peers from another shop', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final service = LanSyncService();
    service.configureApprovedShopForTesting('shop-alpha');
    await service.initialize();
    await service.start();
    expect(service.isRunning, isTrue,
        reason: 'status=${service.status} error=${service.lastError}');

    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      LanSyncService.tcpPort,
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    final received = <String>[];
    final subscription = socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(received.add);

    void sendLine(Map<String, dynamic> message) {
      socket.add(utf8.encode(jsonEncode(message)));
      socket.add(const [10]);
    }

    sendLine({
      'type': 'lan_hello',
      'id': 'foreign_peer',
      'name': 'ForeignPeer',
      'protocolVersion': LanSyncService.protocolVersion,
      'shopId': 'shop-other',
    });

    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(service.connectedPeerIds.contains('foreign_peer'), isFalse);
    expect(
      service.logs.any((line) => line.contains('outside this approved shop')),
      isTrue,
    );

    // Same socket may already be closed by the reject path; open a fresh one.
    await subscription.cancel();
    socket.destroy();

    final okSocket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      LanSyncService.tcpPort,
    );
    okSocket.setOption(SocketOption.tcpNoDelay, true);
    final okSub = okSocket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((_) {});

    okSocket.add(utf8.encode(jsonEncode({
      'type': 'lan_hello',
      'id': 'same_shop_peer',
      'name': 'SameShopPeer',
      'protocolVersion': LanSyncService.protocolVersion,
      'shopId': 'shop-alpha',
    })));
    okSocket.add(const [10]);

    await _waitFor(
      () async => service.connectedPeerIds.contains('same_shop_peer'),
      timeout: const Duration(seconds: 10),
      label: 'same-shop peer accepted',
    );

    await okSub.cancel();
    okSocket.destroy();
    await service.stop();
  }, timeout: const Timeout(Duration(minutes: 1)));
}

Future<void> _waitFor(
  Future<bool> Function() predicate, {
  required Duration timeout,
  required String label,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out after ${timeout.inSeconds}s waiting for: $label');
}
