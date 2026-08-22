import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/app_info.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/features/settings/screens/about_screen.dart';

import '../../support/pump_screen.dart';

/// Records where the app tried to send the user instead of opening a browser.
class OpenedLinks {
  final List<Uri> urls = [];

  Future<void> call(Uri url) async => urls.add(url);
}

Future<OpenedLinks> pumpAbout(WidgetTester tester, {Locale? locale}) async {
  final opened = OpenedLinks();
  await pumpScreen(
    tester,
    const AboutScreen(),
    initialLocation: '/about',
    locale: locale,
    overrides: [urlOpenerProvider.overrideWithValue(opened.call)],
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  testWidgets('says which version is running, so a bug report can name it', (
    tester,
  ) async {
    await pumpAbout(tester);

    expect(find.textContaining(AppInfo.version), findsOneWidget);
    expect(find.textContaining(AppInfo.build), findsOneWidget);
  });

  testWidgets('states that the data can leave, in plain words', (tester) async {
    await pumpAbout(tester);

    expect(
      find.textContaining('Export everything as CSV'),
      findsOneWidget,
      reason: 'no-lock-in is the promise this screen exists to make',
    );
  });

  testWidgets('states that it is free and unmetered', (tester) async {
    await pumpAbout(tester);

    expect(find.textContaining('No ads, no subscription'), findsOneWidget);
  });

  testWidgets('opens the privacy policy in a browser', (tester) async {
    final opened = await pumpAbout(tester);

    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(opened.urls, [GarageLinks.privacyPolicy]);
  });

  testWidgets('shows the open source licences the app is built on', (
    tester,
  ) async {
    await pumpAbout(tester);

    // The screen outgrew a phone once it gained the source and diagnostics
    // rows, so the rows at the bottom are not built until they are scrolled to.
    await tester.scrollUntilVisible(find.text('Open source licences'), 100);
    await tester.tap(find.text('Open source licences'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('offers the source code, which the AGPL requires of a hosted app', (
    tester,
  ) async {
    final opened = await pumpAbout(tester);

    await tester.tap(find.text('Source code'));
    await tester.pumpAndSettle();

    expect(
      opened.urls,
      [GarageLinks.sourceCode],
      reason:
          'AGPL section 13 obliges the running instance to offer its source to '
          'anyone interacting with it over a network, and garage.hrva.cc is '
          'exactly that. A LICENSE file in a repo they never visit does not '
          'discharge it; this row is what does.',
    );
  });

  testWidgets('leads to the diagnostics, so a report can carry a cause', (
    tester,
  ) async {
    final opened = OpenedLinks();
    final log = await pumpScreen(
      tester,
      const AboutScreen(),
      initialLocation: '/about',
      extraRoutes: const ['/diagnostics'],
      overrides: [urlOpenerProvider.overrideWithValue(opened.call)],
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Diagnostics'), 100);
    await tester.tap(find.text('Diagnostics'));
    await tester.pumpAndSettle();

    expect(log.visited, contains('/diagnostics'));
  });

  testWidgets('reads naturally in Croatian too', (tester) async {
    await pumpAbout(tester, locale: const Locale('hr'));

    expect(find.text('O aplikaciji'), findsOneWidget);
    expect(find.text('Pravila privatnosti'), findsOneWidget);
    expect(find.text('Izvorni kôd'), findsOneWidget);
  });

  testWidgets('nothing overflows on a narrow phone', (tester) async {
    final opened = OpenedLinks();
    await pumpScreen(
      tester,
      const AboutScreen(),
      initialLocation: '/about',
      surface: const Size(320, 640),
      overrides: [urlOpenerProvider.overrideWithValue(opened.call)],
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('offers a way to send feedback, addressed to support', (
    tester,
  ) async {
    final opened = await pumpAbout(tester);

    await tester.scrollUntilVisible(find.text('Send feedback'), 100);
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(opened.urls, hasLength(1));
    final url = opened.urls.single;
    expect(url.scheme, 'mailto');
    expect(url.path, 'privacy@hrva.cc');
  });

  testWidgets('the feedback email names the version running', (tester) async {
    // A bug report with no version is a report nobody can act on three
    // releases later — the same reasoning the Diagnostics report already
    // follows.
    final opened = await pumpAbout(tester);

    await tester.scrollUntilVisible(find.text('Send feedback'), 100);
    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();

    expect(
      opened.urls.single.queryParameters['body'],
      contains('${AppInfo.version} (${AppInfo.build})'),
    );
  });
}
