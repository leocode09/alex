import 'package:cloud_firestore/cloud_firestore.dart';

/// Every gateable feature the super admin can turn on/off.
///
/// String values are used as Firestore map keys under
/// `/shops/{id}.featureFlags` and `/devices/{id}.featureOverrides`.
enum FeatureKey {
  sales('sales'),
  inventoryEdit('inventoryEdit'),
  reports('reports'),
  printing('printing'),
  cloudSync('cloudSync'),
  lanSync('lanSync');

  final String key;
  const FeatureKey(this.key);

  static FeatureKey? fromString(String value) {
    for (final k in FeatureKey.values) {
      if (k.key == value) {
        return k;
      }
    }
    return null;
  }
}

/// Why the entire app (or a particular feature) is blocked. Null means
/// no block.
class LicenseBlock {
  final String title;
  final String message;

  const LicenseBlock({required this.title, required this.message});
}

/// The merged policy the whole app reads to decide whether a feature is
/// available. Shop-level values are the baseline; per-device overrides
/// win when present.
///
/// Construction is tolerant: anything missing from the upstream docs
/// defaults to "allow" so the app keeps working when the admin never
/// configured the shop.
class LicensePolicy {
  /// Overall kill-switch. When false, the app is fully locked.
  final bool enabled;

  /// Expiry date (shop-level). When in the past, the app is locked.
  final DateTime? expiresAt;

  /// Optional per-device override of expiry.
  final DateTime? deviceExpiresAt;

  /// Whether the admin has explicitly blocked this specific device.
  final bool deviceBlocked;

  /// Admin-visible notice shown on the sync / license page.
  final String? notice;

  /// Shop-level feature flags (true = enabled; absent = enabled).
  final Map<FeatureKey, bool> shopFlags;

  /// Per-device overrides (true/false). Wins over [shopFlags] when set.
  final Map<FeatureKey, bool> deviceOverrides;

  /// Feature keys the admin is forcing behind PIN regardless of the
  /// device's local PIN preference.
  final Set<FeatureKey> pinForced;

  /// Optional soft quotas.
  final int? maxProducts;
  final int? maxSalesPerDay;

  const LicensePolicy({
    this.enabled = true,
    this.expiresAt,
    this.deviceExpiresAt,
    this.deviceBlocked = false,
    this.notice,
    this.shopFlags = const {},
    this.deviceOverrides = const {},
    this.pinForced = const {},
    this.maxProducts,
    this.maxSalesPerDay,
  });

  /// The default all-allow policy, used when no shop is joined, Firebase
  /// is unavailable, or docs cannot be read.
  static const LicensePolicy unrestricted = LicensePolicy();

  DateTime? get effectiveExpiresAt {
    if (deviceExpiresAt != null && expiresAt != null) {
      return deviceExpiresAt!.isBefore(expiresAt!)
          ? deviceExpiresAt
          : expiresAt;
    }
    return deviceExpiresAt ?? expiresAt;
  }

  bool get isExpired {
    final at = effectiveExpiresAt;
    if (at == null) {
      return false;
    }
    return DateTime.now().isAfter(at);
  }

  bool isFeatureEnabled(FeatureKey feature) {
    if (!enabled) {
      return false;
    }
    if (isExpired) {
      return false;
    }
    if (deviceBlocked) {
      return false;
    }
    final override = deviceOverrides[feature];
    if (override != null) {
      return override;
    }
    return shopFlags[feature] ?? true;
  }

  bool isPinForced(FeatureKey feature) => pinForced.contains(feature);

  /// Top-level block (overrides every feature). Used by the license
  /// watcher to route the app to `/license-locked`.
  LicenseBlock? blockReason() {
    if (!enabled) {
      return const LicenseBlock(
        title: 'Application disabled',
        message:
            'This installation has been disabled by the administrator. '
            'Contact support to restore access.',
      );
    }
    if (deviceBlocked) {
      return const LicenseBlock(
        title: 'Device blocked',
        message:
            'This device has been blocked by the administrator. Contact '
            'support to request access.',
      );
    }
    if (isExpired) {
      final at = effectiveExpiresAt;
      return LicenseBlock(
        title: 'License expired',
        message: at == null
            ? 'The license for this device has expired.'
            : 'The license for this device expired on ${_fmtDate(at)}. '
                'Contact your administrator to renew it.',
      );
    }
    return null;
  }

