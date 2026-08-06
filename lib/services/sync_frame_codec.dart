import 'dart:convert';
import 'dart:typed_data';

import '../models/sync_data.dart';
import 'sync_message_utils.dart';

/// Isolate-friendly sync frame building/parsing.
///
/// Sync payloads can be many megabytes; encoding or decoding them on the UI
/// isolate freezes the app whenever peers exchange data. Every entry point
/// here is a static single-argument function so callers can run it via
/// `compute(...)`, and all inputs/outputs are isolate-sendable.
class SyncFrameCodec {
  SyncFrameCodec._();

  static const int _newline = 10;

  /// Builds the wire frames for one outbound sync message: either a single
  /// `sync_data` line or a series of `sync_chunk` lines. Frames are returned
  /// as UTF-8 bytes with the trailing newline already appended so the socket
  /// write on the UI isolate is a plain buffer copy.
  static OutboundFrameResult buildOutboundFrames(OutboundFrameRequest req) {
    final result = buildOutboundStringFrames(req);
    if (result.error != null) {
      return OutboundFrameResult.error(result.error);
    }
    return OutboundFrameResult(
      frames: result.frames
          .map((frame) => _frameLine(utf8.encode(frame)))
          .toList(),
      chunkCount: result.chunkCount,
      payloadBytes: result.payloadBytes,
    );
  }

  /// Same as [buildOutboundFrames] but returns frames as strings (no trailing
  /// newline) for transports that send string messages (Wi-Fi Direct method
  /// channel).
  static OutboundStringFramesResult buildOutboundStringFrames(
    OutboundFrameRequest req,
  ) {
    final payload = jsonEncode({
      'type': 'sync_data',
      'messageId': req.messageId,
      'protocolVersion': 2,
      'fromId': req.data.deviceId,
      'fromName': req.fromName,
      'sentAt': req.sentAtIso,
      'data': req.data.toJson(),
    });
    final payloadBytes = utf8.encode(payload);

    if (payloadBytes.length > req.maxTotalBytes) {
      return const OutboundStringFramesResult.error(
        'Sync payload exceeded 20 MB and was not sent.',
      );
    }

    if (payloadBytes.length <= req.maxFrameBytes) {
      return OutboundStringFramesResult(
        frames: <String>[payload],
        chunkCount: 1,
        payloadBytes: payloadBytes.length,
      );
    }

    final frames = <String>[];
    final chunkCount =
        (payloadBytes.length + req.chunkRawBytes - 1) ~/ req.chunkRawBytes;
    for (var index = 0; index < chunkCount; index++) {
      final start = index * req.chunkRawBytes;
      final end = (start + req.chunkRawBytes < payloadBytes.length)
          ? start + req.chunkRawBytes
          : payloadBytes.length;
      final frame = jsonEncode({
        'type': SyncMessageUtils.syncChunkType,
        'messageId': req.messageId,
        'protocolVersion': 3,
        'fromId': req.data.deviceId,
        'fromName': req.fromName,
        'chunkIndex': index,
        'chunkCount': chunkCount,
        'encoding': SyncMessageUtils.syncChunkEncoding,
        'payload': base64Encode(payloadBytes.sublist(start, end)),
        'sentAt': req.sentAtIso,
      });
      if (utf8.encode(frame).length > req.maxFrameBytes) {
        return const OutboundStringFramesResult.error(
          'Sync payload chunks exceeded transport size limits.',
        );
      }
      frames.add(frame);
    }

    return OutboundStringFramesResult(
      frames: frames,
      chunkCount: chunkCount,
      payloadBytes: payloadBytes.length,
    );
  }

