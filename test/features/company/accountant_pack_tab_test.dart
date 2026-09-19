import 'dart:async';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/core/files/file_saver.dart';
import 'package:garage/core/widgets/garage_tab_bar.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/company/screens/company_screen.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/fake_attachments.dart';
import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';
import '../reports/accountant_pack_test.dart' show onePixel;
import 'company_providers_test.dart' show RecordingCompanyRepository;
import 'company_screen_test.dart' show company, people;
import 'reimbursements_tab_test.dart' show onTheSoldCar, parking;

/// Downloads that wait to be let through, for a test about the count shown
/// while a pack is being fetched.
class _HeldDownloads extends FakeAttachmentRepository {
  _HeldDownloads(super.stored);

  final gate = Completer<void>();

  @override
  Future<Uint8List> download(Attachment attachment) async {
    await gate.future;
    return super.download(attachment);
  }
}

/// The save dialog, recording what it was handed.
class RecordingSaver {
  final List<String> names = [];
  final List<Uint8List> saved = [];
  bool accept = true;

  /// Held open until completed, for a test about what the tab shows while
  /// a pack with nothing to fetch is still being built.
  Completer<void>? gate;

  Future<bool> call({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    await gate?.future;
    names.add(fileName);
    saved.add(bytes);
    return accept;
  }
}

Future<(RecordingCompanyRepository, RecordingSaver)> pumpPack(
  WidgetTester tester, {
  required List<CostEntry> costs,

  /// Entries on the Passat, which was sold (archived) at the end of June.
  List<CostEntry> soldCarCosts = const [],
  FakeAttachmentRepository? attachments,
  List<VehicleAssignment>? fleet,
  List<HouseholdMember> members = people,
  Household household = company,
  AppFailure? failWith,
  bool acceptSave = true,
  Size surface = const Size(1400, 900),
  Locale? locale,
  double textScale = 1,
}) async {
  final repository = RecordingCompanyRepository(
    // Ana has had the Golf all year; a day before that belongs to nobody.
    fleet:
        fleet ??
        [
          VehicleAssignment(
            id: 'a1',
            vehicleId: 'v1',
            userId: 'u2',
            fromDate: DateTime.utc(2026, 1, 1),
          ),
        ],
    failWith: failWith,
  );
  final saver = RecordingSaver()..accept = acceptSave;
  await pumpScreen(
    tester,
    const CompanyScreen(),
    initialLocation: '/company',
    surface: surface,
    locale: locale,
    textScale: textScale,
    household: household,
    vehicles: [
      testVehicle('v1', nickname: 'Golf'),
      testVehicle('v2', nickname: 'Passat', archived: true),
    ],
    attachments: attachments,
    overrides: [
      companyRepositoryProvider.overrideWithValue(repository),
      membersProvider.overrideWith((ref) async => members),
      todayProvider.overrideWithValue(DateTime(2026, 9, 19)),
      fileSaverProvider.overrideWithValue(saver.call),
      ...vehicleEntryOverrides('v1', costs: costs),
      ...vehicleEntryOverrides('v2', costs: soldCarCosts),
    ],
  );
  await tester.pumpAndSettle();
  // The tab, and not a sidebar link of the same name; on a narrow phone at
  // a large font the strip scrolls, so the tab is brought on screen first.
  final tab = find.descendant(
    of: find.byType(GarageTabBar),
    matching: find.text(
      lookupAppLocalizations(locale ?? const Locale('en')).companyTabPack,
    ),
  );
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
  return (repository, saver);
}

void main() {
  testWidgets('the month\'s entries with no receipt, per car, with a nudge', (
    tester,
  ) async {
    final (repository, _) = await pumpPack(
      tester,
      costs: [
        parking('c1', DateTime.utc(2026, 9, 2)),
        parking('c2', DateTime.utc(2026, 9, 5)),
        parking('august', DateTime.utc(2026, 8, 5)),
      ],
      attachments: FakeAttachmentRepository([
        attachment(kind: AttachmentEntryKind.cost, entryId: 'c2'),
      ]),
    );

    expect(find.byKey(const Key('remind-c1')), findsOneWidget);
    expect(find.byKey(const Key('remind-c2')), findsNothing);
    expect(find.byKey(const Key('remind-august')), findsNothing);
    expect(find.textContaining('Golf · Costs'), findsOneWidget);
    expect(find.textContaining('Driver on this date: Ana'), findsOneWidget);

    await tester.tap(find.byKey(const Key('remind-c1')));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('remind:cost:c1:u2'));
    expect(find.text('Reminder sent to Ana'), findsOneWidget);
  });

