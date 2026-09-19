/// Riverpod's own retry, switched off for the whole app.
///
/// By default a provider whose build throws is rebuilt on its own, ten times
/// with the pause doubling from 200 ms to 6.4 s, for any `Exception`, which
/// every `AppFailure` is. While it retries, the provider is loading with the
/// error tucked inside, and `AsyncValue.when` shows the loading branch for
/// that, not the error: every `AsyncValueView` screen spun for some forty
/// seconds and asked the server ten more times after a refusal before its
/// failure sentence appeared. A permission error does not clear itself, and
/// the app has its own retries where a retry can help: the stale-reads
/// banner, pull-to-refresh, the refetch on resume and the Retry buttons.
/// The same choice the owner made for postgrest's per-request retries
/// (decision 182).
///
/// Passed to the app's `ProviderScope` and to the test harness's, so a test
/// sees what a phone sees; `test/ci/provider_retry_test.dart` keeps the
/// former in place.
Duration? noProviderRetry(int retryCount, Object error) => null;
