/// What an exported file is called.
///
/// Every export used to arrive named something like `3f9a1c-8e21.json`. The
/// call sites did pass a name, but `XFile.fromData` drops it on every platform
/// except web — share_plus documents this — and share_plus then falls back to
/// `Uuid().v1()`. So the name was never wrong in the code and always wrong on
/// the device.
///
/// Fixing that is only worth doing if the result is a name somebody can find
/// again in six months, which means it says **what it is**, **which car**, and
/// **when it was taken**, in that order and in a form that sorts.
library;

enum ExportKind {
  /// The JSON that can be restored. Deliberately a different word from [csv]:
  /// one of these comes back and the other does not, and a folder holding both
  /// a month apart is exactly where that distinction matters.
  backup('backup', 'json'),

  /// The spreadsheet export that can be read but not restored: a zip of one
  /// CSV per vehicle per kind. One file holding twelve differently shaped
  /// tables was not openable by anything.
  csv('export', 'zip'),

  /// A vehicle's printable report.
  report('report', 'pdf'),

  /// The zip the console builds for a month: a folder per car. Named for
  /// the month it holds rather than the day it was built, which is what
  /// the accountant files it under.
  pack('accountant-pack', 'zip', byMonth: true);

  const ExportKind(this.word, this.extension, {this.byMonth = false});

  final String word;
  final String extension;
  final bool byMonth;
}

/// `garage-backup-2026-08-22.json`, `renault-clio-report-2026-08-22.pdf`.
///
/// The date is ISO-ordered and zero-padded so a folder of these sorts by age
/// on its own, which is the only sort a file manager reliably offers.
String exportFileName(
  ExportKind kind, {
  required DateTime on,
  String? vehicleName,
}) {
  final subject = fileSlug(vehicleName ?? '');
  final prefix = subject.isEmpty ? 'garage' : subject;
  final stamp = kind.byMonth ? _month(on) : isoDay(on);
  return '$prefix-${kind.word}-$stamp.${kind.extension}';
}

/// `2026-01-05`: ISO-ordered and zero-padded, so a folder of these sorts by
/// age on its own.
String isoDay(DateTime on) => '${_month(on)}-${_two(on.day)}';

String _month(DateTime on) => '${on.year}-${_two(on.month)}';

String _two(int value) => value.toString().padLeft(2, '0');

/// [fileSlug], or `vehicle` for a car whose name yields nothing: a folder
/// called nothing puts its files at the root of the zip.
String vehicleSlug(String name) {
  final slug = fileSlug(name);
  return slug.isEmpty ? 'vehicle' : slug;
}

/// [name], or the first of `name-2`, `name-3`, … not yet in [taken], which
/// it is added to. Two cars called Golf in one export would otherwise write
/// over each other.
String uniqueName(String name, Set<String> taken) {
  if (taken.add(name)) {
    return name;
  }
  var suffix = 2;
  while (!taken.add('$name-$suffix')) {
    suffix++;
  }
  return '$name-$suffix';
}

/// Croatian letters folded to their bare forms rather than dropped.
///
/// Stripping would turn "Škoda" into "koda" and "Čađavi" into "aavi", which
/// is worse than either keeping or transliterating. Every platform the app
/// runs on can hold the accented form in a filename, but a name that has to
/// survive a share sheet, a sync folder and an email attachment cannot count
/// on it — so the fold happens here, once, where it is visible.
const _folded = {
  'č': 'c',
  'ć': 'c',
  'ž': 'z',
  'š': 's',
  'đ': 'd',
  'Č': 'c',
  'Ć': 'c',
  'Ž': 'z',
  'Š': 's',
  'Đ': 'd',
};

/// How much of a car's name a filename will carry. Long enough for any real
/// nickname, short enough that the date at the end stays visible in a file
/// manager that truncates.
const _maxSubjectLength = 40;

/// A name as a file or folder carries it: lower case, Croatian letters
/// folded, runs of anything else collapsed to one dash, capped. Empty for a
/// name with nothing usable in it, which the caller replaces with its own
/// word rather than writing a file called `.pdf`.
String fileSlug(String raw) {
  final folded = StringBuffer();
  for (final rune in raw.runes) {
    final character = String.fromCharCode(rune);
    folded.write(_folded[character] ?? character);
  }
  final slug = folded
      .toString()
      .toLowerCase()
      // Anything that is not a plain letter or digit becomes a separator, so a
      // path separator cannot survive into the name and neither can an emoji.
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.length <= _maxSubjectLength
      ? slug
      // Trimmed back to a whole word where there is one, so a cut name reads
      // as a name rather than as a fragment.
      : slug.substring(0, _maxSubjectLength).replaceAll(RegExp(r'-+$'), '');
}
