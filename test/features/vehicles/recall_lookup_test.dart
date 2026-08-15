import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/features/vehicles/data/recall_lookup.dart';
import 'package:http/http.dart' as http;

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

http.Response recalls(List<Map<String, Object?>> results) {
  return http.Response(
    jsonEncode({'Count': results.length, 'results': results}),
    200,
  );
}

final _one = {
  'NHTSACampaignNumber': '23V123000',
  'Component': 'ENGINE',
  'Summary': 'The coil pack may fail.',
  'Consequence': 'A stall increases the risk of a crash.',
  'Remedy': 'Dealers will replace the coil pack free of charge.',
  'ReportReceivedDate': '01/03/2023',
};

void main() {
  test('open recalls come back for a make, model, and year', () async {
    final client = FakeHttpClient((_) => recalls([_one]));

    final found = await RecallLookup(
      client: client,
    ).forVehicle(make: 'Volkswagen', model: 'Golf', year: 2015);

    expect(found, hasLength(1));
    expect(found.single.campaign, '23V123000');
    expect(found.single.component, 'ENGINE');
    expect(found.single.summary, 'The coil pack may fail.');
    expect(found.single.remedy, contains('replace the coil pack'));
  });

  test('it asks the registry for exactly that vehicle', () async {
    final client = FakeHttpClient((_) => recalls([]));

    await RecallLookup(
      client: client,
    ).forVehicle(make: 'Volkswagen', model: 'Golf', year: 2015);

    final asked = client.requested.single;
    expect(asked.host, 'api.nhtsa.gov');
    expect(asked.queryParameters['make'], 'Volkswagen');
    expect(asked.queryParameters['model'], 'Golf');
    expect(asked.queryParameters['modelYear'], '2015');
  });

  test('a vehicle with nothing recalled comes back empty', () async {
    final client = FakeHttpClient((_) => recalls([]));

    final found = await RecallLookup(
      client: client,
    ).forVehicle(make: 'Volkswagen', model: 'Golf', year: 2015);

    expect(found, isEmpty);
  });

  test('a vehicle missing its make or model is not looked up', () async {
    final client = FakeHttpClient((_) => recalls([_one]));

    expect(
      await RecallLookup(
        client: client,
      ).forVehicle(make: null, model: 'Golf', year: 2015),
      isEmpty,
    );
    expect(
      await RecallLookup(
        client: client,
      ).forVehicle(make: 'Volkswagen', model: 'Golf', year: null),
      isEmpty,
    );
    expect(client.requested, isEmpty);
  });

  test('a server error becomes a network failure, not a crash', () async {
    final client = FakeHttpClient((_) => http.Response('nope', 503));

    await expectLater(
      RecallLookup(
        client: client,
      ).forVehicle(make: 'Volkswagen', model: 'Golf', year: 2015),
      throwsA(
        isA<AppFailure>().having((f) => f.kind, 'kind', AppFailureKind.network),
      ),
    );
  });

  test('a row missing its optional text still reads', () async {
    final client = FakeHttpClient(
      (_) => recalls([
        {'NHTSACampaignNumber': '23V999000', 'Component': 'BRAKES'},
      ]),
    );

    final found = await RecallLookup(
      client: client,
    ).forVehicle(make: 'Volkswagen', model: 'Golf', year: 2015);

    expect(found.single.campaign, '23V999000');
    expect(found.single.summary, isNull);
    expect(found.single.remedy, isNull);
  });
}
