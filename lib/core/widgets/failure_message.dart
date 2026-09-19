import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../errors/app_failure.dart';
import '../errors/failure_log.dart';

/// Maps a failure to text a person can act on. Raw backend messages are for
/// logs, never for users.
///
/// Every user-facing error passes through here, which makes it the one place
/// worth recording from: the generic sentence goes to the screen, the actual
/// cause goes to [reportFailure] so it is still answerable afterwards.
String failureMessage(AppLocalizations l10n, AppFailure failure) {
  reportFailure(failure);
  return switch (failure.kind) {
    AppFailureKind.network => l10n.errorNoConnection,
    AppFailureKind.timeout => l10n.errorTimeout,
    AppFailureKind.auth => l10n.errorAuth,
    AppFailureKind.emailNotConfirmed => l10n.errorEmailNotConfirmed,
    AppFailureKind.permission => l10n.errorPermission,
    AppFailureKind.notFound => l10n.errorNotFound,
    AppFailureKind.conflict => l10n.errorConflict,
    AppFailureKind.expired => l10n.errorExpired,
    AppFailureKind.alreadyUsed => l10n.errorAlreadyUsed,
    AppFailureKind.invalid => l10n.errorInvalid,
    AppFailureKind.handoverClash => l10n.errorHandoverClash,
    AppFailureKind.planLimit => l10n.errorPlanLimit,
    AppFailureKind.driversNeedAdmin => l10n.errorDriversNeedAdmin,
    AppFailureKind.unknown => l10n.errorGeneric,
  };
}

/// The failure a controller is left holding after a write it answered
/// `false` for, so the sheet that asked can stay open and show it.
///
/// A controller records `AppFailure.from(error)`, so this is a read rather
/// than a guess. A state with nothing in it, or one a controller wrote raw,
/// reads as the generic failure: better than a cast that throws on the way
/// to an error message.
AppFailure failureOf(AsyncValue<void> state) {
  final error = state.error;
  return error == null
      ? const AppFailure(kind: AppFailureKind.unknown)
      : AppFailure.from(error);
}
