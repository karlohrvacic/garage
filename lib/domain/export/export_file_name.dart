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

  /// The CSV that can be read but not restored.
  csv('export', 'csv'),

  /// A vehicle's printable report.
  report('report', 'pdf');

  const ExportKind(this.word, this.extension);

  final String word;
  final String extension;
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
  final subject = _slug(vehicleName ?? '');
  final prefix = subject.isEmpty ? 'garage' : subject;
  return '$prefix-${kind.word}-${_day(on)}.${kind.extension}';
}

String _day(DateTime on) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${on.year}-${two(on.month)}-${two(on.day)}';
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

String _slug(String raw) {
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
