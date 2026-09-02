/// "Škoda", "SKODA" and "skoda " are one make; so are "VW" and "Volkswagen".
///
/// The vehicle's make is free text — typed, or title-cased by the VIN
/// decoder — and stays that way on screen. This is only the lookup key the
/// interval overlay matches on.
class MakeKey {
  MakeKey._();

  static String? of(String? make) {
    if (make == null) {
      return null;
    }
    final folded = _stripDiacritics(
      make.toLowerCase(),
    ).replaceAll(RegExp('[^a-z]'), '');
    if (folded.isEmpty) {
      return null;
    }
    return _aliases[folded] ?? folded;
  }

  static const _aliases = {
    'vw': 'volkswagen',
    'mercedes': 'mercedes_benz',
    'mercedesbenz': 'mercedes_benz',
    // Same engines, same service regime, same overlay row.
    'cupra': 'seat',
  };

  /// Enough for the letters a European make name uses. Not a general
  /// transliteration: anything else is dropped by the caller's filter.
  static String _stripDiacritics(String text) {
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(_plain[char] ?? char);
    }
    return buffer.toString();
  }

  static const _plain = {
    'š': 's',
    'đ': 'd',
    'č': 'c',
    'ć': 'c',
    'ž': 'z',
    'ë': 'e',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'ö': 'o',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ø': 'o',
    'œ': 'oe',
    'ü': 'u',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ý': 'y',
    'ÿ': 'y',
    'ß': 'ss',
  };
}
