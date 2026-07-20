// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Garage';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonDelete => 'Delete';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNoConnection =>
      'No connection. Check your network and retry.';

  @override
  String get fuelEconomyUnavailable =>
      'Not enough full-tank fills to calculate';

  @override
  String get maintenanceStateUpcoming => 'Upcoming';

  @override
  String get maintenanceStateDue => 'Due';

  @override
  String get maintenanceStateOverdue => 'Overdue';

  @override
  String bundleSuggestionTitle(int count) {
    return 'Bundle $count items into one visit';
  }
}
