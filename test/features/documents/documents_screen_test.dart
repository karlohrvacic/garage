import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/clock.dart';
import 'package:garage/core/widgets/adaptive.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/features/documents/providers/document_providers.dart';
import 'package:garage/features/documents/screens/documents_screen.dart';
import 'package:garage/features/settings/providers/unit_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../support/fake_documents.dart';
import '../../support/pump_screen.dart' show testVehicle;

final _today = DateTime.utc(2026, 9, 4);

VehicleDocument document({
  required String id,
  required DocumentType type,
  DateTime? expiresOn,
  String? number,
  String? label,
}) {
  return VehicleDocument(
    id: id,
    vehicleId: 'v1',
    type: type,
    createdBy: 'u1',
    expiresOn: expiresOn,
    number: number,
    label: label,
  );
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeDocumentRepository repository, {
  Size surface = const Size(500, 1400),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = surface;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentRepositoryProvider.overrideWithValue(repository),
        todayProvider.overrideWithValue(_today),
        vehicleProvider(
          'v1',
        ).overrideWith((ref) async => testVehicle('v1', nickname: 'Golf')),
        unitPreferencesProvider.overrideWithValue(
          const UnitPreferences(
            distance: DistanceUnit.km,
            volume: VolumeUnit.liter,
            currencyCode: 'EUR',
          ),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // copyWith, not a fresh MediaQueryData: a bare one has a zero size,
        // and every adaptive layout in this app asks how wide the window is.
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: const DocumentsScreen(vehicleId: 'v1'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the title names the car', (tester) async {
    await pumpScreen(tester, FakeDocumentRepository());
    await tester.pumpAndSettle();

    expect(find.text('Golf · Documents'), findsOneWidget);
  });

  testWidgets('a car with no paperwork says what to record', (tester) async {
    await pumpScreen(tester, FakeDocumentRepository());

    expect(find.textContaining('No documents yet'), findsOneWidget);
  });

  testWidgets('and offers the way out rather than describing one', (
    tester,
  ) async {
    // Every other empty list in this app has the button in it. This one is
    // empty for every household until somebody types their first expiry, so
    // it is the first screen a person sees and the least useful place for a
    // dead end.
    await pumpScreen(tester, FakeDocumentRepository());

    expect(find.widgetWithText(FilledButton, 'Add document'), findsOneWidget);
  });

  testWidgets('and offers it exactly once', (tester) async {
    // Caught by running the app: the floating button and the empty state's
    // own button were both on screen, which is the same offer twice on the
    // first screen anybody sees here.
    await pumpScreen(tester, FakeDocumentRepository());

    expect(find.text('Add document'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('and floats it once the list has something in it', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        document(
          id: 'reg',
          type: DocumentType.registration,
          expiresOn: DateTime.utc(2027, 6, 3),
        ),
      ]),
    );

    expect(find.byKey(const Key('document-add')), findsOneWidget);
  });

  testWidgets('an expired certificate says so, and leads the list', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        document(
          id: 'far',
          type: DocumentType.insuranceLiability,
          expiresOn: DateTime.utc(2027, 3, 1),
        ),
        document(
          id: 'gone',
          type: DocumentType.roadworthiness,
          expiresOn: DateTime.utc(2026, 6, 1),
        ),
      ]),
    );

    expect(find.textContaining('Expired'), findsOneWidget);

    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles.first, 'Roadworthiness test');
  });

  testWidgets('one inside the notice window counts down the days', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        document(
          id: 'soon',
          type: DocumentType.registration,
          expiresOn: DateTime.utc(2026, 9, 14),
        ),
      ]),
    );

    expect(find.text('Expires in 10 days'), findsOneWidget);
  });

  testWidgets('one with no date recorded says that, not "valid"', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        document(id: 'undated', type: DocumentType.greenCard),
      ]),
    );

    expect(find.text('No expiry recorded'), findsOneWidget);
  });

  testWidgets('a document the app has no name for wears its own', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        document(
          id: 'other',
          type: DocumentType.other,
          label: 'Lease agreement',
          expiresOn: DateTime.utc(2028, 1, 1),
        ),
      ]),
    );

    expect(find.text('Lease agreement'), findsOneWidget);
  });

  testWidgets('the number on the paper is shown under the date', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        document(
          id: 'reg',
          type: DocumentType.registration,
          number: 'HR-4451/26',
          expiresOn: DateTime.utc(2027, 6, 3),
        ),
      ]),
    );

    expect(find.text('HR-4451/26'), findsOneWidget);
  });

  group('the layout survives a hostile window', () {
    /// Every type, all dated, one of them with a long name of its own — the
    /// widest this list gets in practice.
    FakeDocumentRepository crowded() => FakeDocumentRepository([
      for (final (index, type) in DocumentType.values.indexed)
        document(
          id: 'd$index',
          type: type,
          number: 'HR-4451/26-000$index',
          label: type == DocumentType.other
              ? 'Ugovor o leasingu s Erste Bankom'
              : null,
          expiresOn: DateTime.utc(2026, 9, 4 + index * 40),
        ),
    ]);

    testWidgets('a narrow phone at the largest text', (tester) async {
      // A RenderFlex overflow throws here rather than painting stripes
      // nobody in CI can see, which is the only way this gets checked at all.
      await pumpScreen(
        tester,
        crowded(),
        surface: const Size(320, 900),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('and a desktop window at the largest text', (tester) async {
      await pumpScreen(
        tester,
        crowded(),
        surface: const Size(1280, 800),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('and the empty state on the narrowest phone', (tester) async {
      await pumpScreen(
        tester,
        FakeDocumentRepository(),
        surface: const Size(320, 640),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('on a desktop window', () {
    testWidgets('the list is capped, not stretched across the monitor', (
      tester,
    ) async {
      // A document row is a two-ended row: a name on the left and a chevron
      // on the right. Across a 1500-pixel window those two ends are a hand's
      // width apart and the row stops reading as one thing — which is why
      // this screen takes reading width and not the dashboard's, exactly like
      // the tyres screen it sits beside.
      await pumpScreen(
        tester,
        FakeDocumentRepository([
          document(
            id: 'reg',
            type: DocumentType.registration,
            number: 'HR-4451/26',
            expiresOn: DateTime.utc(2027, 6, 3),
          ),
        ]),
        surface: const Size(1500, 1000),
      );

      expect(
        tester.getSize(find.byType(ListView)).width,
        lessThanOrEqualTo(GarageBreakpoints.contentMaxWidth),
      );
    });

    testWidgets('and a phone uses the whole width it has', (tester) async {
      await pumpScreen(
        tester,
        FakeDocumentRepository([
          document(
            id: 'reg',
            type: DocumentType.registration,
            expiresOn: DateTime.utc(2027, 6, 3),
          ),
        ]),
        surface: const Size(400, 900),
      );

      expect(tester.getSize(find.byType(ListView)).width, 400);
    });

    testWidgets('the empty state is centred rather than left-hugging', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        FakeDocumentRepository(),
        surface: const Size(1500, 1000),
      );

      // Centred in the *content area*, not in the window: a wide window puts
      // a navigation rail down the left, so the two centres are 120 pixels
      // apart and only one of them is the right answer.
      final button = find.widgetWithText(FilledButton, 'Add document');
      final content = find.ancestor(
        of: button,
        matching: find.byType(SingleChildScrollView),
      );

      expect(
        (tester.getCenter(button).dx - tester.getCenter(content.first).dx)
            .abs(),
        lessThan(1),
      );
    });
  });

  testWidgets('a long list is built lazily, not all on the first frame', (
    tester,
  ) async {
    // `other` is the one type a vehicle may hold any number of, so this list
    // has no ceiling. The repo has already paid for the eager version once:
    // "Every log built its whole history on the first frame".
    await pumpScreen(
      tester,
      FakeDocumentRepository([
        for (var i = 0; i < 60; i++)
          document(
            id: 'd$i',
            type: DocumentType.other,
            label: 'Paper $i',
            expiresOn: DateTime.utc(2027, 1, 1).add(Duration(days: i)),
          ),
      ]),
      surface: const Size(400, 800),
    );

    expect(find.text('Paper 0'), findsOneWidget);
    expect(
      find.byType(Card),
      findsAtLeastNWidgets(1),
      reason: 'the list rendered nothing at all',
    );
    expect(
      tester.widgetList(find.byType(Card)).length,
      lessThan(60),
      reason: 'every row was built for a window that shows a handful',
    );
  });
}
