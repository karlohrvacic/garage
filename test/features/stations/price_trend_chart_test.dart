import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/format/unit_format.dart';
import 'package:garage/core/theme/garage_theme.dart';
import 'package:garage/domain/stations/price_trend.dart';
import 'package:garage/features/stations/widgets/price_trend_chart.dart';

/// A fortnight of prices, and the chart drawn from it.
List<TrendPoint> series({required double lowest, required double highest}) {
  return [
    for (var day = 0; day < 14; day++)
      TrendPoint(
        date: DateTime.utc(2026, 8, 22).add(Duration(days: day)),
        fuelTypeId: 1,
        avgPrice: day.isEven ? lowest : highest,
      ),
  ];
}

Future<LineChartData> pumpChart(
  WidgetTester tester,
  List<TrendPoint> points, {
  String locale = 'en',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: GarageTheme.dark(),
      home: Scaffold(
        body: PriceTrendChart(
          series: points,
          format: UnitFormat(
            locale: locale,
            preferences: const UnitPreferences(
              distance: DistanceUnit.km,
              volume: VolumeUnit.liter,
              currencyCode: 'EUR',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<LineChart>(find.byType(LineChart)).data;
}

void main() {
  testWidgets('the axis runs from the lowest price to the highest', (
    tester,
  ) async {
    // It used to be padded by a tenth on each side, which put the bounds
    // outside the real range — and fl_chart walks its labels up from `minY`
    // by `interval`, so the padded band emitted a third label a few pixels
    // from the second and the two printed on top of each other. Seen on the
    // live Croatian feed while taking store screenshots.
    final data = await pumpChart(tester, series(lowest: 1.69, highest: 1.94));

    expect(data.minY, closeTo(1.69, 0.0001));
    expect(data.maxY, closeTo(1.94, 0.0001));
  });

  testWidgets('and labels exactly its two ends', (tester) async {
    final data = await pumpChart(tester, series(lowest: 1.69, highest: 1.94));
    final interval = data.titlesData.leftTitles.sideTitles.interval!;

    // Walking up from minY by the interval lands on maxY and stops, which is
    // two labels and no third to collide with.
    expect(interval, closeTo(1.94 - 1.69, 0.0001));
    expect(data.minY + interval, closeTo(data.maxY, 0.0001));
  });

  testWidgets('a flat fortnight still gets a band to draw in', (tester) async {
    // Lowest and highest equal is a zero-height axis, and a line has nowhere
    // to go.
    final data = await pumpChart(tester, series(lowest: 1.80, highest: 1.80));

    expect(data.maxY, greaterThan(data.minY));
    expect(data.titlesData.leftTitles.sideTitles.interval, greaterThan(0));
  });

  testWidgets('only the two ends are labelled, whatever else is offered', (
    tester,
  ) async {
    // fl_chart offers title positions of its own as well as the ones the
    // interval walks to; on a 120-pixel band two of them landed a few pixels
    // apart and printed on top of each other. Calling the builder directly
    // with a value between the ends is the cheapest way to prove the widget
    // itself refuses.
    final data = await pumpChart(tester, series(lowest: 1.69, highest: 1.94));
    final titles = data.titlesData.leftTitles.sideTitles;

    Widget at(double value) => titles.getTitlesWidget(
      value,
      TitleMeta(
        min: data.minY,
        max: data.maxY,
        parentAxisSize: 120,
        axisPosition: 0,
        appliedInterval: titles.interval!,
        sideTitles: titles,
        formattedValue: '',
        axisSide: AxisSide.left,
        rotationQuarterTurns: 0,
      ),
    );

    // A label, kept inside the chart; see the test below.
    expect(at(1.69), isA<SideTitleWidget>());
    expect(at(1.94), isA<SideTitleWidget>());
    expect(
      at(1.76),
      isA<SizedBox>(),
      reason: 'a third label a few pixels from another is the whole bug',
    );
  });

  testWidgets('no label runs into another, or off the edge', (tester) async {
    // The lowest price sat on the bottom edge and the first date was centred
    // on the left one, so in the corner they read as one number, "€1.7510/7";
    // the last date hung half off the right. Seen in the store screenshot.
    await pumpChart(tester, series(lowest: 1.75, highest: 1.95));

    final chart = tester.getRect(find.byType(LineChart));
    final lowest = tester.getRect(find.text('€1.75'));
    final firstDay = tester.getRect(find.text('22/8'));
    final lastDay = tester.getRect(find.text('4/9'));

    expect(lowest.overlaps(firstDay), isFalse);
    expect(lowest.bottom, lessThanOrEqualTo(firstDay.top));
    expect(lastDay.right, lessThanOrEqualTo(chart.right));
  });

  testWidgets('each label gets a whole line to itself', (tester) async {
    // Kept inside the chart, each label also gave up eight pixels of its box
    // to fl_chart's default spacing: a date was cut to 12 of its 16 pixels,
    // and the Croatian "1,75 €" wrapped onto two lines. Measured in the
    // app's own figures font, because the test font is wider than any label
    // box and would wrap everything.
    final font = FontLoader('JetBrainsMono')
      ..addFont(rootBundle.load('fonts/JetBrainsMono-Regular.ttf'));
    await font.load();

    await pumpChart(tester, series(lowest: 1.75, highest: 1.95), locale: 'hr');

    // The prices as Croatian prints them, a non-breaking space before the €.
    for (final label in ['1,75', '1,95', '22/8', '29/8', '4/9']) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.textContaining(label),
      );
      expect(
        paragraph.size.height,
        closeTo(paragraph.getMaxIntrinsicHeight(double.infinity), 0.5),
        reason: '$label is wrapped or cut',
      );
    }
  });
}
