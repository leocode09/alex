import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/admin_auth_provider.dart';
import '../../../../services/cloud/firestore_paths.dart';
import '../../../design_system/app_theme_extensions.dart';
import '../../../design_system/app_tokens.dart';
import '../../../design_system/widgets/app_panel.dart';
import '../admin_heuristics.dart';

/// Target of an audit list view.
enum AdminAuditScope { shop, device, global }

/// Streams the last ~20 audit entries for a shop, a device, or (when
/// `global`) the whole fleet via a `collectionGroup('auditLog')` query.
class AdminAuditLogList extends ConsumerWidget {
  final AdminAuditScope scope;
  final String? targetId;
  final int limit;

  const AdminAuditLogList({
    super.key,
    required this.scope,
    this.targetId,
    this.limit = 20,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(adminAuthServiceProvider).db;
    if (db == null) {
      return const AppPanel(
        child: Text('Admin is not signed in.'),
      );
    }

    final Query<Map<String, dynamic>> query = _buildQuery(db);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return AppPanel(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const AppPanel(
            child: Text('No admin actions recorded yet.'),
          );
        }
        return Column(
          children: [
            for (final d in docs) _AuditEntry(data: d.data()),
          ],
        );
      },
    );
  }

  Query<Map<String, dynamic>> _buildQuery(FirebaseFirestore db) {
    switch (scope) {
      case AdminAuditScope.shop:
        return db
            .collection(FirestorePaths.shopsCollection)
            .doc(targetId!)
            .collection('auditLog')
            .orderBy('atIso', descending: true)
            .limit(limit);
      case AdminAuditScope.device:
        return db
            .collection(FirestorePaths.devicesCollection)
            .doc(targetId!)
            .collection('auditLog')
            .orderBy('atIso', descending: true)
            .limit(limit);
      case AdminAuditScope.global:
        return db
            .collectionGroup('auditLog')
            .orderBy('atIso', descending: true)
            .limit(limit);
    }
  }
}

class _AuditEntry extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AuditEntry({required this.data});

  @override
  Widget build(BuildContext context) {
    final extras = context.appExtras;
    final action = (data['action'] as String?) ?? 'Change';
    final actor = (data['actorEmail'] as String?) ??
        (data['actorUid'] as String?) ??
        'unknown';
    final atIso = data['atIso'] as String?;
    final at = atIso == null ? null : DateTime.tryParse(atIso);
    final changes = data['changes'];
    final targetType = data['targetType'] as String?;

    final changeLines = <String>[];
    if (changes is Map) {
      changes.forEach((field, delta) {
        if (delta is Map) {
          final oldV = delta['old'];
          final newV = delta['new'];
          changeLines.add(
            '$field: ${_fmt(oldV)} \u2192 ${_fmt(newV)}',
          );
        }
      });
    }

    return AppPanel(
      margin: const EdgeInsets.only(bottom: AppTokens.space1),
      padding: const EdgeInsets.all(AppTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                targetType == 'device' ? Icons.phone_android : Icons.storefront,
                size: 14,
                color: extras.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  action,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                AdminHeuristics.relativeShort(at),
                style: TextStyle(color: extras.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            actor,
            style: TextStyle(
              color: extras.muted,
              fontSize: 12,
              fontFamily: 'IBMPlexMono',
            ),
          ),
          if (changeLines.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final line in changeLines.take(4))
              Text(
                line,
                style: TextStyle(
                  color: extras.muted,
                  fontSize: 12,
                  fontFamily: 'IBMPlexMono',
                ),
              ),
            if (changeLines.length > 4)
              Text(
                '+${changeLines.length - 4} more',
                style: TextStyle(color: extras.muted, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '\u2014';
    if (v is bool) return v ? 'on' : 'off';
    if (v is String) {
      if (v.isEmpty) return '\u2014';
      // Parse ISO date-times compactly.
      final dt = DateTime.tryParse(v);
      if (dt != null) return AdminHeuristics.fmtDate(dt);
      return v.length > 30 ? '${v.substring(0, 30)}\u2026' : v;
    }
    if (v is num) return v.toString();
    return v.toString();
  }
}
