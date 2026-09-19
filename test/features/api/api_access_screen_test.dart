import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/widgets/text_prompt.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/domain/entities/household.dart';
import 'package:garage/domain/entities/vehicle.dart';
import 'package:garage/domain/api/api_access.dart';
import 'package:garage/features/api/providers/api_access_providers.dart';
import 'package:garage/core/widgets/entry_sheet_body.dart';
import 'package:garage/features/api/screens/api_access_screen.dart';

import '../../support/pump_screen.dart';
import 'fake_api_access.dart';

Future<NavigationLog> pumpApiAccess(
  WidgetTester tester,
  FakeApiAccessRepository repository, {
  Household? household = testHousehold,
  OpenedLinks? opened,
  Locale? locale,
  double textScale = 1,
  Size surface = const Size(320, 3200),
  List<Vehicle> vehicles = const [],
}) {
  return pumpScreen(
    tester,
    const ApiAccessScreen(),
    initialLocation: '/api',
    extraRoutes: const {'/api/webhooks/:id'},
    locale: locale,
    textScale: textScale,
    surface: surface,
    household: household,
    vehicles: vehicles,
    overrides: [
      apiAccessRepositoryProvider.overrideWithValue(repository),
      if (opened != null) urlOpenerProvider.overrideWithValue(opened.call),
    ],
  );
}

/// Records where the app tried to send the user instead of opening a browser.
class OpenedLinks {
  final List<Uri> urls = [];

  Future<void> call(Uri url) async => urls.add(url);
}

