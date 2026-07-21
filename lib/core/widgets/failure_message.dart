import 'package:garage/l10n/app_localizations.dart';

import '../errors/app_failure.dart';

/// Maps a failure to text a person can act on. Raw backend messages are for
/// logs, never for users.
String failureMessage(AppLocalizations l10n, AppFailure failure) {
  return switch (failure.kind) {
    AppFailureKind.network => l10n.errorNoConnection,
    AppFailureKind.auth => l10n.errorAuth,
    AppFailureKind.permission => l10n.errorPermission,
    AppFailureKind.notFound => l10n.errorNotFound,
    AppFailureKind.conflict => l10n.errorConflict,
    AppFailureKind.expired => l10n.errorExpired,
    AppFailureKind.alreadyUsed => l10n.errorAlreadyUsed,
    AppFailureKind.unknown => l10n.errorGeneric,
  };
}
