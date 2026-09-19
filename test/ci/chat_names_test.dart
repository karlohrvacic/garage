import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/income_entry.dart';
import 'package:garage/domain/entities/trip_entry.dart';
import 'package:garage/features/costs/cost_category_labels.dart';
import 'package:garage/features/income/income_category_labels.dart';
import 'package:garage/features/maintenance/service_type_labels.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:garage/l10n/app_localizations_hr.dart';
import 'package:garage/l10n/app_localizations_it.dart';

/// The edge functions name a service, a category or a trip's purpose in a
/// chat message from `supabase/functions/_shared/names.json`, which is
/// generated from the ARB files here. Deno cannot read the ARBs, so this is
/// what keeps the two from drifting: it fails when they do, and regenerates
/// the file when asked.
///
///   CHAT_NAMES_WRITE=1 flutter test test/ci/chat_names_test.dart
const _file = 'supabase/functions/_shared/names.json';

/// The service types the app knows, read from the one switch that names
/// them so a type added there is translated here without a second list.
List<String> serviceTypeKeys() {
  final source = File(
    'lib/features/maintenance/service_type_labels.dart',
  ).readAsStringSync();
  return RegExp(
    r"'(service_\w+)' =>",
  ).allMatches(source).map((match) => match.group(1)!).toList();
}

String purposeLabel(AppLocalizations l10n, TripPurpose purpose) =>
    switch (purpose) {
      TripPurpose.private => l10n.tripPurposePrivate,
      TripPurpose.business => l10n.tripPurposeBusiness,
    };

/// One map per language, keyed the way the rows are: a service type keeps its
/// `service_` prefix, a category and a purpose are bare. The lists are kept
/// apart until the end so a key two of them share is caught below rather
/// than silently taken from whichever list came last.
List<Map<String, String>> listsIn(AppLocalizations l10n) => [
  {for (final key in serviceTypeKeys()) key: serviceTypeLabel(l10n, key)},
  {for (final key in CostCategories.all) key: costCategoryLabel(l10n, key)},
  {for (final key in IncomeCategories.all) key: incomeCategoryLabel(l10n, key)},
  {
    for (final purpose in TripPurpose.values)
      purpose.key: purposeLabel(l10n, purpose),
  },
];

Map<String, String> namesIn(AppLocalizations l10n) => {
  for (final list in listsIn(l10n)) ...list,
};

void main() {
  final languages = {
    'en': AppLocalizationsEn(),
    'hr': AppLocalizationsHr(),
    'it': AppLocalizationsIt(),
  };

  test('the service switch is actually being read', () {
    // A regex that stopped matching would generate a file with no services
    // in it, and every service in a chat message would fall back to words.
    expect(serviceTypeKeys(), contains('service_oil_change'));
    expect(serviceTypeKeys().length, greaterThan(30));
  });

  // Cost and income both have an `other`. The file has one entry per key,
  // so the two must read the same, or one of them is wrong in a message.
  test('a key two lists share is named the same in both', () {
    for (final MapEntry(key: language, value: l10n) in languages.entries) {
      final seen = <String, String>{};
      for (final list in listsIn(l10n)) {
        for (final MapEntry(:key, :value) in list.entries) {
          expect(
            seen[key] ?? value,
            value,
            reason: '$language: "$key" is named twice, differently',
          );
          seen[key] = value;
        }
      }
    }
  });

  test('names.json is what the ARB files say', () {
    final expected = {
      for (final MapEntry(key: language, value: l10n) in languages.entries)
        language: namesIn(l10n),
    };
    final encoded = '${const JsonEncoder.withIndent('  ').convert(expected)}\n';
    if (Platform.environment['CHAT_NAMES_WRITE'] == '1') {
      File(_file).writeAsStringSync(encoded);
    }
    expect(
      File(_file).readAsStringSync(),
      encoded,
      reason:
          'run CHAT_NAMES_WRITE=1 flutter test test/ci/chat_names_test.dart '
          'to regenerate',
    );
  });
}
