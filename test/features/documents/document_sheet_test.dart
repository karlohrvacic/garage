import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/reminder_rule.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/documents/providers/document_providers.dart';
import 'package:garage/features/maintenance/data/maintenance_repository.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/documents/widgets/document_sheet.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/fake_attachments.dart';
import '../../support/fake_documents.dart';

/// Records the rules a saved document asks for.
class RecordingMaintenance implements MaintenanceRepository {
  RecordingMaintenance({this.rules = const []});

  List<ReminderRule> rules;
  final List<String> completed = [];

  @override
  Future<List<ServiceType>> serviceTypes() async => const [];

  @override
  Future<List<ReminderRule>> rulesForVehicle(String vehicleId) async => rules;

  @override
  Future<List<ServiceEntry>> serviceEntriesForVehicle(String vehicleId) async =>
      const [];

  @override
  Future<void> upsertRule(ReminderRule rule) async => rules = [...rules, rule];

  @override
  Future<void> deleteRule(String id) async {}

  @override
  Future<void> completeOneTimeRules(
    String vehicleId,
    List<String> serviceTypeKeys,
  ) async => completed.addAll(serviceTypeKeys);

  @override
  Future<void> addServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> updateServiceEntry(ServiceEntry entry) async {}

  @override
  Future<void> deleteServiceEntry(String id) async {}
}