  /// Parses one inbound line/payload into either a chunk envelope (still
  /// assembled on the caller's side) or a fully constructed [SyncData].
  /// Accepts the same shapes the LAN service historically accepted: a
  /// `sync_chunk` envelope, a `sync_data` envelope whose `data` is a map or a
  /// JSON string, and a bare legacy [SyncData] object.
  static InboundParseResult parseInbound(String payload) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      } else if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      json = null;
    }
    if (json == null) {
      return const InboundParseResult.unrecognized();
    }

    if (json['type'] == SyncMessageUtils.syncChunkType) {
      final messageId = json['messageId']?.toString().trim();
      return InboundParseResult(
        chunkEnvelope: json,
        messageId: messageId,
        fromId: json['fromId']?.toString(),
        fromName: json['fromName']?.toString(),
        messageKey: (messageId == null || messageId.isEmpty)
            ? null
            : SyncMessageUtils.buildMessageKey(
                messageId: messageId,
                payload: messageId,
              ),
      );
    }

    if (json['type'] == 'sync_data') {
      final data = json['data'];
      SyncData? syncData;
      try {
        if (data is Map) {
          syncData = SyncData.fromJson(Map<String, dynamic>.from(data));
        } else if (data is String) {
          final inner = jsonDecode(data);
          if (inner is Map) {
            syncData = SyncData.fromJson(Map<String, dynamic>.from(inner));
          }
        }
      } catch (_) {
        syncData = null;
      }
      if (syncData == null) {
        return const InboundParseResult.unrecognized();
      }
      return InboundParseResult(
        syncData: syncData,
        messageId: json['messageId']?.toString(),
        fromId: json['fromId']?.toString(),
        fromName: json['fromName']?.toString(),
        messageKey: SyncMessageUtils.buildMessageKey(
          messageId: json['messageId']?.toString(),
          payload: payload,
        ),
      );
    }

    // Legacy bare SyncData payload (no envelope).
    try {
      final syncData = SyncData.fromJson(json);
      return InboundParseResult(
        syncData: syncData,
        fromId: syncData.deviceId,
        messageKey: SyncMessageUtils.buildMessageKey(
          messageId: json['messageId']?.toString(),
          payload: payload,
        ),
      );
    } catch (_) {
      return const InboundParseResult.unrecognized();
    }
  }

  static Uint8List _frameLine(List<int> jsonBytes) {
    final line = Uint8List(jsonBytes.length + 1);
    line.setAll(0, jsonBytes);
    line[jsonBytes.length] = _newline;
    return line;
  }
}

class OutboundFrameRequest {
  const OutboundFrameRequest({
    required this.data,
    required this.messageId,
    required this.fromName,
    required this.sentAtIso,
    required this.maxFrameBytes,
    required this.maxTotalBytes,
    required this.chunkRawBytes,
  });

  final SyncData data;
  final String messageId;
  final String fromName;
  final String sentAtIso;
  final int maxFrameBytes;
  final int maxTotalBytes;
  final int chunkRawBytes;
}

class OutboundFrameResult {
  const OutboundFrameResult({
    required this.frames,
    required this.chunkCount,
    required this.payloadBytes,
  }) : error = null;

  const OutboundFrameResult.error(this.error)
      : frames = const <Uint8List>[],
        chunkCount = 0,
        payloadBytes = 0;

  final List<Uint8List> frames;
  final int chunkCount;
  final int payloadBytes;
  final String? error;
}

class OutboundStringFramesResult {
  const OutboundStringFramesResult({
    required this.frames,
    required this.chunkCount,
    required this.payloadBytes,
  }) : error = null;

  const OutboundStringFramesResult.error(this.error)
      : frames = const <String>[],
        chunkCount = 0,
        payloadBytes = 0;

  final List<String> frames;
  final int chunkCount;
  final int payloadBytes;
  final String? error;
}

class InboundParseResult {
  const InboundParseResult({
    this.chunkEnvelope,
    this.syncData,
    this.messageId,
    this.fromId,
    this.fromName,
    this.messageKey,
  });

  const InboundParseResult.unrecognized()
      : chunkEnvelope = null,
        syncData = null,
        messageId = null,
        fromId = null,
        fromName = null,
        messageKey = null;

  final Map<String, dynamic>? chunkEnvelope;
  final SyncData? syncData;
  final String? messageId;
  final String? fromId;
  final String? fromName;
  final String? messageKey;

  bool get isRecognized => chunkEnvelope != null || syncData != null;
}
