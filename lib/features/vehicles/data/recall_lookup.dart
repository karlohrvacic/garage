import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_failure.dart';

/// One safety recall on a vehicle, as the registry describes it.
class Recall {
  const Recall({
    required this.campaign,
    required this.component,
    this.summary,
    this.consequence,
    this.remedy,
  });

  /// The manufacturer's campaign number, which a dealer will ask for.
  final String campaign;

  final String component;
  final String? summary;
  final String? consequence;
  final String? remedy;
}

/// Open safety recalls from NHTSA, the same free registry the VIN lookup uses.
///
/// It is a US dataset: a European-market car may have recalls that never
/// appear here, and a match here may not apply to a European build. So this is
/// shown as "worth checking with a dealer", never as the last word.
class RecallLookup {
  RecallLookup({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'api.nhtsa.gov';

  final http.Client _client;

  Future<List<Recall>> forVehicle({
    required String? make,
    required String? model,
    required int? year,
  }) async {
    // The registry keys on all three. Asking with a blank one returns
    // everything for the rest, which would be noise attributed to this car.
    if (make == null || model == null || year == null) {
      return const [];
    }

    final url = Uri.https(_host, '/recalls/recallsByVehicle', {
      'make': make,
      'model': model,
      'modelYear': '$year',
    });

    try {
      final response = await _client.get(url);
      if (response.statusCode != 200) {
        throw AppFailure(
          kind: AppFailureKind.network,
          debugMessage: 'recallsByVehicle -> ${response.statusCode}',
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = (body['results'] as List<dynamic>?) ?? const [];

      return [
        for (final row in results.cast<Map<String, dynamic>>())
          Recall(
            campaign: row['NHTSACampaignNumber'] as String? ?? '',
            component: row['Component'] as String? ?? '',
            summary: _text(row['Summary']),
            consequence: _text(row['Consequence']),
            remedy: _text(row['Remedy']),
          ),
      ];
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  static String? _text(Object? raw) {
    final value = (raw as String?)?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}
