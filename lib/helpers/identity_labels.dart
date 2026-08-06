/// Shared, non-technical identity formatting for app and admin surfaces.
class IdentityLabels {
  const IdentityLabels._();

  static String deviceDisplayName(Map<String, dynamic> data) {
    return _nonEmpty(data['deviceName']) ??
        _nonEmpty(data['memberDisplayName']) ??
        'Unregistered device';
  }

  static String memberDisplayName(
    Map<String, dynamic> data, {
    required String uid,
  }) {
    return _nonEmpty(data['displayName']) ??
        'Unnamed member (${shortId(uid)})';
  }

  static String shortId(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 8) {
      return trimmed;
    }
    return trimmed.substring(0, 8);
  }

  static String formatPhoneForDisplay(String? value) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) {
      return '';
    }
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.length == 10 && digits.startsWith('0')) {
      digits = '250${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('250')) {
      final local = digits.substring(3);
      return '+250 ${local.substring(0, 3)} ${local.substring(3, 6)} '
          '${local.substring(6)}';
    }
    return raw;
  }

  static String? _nonEmpty(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}
