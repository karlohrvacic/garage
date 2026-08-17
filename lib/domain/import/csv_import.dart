import 'csv_table.dart';

/// What a column of a CSV can be turned into.
enum CsvValueType { date, number, integer, text, flag }

/// One thing an entry kind needs from the file.
class CsvField {
  const CsvField({
    required this.key,
    required this.type,
    this.required = false,
    this.synonyms = const [],
  });

  /// The name the built rows use, and the name a mapping is keyed on.
  final String key;

  final CsvValueType type;

  /// Whether a row without it is a row that cannot be imported.
  final bool required;

  /// Words another app or spreadsheet is likely to have used for this column.
  /// Matched loosely — case and punctuation are ignored — so "Odo (km)" finds
  /// the odometer without the user having to say so.
  final List<String> synonyms;
}

/// The entry kinds a file can be imported as.
enum CsvEntryKind { fuel, cost, service, odometer, trip, income }

/// The fields each kind takes, and the guessing that saves the user most of
/// the mapping.
///
/// This is the answer to "import from Drivvo", and to every other app: rather
/// than reverse-engineering one export whose columns can change under us, the
/// user says which column is which, once, and the file can come from anywhere.
abstract final class CsvSchema {
  static const _date = CsvField(
    key: 'date',
    type: CsvValueType.date,
    required: true,
    synonyms: ['date', 'data', 'datum', 'day', 'when', 'timestamp'],
  );

  static const _odometer = CsvField(
    key: 'odometer',
    type: CsvValueType.integer,
    synonyms: ['odometer', 'odo', 'mileage', 'km', 'kilometers', 'miles'],
  );

  static const _notes = CsvField(
    key: 'notes',
    type: CsvValueType.text,
    synonyms: ['notes', 'note', 'comment', 'remarks', 'description'],
  );

  static List<CsvField> fieldsFor(CsvEntryKind kind) {
    return switch (kind) {
      CsvEntryKind.fuel => const [
        _date,
        CsvField(
          key: 'odometer',
          type: CsvValueType.integer,
          required: true,
          synonyms: ['odometer', 'odo', 'mileage', 'km', 'kilometers', 'miles'],
        ),
        CsvField(
          key: 'volume',
          type: CsvValueType.number,
          required: true,
          synonyms: [
            'volume',
            'litres',
            'liters',
            'gallons',
            'quantity',
            'kwh',
          ],
        ),
        CsvField(
          key: 'pricePerUnit',
          type: CsvValueType.number,
          synonyms: ['price', 'priceperl', 'pricel', 'unitprice', 'ppl'],
        ),
        CsvField(
          key: 'total',
          type: CsvValueType.number,
          synonyms: ['total', 'totalcost', 'cost', 'amount', 'paid', 'sum'],
        ),
        CsvField(
          key: 'fullTank',
          type: CsvValueType.flag,
          synonyms: ['full', 'fulltank', 'filledup'],
        ),
        CsvField(
          key: 'station',
          type: CsvValueType.text,
          synonyms: ['station', 'gasstation', 'petrolstation', 'place', 'shop'],
        ),
        _notes,
      ],
      CsvEntryKind.cost => const [
        _date,
        CsvField(
          key: 'amount',
          type: CsvValueType.number,
          required: true,
          synonyms: ['amount', 'cost', 'total', 'price', 'paid', 'sum'],
        ),
        CsvField(
          key: 'category',
          type: CsvValueType.text,
          synonyms: ['category', 'type', 'kind', 'expensetype'],
        ),
        _odometer,
        _notes,
      ],
      CsvEntryKind.service => const [
        _date,
        CsvField(
          key: 'odometer',
          type: CsvValueType.integer,
          required: true,
          synonyms: ['odometer', 'odo', 'mileage', 'km', 'kilometers', 'miles'],
        ),
        CsvField(
          key: 'type',
          type: CsvValueType.text,
          synonyms: ['type', 'service', 'servicetype', 'work', 'title'],
        ),
        CsvField(
          key: 'cost',
          type: CsvValueType.number,
          synonyms: ['cost', 'total', 'amount', 'price', 'paid'],
        ),
        CsvField(
          key: 'shop',
          type: CsvValueType.text,
          synonyms: ['shop', 'garage', 'workshop', 'place'],
        ),
        _notes,
      ],
      CsvEntryKind.odometer => const [
        _date,
        CsvField(
          key: 'odometer',
          type: CsvValueType.integer,
          required: true,
          synonyms: ['odometer', 'odo', 'mileage', 'km', 'kilometers', 'miles'],
        ),
        _notes,
      ],
      CsvEntryKind.trip => const [
        _date,
        CsvField(
          key: 'distance',
          type: CsvValueType.number,
          required: true,
          synonyms: ['distance', 'km', 'miles', 'length', 'kilometers'],
        ),
        CsvField(
          key: 'title',
          type: CsvValueType.text,
          synonyms: ['title', 'name', 'purpose', 'reason'],
        ),
        CsvField(
          key: 'from',
          type: CsvValueType.text,
          synonyms: ['from', 'start', 'origin', 'departure'],
        ),
        CsvField(
          key: 'to',
          type: CsvValueType.text,
          synonyms: ['to', 'end', 'destination', 'arrival'],
        ),
        CsvField(
          key: 'business',
          type: CsvValueType.flag,
          synonyms: ['business', 'work', 'iswork'],
        ),
        CsvField(
          key: 'minutes',
          type: CsvValueType.integer,
          synonyms: ['minutes', 'duration', 'time'],
        ),
        _notes,
      ],
      CsvEntryKind.income => const [
        _date,
        CsvField(
          key: 'amount',
          type: CsvValueType.number,
          required: true,
          synonyms: ['amount', 'income', 'total', 'earned', 'received', 'sum'],
        ),
        CsvField(
          key: 'category',
          type: CsvValueType.text,
          synonyms: ['category', 'type', 'kind', 'incometype'],
        ),
        _odometer,
        _notes,
      ],
    };
  }

