import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/app_info.dart';
import 'package:garage/core/web/update_notice.dart';
import 'package:garage/l10n/app_localizations.dart';

Future<void> pumpNotice(
  WidgetTester tester, {
  required Future<String?> Function() published,
  Future<void> Function()? reload,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateCheckEnabledProvider.overrideWithValue(true),
        publishedBuildProvider.overrideWithValue(published),
        pageReloaderProvider.overrideWithValue(reload ?? () async {}),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => UpdateNotice(child: child!),
        home: const Scaffold(body: SizedBox()),
      ),
    ),
  );
  // The first check runs after the first frame; this lets it answer, and lets
  // a notice finish coming in: until it has, it is below the bottom of the
  // screen and a tap on it lands on nothing.
  await tester.pump();
  await tester.pumpAndSettle();
}

/// The periodic check and the notice's own timer both end with the tree.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  group('whether the server has a newer build', () {
    test('a larger build number is newer', () {
      expect(isNewerBuild(running: '120', published: '121'), isTrue);
    });
    test('the same one is not', () {
      expect(isNewerBuild(running: '121', published: '121'), isFalse);
    });
    test('an older one is not', () {
      expect(isNewerBuild(running: '121', published: '120'), isFalse);
    });
    test('an answer that is not a number is not', () {
      expect(isNewerBuild(running: '121', published: null), isFalse);
      expect(isNewerBuild(running: '121', published: 'abc'), isFalse);
    });
  });

  testWidgets('a newer build on the server says so, with a way to reload', (
    tester,
  ) async {
    var reloads = 0;
    await pumpNotice(
      tester,
      published: () async => '999999',
      reload: () async => reloads++,
    );

    expect(find.text('A new version of Garage is ready'), findsOneWidget);
    await tester.tap(find.text('Reload'));
    await tester.pump();
    expect(reloads, 1);

    await unmount(tester);
  });

  testWidgets('the build that is running says nothing', (tester) async {
    await pumpNotice(tester, published: () async => AppInfo.build);

    expect(find.byType(SnackBar), findsNothing);
    await unmount(tester);
  });

  testWidgets('a server that cannot be read says nothing', (tester) async {
    await pumpNotice(tester, published: () async => throw Exception('offline'));

    expect(find.byType(SnackBar), findsNothing);
    await unmount(tester);
  });
}
