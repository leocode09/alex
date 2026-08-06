import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cloud/firebase_init.dart';
import '../cloud/firestore_paths.dart';
import 'install_id_service.dart';

enum DeviceBindingStatus { bound, unbound, conflict, unavailable, signedOut }

class DeviceBindingResult {
  final DeviceBindingStatus status;
  final String message;

  const DeviceBindingResult(this.status, this.message);

  bool get isBound => status == DeviceBindingStatus.bound;

  /// Stable status code for LAN / Wi-Fi Direct peer gates.
  ///
  /// Keeps "not signed in" distinct from "device not registered" so the UI
  /// does not blame device registration when the Firebase session is gone.
  String get peerGateStatus {
    switch (status) {
      case DeviceBindingStatus.bound:
        return 'ok';
      case DeviceBindingStatus.signedOut:
        return 'sign_in_required';
      case DeviceBindingStatus.unbound:
        return 'device_not_registered';
      case DeviceBindingStatus.conflict:
        return 'device_conflict';
      case DeviceBindingStatus.unavailable:
        return 'cloud_unavailable';
    }
  }
}

/// Permanently binds one app install to one Firebase account.
///
/// The Firestore transaction is authoritative. A local cache is retained only
/// for diagnostics/offline messaging and is never allowed to override an
/// admin unbind.
class DeviceRegistrationService {
  DeviceRegistrationService._internal();
  static final DeviceRegistrationService _instance =
      DeviceRegistrationService._internal();
  factory DeviceRegistrationService() => _instance;

  static const String boundUidPreferenceKey = 'device_bound_uid';

  /// Pre-Auth gate for registration: any existing bind blocks a second
  /// phone-account signup on this install. Callers should show "log in
  /// instead" rather than creating an orphan Firebase Auth user.
  Future<DeviceBindingResult> assertCanRegister() async {
    if (!FirebaseInit.available) {
      return const DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Cloud is unavailable, so this device could not be registered.',
      );
    }
    final installId = await InstallIdService.ensure();
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.devicesCollection)
          .doc(installId)
          .get();
      if (!snap.exists) {
        return const DeviceBindingResult(
          DeviceBindingStatus.unbound,
          'This device is available for registration.',
        );
      }
      final data = snap.data();
      final existingUid =
          _readUid(data?['boundUid']) ?? _readUid(data?['ownerUid']);
      if (existingUid == null) {
        return const DeviceBindingResult(
          DeviceBindingStatus.unbound,
          'This device is available for registration.',
        );
      }
      return const DeviceBindingResult(
        DeviceBindingStatus.conflict,
        'This device is already registered. Log in with the original '
        'phone number, or ask an administrator to unbind it.',
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Device registration pre-check failed: ${e.code}');
      }
      // permission-denied usually means the doc is bound to someone else
      // (rules only allow reading your own or unbound docs).
      if (e.code == 'permission-denied') {
        return const DeviceBindingResult(
          DeviceBindingStatus.conflict,
          'This device is already registered. Log in with the original '
          'phone number, or ask an administrator to unbind it.',
        );
      }
      return DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Could not check this device: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Device registration pre-check failed: $e');
      }
      return DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Could not check this device: $e',
      );
    }
  }

  /// Claims an unregistered/admin-unbound install or validates the existing
  /// binding. A different account can never overwrite an existing owner.
  Future<DeviceBindingResult> bindToCurrentUser() async {
    if (!FirebaseInit.available) {
      return const DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Cloud is unavailable, so this device could not be registered.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Please log in before registering this device.',
      );
    }

    final installId = await InstallIdService.ensure();
    final ref = FirebaseFirestore.instance
        .collection(FirestorePaths.devicesCollection)
        .doc(installId);
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snap = await transaction.get(ref);
        final data = snap.data();
        final ownerUid = _readUid(data?['ownerUid']);
        final boundUid = _readUid(data?['boundUid']);
        final existingUid = boundUid ?? ownerUid;
        if (existingUid != null && existingUid != uid) {
          throw const _DeviceBindingConflict();
        }

        final payload = <String, dynamic>{
          'installId': installId,
          'ownerUid': uid,
          'boundUid': uid,
          if (data == null || data['boundAt'] == null)
            'boundAt': FieldValue.serverTimestamp(),
          if (data != null && data.containsKey('unboundAt'))
            'unboundAt': FieldValue.delete(),
        };
        transaction.set(ref, payload, SetOptions(merge: true));
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(boundUidPreferenceKey, uid);
      return const DeviceBindingResult(
        DeviceBindingStatus.bound,
        'Device registered.',
      );
    } on _DeviceBindingConflict {
      return const DeviceBindingResult(
        DeviceBindingStatus.conflict,
        'This device is already registered to another account. '
        'Contact an administrator to unbind it.',
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Device registration failed: ${e.code} — ${e.message}');
      }
      if (e.code == 'permission-denied') {
        return const DeviceBindingResult(
          DeviceBindingStatus.conflict,
          'This device is already registered to another account. '
          'Contact an administrator to unbind it.',
        );
      }
      return DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Could not register this device: ${e.message ?? e.code}',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Device registration failed: $e');
      }
      return DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Could not register this device: $e',
      );
    }
  }

  /// Verifies the current signed-in account without claiming an admin-unbound
  /// device. LAN/Wi-Fi Direct and heartbeats use this fail-closed check.
  Future<DeviceBindingResult> verifyCurrentBinding() async {
    if (!FirebaseInit.available) {
      return const DeviceBindingResult(
        DeviceBindingStatus.unavailable,
        'Cloud is unavailable.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const DeviceBindingResult(
        DeviceBindingStatus.signedOut,
        'Your session expired. Please log in again.',
      );
    }
    final installId = await InstallIdService.ensure();
    try {
      final snap = await FirebaseFirestore.instance
          .collection(FirestorePaths.devicesCollection)
          .doc(installId)
          .get();
      if (!snap.exists) {
        return const DeviceBindingResult(
          DeviceBindingStatus.unbound,
          'This device has not been registered.',
        );
      }
      final data = snap.data();
      final boundUid = _readUid(data?['boundUid']);
      final existingUid = boundUid ?? _readUid(data?['ownerUid']);
      if (existingUid == uid) {
        if (boundUid == null || data?['boundAt'] == null) {
          return bindToCurrentUser();
        }
        return const DeviceBindingResult(
          DeviceBindingStatus.bound,
          'Device registration verified.',
        );
      }
      if (existingUid == null) {
        return const DeviceBindingResult(
          DeviceBindingStatus.unbound,
          'This device was unbound by an administrator. Log in again.',
        );
      }
      return const DeviceBindingResult(
        DeviceBindingStatus.conflict,
        'This device belongs to another account.',
      );
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Device binding verification failed: ${e.code}');
      }
      return DeviceBindingResult(
        e.code == 'permission-denied'
            ? DeviceBindingStatus.conflict
            : DeviceBindingStatus.unavailable,
        e.code == 'permission-denied'
            ? 'This device belongs to another account.'
            : 'Could not verify this device.',
      );
    }
  }

  static String? _readUid(Object? value) {
    final text = value is String ? value.trim() : '';
    return text.isEmpty ? null : text;
  }
}

class _DeviceBindingConflict implements Exception {
  const _DeviceBindingConflict();
}
