import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_failure.dart';

/// What a VIN lookup could tell us. Any field may be blank: the registry knows
/// American-market vehicles best, and a European VIN often decodes to the make
/// and little else.
class DecodedVin {
  const DecodedVin({this.make, this.model, this.year, this.trim});

  final String? make;
  final String? model;
  final int? year;
  final String? trim;

  bool get isEmpty =>
      make == null && model == null && year == null && trim == null;

  @override
  String toString() =>
      'DecodedVin(make: $make, model: $model, year: $year, trim: $trim)';
}

/// Decodes a VIN through NHTSA's vPIC registry — the one free, unauthenticated
/// source for this. It is US-oriented, so a decode is a starting point for the
/// vehicle form, never the last word: every field it fills stays editable.
class VinDecoder {
  VinDecoder({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'vpic.nhtsa.dot.gov';

  final http.Client _client;

  Future<DecodedVin> decode(String vin) async {
    final cleaned = vin.trim().toUpperCase();
    // A VIN is 17 characters by standard; anything else is a typo, and asking
    // the registry about it only costs a round trip to be told so.
    if (cleaned.length != 17) {
      throw const AppFailure(
        kind: AppFailureKind.notFound,
        debugMessage: 'a VIN is 17 characters',
      );
    }

    final url = Uri.https(_host, '/api/vehicles/DecodeVinValues/$cleaned', {
      'format': 'json',
    });

    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw AppFailure(
          kind: AppFailureKind.network,
          debugMessage: 'vPIC -> ${response.statusCode}',
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = body['Results'] as List<dynamic>;
      final row = results.first as Map<String, dynamic>;

      // ErrorCode 0 is a clean decode; anything else means the registry could
      // not place the VIN, and its half-guesses are not worth prefilling.
      final errorCode = (row['ErrorCode'] as String?)?.split(',').first;
      if (errorCode != null && errorCode != '0') {
        return const DecodedVin();
      }

      return DecodedVin(
        make: _titleCase(_value(row['Make'])),
        model: _titleCase(_value(row['Model'])),
        year: int.tryParse(_value(row['ModelYear']) ?? ''),
        trim: _titleCase(_value(row['Trim'])),
      );
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  static String? _value(Object? raw) {
    final text = (raw as String?)?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  /// The registry shouts: "VOLKSWAGEN", "E-CLASS". Title-case each word and
  /// each hyphenated part so it reads like a vehicle name on screen.
  static String? _titleCase(String? value) {
    if (value == null) {
      return null;
    }
    return value
        .split(' ')
        .map(
          (word) => word
              .split('-')
              .map(
                (part) => part.isEmpty
                    ? part
                    : part[0].toUpperCase() + part.substring(1).toLowerCase(),
              )
              .join('-'),
        )
        .join(' ');
  }
}
