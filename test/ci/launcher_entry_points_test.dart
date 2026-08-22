import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/core/router/app_redirect.dart';

/// The two Android launcher entry points — the icon's long-press shortcut and
/// the home-screen widget — reach a Flutter route through five files that
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
  final croatian = read('android/app/src/main/res/values-hr/strings.xml');
  final shortcuts = read('android/app/src/main/res/xml/shortcuts.xml');
  final widgetInfo = read(
    'android/app/src/main/res/xml/log_fuel_widget_info.xml',
  );
  final widgetSource = read(
    'android/app/src/main/kotlin/cc/hrva/garage/LogFuelWidget.kt',
  );
  final router = read('lib/core/router/app_router.dart');

  /// The value of `<string name="…">` in an Android resource file.
  String? resource(String xml, String name) {
    final match = RegExp(
      '<string name="$name"[^>]*>(.*?)</string>',
      dotAll: true,
    ).firstMatch(xml);
    return match?.group(1);
  }

  group('the link both entry points open', () {
    test('is the route the app actually serves', () {
      final declared = resource(strings, 'deep_link_log_fuel');

      expect(declared, isNotNull, reason: 'no deep_link_log_fuel string');
      final link = Uri.parse(declared!);
      expect(link.scheme, 'https');
      expect(link.host, GarageLinks.host);
      expect(link.path, quickFuelRoute);
    });

    test('and is the one the Dart side builds', () {
      expect(
        GarageLinks.logFuel.toString(),
        resource(strings, 'deep_link_log_fuel'),
      );
    });

    test('and is registered as a route', () {
      expect(router, contains('quickFuelRoute'));
    });

    // A URL is not a label. Translating it would send Croatian phones to a
    // host that does not exist, and nothing would report it.
    test('is never translated', () {
      expect(
        strings,
        contains(RegExp(r'name="deep_link_log_fuel"\s+translatable="false"')),
      );
      expect(resource(croatian, 'deep_link_log_fuel'), isNull);
    });
  });

  group('the app-icon shortcut', () {
    test('is registered on the launcher activity', () {
      expect(manifest, contains('android:name="android.app.shortcuts"'));
      expect(manifest, contains('android:resource="@xml/shortcuts"'));
    });

    test('opens this app rather than whatever else claims the URL', () {
      expect(shortcuts, contains('android:targetPackage="cc.hrva.garage"'));
      expect(
        shortcuts,
        contains('android:targetClass="cc.hrva.garage.MainActivity"'),
      );
      expect(shortcuts, contains('android.intent.action.VIEW'));
    });

    test('spends the one link resource, not a copy of it', () {
      expect(shortcuts, contains('android:data="@string/deep_link_log_fuel"'));
    });

    // Both are required. A shortcut missing either is dropped at install time
    // with a log line nobody reads.
    test('carries the labels the launcher asks for', () {
      expect(shortcuts, contains('android:shortcutShortLabel='));
      expect(shortcuts, contains('android:shortcutLongLabel='));
    });
  });

  group('the home-screen widget', () {
    test('is declared as a receiver pointing at its provider info', () {
      expect(manifest, contains('android:name=".LogFuelWidget"'));
      expect(manifest, contains('android:name="android.appwidget.provider"'));
      expect(
        manifest,
        contains('android:resource="@xml/log_fuel_widget_info"'),
      );
      expect(manifest, contains('android.appwidget.action.APPWIDGET_UPDATE'));
    });

    test('lays out the view its Kotlin fills in', () {
      expect(widgetInfo, contains('@layout/widget_log_fuel'));
      expect(
        File(
          'android/app/src/main/res/layout/widget_log_fuel.xml',
        ).existsSync(),
        isTrue,
      );
      expect(widgetSource, contains('R.layout.widget_log_fuel'));
    });

    test('opens the same link resource as the shortcut', () {
      expect(widgetSource, contains('R.string.deep_link_log_fuel'));
    });

    // Since API 31 a PendingIntent must declare mutability, and one that does
    // not throws the moment the widget is placed — on the device, in a process
    // with no Flutter engine and no failure log.
    test('builds an immutable PendingIntent, as API 31 requires', () {
      expect(widgetSource, contains('FLAG_IMMUTABLE'));
    });

    // It shows a label and an icon and nothing else. Writing into the layout
    // at runtime is how a widget displays app data, and app data is what a
    // process with no Flutter engine cannot get at; see decision 58.
    test('fills nothing in at runtime, because it has nothing to fill in', () {
      expect(widgetSource, isNot(contains('setTextViewText')));
      expect(widgetSource, isNot(contains('setImageViewBitmap')));
    });
  });

  test('Flutter is asked to read the intent URL it is handed', () {
    // Without this the activity starts and the URL is dropped, so every
    // launcher entry point and every app link lands on the dashboard.
    expect(manifest, contains('android:name="flutter_deeplinking_enabled"'));
    expect(manifest, contains('android:value="true"'));
  });

  // Nothing else checks these: they are Android resources, so the ARB
  // consistency test cannot see them, and a missing translation shows up as
  // English on a Croatian phone's home screen.
  test('every launcher label a person reads has a Croatian one', () {
    final names = RegExp(
      r'<string name="(\w+)"(?![^>]*translatable="false")',
    ).allMatches(strings).map((m) => m.group(1)!).toSet();

    expect(names, isNotEmpty);
    for (final name in names) {
      expect(
        resource(croatian, name),
        isNotNull,
        reason: '$name is not translated in values-hr/strings.xml',
      );
    }
  });
}