void main() {
  testWidgets('a household with no keys is told what this is for', (
    tester,
  ) async {
    await pumpApiAccess(tester, FakeApiAccessRepository());
    await tester.pumpAndSettle();

    expect(find.text('API access'), findsWidgets);
    // The screen is half webhooks, which send this garage's data out; the
    // subtitle that sends people here now says both.
    expect(find.textContaining('Read-only keys'), findsOneWidget);
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
    testWidgets('each hook is listed by host, with its address under it', (
      tester,
    ) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('home.example'), findsOneWidget);
      expect(find.text('https://home.example/garage'), findsOneWidget);
    });

    testWidgets('a named hook is listed by its name', (tester) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook(name: 'Kitchen')]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kitchen'), findsOneWidget);
      expect(find.text('home.example'), findsNothing);
    });

    testWidgets('a hook nothing was sent to yet says so', (tester) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing sent yet'), findsOneWidget);
    });

    testWidgets('a hook that last failed shows its status', (tester) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook(status: 500)]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('500'), findsOneWidget);
    });

    testWidgets('a hook that is delivering says when it last did', (
      tester,
    ) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook(status: 204)]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Delivered'), findsOneWidget);
    });

    testWidgets('a paused hook says so, in red', (tester) async {
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(
          storedWebhooks: [
            webhook(status: 503, active: false, pausedReason: 'failing'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final line = find.textContaining('Paused');
      expect(line, findsOneWidget);
      final failing = find.textContaining('503');
      expect(failing, findsNothing);
      final style = tester.widget<Text>(line).style!;
      final surface = tester
          .widget<Text>(find.text('https://home.example/garage'))
          .style!;
      expect(style.color, isNot(surface.color));
    });

    testWidgets('tapping a hook opens its own screen', (tester) async {
      final log = await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('home.example'));
      await tester.pumpAndSettle();

      expect(log.visited, contains('/api/webhooks/w1'));
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
      await pumpApiAccess(
        tester,
        FakeApiAccessRepository(storedWebhooks: [webhook()]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('copy-webhook-w1')));
      await tester.pumpAndSettle();

      expect(copied, 'https://home.example/garage');
      expect(find.text('Address copied'), findsOneWidget);
    });

    Future<void> openAdd(WidgetTester tester, {String? url}) async {
      final add = find.widgetWithText(OutlinedButton, 'Add webhook');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('webhook-url')),
        url ?? 'https://home.example/garage',
      );
      await tester.pumpAndSettle();
    }

    Future<void> confirmAdd(WidgetTester tester) async {
      final add = find.widgetWithText(FilledButton, 'Add');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
    }

    Future<void> flip(WidgetTester tester, Key key) async {
      final toggle = find.byKey(key);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }

    testWidgets('adding one takes an https URL', (tester) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester);
      await confirmAdd(tester);

      expect(
        repository.calls,
        contains('addWebhook:https://home.example/garage:auto:en'),
      );
    });

    testWidgets('a new hook gets every event unless told otherwise', (
      tester,
    ) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester);
      await confirmAdd(tester);

      expect(repository.addedEvents, WebhookEvent.values.toSet());
      expect(repository.addedName, isNull);
      expect(repository.addedVehicleIds, isNull);
    });

    testWidgets('the choices are in words, not keys', (tester) async {
      await pumpApiAccess(tester, FakeApiAccessRepository());
      await tester.pumpAndSettle();

      await openAdd(tester);

      expect(
        find.text('Fill-ups, services, costs, readings, trips and income'),
        findsOneWidget,
      );
      expect(find.text('Entries edited or deleted'), findsOneWidget);
      expect(
        find.text('Cars added, archived, lent out or handed over'),
        findsOneWidget,
      );
      expect(find.text('Members joining or leaving'), findsOneWidget);
      expect(find.text('Reminders due'), findsOneWidget);
      expect(find.textContaining('entry.created'), findsNothing);
    });

    testWidgets('and can be told to leave out the reminders', (tester) async {
      // A hook pointed at a chat got two reminder messages per job it had
      // never asked for, because the form offered no choice.
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester);
      await flip(tester, const Key('webhook-group-reminders'));
      await confirmAdd(tester);

      expect(
        repository.addedEvents,
        WebhookEvent.values.toSet()..remove(WebhookEvent.reminderDue),
      );
    });

    testWidgets('a group switched off takes every key in it with it', (
      tester,
    ) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester);
      await flip(tester, const Key('webhook-group-cars'));
      await confirmAdd(tester);

      final added = repository.addedEvents!;
      expect(added, isNot(contains(WebhookEvent.vehicleLent)));
      expect(added, isNot(contains(WebhookEvent.vehicleAdded)));
      expect(added, isNot(contains(WebhookEvent.vehicleHandedOver)));
      expect(added, contains(WebhookEvent.entryCreated));
      expect(added, contains(WebhookEvent.memberJoined));
    });

    testWidgets('a hook that would receive nothing is not added', (
      tester,
    ) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester);
      for (final group in WebhookEventGroup.values) {
        await flip(tester, Key('webhook-group-${group.name}'));
      }
      await confirmAdd(tester);

      expect(repository.calls, isEmpty);
      expect(find.text('Choose at least one'), findsOneWidget);
    });

    testWidgets('the sheet writes a name, a language and the chosen cars', (
      tester,
    ) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(
        tester,
        repository,
        vehicles: [
          testVehicle('v1', nickname: 'Golf'),
          testVehicle('v2', nickname: 'Panda'),
        ],
      );
      await tester.pumpAndSettle();

      await openAdd(tester);
      await tester.enterText(find.byKey(const Key('webhook-name')), 'Kitchen');
      await flip(tester, const Key('webhook-car-v2'));
      final language = find.byKey(const Key('webhook-language'));
      await tester.ensureVisible(language);
      await tester.pumpAndSettle();
      await tester.tap(language);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hrvatski').last);
      await tester.pumpAndSettle();
      await confirmAdd(tester);

      expect(
        repository.calls,
        contains('addWebhook:https://home.example/garage:auto:hr'),
      );
      expect(repository.addedName, 'Kitchen');
      expect(repository.addedVehicleIds, ['v1']);
    });

    testWidgets('a name stops at what the column takes', (tester) async {
      // The column checks 80 characters; the field stops there rather than
      // letting the database refuse the hook after the sheet has closed.
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester);
      final name = find.byKey(const Key('webhook-name'));
      expect(tester.widget<TextField>(name).maxLength, 80);
      await tester.enterText(name, 'k' * 90);
      await confirmAdd(tester);

      expect(repository.addedName, 'k' * 80);
    });

    testWidgets('every car on is stored as null, never the full list', (
      tester,
    ) async {
      // Null is every car, including one added next month; the full list
      // would be these two for ever.
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(
        tester,
        repository,
        vehicles: [testVehicle('v1'), testVehicle('v2')],
      );
      await tester.pumpAndSettle();

      await openAdd(tester);
      await confirmAdd(tester);

      expect(repository.calls, hasLength(1));
      expect(repository.addedVehicleIds, isNull);
    });

    testWidgets(
      'and switching every car back on after one is off is null too',
      (tester) async {
        final repository = FakeApiAccessRepository();
        await pumpApiAccess(
          tester,
          repository,
          vehicles: [testVehicle('v1'), testVehicle('v2')],
        );
        await tester.pumpAndSettle();

        await openAdd(tester);
        await flip(tester, const Key('webhook-car-v2'));
        await flip(tester, const Key('webhook-car-v2'));
        await confirmAdd(tester);

        expect(repository.addedVehicleIds, isNull);
      },
    );

    testWidgets('a hook for no car is refused', (tester) async {
      // The dispatcher reads an empty list as every car, so storing what
      // was chosen would mean the opposite of it.
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(
        tester,
        repository,
        vehicles: [testVehicle('v1'), testVehicle('v2')],
      );
      await tester.pumpAndSettle();

      await openAdd(tester);
      await flip(tester, const Key('webhook-car-v1'));
      await flip(tester, const Key('webhook-car-v2'));
      await confirmAdd(tester);

      expect(repository.calls, isEmpty);
      expect(find.text('Choose at least one car'), findsOneWidget);

      // Switching one back on clears the complaint and the hook goes in.
      await flip(tester, const Key('webhook-car-v1'));
      expect(find.text('Choose at least one car'), findsNothing);
      await confirmAdd(tester);

      expect(repository.calls, hasLength(1));
      expect(repository.addedVehicleIds, ['v1']);
    });

    testWidgets('the language starts as the one the app is in', (tester) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository, locale: const Locale('it'));
      await tester.pumpAndSettle();

      final add = find.widgetWithText(OutlinedButton, 'Aggiungi un webhook');
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('webhook-url')),
        'https://home.example/garage',
      );
      final confirm = find.widgetWithText(FilledButton, 'Aggiungi');
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(
        repository.calls,
        contains('addWebhook:https://home.example/garage:auto:it'),
      );
    });

    testWidgets('a Pushover address without its keys is refused', (
      tester,
    ) async {
      // Pushover has no per-channel address: the token and user key ride in
      // the pasted URL, and without them every delivery would be refused.
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester, url: 'https://api.pushover.net/1/messages.json');
      await confirmAdd(tester);

      expect(repository.calls, isEmpty);
      expect(
        find.text('Paste the URL with your token and user key'),
        findsOneWidget,
      );
    });

    testWidgets('and one with them goes through', (tester) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(
        tester,
        url: 'https://api.pushover.net/1/messages.json?token=a&user=b',
      );
      await confirmAdd(tester);

      expect(repository.calls, hasLength(1));
    });

    testWidgets('a plain http URL is refused', (tester) async {
      final repository = FakeApiAccessRepository();
      await pumpApiAccess(tester, repository);
      await tester.pumpAndSettle();

      await openAdd(tester, url: 'http://home.example/garage');
      await confirmAdd(tester);

      expect(repository.calls, isEmpty);
      expect(find.textContaining('https'), findsWidgets);
    });
  });

  testWidgets('the actions are disabled until a household is loaded', (
    tester,
  ) async {
    await pumpApiAccess(tester, FakeApiAccessRepository(), household: null);
    await tester.pumpAndSettle();

    // Enabled buttons that quietly return are worse than disabled ones: a tap
    // that does nothing reads as a broken app.
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('New key'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Add webhook'),
              matching: find.byType(OutlinedButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a new key is named in the prompt every other name uses', (
    tester,
  ) async {
    // One field. Your own name, the garage's, another garage and a join code
    // are all asked for in the shared prompt; the key alone had a sheet.
    await pumpApiAccess(tester, FakeApiAccessRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'New key'));
    await tester.pumpAndSettle();

    expect(find.byType(TextPrompt), findsOneWidget);
    expect(find.byType(EntrySheetBody), findsNothing);
  });

  // Host detection covers Discord, Slack, Google Chat, Telegram and ntfy.sh,
  // and cannot cover a receiver the household runs itself — a self-hosted
  // ntfy or Gotify answers on a domain no list of hostnames will contain. The
  // picker is the only way to say so.
  testWidgets('a self-hosted receiver can name its own format', (tester) async {
    final repository = FakeApiAccessRepository();
    await pumpApiAccess(tester, repository);
    await tester.pumpAndSettle();

    final add = find.widgetWithText(OutlinedButton, 'Add webhook');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('webhook-url')),
      'https://push.example.org/my-garage',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webhook-format')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ntfy').last);
    await tester.pumpAndSettle();
    final confirm = find.widgetWithText(FilledButton, 'Add');
    await tester.ensureVisible(confirm);
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(
      repository.calls,
      contains('addWebhook:https://push.example.org/my-garage:ntfy:en'),
    );
  });

  // The default has to stay the one that is right for everything hosted.
  testWidgets('and defaults to reading the address', (tester) async {
    await pumpApiAccess(tester, FakeApiAccessRepository());
    await tester.pumpAndSettle();

    final add = find.widgetWithText(OutlinedButton, 'Add webhook');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.text('Detect from the address'), findsOneWidget);
  });

  testWidgets('the four new shapes are on offer', (tester) async {
    await pumpApiAccess(tester, FakeApiAccessRepository());
    await tester.pumpAndSettle();

    final add = find.widgetWithText(OutlinedButton, 'Add webhook');
    await tester.ensureVisible(add);
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webhook-format')));
    await tester.pumpAndSettle();

    expect(find.text('Microsoft Teams'), findsWidgets);
    expect(find.text('Rocket.Chat, Matrix (plain text)'), findsWidgets);
    expect(find.text('Pushover'), findsWidgets);
    expect(find.text('Pushbullet'), findsWidgets);
  });

  // A key is a credential with nowhere to spend it unless the endpoints are
  // written down somewhere the holder can reach. The repository is private, so
  // this link is the only route to them.
  testWidgets('offers the documentation beside the keys', (tester) async {
    final opened = OpenedLinks();
    await pumpApiAccess(tester, FakeApiAccessRepository(), opened: opened);
    await tester.pumpAndSettle();

    await tester.tap(find.text('How to use it'));
    await tester.pumpAndSettle();

    expect(opened.urls, [GarageLinks.apiDocs]);
  });

  for (final locale in const [Locale('hr'), Locale('it')]) {
    testWidgets(
      'in ${locale.languageCode} on a narrow phone at a large font it lays out',
      (tester) async {
        await pumpApiAccess(
          tester,
          FakeApiAccessRepository(
            storedKeys: [key()],
            storedWebhooks: [
              webhook(name: 'Kuhinja', status: 204),
              webhook(
                id: 'w2',
                status: 503,
                active: false,
                pausedReason: 'failing',
              ),
            ],
          ),
          locale: locale,
          textScale: 1.5,
          vehicles: [testVehicle('v1', nickname: 'Golf')],
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // The sheet too: five long labels, two dropdowns and a car.
        final add = find.byType(OutlinedButton).last;
        await tester.ensureVisible(add);
        await tester.pumpAndSettle();
        await tester.tap(add);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