  /// Reduces a header to letters and digits, so `Odo (km)` and `odometer_km`
  /// compare the way a reader would expect them to.
  static String _normalise(String header) =>
      header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// A best guess at which column feeds which field.
  ///
  /// Fields are matched in declaration order and a column, once claimed, is not
  /// offered again: "Cost" answers to several fields, and the first — the one
  /// the schema thinks matters most — should keep it. An unmatched field is
  /// left out rather than guessed at, because a wrong mapping that looks right
  /// is worse than an empty one the user has to fill in.
  static Map<String, int> guess(CsvEntryKind kind, List<String> headers) {
    final normalised = [for (final header in headers) _normalise(header)];
    final taken = <int>{};
    final mapping = <String, int>{};

    for (final field in fieldsFor(kind)) {
      final candidates = {_normalise(field.key), ...field.synonyms};
      // Exact matches first, so "km" does not take the column called
      // "kmper100" when a plain "km" exists further along.
      var found = -1;
      for (var i = 0; i < normalised.length && found < 0; i++) {
        if (!taken.contains(i) && candidates.contains(normalised[i])) {
          found = i;
        }
      }
      for (var i = 0; i < normalised.length && found < 0; i++) {
        if (taken.contains(i)) {
          continue;
        }
        if (candidates.any((c) => normalised[i].contains(c))) {
          found = i;
        }
      }
      if (found >= 0) {
        taken.add(found);
        mapping[field.key] = found;
      }
    }
    return mapping;
  }
}

/// One row, or one mapping, that could not be imported.
class CsvProblem {
  const CsvProblem({required this.field, this.rowNumber});

  /// The field that was missing or unreadable.
  final String field;

  /// The line in the file, counting the header as line 1, or null when the
  /// problem is with the mapping rather than with a row.
  final int? rowNumber;

  @override
  String toString() => 'CsvProblem(field: $field, rowNumber: $rowNumber)';
}

class CsvImportResult {
  const CsvImportResult({required this.rows, required this.problems});

  /// One map per importable row, keyed by field. An optional value that was
  /// blank or unreadable is absent rather than null, so a caller can tell
  /// "not given" from "given as nothing".
  final List<Map<String, Object>> rows;

  final List<CsvProblem> problems;

  bool get isUsable => rows.isNotEmpty;
}

abstract final class CsvImport {
  /// Words that mean yes. A flag column is written a dozen ways and none of
  /// them is `true`.
  static const _affirmative = {
    'true',
    'yes',
    'y',
    '1',
    'x',
    'da',
    'full',
    'business',
  };

  static CsvImportResult build({
    required CsvEntryKind kind,
    required CsvTable table,
    required Map<String, int> mapping,
    bool dayFirst = true,
  }) {
    final fields = CsvSchema.fieldsFor(kind);
    final problems = <CsvProblem>[];

    // A required field with no column is a problem with the mapping, not with
    // any one row, so nothing is built at all until it is fixed.
    for (final field in fields) {
      if (field.required && !mapping.containsKey(field.key)) {
        problems.add(CsvProblem(field: field.key));
      }
    }
    if (problems.isNotEmpty) {
      return CsvImportResult(rows: const [], problems: problems);
    }

    final rows = <Map<String, Object>>[];
    for (var index = 0; index < table.rows.length; index++) {
      final raw = table.rows[index];
      final built = <String, Object>{};
      CsvProblem? failure;

      for (final field in fields) {
        final value = _read(
          table.cell(raw, mapping[field.key]),
          field.type,
          dayFirst: dayFirst,
        );
        if (value != null) {
          built[field.key] = value;
        } else if (field.required) {
          // The header is line 1, so the first data row is line 2.
          failure = CsvProblem(field: field.key, rowNumber: index + 2);
          break;
        }
      }

      if (failure != null) {
        problems.add(failure);
      } else {
        rows.add(built);
      }
    }

    return CsvImportResult(rows: rows, problems: problems);
  }

  static Object? _read(
    String raw,
    CsvValueType type, {
    required bool dayFirst,
  }) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return switch (type) {
      CsvValueType.date => CsvTable.date(trimmed, dayFirst: dayFirst),
      CsvValueType.number => CsvTable.number(trimmed),
      CsvValueType.integer => CsvTable.number(trimmed)?.round(),
      CsvValueType.text => trimmed,
      CsvValueType.flag => _affirmative.contains(trimmed.toLowerCase()),
    };
  }
}
