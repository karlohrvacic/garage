import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/domain/stations/fuel_station.dart';
import 'package:garage/features/stations/widgets/station_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/pump_screen.dart';

FuelStation station({
  String? brand = 'INA',
  String? address = 'Ilica 1',
  List<StationPrice> prices = const [
    StationPrice(fuelName: 'eurodizel', fuelTypeId: 2, price: 1.62),
    StationPrice(fuelName: 'euroSUPER 95', fuelTypeId: 1, price: 1.54),
  ],
}) {
  return FuelStation(
    id: 1,
    name: 'BP Zagreb',
    brand: brand,
    address: address,
    place: 'Zagreb',
    lat: 45.815,
    lng: 15.9819,
    prices: prices,
  );
}

Future<NavigationLog> pumpSheet(
  WidgetTester tester, {
  FuelStation? subject,
  List<Uri>? opened,
}) {
  return pumpScreen(
    tester,
    Scaffold(body: StationDetailSheet(station: subject ?? station())),
    surface: const Size(420, 800),
    overrides: [
      urlOpenerProvider.overrideWithValue((url) async => opened?.add(url)),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('it names the station and where it is', (tester) async {
    await pumpSheet(tester);
    await tester.pumpAndSettle();

    expect(find.text('BP Zagreb'), findsOneWidget);
    expect(find.text('INA'), findsOneWidget);
    expect(find.textContaining('Ilica 1'), findsOneWidget);
  });

  testWidgets('a station with no brand shows just its name', (tester) async {
    await pumpSheet(tester, subject: station(brand: null));
    await tester.pumpAndSettle();

    expect(find.text('BP Zagreb'), findsOneWidget);
    expect(find.text('INA'), findsNothing);
  });

  testWidgets('every fuel it sells is priced', (tester) async {
    await pumpSheet(tester);
    await tester.pumpAndSettle();

    expect(find.text('euroSUPER 95'), findsOneWidget);
    expect(find.text('eurodizel'), findsOneWidget);
    expect(find.textContaining('1.54'), findsOneWidget);
    expect(find.textContaining('1.62'), findsOneWidget);
  });

  testWidgets('prices are ordered petrol, diesel, LPG', (tester) async {
    await pumpSheet(tester);
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();

    expect(texts.indexOf('euroSUPER 95'), lessThan(texts.indexOf('eurodizel')));
  });

  testWidgets('starring a station keeps it starred', (tester) async {
    await pumpSheet(tester);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_border), findsOneWidget);

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('the map button opens that location', (tester) async {
    final opened = <Uri>[];
    await pumpSheet(tester, opened: opened);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Open in maps'));
    await tester.pumpAndSettle();

    expect(opened.single.host, 'www.google.com');
    expect(opened.single.queryParameters['query'], '45.815,15.9819');
  });
}
