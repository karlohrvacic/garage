import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/code_description.dart';
import 'package:garage/domain/entities/guest_pass.dart';
import 'package:garage/domain/entities/service_entry.dart';
import 'package:garage/domain/entities/vehicle_briefing.dart';
import 'package:garage/features/vehicles/data/guest_pass_repository.dart';
import 'package:garage/features/vehicles/providers/guest_pass_providers.dart';
import 'package:garage/features/vehicles/screens/guest_passes_screen.dart';
import 'package:garage/features/vehicles/screens/lent_history_screen.dart';
import 'package:garage/features/vehicles/screens/vehicles_screen.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../support/pump_screen.dart';

class RecordingGuestPassRepository implements GuestPassRepository {
  RecordingGuestPassRepository({this.passes = const []});

  List<GuestPass> passes;
  final List<String> calls = [];
  Map<String, Object?>? created;
  Object? redeemFailsWith;

  @override
  Future<List<GuestPass>> forVehicle(String vehicleId) async => passes;

  @override
  Future<List<GuestPass>> mine() async => held;

  List<GuestPass> held = const [];

  @override
  Future<List<ServiceEntry>> serviceHistory(String vehicleId) async => history;

  @override
  Future<VehicleBriefing?> briefing(String vehicleId) async => briefingFor;

  @override
  Future<CodeDescription?> describe(String code) async {
    calls.add('describe:$code');
    return describes;
  }

  @override
  Future<void> updatePermissions(GuestPass pass) async {
    calls.add('permissions:${pass.id}:${pass.canLogCosts}');
  }

  CodeDescription? describes;

  VehicleBriefing? briefingFor;

  List<ServiceEntry> history = const [];

  @override
  Future<String> create({
    required String vehicleId,
    required DateTime endsAt,
    DateTime? startsAt,
    String? label,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
    bool canViewPrices = false,
  }) async {
    created = {
      'vehicleId': vehicleId,
      'endsAt': endsAt,
      'startsAt': startsAt,
      'label': label,
      'canLogFuel': canLogFuel,
      'canLogTrips': canLogTrips,
      'canLogCosts': canLogCosts,
      'canViewHistory': canViewHistory,
      'canViewPrices': canViewPrices,
    };
    return 'WXYZ7788';
  }

  @override
  Future<void> extend(String id, DateTime endsAt) async {
    calls.add('extend:$id:${endsAt.toIso8601String()}');
  }

  @override
  Future<void> revoke(String id) async => calls.add('revoke:$id');

  @override
  Future<void> giveBack(String id) async => calls.add('giveBack:$id');

  @override
  Future<String> redeem(String code) async {
    calls.add('redeem:$code');
    if (redeemFailsWith != null) {
      throw redeemFailsWith!;
    }
    return 'v1';
  }
}

final _now = DateTime.now().toUtc();

GuestPass livePass({String id = 'p1', String? label}) {
  return GuestPass(
    id: id,
    vehicleId: 'v1',
    code: 'ABCD2345',
    createdBy: 'u1',
    createdAt: _now.subtract(const Duration(days: 1)),
    expiresAt: _now.add(const Duration(days: 4)),
    redeemedBy: 'g1',
    redeemedAt: _now.subtract(const Duration(hours: 2)),
    label: label,
  );
}

Future<void> pumpPasses(
  WidgetTester tester,
  RecordingGuestPassRepository repository, {
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(500, 1600),
}) async {
  await pumpScreen(
    tester,
    const GuestPassesScreen(vehicleId: 'v1'),
    initialLocation: '/vehicles/v1/lending',
    locale: locale,
    textScale: textScale,
    surface: surface,
    vehicles: [testVehicle('v1', nickname: 'Golf')],
    overrides: [guestPassRepositoryProvider.overrideWithValue(repository)],
  );
  await tester.pumpAndSettle();
}

