import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppFailureKind {
  network,

  /// A write that got no answer in time. Not the same as no connection: the
  /// request may still land, so the message says to look before retrying.
  timeout,
  auth,
  emailNotConfirmed,
  notFound,
  permission,
  conflict,
  expired,
  alreadyUsed,
  invalid,

  /// A handover on a day a window already covers (migration 0080). Named
  /// rather than a conflict: the fix is to remove the wrong row, and the
  /// console says so.
  handoverClash,

  /// A free garage at its cap of active cars: the unarchive guard, a sale
  /// redeemed into a full garage, a merge that would overflow one.
  planLimit,

  /// The last admin leaving a garage that would keep only drivers
  /// (migration 0080). Refused rather than left adminless: a driver sees
  /// one car and cannot inherit the console, so somebody has to be made an
  /// admin first, and the sentence says so.
  driversNeedAdmin,
  unknown,
}

/// Every error that reaches the UI is one of these. Raw Postgrest and auth
/// exceptions never make it to a widget: the screen picks a localized message
/// from [kind], and [debugMessage] exists only for logs.
class AppFailure implements Exception {
  const AppFailure({required this.kind, this.debugMessage});

  final AppFailureKind kind;
  final String? debugMessage;

  /// The network did not carry the request: nothing was answered. The write
  /// queue keeps such a write and the read cache serves an old list for such
  /// a read; every other kind is the server answering and must be shown.
  bool get isConnectionFailure =>
      kind == AppFailureKind.network || kind == AppFailureKind.timeout;

  static AppFailure from(Object error) {
    if (error is AppFailure) {
      return error;
    }
    // Supabase's http client wraps SocketException in ClientException, and on
    // web the dart:io types never occur at all — so ClientException and the
    // retryable auth fetch failure are the network signals that actually fire.
    if (error is TimeoutException) {
      return AppFailure(
        kind: AppFailureKind.timeout,
        debugMessage: error.toString(),
      );
    }
    if (error is SocketException ||
        error is HttpException ||
        error is http.ClientException ||
        error is AuthRetryableFetchException) {
      return AppFailure(
        kind: AppFailureKind.network,
        debugMessage: error.toString(),
      );
    }
    if (error is AuthException) {
      // Separated from every other auth failure because the advice differs
      // completely. "Check your email and password" is false here — they are
      // correct — and it sends someone to retype credentials that were never
      // the problem, forever.
      //
      // Matched on the message as well as the code: older projects answer
      // without one, and being wrong in this direction costs a user their
      // whole registration.
      final unconfirmed =
          error is AuthApiException && error.code == 'email_not_confirmed';
      final saysSo = error.message.toLowerCase().contains('not confirmed');
      return AppFailure(
        kind: unconfirmed || saysSo
            ? AppFailureKind.emailNotConfirmed
            : AppFailureKind.auth,
        debugMessage: error.message,
      );
    }
    if (error is FunctionException) {
      // Edge-function failures (e.g. account deletion) have no cleaner mapping;
      // surface them as a generic failure but keep the detail for logs.
      return AppFailure(
        kind: AppFailureKind.unknown,
        debugMessage: 'function ${error.status}: ${error.details}',
      );
    }
    if (error is StorageException) {
      return AppFailure(
        // Storage answers 400 and names the real status in the body. A type
        // or a size the bucket refuses (migration 0075) is refused on every
        // attempt, so a queued photo is dropped rather than retried. Nothing
        // else is decided here: a 403 can be a token about to be refreshed.
        kind: switch (error.statusCode) {
          '413' || '415' => AppFailureKind.invalid,
          _ => AppFailureKind.unknown,
        },
        debugMessage: 'storage ${error.statusCode}: ${error.message}',
      );
    }
    if (error is PostgrestException) {
      return AppFailure(
        kind: switch (error.code) {
          '42501' => AppFailureKind.permission,
          '23505' => AppFailureKind.conflict,
          // A check constraint (a VIN outside 11–17 characters, say). The form
          // validates the cases it knows about; this is the net under it, and
          // "check the values" beats "something went wrong" for whatever the
          // form has not learned yet.
          '23514' => AppFailureKind.invalid,
          'PGRST116' => AppFailureKind.notFound,
          // Invite-redemption codes raised by join_household_with_code: a typo,
          // an expired code, and an already-used code are distinct situations
          // the user needs to tell apart.
          'P0002' => AppFailureKind.notFound,
          'P0003' => AppFailureKind.expired,
          'P0004' => AppFailureKind.alreadyUsed,
          // redeem_vehicle_transfer only: the code is fine, the car is
          // already where it would be moved to (migration 0048).
          'P0005' => AppFailureKind.conflict,
          // hand_over_vehicle: a window already covers the day (0080).
          'P0006' => AppFailureKind.handoverClash,
          // promote_after_member_left: the last admin leaving a garage of
          // drivers (0080).
          'P0007' => AppFailureKind.driversNeedAdmin,
          // A free garage at its cap of active cars (0080).
          'P0008' => AppFailureKind.planLimit,
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
