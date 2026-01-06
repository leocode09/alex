import 'dart:convert';
import 'dart:math';

/// Model for a chunk of sync data
class SyncChunk {
  final int chunkIndex;      // Current chunk number (0-based)
  final int totalChunks;     // Total number of chunks
  final String sessionId;    // Unique ID for this sync session
  final String data;         // The actual data chunk
  final String checksum;     // MD5 checksum of complete data
  final int totalDataSize;   // Size of complete data before chunking

  SyncChunk({
    required this.chunkIndex,
    required this.totalChunks,
    required this.sessionId,
    required this.data,
    required this.checksum,
    required this.totalDataSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'i': chunkIndex,        // Short keys to save space
      't': totalChunks,
      's': sessionId,
      'd': data,
      'c': checksum,
      'z': totalDataSize,
    };
  }

  factory SyncChunk.fromJson(Map<String, dynamic> json) {
    return SyncChunk(
      chunkIndex: json['i'] as int,
      totalChunks: json['t'] as int,
      sessionId: json['s'] as String,
      data: json['d'] as String,
      checksum: json['c'] as String,
      totalDataSize: json['z'] as int,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory SyncChunk.fromJsonString(String jsonString) {
    return SyncChunk.fromJson(jsonDecode(jsonString));
  }
}

/// Service to handle chunking of large sync data
class ChunkingService {
  // Maximum size per QR code chunk (bytes) - conservative limit
  static const int maxChunkSize = 2500;

  /// Generate a unique session ID for this sync
  String generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(9999);
    return '${timestamp}_$random';
  }

  /// Calculate simple checksum for data validation
  String calculateChecksum(String data) {
    // Simple hash - sum of character codes
    int sum = 0;
    for (int i = 0; i < data.length; i++) {
      sum += data.codeUnitAt(i);
    }
    return sum.toRadixString(36).padLeft(8, '0');
  }

  /// Check if data needs to be chunked
  bool needsChunking(String data) {
    return data.length > maxChunkSize;
  }

  /// Split data into chunks
  List<SyncChunk> chunkData(String data) {
    if (!needsChunking(data)) {
      // Single chunk
      final sessionId = generateSessionId();
      final checksum = calculateChecksum(data);
      return [
        SyncChunk(
          chunkIndex: 0,
          totalChunks: 1,
          sessionId: sessionId,
          data: data,
          checksum: checksum,
          totalDataSize: data.length,
        ),
      ];
    }

    final sessionId = generateSessionId();
    final checksum = calculateChecksum(data);
    final chunks = <SyncChunk>[];
    
    // Calculate optimal chunk size (leaving room for metadata)
    final metadataSize = 150; // Estimated size of chunk metadata
    final effectiveChunkSize = maxChunkSize - metadataSize;
    
    int totalChunks = (data.length / effectiveChunkSize).ceil();
    
    for (int i = 0; i < totalChunks; i++) {
      final start = i * effectiveChunkSize;
      final end = min(start + effectiveChunkSize, data.length);
      final chunkData = data.substring(start, end);
      
      chunks.add(SyncChunk(
        chunkIndex: i,
        totalChunks: totalChunks,
        sessionId: sessionId,
        data: chunkData,
        checksum: checksum,
        totalDataSize: data.length,
      ));
    }
    
    return chunks;
  }

  /// Validate that all chunks are present and in order
  bool validateChunks(List<SyncChunk> chunks) {
    if (chunks.isEmpty) return false;
    
    final sessionId = chunks.first.sessionId;
    final totalChunks = chunks.first.totalChunks;
    final checksum = chunks.first.checksum;
    
    // Check we have the right number of chunks
    if (chunks.length != totalChunks) return false;
    
    // Check all chunks have same session ID and checksum
    for (var chunk in chunks) {
      if (chunk.sessionId != sessionId) return false;
      if (chunk.totalChunks != totalChunks) return false;
      if (chunk.checksum != checksum) return false;
    }
    
    // Check all chunk indices are present (0 to totalChunks-1)
    final indices = chunks.map((c) => c.chunkIndex).toSet();
    for (int i = 0; i < totalChunks; i++) {
      if (!indices.contains(i)) return false;
    }
    
    return true;
  }

  /// Merge chunks back into original data
  String mergeChunks(List<SyncChunk> chunks) {
    if (!validateChunks(chunks)) {
      throw Exception('Invalid chunks: cannot merge');
    }
    
    // Sort chunks by index
    final sortedChunks = List<SyncChunk>.from(chunks)
      ..sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
    
    // Concatenate data
    final buffer = StringBuffer();
    for (var chunk in sortedChunks) {
      buffer.write(chunk.data);
    }
    
    final mergedData = buffer.toString();
    
    // Validate checksum
    final expectedChecksum = chunks.first.checksum;
    final actualChecksum = calculateChecksum(mergedData);
    
    if (expectedChecksum != actualChecksum) {
      throw Exception('Checksum mismatch: data may be corrupted');
    }
    
    return mergedData;
  }

  /// Get progress percentage
  double getProgress(List<SyncChunk> receivedChunks, int totalChunks) {
    if (totalChunks == 0) return 0.0;
    return (receivedChunks.length / totalChunks) * 100;
  }

  /// Get missing chunk indices
  List<int> getMissingChunks(List<SyncChunk> receivedChunks, int totalChunks) {
    final receivedIndices = receivedChunks.map((c) => c.chunkIndex).toSet();
    final missing = <int>[];
    
    for (int i = 0; i < totalChunks; i++) {
      if (!receivedIndices.contains(i)) {
        missing.add(i);
      }
    }
    
    return missing;
  }
}