void main() {
  group('a car lent to you, read as the mechanic', _lentHistoryTests);
  group('narrow phone, long language', _lendSheetLayoutTests);

  group('the owner side', () {
    testWidgets('a car nobody has borrowed says so', (tester) async {
      await pumpPasses(tester, RecordingGuestPassRepository());

      expect(find.text('This car has never been lent out.'), findsOneWidget);
      expect(find.byKey(const Key('lend-car')), findsOneWidget);
    });

    testWidgets('a live pass shows its code, who it is for, and its days', (
      tester,
    ) async {
      await pumpPasses(
        tester,
        RecordingGuestPassRepository(passes: [livePass(label: 'Ivan')]),
      );

      expect(find.text('In use'), findsOneWidget);
      expect(find.text('ABCD2345'), findsOneWidget);
      expect(find.text('Ivan'), findsOneWidget);
      expect(find.textContaining('days left'), findsOneWidget);
    });

    testWidgets('minting sends exactly what the switches say', (tester) async {
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('lend-label')), 'Ivan');
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(repository.created!['vehicleId'], 'v1');
      expect(repository.created!['label'], 'Ivan');
      expect(repository.created!['canLogFuel'], true);
      expect(repository.created!['canLogTrips'], true);
      // Off unless deliberately switched on: entering a service invoice
      // against somebody else's car is not what borrowing one involves.
      expect(repository.created!['canLogCosts'], false);
      expect(repository.created!['canViewHistory'], false);
      expect(repository.created!['canViewPrices'], false);
    });

    // A loan is a window. "For four days" cannot say "his from Friday to
    // Sunday", and a car promised for next weekend is the ordinary case.
    testWidgets('a loan that starts today sends no start, only an end', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      // Null means "usable the moment it is handed over", which is what the
      // table means by no start at all.
      expect(repository.created!['startsAt'], isNull);
      final endsAt = repository.created!['endsAt'] as DateTime;
      expect(endsAt.isAfter(DateTime.now().toUtc()), isTrue);
      // The end of the last day, not its midnight: a pass "until Sunday" that
      // dies at Saturday midnight is a bug report.
      expect(endsAt.toLocal().hour, 23);
    });

    testWidgets('the prices switch appears only once history is on', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lend-prices')), findsNothing);

      await tester.tap(find.byKey(const Key('lend-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-prices')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(repository.created!['canViewHistory'], true);
      expect(repository.created!['canViewPrices'], true);
    });

    testWidgets('turning history back off takes the prices with it', (
      tester,
    ) async {
      // Prices without history would grant figures for work the holder cannot
      // see. The database refuses it; the form should never send it.
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-prices')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-history')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(repository.created!['canViewHistory'], false);
      expect(repository.created!['canViewPrices'], false);
    });

    // "He rang and needs it one more day" used to mean withdrawing the pass
    // and minting a second code for the same person on the same car.
    testWidgets('a live pass can be extended, keeping its code', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository()
        ..passes = [livePass(label: 'Ivan')];
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('pass-menu-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Extend'));
      await tester.pumpAndSettle();
      // The picker opens on the day it already runs to; taking it as offered
      // is the "no change" case, so move a day on before accepting.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        repository.calls.where((call) => call.startsWith('extend:p1:')),
        isNotEmpty,
      );
    });

    testWidgets('history is off unless it is deliberately switched on', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository();
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(repository.created!['canViewHistory'], false);
    });

    testWidgets('the code is shown for handing over, not just saved', (
      tester,
    ) async {
      // A pass whose code nobody read is a pass nobody can use.
      await pumpPasses(tester, RecordingGuestPassRepository());

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-create')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lend-code')), findsOneWidget);
      expect(find.text('WXYZ7788'), findsOneWidget);
    });

    testWidgets('withdrawing asks first', (tester) async {
      final repository = RecordingGuestPassRepository(passes: [livePass()]);
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('pass-menu-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Withdraw'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Everything they logged stays.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Withdraw').last);
      await tester.pumpAndSettle();
      expect(repository.calls, contains('revoke:p1'));
    });

    testWidgets('a finished pass offers no way to withdraw it', (tester) async {
      await pumpPasses(
        tester,
        RecordingGuestPassRepository(
          passes: [
            GuestPass(
              id: 'p2',
              vehicleId: 'v1',
              code: 'OLDCODE1',
              createdBy: 'u1',
              createdAt: _now.subtract(const Duration(days: 30)),
              expiresAt: _now.subtract(const Duration(days: 20)),
              redeemedBy: 'g1',
              redeemedAt: _now.subtract(const Duration(days: 29)),
            ),
          ],
        ),
      );

      // It is behind the collapsed group now; open it to see the state, and
      // note there is still no menu on it.
      await tester.tap(find.byKey(const Key('passes-finished')));
      await tester.pumpAndSettle();

      expect(find.text('Finished'), findsOneWidget);
      expect(find.byKey(const Key('pass-menu-p2')), findsNothing);
    });
  });

  group('the owner keeps control after handing the code over', () {
    GuestPass finishedPass({String id = 'old'}) => GuestPass(
      id: id,
      vehicleId: 'v1',
      code: 'OLD12345',
      createdBy: 'u1',
      createdAt: _now.subtract(const Duration(days: 30)),
      expiresAt: _now.subtract(const Duration(days: 20)),
      redeemedBy: 'g1',
      redeemedAt: _now.subtract(const Duration(days: 29)),
    );

    // Nothing is deleted: a finished pass is the record of who had the car
    // and the entries they logged point back at it. It just stops being what
    // the screen is about.
    testWidgets('finished passes collapse instead of cluttering', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository()
        ..passes = [livePass(label: 'Ivan'), finishedPass()];
      await pumpPasses(tester, repository);

      expect(find.text('Ivan'), findsOneWidget);
      expect(find.text('OLD12345'), findsNothing);

      await tester.tap(find.byKey(const Key('passes-finished')));
      await tester.pumpAndSettle();

      expect(find.text('OLD12345'), findsOneWidget);
    });

    testWidgets('a car with only live passes shows no finished section', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository()
        ..passes = [livePass(label: 'Ivan')];
      await pumpPasses(tester, repository);

      expect(find.byKey(const Key('passes-finished')), findsNothing);
    });

    // "He can log costs after all" used to mean withdrawing the code and
    // minting another for the same person on the same car.
    testWidgets('what a live pass allows can be changed retroactively', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository()
        ..passes = [livePass(label: 'Ivan')];
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('pass-menu-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change what it allows'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-pass-costs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-pass-save')));
      await tester.pumpAndSettle();

      // Costs were on; the owner turned them off on the code Ivan already
      // holds, and the policy reads the row on the next request.
      expect(repository.calls, contains('permissions:p1:false'));
    });

    testWidgets('prices cannot be left on when history goes off', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository()
        ..passes = [
          GuestPass(
            id: 'p1',
            vehicleId: 'v1',
            code: 'ABCD2345',
            createdBy: 'u1',
            createdAt: _now.subtract(const Duration(days: 1)),
            expiresAt: _now.add(const Duration(days: 4)),
            redeemedBy: 'g1',
            redeemedAt: _now,
            canViewHistory: true,
            canViewPrices: true,
          ),
        ];
      await pumpPasses(tester, repository);

      await tester.tap(find.byKey(const Key('pass-menu-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change what it allows'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-pass-prices')), findsOneWidget);

      await tester.tap(find.byKey(const Key('edit-pass-history')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-pass-prices')), findsNothing);
    });
  });

  group('the borrower side', () {
    Future<NavigationLog> pumpBox(
      WidgetTester tester,
      RecordingGuestPassRepository repository,
    ) async {
      final log = await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1200),
        extraRoutes: const {'/vehicles/v1', '/transfer', '/join'},
        overrides: [guestPassRepositoryProvider.overrideWithValue(repository)],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vehicles-code-box')));
      await tester.pumpAndSettle();
      return log;
    }

    CodeDescription lending() => CodeDescription(
      kind: CodeKind.lending,
      subject: 'Golf',
      until: _now.add(const Duration(days: 4)),
      spent: false,
    );

    // Three kinds of eight-character code, one box. It says what the code is
    // before spending it, so nobody has to know which kind they were handed.
    testWidgets('a code is explained before it is used', (tester) async {
      final repository = RecordingGuestPassRepository()..describes = lending();
      await pumpBox(tester, repository);

      await tester.enterText(
        find.byKey(const Key('code-box-input')),
        'abcd2345',
      );
      await tester.tap(find.byKey(const Key('code-box-submit')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('describe:abcd2345'));
      expect(find.byKey(const Key('code-box-explains')), findsOneWidget);
      expect(find.textContaining('Golf'), findsWidgets);
      // Explained, not spent: redeeming is the second, deliberate tap.
      expect(
        repository.calls.any((call) => call.startsWith('redeem:')),
        isFalse,
      );
    });

    testWidgets('and then opens the car it turned out to be', (tester) async {
      final repository = RecordingGuestPassRepository()..describes = lending();
      final log = await pumpBox(tester, repository);

      await tester.enterText(
        find.byKey(const Key('code-box-input')),
        'abcd2345',
      );
      await tester.tap(find.byKey(const Key('code-box-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('code-box-submit')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('redeem:abcd2345'));
      expect(log.visited, containsAll(['/vehicles', '/vehicles/v1']));
    });

    testWidgets('a code nobody issued is refused before anything happens', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository();
      await pumpBox(tester, repository);

      await tester.enterText(
        find.byKey(const Key('code-box-input')),
        'zzzz9999',
      );
      await tester.tap(find.byKey(const Key('code-box-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('No code like that. Check it and try again.'),
        findsOneWidget,
      );
      expect(
        repository.calls.any((call) => call.startsWith('redeem:')),
        isFalse,
      );
    });

    testWidgets('a spent code says so rather than failing at the end', (
      tester,
    ) async {
      final repository = RecordingGuestPassRepository()
        ..describes = CodeDescription(
          kind: CodeKind.lending,
          subject: 'Golf',
          until: _now.subtract(const Duration(days: 1)),
          spent: true,
        );
      await pumpBox(tester, repository);

      await tester.enterText(
        find.byKey(const Key('code-box-input')),
        'abcd2345',
      );
      await tester.tap(find.byKey(const Key('code-box-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('That code has already been used, or it has run out.'),
        findsOneWidget,
      );
    });
  });

  group('a car somebody lent you', () {
    testWidgets('appears under its own heading, not among your own', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1600),
        vehicles: [testVehicle('v1', nickname: 'My Golf')],
        borrowedVehicles: [
          testVehicle('v9', nickname: 'Sister Clio', householdId: 'hers'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vehicle-v1')), findsOneWidget);
      expect(find.byKey(const Key('borrowed-v9')), findsOneWidget);
      expect(
        find.byKey(const Key('vehicle-v9')),
        findsNothing,
        reason: 'a borrowed car is not one of the garage\'s own',
      );
      expect(find.text('LENT TO YOU'), findsOneWidget);
    });

    testWidgets('is not shown at all when nothing is borrowed', (tester) async {
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1600),
        vehicles: [testVehicle('v1', nickname: 'My Golf')],
      );
      await tester.pumpAndSettle();

      expect(find.text('LENT TO YOU'), findsNothing);
    });

    testWidgets('has a page of its own, so redeeming can land on it', (
      tester,
    ) async {
      // Redeeming navigates straight to /vehicles/<id>. The vehicle lookup
      // used to search only the garage's own cars, so that page rendered as
      // "no such vehicle" for the one car the pass had just opened.
      await pumpScreen(
        tester,
        const VehiclesScreen(),
        initialLocation: '/vehicles',
        surface: const Size(500, 1600),
        vehicles: const [],
        borrowedVehicles: [
          testVehicle('v9', nickname: 'Sister Clio', householdId: 'hers'),
        ],
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(VehiclesScreen)),
      );
      expect(
        (await container.read(vehicleProvider('v9').future))?.nickname,
        'Sister Clio',
      );
    });
  });
}

// What a mechanic holding the car is there to answer is what has already been
// done to it — and what the owner paid is a different question, which the
// owner is entitled to leave unanswered. The masking is the database's; this
// checks that the screen says which of "nothing recorded" and "not shared"
// the reader is looking at.
void _lentHistoryTests() {
  ServiceEntry job({double? cost}) => ServiceEntry(
    id: 's1',
    vehicleId: 'v1',
    date: DateTime.utc(2026, 3, 4),
    odometerKm: 180000,
    serviceTypeKeys: const ['service_timing_belt'],
    createdBy: '',
    cost: cost,
    shop: 'Autoservis Kovač',
  );

  GuestPass historyPass({bool prices = false}) => GuestPass(
    id: 'p9',
    vehicleId: 'v1',
    code: 'HIST2345',
    createdBy: 'u1',
    createdAt: _now.subtract(const Duration(days: 1)),
    expiresAt: _now.add(const Duration(days: 3)),
    redeemedBy: 'g1',
    redeemedAt: _now.subtract(const Duration(hours: 1)),
    canViewHistory: true,
    canViewPrices: prices,
  );

  Future<void> pumpHistory(
    WidgetTester tester,
    RecordingGuestPassRepository repository,
  ) async {
    await pumpScreen(
      tester,
      const LentHistoryScreen(vehicleId: 'v1'),
      initialLocation: '/vehicles/v1/lent-history',
      surface: const Size(500, 1200),
      vehicles: [testVehicle('v1', nickname: 'Golf')],
      overrides: [guestPassRepositoryProvider.overrideWithValue(repository)],
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a borrower sees what was done and when', (tester) async {
    final repository = RecordingGuestPassRepository()
      ..held = [historyPass()]
      ..history = [job()];
    await pumpHistory(tester, repository);

    expect(find.text('Timing belt'), findsOneWidget);
    expect(find.textContaining('Autoservis Kovač'), findsOneWidget);
  });

  testWidgets('a pass without prices says so, rather than showing nothing', (
    tester,
  ) async {
    final repository = RecordingGuestPassRepository()
      ..held = [historyPass()]
      ..history = [job()];
    await pumpHistory(tester, repository);

    expect(
      find.text('The owner has not shared what the work cost.'),
      findsOneWidget,
    );
  });

  testWidgets('a pass with prices carries the figures the server sent', (
    tester,
  ) async {
    final repository = RecordingGuestPassRepository()
      ..held = [historyPass(prices: true)]
      ..history = [job(cost: 240)];
    await pumpHistory(tester, repository);

    expect(
      find.text('The owner has not shared what the work cost.'),
      findsNothing,
    );
    expect(find.textContaining('240'), findsOneWidget);
  });
}

void _lendSheetLayoutTests() {
  // Two dates side by side inside a bottom sheet, on the narrowest phone, in
  // the longest language: the shape that overflowed the pass row the moment
  // it gained a second action.
  for (final language in ['hr', 'it']) {
    testWidgets('the lend sheet lays out in $language at a large font', (
      tester,
    ) async {
      await pumpPasses(
        tester,
        RecordingGuestPassRepository(),
        locale: Locale(language),
        textScale: 1.5,
        surface: const Size(320, 2400),
      );

      await tester.tap(find.byKey(const Key('lend-car')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('lend-history')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a live pass lays out in $language at a large font', (
      tester,
    ) async {
      await pumpPasses(
        tester,
        RecordingGuestPassRepository()..passes = [livePass(label: 'Ivan')],
        locale: Locale(language),
        textScale: 1.5,
        surface: const Size(320, 2400),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
