import 'app_failure.dart';

/// Runs [action], retrying a transport failure on a fresh attempt.
///
/// For one specific shape of problem: a request that fails below HTTP, where
/// nothing was refused and nothing was decided. A TLS record that fails its
/// integrity check — `SSLV3_ALERT_BAD_RECORD_MAC`, seen uploading a photo over
/// a flaky link — is the case this exists for. It is not a rejection to show
/// the user; it is a connection that went wrong in transit, and the same bytes
/// over a new connection usually land.
///
/// Deliberately narrow:
///
/// * Only [AppFailureKind.network] is retried. A permission error, a conflict
///   or a bad request means the server made a decision, and repeating it wastes
///   the user's time and battery to be told the same thing.
/// * [attempts] is small. This is a retry, not a queue; if the network is
///   genuinely down, saying so quickly beats a long silence.
/// * The action must be **idempotent**. A retry that can create a second copy
///   of something is worse than the failure it papers over — see the caller in
///   `supabase_attachment_repository.dart`, which retries against the same
///   storage path with upsert so a partially-landed upload is overwritten
///   rather than duplicated.
Future<T> retryOnTransportFailure<T>(
  Future<T> Function() action, {
  int attempts = 3,
  Duration delay = const Duration(milliseconds: 400),
  Future<void> Function(Duration)? sleep,
}) async {
  assert(attempts >= 1, 'an action has to be attempted at least once');
  final wait = sleep ?? Future<void>.delayed;

  var attempt = 0;
  while (true) {
    attempt++;
    try {
      return await action();
    } catch (error) {
      final failure = AppFailure.from(error);
      if (attempt >= attempts || failure.kind != AppFailureKind.network) {
        rethrow;
      }
      // Linear rather than exponential: three tries a few hundred milliseconds
      // apart is a hiccup absorbed while the spinner is still turning.
      // Doubling would turn the last attempt into a wait the user reads as a
      // hang.
      await wait(delay * attempt);
    }
  }
}
