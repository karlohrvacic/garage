import 'package:garage/l10n/app_localizations.dart';

/// How the camshaft is driven, in the order offered. Keys match the check
/// constraint in migration 0046.
const timingDriveKeys = ['belt', 'chain', 'wet_belt'];

/// Gearbox kinds, in the order offered. Keys match migration 0046.
const transmissionKeys = ['manual', 'automatic', 'dct_dry', 'dct_wet', 'cvt'];

/// The translated name for a timing-drive key, or null for one this version
/// does not know — a vehicle stored by a newer build must not crash an
/// older one.
String? timingDriveLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'belt' => l10n.timingDriveBelt,
    'chain' => l10n.timingDriveChain,
    'wet_belt' => l10n.timingDriveWetBelt,
    _ => null,
  };
}

String? transmissionLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'manual' => l10n.transmissionManual,
    'automatic' => l10n.transmissionAutomatic,
    'dct_dry' => l10n.transmissionDctDry,
    'dct_wet' => l10n.transmissionDctWet,
    'cvt' => l10n.transmissionCvt,
    _ => null,
  };
}
