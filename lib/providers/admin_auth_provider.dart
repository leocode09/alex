import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/admin/admin_auth_service.dart';

final adminAuthServiceProvider = Provider<AdminAuthService>(
  (ref) => AdminAuthService(),
);

/// Current signed-in admin uid, or null if signed out. Updated manually
/// by the login page — the admin session is in-memory for this process
/// only so a simple [StateProvider] is enough.
final adminUidProvider = StateProvider<String?>(
  (ref) => AdminAuthService().currentUid,
);
