/// What an eight-character code turns out to be, before it is spent.
///
/// Three kinds exist — a garage invite, a vehicle transfer, a lending pass —
/// and whoever is holding one cannot tell which. Asking the server what it is
/// costs nothing and lets the app say what redeeming will do *before* somebody
/// agrees to it, instead of making the difference the user's problem.
enum CodeKind {
  /// Join a garage and share its vehicles, for good.
  invite,

  /// The vehicle and its whole history become yours.
  transfer,

  /// Scoped, expiring access to one car.
  lending;

  static CodeKind? fromKey(String key) {
    for (final kind in values) {
      if (kind.name == key) {
        return kind;
      }
    }
    // A kind this build does not know: a newer server, an older app. Treat it
    // as unrecognised rather than guessing which of three things it does.
    return null;
  }
}

class CodeDescription {
  const CodeDescription({
    required this.kind,
    required this.subject,
    required this.until,
    required this.spent,
  });

  final CodeKind kind;

  /// The car's nickname, or the garage's name: what the code is *about*,
  /// which is the only thing worth showing before it is used.
  final String subject;

  final DateTime until;

  /// Redeemed, withdrawn or run out. Shown as a refusal rather than offered
  /// and then rejected.
  final bool spent;
}
