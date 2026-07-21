import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

enum AppFailureKind { network, auth, notFound, permission, conflict, unknown }

/// Every error that reaches the UI is one of these. Raw Postgrest and auth
/// exceptions never make it to a widget: the screen picks a localized message
/// from [kind], and [debugMessage] exists only for logs.
class AppFailure implements Exception {
  const AppFailure({required this.kind, this.debugMessage});

  final AppFailureKind kind;
  final String? debugMessage;

  static AppFailure from(Object error) {
    if (error is AppFailure) {
      return error;
    }
    if (error is SocketException || error is HttpException) {
      return AppFailure(
        kind: AppFailureKind.network,
        debugMessage: error.toString(),
      );
    }
    if (error is AuthException) {
      return AppFailure(
        kind: AppFailureKind.auth,
        debugMessage: error.message,
      );
    }
    if (error is PostgrestException) {
      return AppFailure(
        kind: switch (error.code) {
          '42501' => AppFailureKind.permission,
          '23505' => AppFailureKind.conflict,
          'PGRST116' => AppFailureKind.notFound,
          _ => AppFailureKind.unknown,
        },
        debugMessage: '${error.code}: ${error.message}',
      );
    }
    return AppFailure(
      kind: AppFailureKind.unknown,
      debugMessage: error.toString(),
    );
  }

  @override
  String toString() => 'AppFailure($kind, $debugMessage)';
}