  static String _fmtDate(DateTime at) {
    final y = at.year.toString().padLeft(4, '0');
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  LicensePolicy copyWith({
    bool? enabled,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    DateTime? deviceExpiresAt,
    bool clearDeviceExpiresAt = false,
    bool? deviceBlocked,
    String? notice,
    Map<FeatureKey, bool>? shopFlags,
    Map<FeatureKey, bool>? deviceOverrides,
    Set<FeatureKey>? pinForced,
    int? maxProducts,
    int? maxSalesPerDay,
    bool clearMaxProducts = false,
    bool clearMaxSalesPerDay = false,
  }) {
    return LicensePolicy(
      enabled: enabled ?? this.enabled,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      deviceExpiresAt: clearDeviceExpiresAt
          ? null
          : (deviceExpiresAt ?? this.deviceExpiresAt),
      deviceBlocked: deviceBlocked ?? this.deviceBlocked,
      notice: notice ?? this.notice,
      shopFlags: shopFlags ?? this.shopFlags,
      deviceOverrides: deviceOverrides ?? this.deviceOverrides,
      pinForced: pinForced ?? this.pinForced,
      maxProducts:
          clearMaxProducts ? null : (maxProducts ?? this.maxProducts),
      maxSalesPerDay: clearMaxSalesPerDay
          ? null
          : (maxSalesPerDay ?? this.maxSalesPerDay),
    );
  }

  /// Merge a shop doc and (optionally) a device doc into a policy.
  ///
  /// Both args are the raw Firestore map payloads. When a field is
  /// missing, defaults favour "allow" so the app degrades gracefully.
  factory LicensePolicy.fromDocs({
    Map<String, dynamic>? shop,
    Map<String, dynamic>? device,
  }) {
    final shopData = shop ?? const <String, dynamic>{};
    final deviceData = device ?? const <String, dynamic>{};

    final shopFlags = _readFeatureMap(shopData['featureFlags']);
    final deviceOverrides = _readFeatureMap(deviceData['featureOverrides']);
    final pinForced = _readFeatureSet(shopData['pinForcedFlags']);

    return LicensePolicy(
      enabled: shopData['enabled'] as bool? ?? true,
      expiresAt: _parseTs(shopData['licenseExpiresAt']),
      deviceExpiresAt: _parseTs(deviceData['expiresAt']),
      deviceBlocked: deviceData['blocked'] as bool? ?? false,
      notice: shopData['notice'] as String?,
      shopFlags: shopFlags,
      deviceOverrides: deviceOverrides,
      pinForced: pinForced,
      maxProducts: _parseInt(shopData['maxProducts']),
      maxSalesPerDay: _parseInt(shopData['maxSalesPerDay']),
    );
  }

  static Map<FeatureKey, bool> _readFeatureMap(dynamic raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <FeatureKey, bool>{};
    raw.forEach((key, value) {
      if (key is String && value is bool) {
        final fk = FeatureKey.fromString(key);
        if (fk != null) {
          result[fk] = value;
        }
      }
    });
    return result;
  }

  static Set<FeatureKey> _readFeatureSet(dynamic raw) {
    if (raw is! Map) {
      return const {};
    }
    final result = <FeatureKey>{};
    raw.forEach((key, value) {
      if (key is String && value == true) {
        final fk = FeatureKey.fromString(key);
        if (fk != null) {
          result.add(fk);
        }
      }
    });
    return result;
  }

  static DateTime? _parseTs(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    if (raw is String) {
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw);
    }
    return null;
  }

  static int? _parseInt(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw);
    }
    return null;
  }
}
