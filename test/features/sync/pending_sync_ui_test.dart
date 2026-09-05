import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/sync/pending_write.dart';
import 'package:garage/core/sync/write_queue.dart';
import 'package:garage/features/sync/screens/pending_sync_screen.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/sync/sync_providers.dart';
import 'package:garage/features/sync/widgets/pending_sync_banner.dart';

import '../../support/pump_screen.dart';

PendingWrite waiting(
  String id, {
  PendingWriteKind kind = PendingWriteKind.fuel,
}) {
  return PendingWrite(
    id: id,
    kind: kind,
    vehicleId: 'v1',
    row: {'id': id, 'vehicle_id': 'v1'},
    queuedAt: DateTime.utc(2026, 9, 5, 7, 30),
  );
}

Future<InMemoryPendingWriteStore> storeWith(List<PendingWrite> writes) async {
  final store = InMemoryPendingWriteStore();
  for (final write in writes) {
    await store.put(write);
  }
  return store;
}

void main() {
  group('the banner', () {
    testWidgets('says nothing when nothing is waiting', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: PendingSyncBanner()),
        surface: const Size(420, 800),
        pendingWrites: await storeWith([]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pending-sync-banner')), findsNothing);
    });

    testWidgets('counts what is on the phone', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: PendingSyncBanner()),
        surface: const Size(420, 800),
        pendingWrites: await storeWith([waiting('a'), waiting('b')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 entries are waiting to sync'), findsOneWidget);
    });

    testWidgets('one entry is not "1 entries"', (tester) async {
      await pumpScreen(
        tester,
        const Scaffold(body: PendingSyncBanner()),
        surface: const Size(420, 800),
        pendingWrites: await storeWith([waiting('a')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 entry is waiting to sync'), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('names what each waiting entry is', (tester) async {
      await pumpScreen(
        tester,
        const PendingSyncScreen(),
        initialLocation: '/pending',
        surface: const Size(420, 1000),
        pendingWrites: await storeWith([
          waiting('a'),
          waiting('b', kind: PendingWriteKind.odometer),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fill-up'), findsOneWidget);
      expect(find.text('Odometer reading'), findsOneWidget);
      expect(find.byKey(const Key('pending-a')), findsOneWidget);
    });

    testWidgets('an empty queue says everything went', (tester) async {
      await pumpScreen(
        tester,
        const PendingSyncScreen(),
        initialLocation: '/pending',
        surface: const Size(420, 1000),
        pendingWrites: await storeWith([]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Everything has been sent.'), findsOneWidget);
    });

    testWidgets('retrying with no connection says so, and keeps the entry', (
      tester,
    ) async {
      // A button that reports nothing reads as a button that does nothing.
      final store = await storeWith([waiting('a')]);
      await pumpScreen(
        tester,
        const PendingSyncScreen(),
        initialLocation: '/pending',
        surface: const Size(420, 1000),
        pendingWrites: store,
        overrides: [
          // Still no signal: the sender fails the way the network does.
          pendingWriteSenderProvider.overrideWithValue(
            (write) async =>
                throw const AppFailure(kind: AppFailureKind.network),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sync-retry')));
      await tester.pumpAndSettle();

      expect(
        find.text('Still no connection. Nothing was lost.'),
        findsOneWidget,
      );
      expect(await store.all(), hasLength(1));
    });
  });

  testWidgets('the banner appears the moment a write is kept', (tester) async {
    // Found on a device, not in a test: every unit test passed and the banner
    // never showed, because nothing told it the queue had changed. An entry
    // that is safe and invisible reads exactly like one that was lost.
    final store = InMemoryPendingWriteStore();
    await pumpScreen(
      tester,
      const Scaffold(body: PendingSyncBanner()),
      surface: const Size(420, 800),
      pendingWrites: store,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pending-sync-banner')), findsNothing);

    await store.put(waiting('a'));
    await tester.pumpAndSettle();

    expect(find.text('1 entry is waiting to sync'), findsOneWidget);
  });

  testWidgets('and goes when the queue empties', (tester) async {
    final store = InMemoryPendingWriteStore();
    await store.put(waiting('a'));
    await pumpScreen(
      tester,
      const Scaffold(body: PendingSyncBanner()),
      surface: const Size(420, 800),
      pendingWrites: store,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pending-sync-banner')), findsOneWidget);

    await store.remove('a');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pending-sync-banner')), findsNothing);
  });
}
