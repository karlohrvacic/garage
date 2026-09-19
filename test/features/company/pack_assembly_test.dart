import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/provider_retry.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/core/sync/read_cache_providers.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/domain/entities/cost_entry.dart';
import 'package:garage/domain/entities/fuel_entry.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/company/providers/company_providers.dart';
import 'package:garage/features/company/providers/pack_assembly.dart';
import 'package:garage/features/household/data/garage_bootstrap_cache.dart';
import 'package:garage/features/household/providers/household_providers.dart';
import 'package:garage/features/household/providers/member_providers.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../support/fake_attachments.dart';
import '../../support/fake_repositories.dart';
import '../../support/pump_screen.dart';
import '../../support/vehicle_entries.dart';
import '../reports/accountant_pack_test.dart' show onePixel;
import 'company_providers_test.dart' show RecordingCompanyRepository;
import 'company_screen_test.dart' show company, people;
import 'reimbursements_tab_test.dart' show parking;

/// A fill-up with no total: not money, so not a ledger row and not an entry
/// whose receipts are fetched.
FuelEntry topUp(String id, DateTime on) {
  return FuelEntry(
    id: id,
    vehicleId: 'v1',
    date: on,
    odometerKm: 61000,
    volumeL: 10,
    fullTank: false,
    missedFill: false,
    createdBy: 'u2',
  );
}

