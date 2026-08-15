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

    await tester.tap(find.text('Open source licences'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('reads naturally in Croatian too', (tester) async {
    await pumpAbout(tester, locale: const Locale('hr'));

    expect(find.text('O aplikaciji'), findsOneWidget);
    expect(find.text('Pravila privatnosti'), findsOneWidget);
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
}
