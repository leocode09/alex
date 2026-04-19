import 'package:cloud_firestore/cloud_firestore.dart';

/// Small pure helpers the admin UI uses to derive status / filter /
/// sort values from raw Firestore doc maps. Kept in one place so the
/// badge, filter chip, and alert banner always agree.
class AdminHeuristics {
  const AdminHeuristics._();

  /// A license is "expiring soon" when its expiry is within the next
  /// 7 days (inclusive of today).
  static const Duration expiringSoonWindow = Duration(days: 7);

  /// A device is considered "offline" when we have not heard a
  /// heartbeat for 3 days.
  static const Duration offlineWindow = Duration(days: 3);

  /// Parses a Firestore timestamp-ish value to a DateTime.
  static DateTime? parseTs(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  /// Derived status for a shop, driven by `enabled` + expiry.
  static ShopStatus shopStatus(Map<String, dynamic> data) {
    final enabled = data['enabled'] as bool? ?? true;
    if (!enabled) return ShopStatus.disabled;
    final expiry = parseTs(data['licenseExpiresAt']);
    if (expiry == null) return ShopStatus.active;
    final now = DateTime.now();
    if (expiry.isBefore(now)) return ShopStatus.expired;
    if (expiry.difference(now) <= expiringSoonWindow) {
      return ShopStatus.expiringSoon;
    }
    return ShopStatus.active;
  }

  /// Derived status for a device, driven by `blocked` + expiry +
  /// last-seen timestamp.
  static DeviceStatus deviceStatus(Map<String, dynamic> data) {
    if (data['blocked'] == true) return DeviceStatus.blocked;
    final expiry = parseTs(data['expiresAt']);
    final now = DateTime.now();
    if (expiry != null) {
      if (expiry.isBefore(now)) return DeviceStatus.expired;
      if (expiry.difference(now) <= expiringSoonWindow) {
        return DeviceStatus.expiringSoon;
      }
    }
    final lastSeen = parseTs(data['lastSeenAtIso']) ??
        parseTs(data['lastSeenAt']);
    if (lastSeen == null ||
        now.difference(lastSeen) > offlineWindow) {
      return DeviceStatus.offline;
    }
    return DeviceStatus.online;
  }

  /// Days until the license expires. Negative if already expired.
  static int? daysUntilExpiry(Map<String, dynamic> data,
      {bool deviceScoped = false}) {
    final key = deviceScoped ? 'expiresAt' : 'licenseExpiresAt';
    final expiry = parseTs(data[key]);
    if (expiry == null) return null;
    final now = DateTime.now();
    return expiry.difference(now).inDays;
  }

  /// `null` if no lastSeen field exists, else how many days ago it was.
  static int? daysSinceLastSeen(Map<String, dynamic> data) {
    final lastSeen = parseTs(data['lastSeenAtIso']) ??
        parseTs(data['lastSeenAt']);
    if (lastSeen == null) return null;
    return DateTime.now().difference(lastSeen).inDays;
  }

  /// Compares two semver-ish `appVersion` strings lexicographically
  /// after normalizing each numeric segment. Returns negative if [a] <
  /// [b], zero if equal, positive if [a] > [b].
  static int compareAppVersions(String? a, String? b) {
    if ((a ?? '') == (b ?? '')) return 0;
    if (a == null || a.isEmpty) return -1;
    if (b == null || b.isEmpty) return 1;
    final as = _splitVersion(a);
    final bs = _splitVersion(b);
    final len = as.length > bs.length ? as.length : bs.length;
    for (var i = 0; i < len; i++) {
      final av = i < as.length ? as[i] : 0;
      final bv = i < bs.length ? bs[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }

  static List<int> _splitVersion(String v) {
    final clean = v.split('+').first;
    return clean.split('.').map((s) {
      return int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }).toList();
  }

  /// Finds the "latest known" app version in a list of device docs.
  /// Used to flag everything below as outdated.
  static String? maxAppVersion(Iterable<Map<String, dynamic>> devices) {
    String? max;
    for (final d in devices) {
      final v = d['appVersion'] as String?;
      if (v == null || v.isEmpty) continue;
      if (max == null || compareAppVersions(v, max) > 0) {
        max = v;
      }
    }
    return max;
  }

  /// Formats a short relative time: "2m", "4h", "3d", "2w", "5mo".
  static String relativeShort(DateTime? at) {
    if (at == null) return '—';
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 30).floor()}mo';
  }

  /// Formats YYYY-MM-DD.
  static String fmtDate(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats revenue from cents.
  static String fmtMoneyFromCents(int cents) {
    final value = cents / 100;
    if (value.abs() >= 1000000) {
      return '\$${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '\$${(value / 1000).toStringAsFixed(1)}k';
    }
    return '\$${value.toStringAsFixed(2)}';
  }
}

enum ShopStatus { active, disabled, expiringSoon, expired }

enum DeviceStatus {
  online,
  offline,
  blocked,
  expiringSoon,
  expired,
}
