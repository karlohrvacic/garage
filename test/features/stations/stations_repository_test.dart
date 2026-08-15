import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/features/stations/data/stations_repository.dart';
import 'package:http/http.dart' as http;

/// Answers whatever the test hands it, and records what was asked for.
class FakeHttpClient extends http.BaseClient {
  FakeHttpClient(this.responder);

  final http.Response Function(Uri url) responder;
  final List<Uri> requested = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requested.add(request.url);
    final response = responder(request.url);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
    );
  }
}

final _stationsPayload = {
  'obvezniks': [
    {'id': 5, 'naziv': 'INA'},
  ],
  'vrsta_gorivas': [
    {'id': 1, 'vrsta_goriva': 'Eurosuper 95', 'tip_goriva_id': 1},
  ],
  'gorivos': [
    {'id': 10, 'naziv': 'euroSUPER 95', 'vrsta_goriva_id': 1},
  ],
  'postajas': [
    {
      'id': 1,
      'naziv': 'BP Zagreb',
      'adresa': 'Ilica 1',
      'mjesto': 'Zagreb',
      'obveznik_id': 5,
      'long': '45.8150',
      'lat': '15.9819',
      'cjenici': [
        {'id': 100, 'gorivo_id': 10, 'cijena': 1.54},
      ],
    },
  ],
};

http.Response gzipped(Object payload) {
  final bytes = GZipEncoder().encode(utf8.encode(jsonEncode(payload)));
  return http.Response.bytes(bytes, 200);
}

void main() {
  group('fetchStations', () {
    test('gunzips and parses the ministry payload', () async {
      final client = FakeHttpClient((_) => gzipped(_stationsPayload));

      final stations = await StationsRepository(client: client).fetchStations();

      expect(stations, hasLength(1));
      expect(stations.single.name, 'BP Zagreb');
      expect(stations.single.brand, 'INA');
      expect(stations.single.prices.single.price, 1.54);
    });

    test('asks the ministry host for the compressed dataset', () async {
      final client = FakeHttpClient((_) => gzipped(_stationsPayload));

      await StationsRepository(client: client).fetchStations();

      expect(client.requested.single.host, 'webservis.mzoe-gor.hr');
      expect(client.requested.single.path, '/data.gz');
    });

    test('a non-200 becomes a network failure, not a crash', () async {
      final client = FakeHttpClient((_) => http.Response('nope', 503));

      await expectLater(
        StationsRepository(client: client).fetchStations(),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            AppFailureKind.network,
          ),
        ),
      );
    });

    test('a body that is not gzip becomes a failure, not a crash', () async {
      final client = FakeHttpClient((_) => http.Response('not gzip', 200));

      await expectLater(
        StationsRepository(client: client).fetchStations(),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('fetchTrend', () {
    test('reads the national average series', () async {
      final client = FakeHttpClient(
        (_) => http.Response(
          jsonEncode([
            {'dat_poc': '2026-07-01', 'tip_goriva_id': 2, 'avg_cijena': 1.62},
          ]),
          200,
        ),
      );

      final trend = await StationsRepository(client: client).fetchTrend();

      expect(trend.single.date, DateTime.utc(2026, 7, 1));
      expect(trend.single.fuelTypeId, 2);
      expect(trend.single.avgPrice, 1.62);
    });

    test('a row with an unparseable date is skipped, not fatal', () async {
      final client = FakeHttpClient(
        (_) => http.Response(
          jsonEncode([
            {'dat_poc': 'not a date', 'tip_goriva_id': 2, 'avg_cijena': 1.62},
            {'dat_poc': '2026-07-02', 'tip_goriva_id': 1, 'avg_cijena': 1.44},
          ]),
          200,
        ),
      );

      final trend = await StationsRepository(client: client).fetchTrend();

      expect(trend, hasLength(1));
      expect(trend.single.fuelTypeId, 1);
    });

    test('missing numerics fall back rather than throwing', () async {
      final client = FakeHttpClient(
        (_) => http.Response(
          jsonEncode([
            {'dat_poc': '2026-07-01'},
          ]),
          200,
        ),
      );

      final trend = await StationsRepository(client: client).fetchTrend();

      expect(trend.single.fuelTypeId, 0);
      expect(trend.single.avgPrice, 0);
    });

    test('a non-200 becomes a network failure', () async {
      final client = FakeHttpClient((_) => http.Response('nope', 500));

      await expectLater(
        StationsRepository(client: client).fetchTrend(),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.kind,
            'kind',
            AppFailureKind.network,
          ),
        ),
      );
    });
  });
}