void main() {
  // The ledger's font is an asset.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeDateFormatting);

  final l10n = AppLocalizationsEn();
  final format = UnitFormat(locale: 'en', preferences: metricPreferences);

  /// The console's provider graph over fakes: the Golf, and the Passat
  /// that was sold (archived) at the end of June.
  ProviderContainer scoped({
    Household household = company,
    required List<CostEntry> costs,
    List<FuelEntry> fuel = const [],
    List<CostEntry> soldCarCosts = const [],
    FakeAttachmentRepository? attachments,
  }) {
    final container = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        currentHouseholdProvider.overrideWith((ref) async => household),
        currentUserIdProvider.overrideWithValue('u1'),
        garageBootstrapCacheProvider.overrideWithValue(
          const NoGarageBootstrapCache(),
        ),
        readCacheStoreProvider.overrideWithValue(const NoReadCacheStore()),
        garageBootstrapRepositoryProvider.overrideWithValue(
          FakeGarageBootstrapRepository(
            households: [household],
            vehicles: [
              testVehicle('v1', nickname: 'Golf'),
              testVehicle('v2', nickname: 'Passat', archived: true),
            ],
            roles: {household.id: 'admin'},
          ),
        ),
        companyRepositoryProvider.overrideWithValue(
          RecordingCompanyRepository(
            fleet: [
              VehicleAssignment(
                id: 'a1',
                vehicleId: 'v1',
                userId: 'u2',
                fromDate: DateTime.utc(2026, 1, 1),
              ),
            ],
          ),
        ),
        membersProvider.overrideWith((ref) async => people),
        attachmentRepositoryProvider.overrideWithValue(
          attachments ?? FakeAttachmentRepository(),
        ),
        ...vehicleEntryOverrides('v1', costs: costs, fuel: fuel),
        ...vehicleEntryOverrides('v2', costs: soldCarCosts),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Archive> build(
    ProviderContainer container, {
    DateTime? month,
    PackProgress? onProgress,
  }) async {
    final bytes = await container
        .read(accountantPackAssemblyProvider)
        .build(
          month: month ?? DateTime.utc(2026, 9),
          locale: 'en',
          l10n: l10n,
          format: format,
          onProgress: onProgress,
        );
    return ZipDecoder().decodeBytes(bytes);
  }

  List<String> names(Archive archive) =>
      archive.files.map((file) => file.name).toList();

  test(
    'every car in the month, its receipts fetched, counted as they come',
    () async {
      final attachments = FakeAttachmentRepository([
        attachment(kind: AttachmentEntryKind.cost, entryId: 'c1'),
        attachment(
          id: 'a2',
          kind: AttachmentEntryKind.cost,
          entryId: 'c2',
          fileName: 'wash.png',
        ),
      ])..bytesOf.addAll({'a1': onePixel, 'a2': onePixel});
      final progress = <(int, int)>[];
      final archive = await build(
        scoped(
          costs: [
            parking('c1', DateTime.utc(2026, 9, 2)),
            parking('c2', DateTime.utc(2026, 9, 5)),
            parking('c3', DateTime.utc(2026, 9, 9)),
          ],
          attachments: attachments,
        ),
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(names(archive), contains('golf/golf-2026-09-ledger.pdf'));
      expect(names(archive), contains('golf/2026-09-02-cost-12.00.jpg'));
      expect(names(archive), contains('golf/2026-09-05-cost-12.00.png'));
      expect(progress, [(0, 2), (1, 2), (2, 2)]);
      // One round trip per entry that has something, none for the rest.
      expect(attachments.calls, contains('forEntry:cost:c1'));
      expect(attachments.calls, contains('forEntry:cost:c2'));
      expect(attachments.calls, isNot(contains('forEntry:cost:c3')));
    },
  );

  test('a car since sold is in the pack for the month it still ran', () async {
    final june = await build(
      scoped(
        costs: const [],
        soldCarCosts: [
          CostEntry(
            id: 'w1',
            vehicleId: 'v2',
            date: DateTime.utc(2026, 6, 10),
            category: CostCategories.wash,
            amount: 8,
            createdBy: 'u2',
          ),
        ],
      ),
      month: DateTime.utc(2026, 6),
    );

    expect(names(june), contains('passat/passat-2026-06-ledger.pdf'));
    expect(names(june), contains('golf/golf-2026-06-ledger.pdf'));
  });

  test('and out of it for a month it did not', () async {
    final september = await build(scoped(costs: const []));

    expect(names(september), contains('golf/golf-2026-09-ledger.pdf'));
    expect(
      names(september).where((name) => name.startsWith('passat')),
      isEmpty,
    );
  });

  test('a fill-up with no total has no receipt to fetch', () async {
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.fuel, entryId: 'f1'),
    ]);
    await build(
      scoped(
        costs: const [],
        fuel: [topUp('f1', DateTime.utc(2026, 9, 4))],
        attachments: attachments,
      ),
    );

    expect(attachments.calls, isNot(contains('forEntry:fuel:f1')));
    expect(attachments.calls, isNot(contains('download:a1')));
  });

  test('a download that fails fails the build', () async {
    final attachments = FakeAttachmentRepository([
      attachment(kind: AttachmentEntryKind.cost, entryId: 'c1'),
    ])..downloadFailsWith = const AppFailure(kind: AppFailureKind.network);

    await expectLater(
      build(
        scoped(
          costs: [parking('c1', DateTime.utc(2026, 9, 2))],
          attachments: attachments,
        ),
      ),
      throwsA(
        isA<AppFailure>().having(
          (it) => it.kind,
          'kind',
          AppFailureKind.network,
        ),
      ),
    );
  });

  test('the letterhead is the company name and OIB, or nothing', () {
    expect(
      letterheadOf(
        const Household(
          id: 'h1',
          name: 'Prijevoz',
          plan: 'company',
          companyName: 'Prijevoz d.o.o.',
          companyOib: '12345678901',
        ),
      ),
      'Prijevoz d.o.o. · 12345678901',
    );
    expect(
      letterheadOf(
        const Household(
          id: 'h1',
          name: 'Prijevoz',
          plan: 'company',
          companyName: 'Prijevoz d.o.o.',
        ),
      ),
      'Prijevoz d.o.o.',
    );
    expect(letterheadOf(company), isNull);
    expect(letterheadOf(null), isNull);
  });

  test('the bytes are a zip', () async {
    final bytes = await scoped(costs: const [])
        .read(accountantPackAssemblyProvider)
        .build(
          month: DateTime.utc(2026, 9),
          locale: 'en',
          l10n: l10n,
          format: format,
        );

    expect(bytes, isA<Uint8List>());
    expect(bytes.sublist(0, 2), [0x50, 0x4b]);
  });
}
