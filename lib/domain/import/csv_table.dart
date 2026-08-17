import 'package:csv/csv.dart';

/// A CSV file read as a header row and the rows under it.
///
/// This exists because the file the user has is not the file this app writes.
/// It came out of a spreadsheet, or another app's export, with whatever
/// delimiter and number format the machine that produced it happened to use.
/// Guessing those is the difference between an importer that works and one that
/// silently mangles half a household's history.
class CsvTable {
  const CsvTable({required this.headers, required this.rows});

  final List<String> headers;

  /// Every row padded to the header's width, so a column index is always safe
  /// to read. Spreadsheets routinely omit trailing empty cells.
  final List<List<String>> rows;

  /// Delimiters worth trying, most likely first. A semicolon file is what a
  /// Croatian or German Excel writes, and it is the common case here.
  static const _delimiters = [',', ';', '\t', '|'];

  static CsvTable parse(String text) {
    final cleaned = text.replaceFirst('﻿', '');
    if (cleaned.trim().isEmpty) {
      return const CsvTable(headers: [], rows: []);
    }

    // The delimiter that splits the header into the most columns is the one
    // that is actually separating them. Trying them in order and taking the
    // first that "works" picks a comma inside a quoted field over the real
    // semicolon.
    List<List<dynamic>> best = const [];
    for (final delimiter in _delimiters) {
      final parsed = Csv(
        fieldDelimiter: delimiter,
        lineDelimiter: '\n',
        // Auto-detection would defeat the point of trying each delimiter.
        autoDetect: false,
      ).decode(cleaned.replaceAll('\r\n', '\n'));
      if (parsed.isEmpty) {
        continue;
      }
      if (best.isEmpty || parsed.first.length > best.first.length) {
        best = parsed;
      }
    }
    if (best.isEmpty) {
      return const CsvTable(headers: [], rows: []);
    }

    final headers = [for (final cell in best.first) cell.toString().trim()];
    final rows = <List<String>>[];
    for (final row in best.skip(1)) {
      final cells = [for (final cell in row) cell.toString().trim()];
      if (cells.every((cell) => cell.isEmpty)) {
        continue;
      }
      while (cells.length < headers.length) {
        cells.add('');
      }
      rows.add(cells);
    }
    return CsvTable(headers: headers, rows: rows);
  }

  /// The cell at [column] of [row], or empty when the column was not mapped.
  String cell(List<String> row, int? column) {
    if (column == null || column < 0 || column >= row.length) {
      return '';
    }
    return row[column];
  }

  /// Reads a number written however the exporting machine writes numbers.
  ///
  /// Both separators are in play and neither is knowable from one value, so
  /// the rule is positional: whichever of `.` and `,` appears **last** is the
  /// decimal point, and everything else is grouping. That reads `1,234.56` and
  /// `1.234,56` correctly, which is the pair that actually matters.
  static double? number(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    // Strip anything that is not a digit, a separator or a leading sign:
    // currency symbols, non-breaking spaces, unit suffixes.
    var cleaned = trimmed.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (cleaned.isEmpty) {
      return null;
    }

    final lastComma = cleaned.lastIndexOf(',');
    final lastDot = cleaned.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      final decimal = lastComma > lastDot ? ',' : '.';
      final grouping = decimal == ',' ? '.' : ',';
      cleaned = cleaned.replaceAll(grouping, '').replaceFirst(decimal, '.');
    } else if (lastComma >= 0) {
      cleaned = cleaned.replaceFirst(',', '.');
    }
    return double.tryParse(cleaned);
  }

  /// Reads a date written however the exporting machine writes dates.
  ///
  /// ISO first, because that is what an export usually produces. A slashed or
  /// dotted date is genuinely ambiguous — 03/09 is two different days on two
  /// sides of an ocean — so [dayFirst] is a choice the importer makes the user
  /// confirm rather than a guess it makes for them.
  static DateTime? date(String raw, {bool dayFirst = true}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    // A timestamp is a date with something after it; take the day.
    final datePart = trimmed.split(RegExp(r'[ T]')).first;

    final iso = RegExp(
      r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$',
    ).firstMatch(datePart);
    if (iso != null) {
      return _dayOrNull(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final parts = RegExp(
      r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$',
    ).firstMatch(datePart);
    if (parts == null) {
      return null;
    }
    final first = int.parse(parts.group(1)!);
    final second = int.parse(parts.group(2)!);
    var year = int.parse(parts.group(3)!);
    if (year < 100) {
      year += 2000;
    }
    // A value above 12 can only be a day, whatever the chosen order says.
    final dayIsFirst = second > 12 ? false : (first > 12 ? true : dayFirst);
    return _dayOrNull(
      year,
      dayIsFirst ? second : first,
      dayIsFirst ? first : second,
    );
  }

  /// A date, or null when the numbers do not name a real day.
  ///
  /// `DateTime.utc(2026, 2, 31)` is 2 March, which would import an entry onto
  /// the wrong day rather than refusing the row.
  static DateTime? _dayOrNull(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final date = DateTime.utc(year, month, day);
    if (date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