Future<void> pumpSheet(
  WidgetTester tester, {
  required FakeDocumentRepository repository,
  RecordingMaintenance? maintenance,
  VehicleDocument? existing,
  Set<DocumentType> alreadyHeld = const {},
  Size surface = const Size(500, 1600),
  double textScale = 1,
  Locale? locale,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        maintenanceRepositoryProvider.overrideWithValue(
          maintenance ?? RecordingMaintenance(),
        ),
        attachmentRepositoryProvider.overrideWithValue(
          FakeAttachmentRepository(),
        ),
        filePickerProvider.overrideWithValue(() async => null),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: DocumentSheet(
                vehicleId: 'v1',
                existing: existing,
                alreadyHeld: alreadyHeld,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  final save = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}

Future<void> pickExpiry(WidgetTester tester, {required int day}) async {
  final field = find.text('Valid until');
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new document saves what was typed on it', (tester) async {
    final repository = FakeDocumentRepository();
    await pumpSheet(tester, repository: repository);

    await tester.enterText(
      find.byKey(const Key('document-number')),
      'HR-4451/26',
    );
    await tapSave(tester);

    final saved = repository.documents.single;
    expect(saved.type, DocumentType.registration);
    expect(saved.number, 'HR-4451/26');
  });

  testWidgets('an expiry raises a reminder of the paperwork type', (
    tester,
  ) async {
    final maintenance = RecordingMaintenance();
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository(),
      maintenance: maintenance,
    );

    await pickExpiry(tester, day: 20);
    await tapSave(tester);

    final rule = maintenance.rules.single;
    expect(rule.serviceTypeKey, 'service_registration');
    expect(rule.oneTime, isTrue);
    expect(rule.dueDate, isNotNull);
    // Cleared first, so the previous year's rule does not stand beside it.
    expect(maintenance.completed, contains('service_registration'));
  });

  testWidgets('a document with no expiry raises none, and clears none', (
    tester,
  ) async {
    // And in particular does not clear one somebody else raised. Recording a
    // registration certificate with just its number must not take down the
    // reminder the *cost* sheet raised when the registration was paid: the
    // planner entry would vanish with nothing on screen saying why, and
    // nothing but paying again brings a paperwork rule back.
    final maintenance = RecordingMaintenance();
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository(),
      maintenance: maintenance,
    );

    await tapSave(tester);

    expect(maintenance.rules, isEmpty);
    expect(maintenance.completed, isEmpty);
  });

  testWidgets('but clearing an expiry it had does retract its reminder', (
    tester,
  ) async {
    final existing = VehicleDocument(
      id: 'd1',
      vehicleId: 'v1',
      type: DocumentType.registration,
      createdBy: 'u1',
      expiresOn: DateTime.utc(2027, 6, 3),
    );
    final maintenance = RecordingMaintenance();
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository([existing]),
      maintenance: maintenance,
      existing: existing,
    );

    final clear = find.byTooltip('Clear');
    await tester.ensureVisible(clear.first);
    await tester.pumpAndSettle();
    await tester.tap(clear.first);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(maintenance.completed, contains('service_registration'));
    expect(maintenance.rules, isEmpty);
  });

  testWidgets('a name typed under "other" does not ride along on a type', (
    tester,
  ) async {
    // `documentTitle` prefers the label, so the card would read as whatever
    // was typed — and a labelled registration slips past an unlabelled one on
    // restore and is inserted as a second row the unique index refuses.
    final repository = FakeDocumentRepository();
    await pumpSheet(tester, repository: repository);

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('document-label')),
      'Lease agreement',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registration').last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(repository.documents.single.type, DocumentType.registration);
    expect(repository.documents.single.label, isNull);
  });

  testWidgets('"other" needs a name, and says so rather than saving one', (
    tester,
  ) async {
    final repository = FakeDocumentRepository();
    await pumpSheet(tester, repository: repository);

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(repository.documents, isEmpty);
    expect(find.textContaining('Say what this document is'), findsOneWidget);
  });

  testWidgets('a type the car already holds is not offered again', (
    tester,
  ) async {
    // The database allows one of each per car, so offering it is a dead end.
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository(),
      alreadyHeld: {DocumentType.registration},
    );

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();

    expect(find.text('Registration'), findsNothing);
  });

  testWidgets('editing one keeps its own type in the list', (tester) async {
    final existing = VehicleDocument(
      id: 'd1',
      vehicleId: 'v1',
      type: DocumentType.registration,
      createdBy: 'u1',
      number: 'HR-1',
    );
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository([existing]),
      existing: existing,
      alreadyHeld: {DocumentType.registration},
    );

    expect(find.text('Registration'), findsOneWidget);
    expect(find.text('HR-1'), findsOneWidget);
  });

  testWidgets('a document the app cannot name says it sets no reminder', (
    tester,
  ) async {
    await pumpSheet(tester, repository: FakeDocumentRepository());

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('No reminder'), findsOneWidget);
  });

  testWidgets('changing a document\'s type takes the old reminder down', (
    tester,
  ) async {
    // Nothing settles a paperwork rule except recording the paperwork again,
    // so a reminder left behind by a corrected type is effectively permanent.
    final existing = VehicleDocument(
      id: 'd1',
      vehicleId: 'v1',
      type: DocumentType.registration,
      createdBy: 'u1',
      expiresOn: DateTime.utc(2027, 6, 3),
    );
    final maintenance = RecordingMaintenance();
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository([existing]),
      maintenance: maintenance,
      existing: existing,
    );

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Green card').last);
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(maintenance.completed, contains('service_registration'));
    expect(maintenance.completed, contains('service_green_card'));
    expect(maintenance.rules.single.serviceTypeKey, 'service_green_card');
  });

  testWidgets('and a change to "other" leaves no reminder standing', (
    tester,
  ) async {
    final existing = VehicleDocument(
      id: 'd1',
      vehicleId: 'v1',
      type: DocumentType.registration,
      createdBy: 'u1',
      expiresOn: DateTime.utc(2027, 6, 3),
    );
    final maintenance = RecordingMaintenance();
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository([existing]),
      maintenance: maintenance,
      existing: existing,
    );

    await tester.tap(find.byKey(const Key('document-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('document-label')),
      'Lease agreement',
    );
    await tester.pumpAndSettle();
    await tapSave(tester);

    expect(maintenance.completed, contains('service_registration'));
    expect(maintenance.rules, isEmpty);
  });

  group('the sheet survives a hostile window', () {
    testWidgets('a narrow phone at the largest text', (tester) async {
      // The date rows carry a label, a value and *two* trailing icons, which
      // is the shape most likely to run out of width when the text doubles.
      await pumpSheet(
        tester,
        repository: FakeDocumentRepository(),
        existing: VehicleDocument(
          id: 'd1',
          vehicleId: 'v1',
          type: DocumentType.insuranceComprehensive,
          createdBy: 'u1',
          number: 'HR-4451/26-000',
          issuer: 'Croatia osiguranje',
          issuedOn: DateTime.utc(2026, 6, 3),
          expiresOn: DateTime.utc(2027, 6, 3),
        ),
        surface: const Size(320, 900),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the "other" form, which has one more field', (
      tester,
    ) async {
      await pumpSheet(
        tester,
        repository: FakeDocumentRepository(),
        existing: VehicleDocument(
          id: 'd1',
          vehicleId: 'v1',
          type: DocumentType.other,
          createdBy: 'u1',
          label: 'Ugovor o leasingu s Erste Bankom',
        ),
        surface: const Size(320, 900),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('in Croatian on a narrow phone at a large font it lays out', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      repository: FakeDocumentRepository(),
      locale: const Locale('hr'),
      textScale: 1.5,
      surface: const Size(320, 3200),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
