import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/core/router/app_redirect.dart';

/// One thing a person can start from the launcher: a fill-up or an expense.
class _EntryPoint {
  const _EntryPoint({
    required this.name,
    required this.route,
    required this.link,
    required this.widgetClass,
  });

  /// The suffix every resource of this entry point carries: `log_fuel`
  /// names `deep_link_log_fuel`, `widget_log_fuel` and so on.
  final String name;
  final String route;
  final Uri link;
  final String widgetClass;
}

final _entryPoints = [
  _EntryPoint(
    name: 'log_fuel',
    route: quickFuelRoute,
    link: GarageLinks.logFuel,
    widgetClass: 'LogFuelWidget',
  ),
  _EntryPoint(
    name: 'log_cost',
    route: quickCostRoute,
    link: GarageLinks.logCost,
    widgetClass: 'LogCostWidget',
  ),
];

/// The Android launcher entry points — the icon's long-press shortcuts and
/// the home-screen widgets — reach a Flutter route through five files that
/// nothing else relates: a string resource holding the URL, the shortcut XML
/// that spends it, the widget's Kotlin, the manifest that registers both, and
/// the router. None of that is reachable from a Flutter test at runtime, and
/// every one of those joints fails *silently*: a shortcut whose URL no route
/// matches simply opens the dashboard, which is also what a working shortcut
/// does for a user with no car. So this reads the files instead.
///
/// What it cannot tell you: whether the widget renders, whether Android
/// verifies the app link, or whether a cold start delivers the intent. Those
/// need a device.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final manifest = read('android/app/src/main/AndroidManifest.xml');
  final strings = read('android/app/src/main/res/values/strings.xml');
  final shortcuts = read('android/app/src/main/res/xml/shortcuts.xml');
  final router = read('lib/core/router/app_router.dart');

  /// The launcher labels in every language the app ships in besides English,
  /// by the directory Android reads them from.
  final translations = {
    for (final locale in ['hr', 'it'])
      locale: read('android/app/src/main/res/values-$locale/strings.xml'),
  };

  /// The value of `<string name="…">` in an Android resource file.
  String? resource(String xml, String name) {
    final match = RegExp(
      '<string name="$name"[^>]*>(.*?)</string>',
      dotAll: true,
    ).firstMatch(xml);
    return match?.group(1);
  }

  for (final entry in _entryPoints) {
    final linkName = 'deep_link_${entry.name}';
    final widgetInfo = read(
      'android/app/src/main/res/xml/${entry.name}_widget_info.xml',
    );
    final widgetSource = read(
      'android/app/src/main/kotlin/cc/hrva/garage/${entry.widgetClass}.kt',
    );

    group('${entry.name}: the link both entry points open', () {
      test('is the route the app actually serves', () {
        final declared = resource(strings, linkName);

        expect(declared, isNotNull, reason: 'no $linkName string');
        final link = Uri.parse(declared!);
        expect(link.scheme, 'https');
        expect(link.host, GarageLinks.host);
        expect(link.path, entry.route);
      });

      test('and is the one the Dart side builds', () {
        expect(entry.link.toString(), resource(strings, linkName));
      });

      test('and is registered as a route', () {
        expect(router, contains('path: ${_routeConstant(entry.route)}'));
      });

      // A URL is not a label. Translating it would send Croatian phones to a
      // host that does not exist, and nothing would report it.
      test('is never translated', () {
        expect(
          strings,
          contains(RegExp('name="$linkName"\\s+translatable="false"')),
        );
        for (final translated in translations.values) {
          expect(resource(translated, linkName), isNull);
        }
      });
    });

    group('${entry.name}: the app-icon shortcut', () {
      final shortcut = RegExp(
        '<shortcut\\s[^>]*android:shortcutId="${entry.name}".*?</shortcut>',
        dotAll: true,
      ).firstMatch(shortcuts)?.group(0);

      test('is declared', () {
        expect(shortcut, isNotNull);
      });

      test('opens this app rather than whatever else claims the URL', () {
        expect(shortcut, contains('android:targetPackage="cc.hrva.garage"'));
        expect(
          shortcut,
          contains('android:targetClass="cc.hrva.garage.MainActivity"'),
        );
        expect(shortcut, contains('android.intent.action.VIEW'));
      });

      test('spends the one link resource, not a copy of it', () {
        expect(shortcut, contains('android:data="@string/$linkName"'));
      });

      // Both are required. A shortcut missing either is dropped at install
      // time with a log line nobody reads.
      test('carries the labels the launcher asks for', () {
        expect(shortcut, contains('android:shortcutShortLabel='));
        expect(shortcut, contains('android:shortcutLongLabel='));
      });
    });

    group('${entry.name}: the home-screen widget', () {
      test('is declared as a receiver pointing at its provider info', () {
        expect(manifest, contains('android:name=".${entry.widgetClass}"'));
        expect(
          manifest,
          contains('android:resource="@xml/${entry.name}_widget_info"'),
        );
      });

      test('lays out the view its Kotlin fills in', () {
        expect(widgetInfo, contains('@layout/widget_${entry.name}'));
        expect(
          File(
            'android/app/src/main/res/layout/widget_${entry.name}.xml',
          ).existsSync(),
          isTrue,
        );
        expect(widgetSource, contains('R.layout.widget_${entry.name}'));
      });

      test('opens the same link resource as the shortcut', () {
        expect(widgetSource, contains('R.string.$linkName'));
      });

      // Since API 31 a PendingIntent must declare mutability, and one that
      // does not throws the moment the widget is placed — on the device, in a
      // process with no Flutter engine and no failure log.
      test('builds an immutable PendingIntent, as API 31 requires', () {
        expect(widgetSource, contains('FLAG_IMMUTABLE'));
      });

      // It shows a label and an icon and nothing else. Writing into the
      // layout at runtime is how a widget displays app data, and app data is
      // what a process with no Flutter engine cannot get at; see decision 58.
      test(
        'fills nothing in at runtime, because it has nothing to fill in',
        () {
          expect(widgetSource, isNot(contains('setTextViewText')));
          expect(widgetSource, isNot(contains('setImageViewBitmap')));
        },
      );
    });
  }

  test('the shortcuts are registered on the launcher activity', () {
    expect(manifest, contains('android:name="android.app.shortcuts"'));
    expect(manifest, contains('android:resource="@xml/shortcuts"'));
  });

  test('every widget listens for the launcher asking it to draw', () {
    expect(
      'android.appwidget.action.APPWIDGET_UPDATE'.allMatches(manifest),
      hasLength(_entryPoints.length),
    );
    expect(
      'android:name="android.appwidget.provider"'.allMatches(manifest),
      hasLength(_entryPoints.length),
    );
  });

  test('Flutter is asked to read the intent URL it is handed', () {
    // Without this the activity starts and the URL is dropped, so every
    // launcher entry point and every app link lands on the dashboard.
    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:value="true"'));
  });

  // Nothing else checks these: they are Android resources, so the ARB
  // consistency test cannot see them, and a missing translation shows up as
  // English on a Croatian or Italian phone's home screen.
  test('every launcher label a person reads is translated', () {
    final names = RegExp(
      r'<string name="(\w+)"(?![^>]*translatable="false")',
    ).allMatches(strings).map((m) => m.group(1)!).toSet();

    expect(names, isNotEmpty);
    for (final MapEntry(key: locale, value: translated)
        in translations.entries) {
      for (final name in names) {
        expect(
          resource(translated, name),
          isNotNull,
          reason: '$name is not translated in values-$locale/strings.xml',
        );
      }
    }
  });
}

/// The name the router spells [route] with.
String _routeConstant(String route) => switch (route) {
  quickFuelRoute => 'quickFuelRoute',
  quickCostRoute => 'quickCostRoute',
  _ => throw ArgumentError(route),
};
