import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_failure.dart';
import '../../../domain/stations/fuel_station.dart';

/// One point of the ministry's national average price series.
class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.fuelTypeId,
    required this.avgPrice,
  });

  final DateTime date;
  final int fuelTypeId;
  final double avgPrice;
}

/// Croatia's official fuel-price dataset (mzoe-gor.hr, MINGOR). One request
/// downloads every station with current prices; the server caches for five
/// minutes and allows cross-origin reads, so the app can fetch it directly on
/// both Android and web.
class StationsRepository {
  StationsRepository({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _dataUrl = Uri.parse(
    'https://webservis.mzoe-gor.hr/data.gz',
  );
  static final Uri _trendUrl = Uri.parse(
    'https://webservis.mzoe-gor.hr/api/trend-cijena',
  );

  final http.Client _client;

  Future<List<TrendPoint>> fetchTrend() async {
    try {
      final response = await _client.get(_trendUrl);
      if (response.statusCode != 200) {
        throw AppFailure(
          kind: AppFailureKind.network,
          debugMessage: 'trend-cijena -> ${response.statusCode}',
        );
      }
      final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
      return [
        for (final row in rows.cast<Map<String, dynamic>>())
          if (DateTime.tryParse(row['dat_poc'] as String? ?? '')
              case final DateTime date)
            TrendPoint(
              date: DateTime.utc(date.year, date.month, date.day),
              fuelTypeId: row['tip_goriva_id'] as int? ?? 0,
              avgPrice: (row['avg_cijena'] as num?)?.toDouble() ?? 0,
            ),
      ];
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Future<List<FuelStation>> fetchStations() async {
    try {
      final response = await _client.get(_dataUrl);
      if (response.statusCode != 200) {
        throw AppFailure(
          kind: AppFailureKind.network,
          debugMessage: 'data.gz -> ${response.statusCode}',
        );
      }
      final bytes = GZipDecoder().decodeBytes(response.bodyBytes);
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return parseStations(json);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}
