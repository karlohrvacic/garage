/// Reading one Car Scanner recording as one drive.
///
/// A Car Scanner export is not a list of trips: it is telemetry, one row per
/// sample per channel, tens of thousands of rows for a half-hour drive and
/// eighty megabytes for a long one. What the app wants from it is a single
/// line in the trip log, so this accumulates rather than parses — lines go in
/// one at a time and nothing but four running maxima is kept, which is what
/// makes an eighty-megabyte file survivable on a phone.
///
/// The long format, `SECONDS;PID;VALUE;UNITS;LATITUDE;LONGTITUDE`, is what
/// "export records" produces, one file per drive. The wide format (one column
/// per channel) is a different export of the same data and is recognised only
/// to say so.
library;

/// The channels worth keeping, and what they mean.
///
/// `Distance travelled` is this drive; `Distance travelled (total)` is Car
/// Scanner's own running total across drives and is deliberately **not** read
/// as an odometer — it starts wherever the app was installed, and writing it
/// into a car's odometer would be a fabricated reading.
const _distancePid = 'Distance travelled';
const _fuelPid = 'Fuel used';
const _pricePid = 'Fuel used price';

/// What one recording adds up to.
class CarScannerDrive {
  const CarScannerDrive({
    required this.startedAt,
    required this.minutes,
    this.distanceKm,
    this.litresUsed,
    this.amountPaid,
  });

  /// From the file's own name, which Car Scanner writes as the local date and
  /// time the recording began. The `SECONDS` column counts from midnight and
  /// agrees with it; the name is used because it is unambiguous about the day.
  ///
  /// Null when the name was not one Car Scanner wrote — renamed, or saved by
  /// something that renamed it. The recording is still a drive; nothing in it
  /// says which day, so the screen asks rather than inventing one. Today's
  /// date would be a guess wearing the clothes of a fact.
  final DateTime? startedAt;

  final int minutes;
  final double? distanceKm;
  final double? litresUsed;
  final double? amountPaid;

  /// Litres per 100 km over the whole drive.
  ///
  /// Computed from the totals rather than read from the file's own average:
  /// that channel spikes to hundreds of litres per 100 km whenever the car
  /// idles, and its maximum is meaningless.
  double? get litresPerHundredKm {
    final distance = distanceKm;
    final litres = litresUsed;
    if (distance == null || litres == null || distance <= 0) {
      return null;
    }
    return litres / distance * 100;
  }

  /// A recording of a car that never went anywhere: the scanner left running
  /// in a parked car, which is most of what a long thin recording is.
  bool get wentNowhere => (distanceKm ?? 0) < 0.5;
}

/// Feeds on the lines of one recording and keeps only what a trip needs.
class CarScannerReading {
  double? _firstSecond;
  double? _lastSecond;
  double? _distance;
  double? _fuel;
  double? _price;
  bool _sawHeader = false;
  int _rows = 0;

  /// Whether anything in this file looked like the long-format export.
  bool get recognised => _sawHeader && _rows > 0;

  void addLine(String line) {
    if (line.isEmpty) {
      return;
    }
    if (!_sawHeader) {
      // The header names its columns in quotes and semicolons; anything else
      // is a different file and there is nothing to read.
      final upper = line.toUpperCase();
      _sawHeader = upper.contains('SECONDS') && upper.contains('PID');
      return;
    }

    final parts = line.split(';');
    if (parts.length < 3) {
      return;
    }
    final second = _number(parts[0]);
    if (second != null) {
      _firstSecond = _firstSecond == null
          ? second
          : (second < _firstSecond! ? second : _firstSecond);
      _lastSecond = _lastSecond == null
          ? second
          : (second > _lastSecond! ? second : _lastSecond);
    }
    final pid = _unquote(parts[1]);
    final value = _number(parts[2]);
    if (value == null) {
      return;
    }
    _rows++;
    switch (pid) {
      case _distancePid:
        _distance = _max(_distance, value);
      case _fuelPid:
        _fuel = _max(_fuel, value);
      case _pricePid:
        _price = _max(_price, value);
    }
  }

  /// The drive, or null when the file was not one.
  CarScannerDrive? drive(DateTime? startedAt) {
    if (!recognised) {
      return null;
    }
    final from = _firstSecond;
    final to = _lastSecond;
    // Rounded, not truncated: a drive of ten minutes forty seconds is eleven,
    // the same rule the app's own drive drafts use.
    final minutes = (from == null || to == null)
        ? 0
        : ((to - from) / 60).round();
    return CarScannerDrive(
      startedAt: startedAt,
      minutes: minutes,
      distanceKm: _distance,
      litresUsed: _fuel,
      amountPaid: _price,
    );
  }

  /// One numeric field, in whichever convention the phone wrote it.
  ///
  /// Car Scanner follows the device's locale, and a device that writes "2,57"
  /// is exactly the kind that makes the export semicolon-delimited in the
  /// first place — the separator is a semicolon *because* the comma is taken.
  /// Read strictly, such a file parses as no rows at all, is not recognised as
  /// a recording, and lands in the column-mapping screen as an unmappable
  /// table: a confusing way to be told "wrong locale".
  ///
  /// The plain parse is tried first, so anything already in the machine
  /// convention is untouched. Only past it does the grouping question arise,
  /// and there the *later* separator is the decimal one, which is true of both
  /// conventions.
  static double? _number(String field) {
    final text = _unquote(field);
    final direct = double.tryParse(text);
    if (direct != null) {
      return direct;
    }
    final comma = text.lastIndexOf(',');
    final dot = text.lastIndexOf('.');
    if (comma < 0) {
      return null;
    }
    return double.tryParse(
      comma > dot
          ? text.replaceAll('.', '').replaceAll(',', '.')
          : text.replaceAll(',', ''),
    );
  }

  static double _max(double? current, double value) =>
      current == null || value > current ? value : current;

  static String _unquote(String field) {
    final trimmed = field.trim();
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }
}

/// The local date and time in a Car Scanner file name, `2026-01-27 23-38-14`.
///
/// Returns null for a name it does not recognise, and the caller falls back to
/// asking. Guessing a date from a file's modification time would be worse: a
/// copied file carries the day it was copied.
DateTime? carScannerDateFromName(String fileName) {
  final match = RegExp(
    r'(\d{4})-(\d{2})-(\d{2})[ _](\d{2})-(\d{2})-(\d{2})',
  ).firstMatch(fileName);
  if (match == null) {
    return null;
  }
  int at(int group) => int.parse(match.group(group)!);
  return DateTime(at(1), at(2), at(3), at(4), at(5), at(6));
}
