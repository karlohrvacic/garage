import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/features/vehicles/data/vin_decoder.dart';
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

http.Response vpic(Map<String, Object?> result) {
  return http.Response(
    jsonEncode({
      'Count': 1,
      'Message': 'Results returned successfully',
      'Results': [result],
    }),
    200,
  );
}

void main() {
  test('a decoded VIN fills in what the registry knows', () async {
    final client = FakeHttpClient(
      (_) => vpic({
        'Make': 'VOLKSWAGEN',
        'Model': 'Golf',
        'ModelYear': '2015',
        'Trim': 'Highline',
        'ErrorCode': '0',
      }),
    );

    final decoded = await VinDecoder(
      client: client,
    ).decode('WVWZZZ1KZAW000001');

    expect(decoded.make, 'Volkswagen');
    expect(decoded.model, 'Golf');
    expect(decoded.year, 2015);
    expect(decoded.trim, 'Highline');
  });

  test('it asks the government registry for that VIN', () async {
    final client = FakeHttpClient((_) => vpic({'ErrorCode': '0'}));

    await VinDecoder(client: client).decode('WVWZZZ1KZAW000001');

    expect(client.requested.single.host, 'vpic.nhtsa.dot.gov');
    expect(
      client.requested.single.path,
      contains('DecodeVinValues/WVWZZZ1KZAW000001'),
    );
  });

  test('fields the registry left blank read as null, not empty text', () async {
    final client = FakeHttpClient(
      (_) => vpic({
        'Make': 'VOLKSWAGEN',
        'Model': '',
        'ModelYear': '',
        'Trim': null,
        'ErrorCode': '0',
      }),
    );

    final decoded = await VinDecoder(
      client: client,
    ).decode('WVWZZZ1KZAW000001');

    expect(decoded.model, isNull);
    expect(decoded.year, isNull);
    expect(decoded.trim, isNull);
  });

  test('a decode that found nothing is empty rather than wrong', () async {
    final client = FakeHttpClient((_) => vpic({'ErrorCode': '11'}));

    // 17 characters, so it reaches the registry — which cannot place it.
    final decoded = await VinDecoder(
      client: client,
    ).decode('11111111111111111');

    expect(decoded.isEmpty, isTrue);
  });

  test('a VIN of the wrong length is refused before any request', () async {
    final client = FakeHttpClient((_) => vpic({'ErrorCode': '0'}));

    await expectLater(
      VinDecoder(client: client).decode('SHORT'),
      throwsA(isA<AppFailure>()),
    );
    expect(client.requested, isEmpty);
  });

  test('a server error becomes a network failure, not a crash', () async {
    final client = FakeHttpClient((_) => http.Response('nope', 503));

    await expectLater(
      VinDecoder(client: client).decode('WVWZZZ1KZAW000001'),
      throwsA(
        isA<AppFailure>().having((f) => f.kind, 'kind', AppFailureKind.network),
      ),
    );
  });

  test('a body that is not the expected shape becomes a failure', () async {
    final client = FakeHttpClient((_) => http.Response('{"nope": true}', 200));

    await expectLater(
      VinDecoder(client: client).decode('WVWZZZ1KZAW000001'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('a make in registry shouting is title-cased for display', () async {
    final client = FakeHttpClient(
      (_) =>
          vpic({'Make': 'MERCEDES-BENZ', 'Model': 'E-CLASS', 'ErrorCode': '0'}),
    );

    final decoded = await VinDecoder(
      client: client,
    ).decode('WDD2130421A000001');

    expect(decoded.make, 'Mercedes-Benz');
    expect(decoded.model, 'E-Class');
  });
}
