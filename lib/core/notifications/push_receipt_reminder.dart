import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import 'notification_scheduler.dart' as scheduler;

/// "The console asked you for a receipt", as it arrives from the server.
///
/// Data-only like the due reminder, and for the same reason: the server has
/// no idea what language this phone reads. Nothing here touches a plugin.
class PushReceiptReminder {
  const PushReceiptReminder({
    required this.vehicleId,
    required this.entryKind,
    required this.entryId,
    required this.entryDate,
    this.vehicleNickname,
  });

  static const String messageType = 'receipt_missing';

  final String vehicleId;

  /// `fuel`, `service` or `cost`: the table the entry lives in.
  final String entryKind;
  final String entryId;

  /// UTC date-only, like every domain date.
  final DateTime entryDate;
  final String? vehicleNickname;

  /// Reads a payload, or null when it is not this. Half-read is worse than
  /// ignored.
  static PushReceiptReminder? from(Map<String, dynamic> data) {
    if (data['type'] != messageType) {
      return null;
    }
    final vehicleId = data['vehicle_id'];
    final kind = data['entry_kind'];
    final entryId = data['entry_id'];
    final date = DateTime.tryParse('${data['entry_date']}');
    if (vehicleId is! String ||
        vehicleId.isEmpty ||
        kind is! String ||
        entryId is! String ||
        entryId.isEmpty ||
        date == null) {
      return null;
    }
    final nickname = data['vehicle_nickname'];
    return PushReceiptReminder(
      vehicleId: vehicleId,
      entryKind: kind,
      entryId: entryId,
      entryDate: DateTime.utc(date.year, date.month, date.day),
      vehicleNickname: nickname is String && nickname.isNotEmpty
          ? nickname
          : null,
    );
  }

  /// The entry itself, through the hash every notification on this device
  /// takes its id from: a second nudge for the same receipt replaces the
  /// first rather than stacking, and no due reminder's identity begins with
  /// `receipt:`.
  int get notificationId => scheduler.notificationIdFor('receipt:$entryId');

  String title(AppLocalizations l10n) => l10n.notificationReceiptMissingTitle;

  /// Which car and which day, so the driver knows what to photograph. The
  /// sentence leads with the car, so a car with no name gets the app's own
  /// word for one rather than a bare colon.
  ///
  /// Needs the locale's date symbols loaded, which `intl` has for English
  /// alone until `initializeDateFormatting` runs; the receiver does that.
  String body(AppLocalizations l10n) => l10n.notificationReceiptMissingBody(
    DateFormat.yMd(l10n.localeName).format(entryDate),
    vehicleNickname ?? l10n.commonVehicle,
  );
}
