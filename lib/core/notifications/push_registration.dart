import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/push_config.dart';
import '../errors/app_failure.dart';
import '../errors/failure_log.dart';
import '../supabase/supabase_client_provider.dart';

/// Registers and withdraws this device's push token.
///
/// A seam, like the file picker and the URL opener: the messaging plugin needs
/// a platform channel and a live Firebase project, so screens and controllers
/// ask for this rather than calling the plugin, and tests substitute a
/// recorder.
abstract interface class PushRegistration {
  /// Called after sign-in. Safe to call repeatedly: the row is keyed on the
  /// token, and a device that already registered simply updates its timestamp.
  Future<void> register();

  /// Called before sign-out, so a shared device stops receiving another
  /// household's reminders. Deleting the row is what stops delivery; the token
  /// itself survives on the device.
  Future<void> withdraw();
}

/// What a build without Firebase configured gets: push is off, and every call
/// is a no-op rather than a crash. See [PushConfig] for why that is the default
/// rather than a broken build.
class PushDisabled implements PushRegistration {
  const PushDisabled();

  @override
  Future<void> register() async {}

  @override
  Future<void> withdraw() async {}
}

class FirebasePushRegistration implements PushRegistration {
  FirebasePushRegistration(this._ref);

  final Ref _ref;

  static bool _initialized = false;

  Future<FirebaseMessaging> _messaging() async {
    if (!_initialized) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: PushConfig.apiKey,
          appId: PushConfig.appId,
          messagingSenderId: PushConfig.messagingSenderId,
          projectId: PushConfig.projectId,
        ),
      );
      _initialized = true;
    }
    return FirebaseMessaging.instance;
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }
    return Platform.isIOS ? 'ios' : 'android';
  }

  @override
  Future<void> register() async {
    // Never fatal: a household that cannot register for push should still be
    // able to use the app, so this reports and returns rather than throwing
    // into a sign-in that otherwise succeeded.
    try {
      final messaging = await _messaging();
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await messaging.getToken(
        vapidKey: kIsWeb && PushConfig.vapidKey.isNotEmpty
            ? PushConfig.vapidKey
            : null,
      );
      final userId = _ref.read(currentUserIdProvider);
      if (token == null || userId == null) {
        return;
      }
      await _ref.read(supabaseClientProvider).from('device_tokens').upsert({
        'token': token,
        'user_id': userId,
        'platform': _platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on Object catch (error) {
      reportFailure(AppFailure.from(error));
    }
  }

  @override
  Future<void> withdraw() async {
    try {
      final messaging = await _messaging();
      final token = await messaging.getToken();
      if (token == null) {
        return;
      }
      await _ref
          .read(supabaseClientProvider)
          .from('device_tokens')
          .delete()
          .eq('token', token);
    } on Object catch (error) {
      reportFailure(AppFailure.from(error));
    }
  }
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  return PushConfig.isConfigured
      ? FirebasePushRegistration(ref)
      : const PushDisabled();
});