  testWidgets('a refused reminder is said', (tester) async {
    await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      failWith: const AppFailure(kind: AppFailureKind.permission),
    );

    await tester.tap(find.byKey(const Key('remind-c1')));
    await tester.pumpAndSettle();

    expect(find.text('Reminder sent to Ana'), findsNothing);
    expect(find.textContaining('You do not have access'), findsOneWidget);
  });

  testWidgets('a day nobody had the car has nobody to remind', (tester) async {
    await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      fleet: const [],
    );

    expect(find.textContaining('Golf · Costs'), findsOneWidget);
    expect(find.byKey(const Key('remind-c1')), findsNothing);
    expect(find.text('No driver assigned on this date'), findsOneWidget);
  });

  testWidgets('a driver who has since left is named as one, not nudged', (
    tester,
  ) async {
    await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      members: const [
        HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
      ],
    );

    expect(find.byKey(const Key('remind-c1')), findsNothing);
    expect(find.textContaining('a former member'), findsOneWidget);
  });

  testWidgets('a car since sold is named on its row like any other', (
    tester,
  ) async {
    await pumpPack(
      tester,
      costs: const [],
      soldCarCosts: [onTheSoldCar('w1', DateTime.utc(2026, 9, 1))],
    );

    expect(find.textContaining('Passat · Costs'), findsOneWidget);
    expect(find.textContaining(' · Costs'), findsOneWidget);
  });

  testWidgets('a month with every receipt says so', (tester) async {
    await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      attachments: FakeAttachmentRepository([
        attachment(kind: AttachmentEntryKind.cost, entryId: 'c1'),
      ]),
    );

    expect(find.text('Every entry this month has a receipt.'), findsOneWidget);
    expect(find.byKey(const Key('build-pack')), findsOneWidget);
  });

  testWidgets('building the pack saves one zip, named for the month', (
    tester,
  ) async {
    final receipt = attachment(
      kind: AttachmentEntryKind.cost,
      entryId: 'c1',
      fileName: 'parking.png',
    );
    final attachments = FakeAttachmentRepository([receipt])
      ..bytesOf['a1'] = onePixel;
    final (_, saver) = await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      attachments: attachments,
    );

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pumpAndSettle();

    expect(saver.names.single, 'garage-accountant-pack-2026-09.zip');
    expect(attachments.calls, contains('download:a1'));
    expect(find.textContaining('Saved'), findsOneWidget);
    final names = ZipDecoder()
        .decodeBytes(saver.saved.single)
        .files
        .map((file) => file.name);
    expect(names, contains('golf/golf-2026-09-ledger.pdf'));
    expect(names, contains('golf/2026-09-02-cost-12.00.png'));
    expect(names, contains('golf/golf-2026-09-cost.csv'));
  });

  testWidgets('backing out of the save dialog is not a success', (
    tester,
  ) async {
    await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      acceptSave: false,
    );

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pumpAndSettle();

    expect(find.text('Pack not saved'), findsOneWidget);
    expect(find.textContaining('Saved'), findsNothing);
  });

  testWidgets('a receipt that cannot be fetched stops the pack', (
    tester,
  ) async {
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.cost, entryId: 'c1'),
    ])..downloadFailsWith = const AppFailure(kind: AppFailureKind.network);
    final (_, saver) = await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      attachments: attachments,
    );

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pumpAndSettle();

    expect(saver.names, isEmpty, reason: 'no half-built pack is saved');
    expect(find.textContaining('No connection'), findsOneWidget);
    // The button is back: the next attempt is one tap away.
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('build-pack')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('another month can be picked, and its pack is named for it', (
    tester,
  ) async {
    final (_, saver) = await pumpPack(
      tester,
      costs: [
        parking('c1', DateTime.utc(2026, 9, 2)),
        parking('august', DateTime.utc(2026, 8, 5)),
      ],
    );
    expect(find.byKey(const Key('remind-august')), findsNothing);

    await tester.tap(find.byKey(const Key('pack-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('August 2026').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remind-august')), findsOneWidget);
    expect(find.byKey(const Key('remind-c1')), findsNothing);

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pumpAndSettle();

    expect(saver.names.single, 'garage-accountant-pack-2026-08.zip');
  });

  testWidgets('the count of receipts fetched is shown while they come', (
    tester,
  ) async {
    final attachments = _HeldDownloads([
      attachment(kind: AttachmentEntryKind.cost, entryId: 'c1'),
    ])..bytesOf['a1'] = onePixel;
    final (_, saver) = await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      attachments: attachments,
    );

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Fetching receipts, 0 of 1'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('build-pack')),
    );
    expect(button.onPressed, isNull);

    attachments.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pack-progress')), findsNothing);
    expect(saver.names, hasLength(1));
  });

  testWidgets('a month with nothing to fetch shows no count', (tester) async {
    final (_, saver) = await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
    );
    saver.gate = Completer<void>();

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pump();
    await tester.pump();

    // Building, and nothing to count: the button is off and no "0 of 0".
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('build-pack')),
    );
    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('pack-progress')), findsNothing);

    saver.gate!.complete();
    await tester.pumpAndSettle();

    expect(saver.names, hasLength(1));
  });

  testWidgets('a pack finished after leaving the tab is let go quietly', (
    tester,
  ) async {
    final attachments = _HeldDownloads([
      attachment(kind: AttachmentEntryKind.cost, entryId: 'c1'),
    ])..bytesOf['a1'] = onePixel;
    final (_, saver) = await pumpPack(
      tester,
      costs: [parking('c1', DateTime.utc(2026, 9, 2))],
      attachments: attachments,
    );
    final failuresBefore = recordedFailures.length;

    await tester.tap(find.byKey(const Key('build-pack')));
    await tester.pump();
    await tester.pump();
    // Away to Settings while the receipts are still coming: the tab is
    // disposed with the ref the save dialog would be read through.
    await tester.tap(
      find.descendant(
        of: find.byType(GarageTabBar),
        matching: find.text('Settings'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('build-pack')), findsNothing);

    attachments.gate.complete();
    await tester.pumpAndSettle();

    expect(saver.names, isEmpty);
    expect(find.textContaining('Something went wrong'), findsNothing);
    expect(recordedFailures.length, failuresBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('in Croatian on a narrow phone at a large font', (tester) async {
    await pumpPack(
      tester,
      costs: [
        parking('c1', DateTime.utc(2026, 9, 2)),
        parking('c0', DateTime.utc(2025, 12, 20)),
      ],
      surface: const Size(320, 2000),
      locale: const Locale('hr'),
      textScale: 1.5,
    );

    expect(tester.takeException(), isNull);
  });
}
