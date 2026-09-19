import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/read_cache.dart';
import 'package:garage/core/sync/read_cache_providers.dart';
import 'package:garage/core/sync/read_cache_store.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/stale_reads_banner.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:riverpod/misc.dart' show Override;

Future<ValueNotifier<StaleReads>> pumpBanner(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  ValueNotifier<StaleReads>? stale,
  List<Override> overrides = const [],
}) async {
  stale ??= ValueNotifier(const StaleReads({}));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [staleReadsProvider.overrideWithValue(stale), ...overrides],
      child: MaterialApp(
        theme: GarageTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: StaleReadsBanner()),
      ),
    ),
  );
  await tester.pump();
  return stale;
}

void main() {
  testWidgets('is nothing while every read is fresh', (tester) async {
    await pumpBanner(tester);

    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('names the oldest copy once something is served stale', (
    tester,
  ) async {
    final stale = await pumpBanner(tester);

    stale.value = StaleReads({
      'fuel/v1': DateTime(2026, 9, 18, 14, 2),
      'costs/v1': DateTime(2026, 9, 18, 16, 30),
    });
    await tester.pump();

    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.textContaining('14:02'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('goes when the reads are fresh again', (tester) async {
    final stale = await pumpBanner(tester);
    stale.value = StaleReads({'fuel/v1': DateTime(2026, 9, 18, 14, 2)});
    await tester.pump();

    stale.value = const StaleReads({});
    await tester.pump();

    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('Retry clears the banner, even for a list nothing shows', (
    tester,
  ) async {
    // A mark belongs to a list that was on screen when the copy was served.
    // Invalidating refetches only what is still watched, so a mark left by a
    // closed screen has to be dropped by Retry itself or the banner stays
    // "Offline" while online.
    final cache = ReadCache(
      store: InMemoryReadCacheStore(),
      userId: () => 'u1',
    );
    await cache.rows(
      'costs/v1',
      () async => [
        {'id': 'c1'},
      ],
    );
    await cache.rows(
      'costs/v1',
      () async => throw const AppFailure(kind: AppFailureKind.network),
    );
    await pumpBanner(
      tester,
      stale: cache.stale,
      overrides: [readCacheProvider.overrideWithValue(cache)],
    );
    expect(find.textContaining('Offline'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('reads naturally in Croatian at 320px and 1.5x', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final stale = await pumpBanner(tester, locale: const Locale('hr'));

    stale.value = StaleReads({'fuel/v1': DateTime(2026, 9, 18, 14, 2)});
    await tester.pump();

    expect(find.textContaining('Nema veze'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
