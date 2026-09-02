import 'dart:math';

/// Where a garage's name comes from when nobody wants to think one up.
///
/// The surname is the name most garages end up with anyway, so it is offered
/// first; the rest of the pool is whatever the screen has to hand.
class GarageName {
  GarageName._();

  /// The last word of a full name, or the whole of a single-word one. The
  /// account's display name may be "Karlo Hrvačić" or "Karlo"; it may also be
  /// the part of an address before the `@`, and "karlo.hrvacic" is nobody's
  /// garage, so a handle-shaped name yields nothing and leaves the dice as
  /// the way in.
  static String fromPerson(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final words = trimmed.split(RegExp(r'\s+'));
    final last = words.last;
    return words.length == 1 && _handle.hasMatch(last) ? '' : last;
  }

  static final _handle = RegExp(r'[._\-\d]');

  /// A draw from [pool] that is not [current], so tapping the dice always
  /// visibly does something. A pool of one, or none, has nothing else to
  /// offer and says so by returning what is there.
  static String next(List<String> pool, String current, Random random) {
    final others = pool.where((name) => name != current).toList();
    if (others.isEmpty) {
      return pool.isEmpty ? current : pool.first;
    }
    return others[random.nextInt(others.length)];
  }
}
