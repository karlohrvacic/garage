import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/domain/api/api_access.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/features/api/providers/api_access_providers.dart';
import 'package:garage/features/api/screens/webhook_screen.dart';

import '../../support/pump_screen.dart';
import 'fake_api_access.dart';

Future<NavigationLog> pumpWebhook(
  WidgetTester tester,
  FakeApiAccessRepository repository, {
  String webhookId = 'w1',
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(320, 2400),
  List<Vehicle> vehicles = const [],
}) {
  return pumpScreen(
    tester,
    WebhookScreen(webhookId: webhookId),
    initialLocation: '/api/webhooks/$webhookId',
    extraRoutes: const {'/api'},
    locale: locale,
    textScale: textScale,
    surface: surface,
    vehicles: vehicles,
    overrides: [apiAccessRepositoryProvider.overrideWithValue(repository)],
  );
}

Future<void> tapField(WidgetTester tester, Key key) async {
  final field = find.byKey(key);
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
}

Future<void> flip(WidgetTester tester, Key key) async {
  final toggle = find.byKey(key);
  await tester.ensureVisible(toggle);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Save');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the screen is titled by the name, or the host without one', (
    tester,
  ) async {
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(storedWebhooks: [webhook(name: 'Kitchen')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kitchen'), findsWidgets);
    expect(find.text('https://home.example/garage'), findsOneWidget);
  });

  testWidgets('a hook that no longer exists says so', (tester) async {
    await pumpWebhook(tester, FakeApiAccessRepository(), webhookId: 'gone');
    await tester.pumpAndSettle();

    expect(find.text('This webhook no longer exists'), findsOneWidget);
  });

  testWidgets('a list that failed to load is not "gone"', (tester) async {
    // With no signal the list is an error, not an empty list, and the hook
    // is still there; saying it no longer exists would be a lie.
    await pumpWebhook(
      tester,
      FakeApiAccessRepository()
        ..webhooksFailure = const AppFailure(kind: AppFailureKind.network),
    );
    await tester.pumpAndSettle();

    expect(find.text('This webhook no longer exists'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('each hook says what it receives, in words', (tester) async {
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(storedWebhooks: [webhook()]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Fill-ups, services, costs, readings, trips and income'),
      findsOneWidget,
    );
    expect(find.textContaining('entry.created'), findsNothing);
  });

  testWidgets('every car, some cars and the language are said in words', (
    tester,
  ) async {
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(
        storedWebhooks: [
          webhook(vehicleIds: ['v1', 'v2'], language: WebhookLanguage.hr),
        ],
      ),
      vehicles: [testVehicle('v1'), testVehicle('v2'), testVehicle('v3')],
    );
    await tester.pumpAndSettle();

    expect(find.text('2 cars'), findsOneWidget);
    expect(find.text('Hrvatski'), findsOneWidget);
  });

  testWidgets('and no list at all is every car', (tester) async {
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(storedWebhooks: [webhook()]),
      vehicles: [testVehicle('v1')],
    );
    await tester.pumpAndSettle();

    expect(find.text('Every car'), findsOneWidget);
  });

  testWidgets('tapping what it receives changes it', (tester) async {
    final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
    await pumpWebhook(tester, repository);
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-events'));
    await flip(tester, const Key('webhook-group-reminders'));
    await save(tester);

    expect(
      repository.calls,
      contains('updateWebhook:w1:events=entry.created,reminder.due'),
    );
  });

  testWidgets('a hook that would receive nothing is not saved', (tester) async {
    final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
    await pumpWebhook(tester, repository);
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-events'));
    await flip(tester, const Key('webhook-group-entries'));
    await save(tester);

    expect(find.text('Choose at least one'), findsOneWidget);
    expect(repository.calls.where((c) => c.startsWith('update')), isEmpty);
  });

  testWidgets('renaming goes through the shared prompt', (tester) async {
    final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
    await pumpWebhook(tester, repository);
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-name'));
    await tester.enterText(find.byType(TextField), 'Kitchen display');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('updateWebhook:w1:name=Kitchen display'));
  });

  testWidgets('a name stops at what the column takes', (tester) async {
    // The column checks 80 characters; the field stops there rather than
    // letting the database refuse a name after the prompt has closed.
    final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
    await pumpWebhook(tester, repository);
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-name'));
    expect(tester.widget<TextField>(find.byType(TextField)).maxLength, 80);
    await tester.enterText(find.byType(TextField), 'k' * 90);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.lastChanges?.name, 'k' * 80);
  });

  testWidgets('a name is typed as typed, not in capitals', (tester) async {
    // The shared prompt's capitals mode is for codes; a name keeps its case.
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(storedWebhooks: [webhook()]),
    );
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-name'));

    expect(
      tester.widget<TextField>(find.byType(TextField)).textCapitalization,
      TextCapitalization.sentences,
    );
  });

  testWidgets('narrowing to some cars writes their ids', (tester) async {
    final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
    await pumpWebhook(
      tester,
      repository,
      vehicles: [
        testVehicle('v1', nickname: 'Golf'),
        testVehicle('v2', nickname: 'Panda'),
      ],
    );
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-cars'));
    expect(find.text('Golf'), findsOneWidget);
    await flip(tester, const Key('webhook-car-v2'));
    await save(tester);

    expect(repository.calls, contains('updateWebhook:w1:vehicleIds=v1'));
  });

  testWidgets('narrowing to no car is refused', (tester) async {
    // The dispatcher reads an empty list as every car, so storing what was
    // chosen would mean the opposite of it.
    final repository = FakeApiAccessRepository(
      storedWebhooks: [
        webhook(vehicleIds: ['v1']),
      ],
    );
    await pumpWebhook(
      tester,
      repository,
      vehicles: [testVehicle('v1'), testVehicle('v2')],
    );
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-cars'));
    await flip(tester, const Key('webhook-car-v1'));
    await save(tester);

    expect(find.text('Choose at least one car'), findsOneWidget);
    expect(repository.calls.where((c) => c.startsWith('update')), isEmpty);

    await flip(tester, const Key('webhook-car-v2'));
    expect(find.text('Choose at least one car'), findsNothing);
    await save(tester);

    expect(repository.calls, contains('updateWebhook:w1:vehicleIds=v2'));
  });

  testWidgets('and switching every car back on stores null, not the list', (
    tester,
  ) async {
    final repository = FakeApiAccessRepository(
      storedWebhooks: [
        webhook(vehicleIds: ['v1']),
      ],
    );
    await pumpWebhook(
      tester,
      repository,
      vehicles: [testVehicle('v1'), testVehicle('v2')],
    );
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-cars'));
    await flip(tester, const Key('webhook-car-v2'));
    await save(tester);

    expect(repository.calls, contains('updateWebhook:w1:clearVehicleIds'));
  });

  group('a car that has left the garage', () {
    testWidgets('is not written back, and does not count', (tester) async {
      // Sold or deleted since the hook was narrowed. The stored id must not
      // make the list read as every car, nor be written back as a car.
      final repository = FakeApiAccessRepository(
        storedWebhooks: [
          webhook(vehicleIds: ['v1', 'gone']),
        ],
      );
      await pumpWebhook(
        tester,
        repository,
        vehicles: [testVehicle('v1'), testVehicle('v2')],
      );
      await tester.pumpAndSettle();

      expect(find.text('1 car'), findsOneWidget);

      await tapField(tester, const Key('webhook-field-cars'));
      await save(tester);

      expect(repository.calls, contains('updateWebhook:w1:vehicleIds=v1'));
    });

    testWidgets('leaves nothing to save until a car is chosen', (tester) async {
      // Every stored id is gone: the sheet opens with no car on, and Save
      // is refused rather than writing an empty list the drain would read
      // as every car.
      final repository = FakeApiAccessRepository(
        storedWebhooks: [
          webhook(vehicleIds: ['gone']),
        ],
      );
      await pumpWebhook(
        tester,
        repository,
        vehicles: [testVehicle('v1'), testVehicle('v2')],
      );
      await tester.pumpAndSettle();

      expect(find.text('0 cars'), findsOneWidget);

      await tapField(tester, const Key('webhook-field-cars'));
      await save(tester);

      expect(find.text('Choose at least one car'), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('update')), isEmpty);
    });
  });

  testWidgets('a garage with no cars has no cars field', (tester) async {
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(storedWebhooks: [webhook()]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('webhook-field-cars')), findsNothing);
    expect(find.byKey(const Key('webhook-field-language')), findsOneWidget);
  });

  testWidgets('the language is picked from the three', (tester) async {
    final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
    await pumpWebhook(tester, repository);
    await tester.pumpAndSettle();

    await tapField(tester, const Key('webhook-field-language'));
    await tester.tap(find.byKey(const Key('webhook-language-it')));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('updateWebhook:w1:language=it'));
  });

  testWidgets('the copy button puts the address on the clipboard', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await pumpWebhook(
      tester,
      FakeApiAccessRepository(storedWebhooks: [webhook()]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('copy-webhook-url')));
    await tester.pumpAndSettle();

    expect(copied, 'https://home.example/garage');
    expect(find.text('Address copied'), findsOneWidget);
  });

  group('paused', () {
    testWidgets('a paused hook says so and offers to resume', (tester) async {
      final repository = FakeApiAccessRepository(
        storedWebhooks: [webhook(active: false, pausedReason: 'failing')],
      );
      await pumpWebhook(tester, repository);
      await tester.pumpAndSettle();

      expect(
        find.text('Paused: the last deliveries all failed'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('webhook-resume')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('updateWebhook:w1:active=true'));
    });

    testWidgets('a paused hook cannot send a test', (tester) async {
      // The drain sends nothing to an inactive hook, so the ping would only
      // sit in the log as queued and read as the receiver being slow.
      await pumpWebhook(
        tester,
        FakeApiAccessRepository(
          storedWebhooks: [webhook(active: false, pausedReason: 'failing')],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('webhook-send-test')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a running hook is not offered it', (tester) async {
      await pumpWebhook(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('webhook-resume')), findsNothing);
    });
  });

  group('sending a test', () {
    testWidgets('asks for a ping and says to watch the log', (tester) async {
      final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
      await pumpWebhook(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('webhook-send-test')));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('sendTest:h1'));
      expect(find.text('Test sent. Watch the log below.'), findsOneWidget);
    });
  });

  group('the log', () {
    testWidgets('is empty until something was sent', (tester) async {
      await pumpWebhook(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing sent yet'), findsOneWidget);
    });

    testWidgets('shows each delivery with its outcome', (tester) async {
      await pumpWebhook(
        tester,
        FakeApiAccessRepository(
          storedWebhooks: [webhook()],
          storedDeliveries: [
            delivery(
              id: 'd1',
              event: 'test.ping',
              deliveredAt: DateTime(2026, 9, 19, 8, 0, 2),
            ),
            delivery(
              id: 'd2',
              event: 'entry.created',
              attempts: 4,
              lastStatus: 503,
              givenUpAt: DateTime(2026, 9, 19, 9, 11),
            ),
            delivery(
              id: 'd3',
              event: 'reminder.due',
              attempts: 1,
              lastStatus: 502,
            ),
            delivery(
              id: 'd4',
              event: 'member.joined',
              attempts: 0,
              lastStatus: null,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // The key a receiver matched on, as is.
      expect(find.text('test.ping'), findsOneWidget);
      expect(find.text('entry.created'), findsOneWidget);
      expect(find.text('Delivered 08:00'), findsOneWidget);
      expect(find.text('Gave up after 4 attempts'), findsOneWidget);
      expect(find.text('Retrying, attempt 2 of 4 (502)'), findsOneWidget);
      // Not yet posted: nothing has been tried, so nothing is being retried.
      expect(find.text('Queued'), findsOneWidget);
      expect(find.textContaining('attempt 1 of'), findsNothing);
    });

    testWidgets('a fourth attempt that arrived reads as delivered', (
      tester,
    ) async {
      await pumpWebhook(
        tester,
        FakeApiAccessRepository(
          storedWebhooks: [webhook()],
          storedDeliveries: [
            delivery(
              attempts: 4,
              deliveredAt: DateTime(2026, 9, 19, 9, 11, 2),
              givenUpAt: DateTime(2026, 9, 19, 9, 11),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delivered 09:11'), findsOneWidget);
      expect(find.textContaining('Gave up'), findsNothing);
    });
  });

  group('deleting', () {
    testWidgets('asks first', (tester) async {
      final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
      await pumpWebhook(tester, repository);
      await tester.pumpAndSettle();

      final delete = find.byKey(const Key('webhook-delete'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();

      expect(find.text('Delete entry?'), findsOneWidget);
      expect(repository.calls.where((c) => c.startsWith('delete')), isEmpty);
    });

    testWidgets('a confirmed delete goes through and leaves the screen', (
      tester,
    ) async {
      final repository = FakeApiAccessRepository(storedWebhooks: [webhook()]);
      final log = await pumpWebhook(tester, repository);
      await tester.pumpAndSettle();

      final delete = find.byKey(const Key('webhook-delete'));
      await tester.ensureVisible(delete);
      await tester.pumpAndSettle();
      await tester.tap(delete);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('deleteWebhook:w1'));
      expect(log.visited, contains('/api'));
    });
  });

  // The sheet's cancel label in each language, to close the cars sheet.
  const cancel = {'hr': 'Odustani', 'it': 'Annulla'};
  for (final locale in cancel.keys.map(Locale.new)) {
    testWidgets(
      'in ${locale.languageCode} on a narrow phone at a large font it lays out',
      (tester) async {
        await pumpWebhook(
          tester,
          FakeApiAccessRepository(
            storedWebhooks: [
              webhook(
                name: 'Kuhinja',
                vehicleIds: ['v1'],
                events: WebhookEvent.values.toSet(),
                active: false,
                pausedReason: 'failing',
              ),
            ],
            storedDeliveries: [
              delivery(deliveredAt: DateTime(2026, 9, 19, 8, 0, 2)),
              delivery(
                id: 'd2',
                attempts: 4,
                lastStatus: 503,
                givenUpAt: DateTime(2026, 9, 19, 9, 11),
              ),
              delivery(id: 'd3', attempts: 1, lastStatus: 502),
            ],
          ),
          locale: locale,
          textScale: 1.5,
          vehicles: [testVehicle('v1', nickname: 'Golf')],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tapField(tester, const Key('webhook-field-cars'));
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.widgetWithText(TextButton, cancel[locale.languageCode]!),
        );
        await tester.pumpAndSettle();

        await tapField(tester, const Key('webhook-field-events'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
