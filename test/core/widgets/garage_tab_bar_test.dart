import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/core/widgets/garage_tab_bar.dart';
import 'package:garage/l10n/app_localizations.dart';

/// The app's own text face. The test font draws every glyph a full em wide,
/// which makes every label longer than any phone would and says nothing
/// about what fits.
Future<void> _loadInter() async {
  final font = FontLoader('Inter')
    ..addFont(rootBundle.load('fonts/InterDisplay-Regular.ttf'))
    ..addFont(rootBundle.load('fonts/InterDisplay-Medium.ttf'))
    ..addFont(rootBundle.load('fonts/InterDisplay-SemiBold.ttf'));
  await font.load();
}

Future<void> _pumpStrip(
  WidgetTester tester,
  List<String> labels, {
  double width = 360,
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: GarageTheme.dark(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: DefaultTabController(
            length: labels.length,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Golf'),
                bottom: GarageTabBar(labels: labels),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

bool _scrolls(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).isScrollable;

/// The labels drawn narrower than they are: a fixed strip fades a label that
/// does not fit its share rather than wrapping or throwing, so nothing else
/// notices.
List<String> _cutOff(WidgetTester tester, List<String> labels) => [
  for (final label in labels)
    if (tester.renderObject<RenderParagraph>(find.text(label))
        case final paragraph
        when paragraph.size.width + 0.5 <
            paragraph.getMaxIntrinsicWidth(double.infinity))
      label,
];

void main() {
  testWidgets('shares the width out evenly when every label fits', (
    tester,
  ) async {
    await _loadInter();
    await _pumpStrip(tester, ['Fuel', 'Upkeep', 'Car', 'Costs']);

    expect(_scrolls(tester), isFalse);
    // Each label centred in its own quarter.
    for (final (index, label) in ['Fuel', 'Upkeep', 'Car', 'Costs'].indexed) {
      expect(
        tester.getCenter(find.text(label)).dx,
        closeTo((index + 0.5) * 360 / 4, 1),
      );
    }
  });

  testWidgets('scrolls rather than cut a label off', (tester) async {
    // A fixed strip gives each tab a quarter of the width whatever it says;
    // "Reminders" was faded out mid-word on a 360-pixel phone at the default
    // font size, and the test that was meant to notice read a property that
    // a tab label can never set.
    await _loadInter();
    const labels = ['Economy', 'Reminders', 'Services', 'Costs'];
    await _pumpStrip(tester, labels);

    expect(_scrolls(tester), isTrue);
    expect(_cutOff(tester, labels), isEmpty);
  });

  // Every tabbed screen of four, in every language, at every size a phone
  // offers. Android goes to 2.0 in its accessibility settings, and plenty of
  // people run 1.3 without thinking of it as a setting at all.
  final strips = <String, List<String> Function(AppLocalizations)>{
    'the car': (l10n) => [
      l10n.vehicleTabFuel,
      l10n.vehicleTabUpkeep,
      l10n.vehicleTabCar,
      l10n.costsTitle,
    ],
    'statistics': (l10n) => [
      l10n.statsTabFillUps,
      l10n.statsTabCosts,
      l10n.statsTabDistance,
      l10n.statsTabTrips,
    ],
  };

  for (final MapEntry(key: screen, value: labelsOf) in strips.entries) {
    for (final language in AppLocalizations.supportedLocales) {
      final labels = labelsOf(lookupAppLocalizations(language));

      testWidgets('$screen: no tab is cut off in $language at any size', (
        tester,
      ) async {
        await _loadInter();
        for (final width in [320.0, 360.0, 412.0]) {
          for (final scale in [1.0, 1.3, 1.6, 2.0]) {
            await _pumpStrip(tester, labels, width: width, textScale: scale);

            expect(
              _cutOff(tester, labels),
              isEmpty,
              reason: 'cut off at $width pixels and a font scale of $scale',
            );
          }
        }
      });
    }
  }

  // Scrolling is the fallback, not the layout: on an ordinary phone at the
  // ordinary size the car's four tabs share the strip in every language.
  for (final language in AppLocalizations.supportedLocales) {
    testWidgets('the car\'s tabs fit a 360-pixel phone in $language', (
      tester,
    ) async {
      await _loadInter();
      final l10n = lookupAppLocalizations(language);
      await _pumpStrip(tester, [
        l10n.vehicleTabFuel,
        l10n.vehicleTabUpkeep,
        l10n.vehicleTabCar,
        l10n.costsTitle,
      ]);

      expect(_scrolls(tester), isFalse);
    });
  }
}
