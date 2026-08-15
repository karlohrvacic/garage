import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/api/api_access.dart';
import 'package:garage/features/api/data/api_access_repository.dart';
import 'package:garage/features/api/providers/api_access_providers.dart';
import 'package:garage/features/api/screens/api_access_screen.dart';

import '../../support/pump_screen.dart';

class FakeApiAccessRepository implements ApiAccessRepository {
  FakeApiAccessRepository({
    this.storedKeys = const [],
    this.storedWebhooks = const [],
  });

  List<ApiKeyRecord> storedKeys;
  List<Webhook> storedWebhooks;
  final List<String> calls = [];

  @override
  Future<List<ApiKeyRecord>> keys(String householdId) async => storedKeys;

  @override
  Future<String> createKey({
    required String householdId,
    required String name,
  }) async {
    calls.add('createKey:$name');
    storedKeys = [
      ...storedKeys,
      ApiKeyRecord(
        id: 'new',
        name: name,
        preview: '…wxyz',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    ];
    return 'grg_abcdefghijklmnopqrstuvwxyz012345';
  }

  @override
  Future<void> revokeKey(String id) async => calls.add('revokeKey:$id');

  @override
  Future<List<Webhook>> webhooks(String householdId) async => storedWebhooks;

  @override
  Future<void> addWebhook({
    required String householdId,
    required Uri url,
    required Set<WebhookEvent> events,
  }) async => calls.add('addWebhook:$url');

  @override
  Future<void> deleteWebhook(String id) async => calls.add('deleteWebhook:$id');
}

ApiKeyRecord key({
  String id = 'k1',
  String name = 'Home Assistant',
  DateTime? lastUsedAt,
  DateTime? revokedAt,
}) {
  return ApiKeyRecord(
    id: id,
    name: name,
    preview: '…mnop',
    createdAt: DateTime.utc(2026, 7, 24),
    lastUsedAt: lastUsedAt,
    revokedAt: revokedAt,
  );
}

Webhook webhook({int? status}) {
  return Webhook(
    id: 'w1',
    url: Uri.parse('https://home.example/garage'),
    events: const {WebhookEvent.entryCreated},
    active: true,
    createdAt: DateTime.utc(2026, 7, 24),
    lastDeliveryStatus: status,
  );
}

Future<NavigationLog> pumpApiAccess(
  WidgetTester tester,
  FakeApiAccessRepository repository,
) {
  return pumpScreen(
    tester,
    const ApiAccessScreen(),
    initialLocation: '/api',
    surface: const Size(420, 1000),
    overrides: [apiAccessRepositoryProvider.overrideWithValue(repository)],
  );
}

void main() {
  testWidgets('a household with no keys is told what this is for', (
    tester,
  ) async {
    await pumpApiAccess(tester, FakeApiAccessRepository());
    await tester.pumpAndSettle();

    expect(find.text('API access'), findsWidgets);
    expect(find.textContaining('read-only'), findsOneWidget);
  });

  testWidgets('each key is listed by name and tail', (tester) async {
    await pumpApiAccess(tester, FakeApiAccessRepository(storedKeys: [key()]));
    await tester.pumpAndSettle();

    expect(find.text('Home Assistant'), findsOneWidget);
    expect(find.textContaining('…mnop'), findsOneWidget);
  });

  testWidgets('a key that has never been called says so', (tester) async {
    await pumpApiAccess(tester, FakeApiAccessRepository(storedKeys: [key()]));
    await tester.pumpAndSettle();

    expect(find.textContaining('Never used'), findsOneWidget);
  });

  testWidgets('a revoked key is marked, not hidden', (tester) async {
    await pumpApiAccess(
      tester,
      FakeApiAccessRepository(
        storedKeys: [key(revokedAt: DateTime.utc(2026, 8, 1))],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home Assistant'), findsOneWidget);
    expect(find.textContaining('Revoked'), findsWidgets);
  });

  testWidgets('creating a key shows it once, in full', (tester) async {
    final repository = FakeApiAccessRepository();
    await pumpApiAccess(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Home Assistant');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('createKey:Home Assistant'));
    expect(
      find.textContaining('grg_abcdefghijklmnopqrstuvwxyz012345'),
      findsOneWidget,
    );
    expect(find.textContaining('not shown again'), findsOneWidget);
  });

  testWidgets('revoking a key asks first', (tester) async {
    final repository = FakeApiAccessRepository(storedKeys: [key()]);
    await pumpApiAccess(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('a confirmed revoke goes through', (tester) async {
    final repository = FakeApiAccessRepository(storedKeys: [key()]);
    await pumpApiAccess(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Revoke'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.calls, ['revokeKey:k1']);
  });

  group('webhooks', () {
    testWidgets('each hook is listed by URL', (tester) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('home.example'), findsOneWidget);
    });

    testWidgets('a hook that last failed shows its status', (tester) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook(status: 500)]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('500'), findsOneWidget);
    });

    testWidgets('adding one takes an https URL', (tester) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      final add = find.widgetWithText(OutlinedButton, 'Add webhook');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'https://home.example/garage',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        contains('addWebhook:https://home.example/garage'),
      );
    });

    testWidgets('a plain http URL is refused', (tester) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      final add = find.widgetWithText(OutlinedButton, 'Add webhook');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'http://home.example/garage',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(repository.calls, isEmpty);
      expect(find.textContaining('https'), findsWidgets);
    });
  });
}
