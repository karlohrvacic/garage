import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_scheduler.dart';
import 'package:garage/core/notifications/push_receipt_reminder.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

Map<String, dynamic> message({String type = 'receipt_missing'}) => {
  'type': type,
  'vehicle_id': 'v1',
  'vehicle_nickname': 'Golf',
  'entry_kind': 'cost',
  'entry_id': 'c1',
  'entry_date': '2026-09-13',
};

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  // The body carries a date, and `intl` formats none until its symbols are
  // loaded; the receiver does this on the device.
  setUpAll(initializeDateFormatting);

  test('a receipt push becomes something showable', () {
    final reminder = PushReceiptReminder.from(message());

    expect(reminder, isNotNull);
    expect(reminder!.vehicleId, 'v1');
    expect(reminder.entryKind, 'cost');
    expect(reminder.entryId, 'c1');
    expect(reminder.entryDate, DateTime.utc(2026, 9, 13));
    expect(reminder.title(en), 'Receipt missing');
    expect(reminder.body(en), contains('Golf'));
    expect(reminder.body(en), contains('13'));
  });

  test('a car with no name is not written as one', () {
    final reminder = PushReceiptReminder.from({
      ...message(),
      'vehicle_nickname': '',
    });

    expect(reminder!.vehicleNickname, isNull);
    // The sentence leads with the car; with none it used to lead with a
    // colon. The app's own word for a car takes its place.
    expect(reminder.body(en), startsWith('Vehicle: '));
    expect(
      reminder.body(lookupAppLocalizations(const Locale('hr'))),
      startsWith('Vozilo: '),
    );
  });

  test('its id is the entry, so a second nudge replaces the first', () {
    expect(
      PushReceiptReminder.from(message())!.notificationId,
      PushReceiptReminder.from(message())!.notificationId,
    );
    expect(
      PushReceiptReminder.from(message())!.notificationId,
      isNot(
        PushReceiptReminder.from({
          ...message(),
          'entry_id': 'c2',
        })!.notificationId,
      ),
    );
  });

  test('its id comes from the scheduler, keyed on the entry', () {
    // The same hash every notification on this device uses, so it fits the
    // plugin and cannot collide with a due reminder's by construction.
    expect(
      PushReceiptReminder.from(message())!.notificationId,
      notificationIdFor('receipt:c1'),
    );
  });

  test('anything else is ignored, not guessed at', () {
    expect(PushReceiptReminder.from(message(type: 'reminder_due')), isNull);
    expect(
      PushReceiptReminder.from({...message(), 'entry_date': 'soon'}),
      isNull,
    );
    expect(PushReceiptReminder.from({...message(), 'entry_id': ''}), isNull);
    expect(
      PushReceiptReminder.from({...message()}..remove('vehicle_id')),
      isNull,
    );
    expect(PushReceiptReminder.from(const {}), isNull);
  });
}
