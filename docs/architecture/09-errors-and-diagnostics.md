# 09. Errors and diagnostics

What happens when something fails: what the user is told, and what is kept so the
failure can be answered later. Siblings:
[05-data-access-and-sync.md](05-data-access-and-sync.md) for where failures
originate, [10-localization-and-units.md](10-localization-and-units.md) for the
message text.

> Jump to [Sharp edges](#sharp-edges): an unmapped exception reads as a generic
> one, and persistence of the log is best-effort by design.

## Why this exists, and why it is built this way

Two audiences, and they want opposite things. A user wants a sentence they can act
on, in their language, with no stack trace. Whoever fixes the bug wants the exact
`AuthApiException` message.

The design gives each what it needs by splitting them at a single point instead of
choosing one.

## The path a failure takes

```
repository throws  ->  AppFailure.from(error)  ->  failureMessage(l10n, failure)
                            |                              |            |
                     kind + debugMessage          reportFailure    localized sentence
                                                        |               |
                                              developer.log +      shown to the user
                                              last 20 kept
                                              + shared_preferences
FlutterError.onError        -----------------------^
PlatformDispatcher.onError  -----------------------^
```

**Nothing caught anywhere still reaches the log.** `installGlobalErrorHandlers`
(`lib/core/errors/global_error_handler.dart:24`) routes framework errors and
uncaught asynchronous errors into the same `reportFailure`, and `main` installs
it before anything that can fail (`lib/main.dart:24`). Before that, a failure was
recorded only if some screen had thought to route it there — so the app's own
diagnostics reported a clean run for exactly the crashes worth reading about,
since a crash leaves no screen behind to report anything.

Both handlers **chain rather than replace**, and the platform handler returns
`false` (not handled). They observe; they do not resolve. `flutter_test` installs
its own `FlutterError.onError` to fail tests on framework errors, and swallowing
that would turn every future red test green.

**Mapping.** `AppFailure.from` (`lib/core/errors/app_failure.dart:26`) classifies
anything thrown into an `AppFailureKind` and keeps the original description in
`debugMessage`. The interesting cases are deliberate:

| Thrown | Kind | Why |
|---|---|---|
| `SocketException`, `ClientException`, `AuthRetryableFetchException` | `network` | Supabase wraps socket errors in `ClientException`, and on web the `dart:io` types never occur at all (`app_failure.dart:31`) |
| `PostgrestException` `42501` | `permission` | RLS refused |
| `PostgrestException` `23505` | `conflict` | Unique violation |
| `P0002` / `P0003` / `P0004` | `notFound` / `expired` / `alreadyUsed` | Invite redemption raises these, and a typo, an expired code, and a used code are three different things a user must tell apart (`app_failure.dart:59`) |
| anything else | `unknown` | With `error.toString()` kept |

**Presentation and recording.** `failureMessage`
(`lib/core/widgets/failure_message.dart:12`) is the single choke point every
user-facing error passes through. It calls `reportFailure` and then returns the
localized sentence for the kind.

**Recording.** `reportFailure` (`lib/core/errors/failure_log.dart:35`) stamps the
line with the local time, writes it to `dart:developer` under the name
`garage.failure`, keeps the last 20 (`failure_log.dart:9`), and starts a write to
`shared_preferences`. `loadRecordedFailures` reads them back at startup, because
a crash *is* a restart: an in-memory log forgets precisely the failure somebody
later goes looking for.

**Reading it, without a cable.** Settings → About → **Diagnostics**
(`lib/features/settings/screens/diagnostics_screen.dart:27`) lists the failures
newest-first, shares the whole log with the running version prepended, and
clears it. That closes the gap that made every field report stop at "it said
something went wrong".

That last part was added because it was missing, and the gap was expensive:
`debugMessage` was being constructed at every failure site and read nowhere. The
class comment claimed it existed "only for logs" while no log existed. A Google
sign-in failure therefore presented as "Something went wrong. Please try again."
with the actual exception discarded, and diagnosing it took an evening of
elimination that one recorded line would have ended.

In the field:

```bash
adb logcat -s garage.failure
```

## Sharp edges

- **An unmapped exception type is indistinguishable from a real unknown.** Both
  land in `AppFailureKind.unknown` and render `errorGeneric`. When a new
  dependency starts throwing its own type, the symptom is a generic message with
  no hint that a mapping is missing. Check `garage.failure` before assuming the
  backend is at fault.
- **Persisting the log is best-effort.** A failed write is logged to
  `garage.failure` and otherwise ignored (`failure_log.dart:97`): storage can be
  full, and on the web it can be denied outright in a private window. An app must
  not fall over because it could not save its own error log — but it does mean a
  restart can lose the log on a device where storage is refusing writes.
- **`reportFailure` now touches a plugin.** A pure `test()` that calls it or
  `clearRecordedFailures` needs `TestWidgetsFlutterBinding.ensureInitialized()`
  and `SharedPreferences.setMockInitialValues({})`, which is why
  `test/core/widgets/failure_message_test.dart` has both.
- **There is still no crash reporter.** Nothing leaves the device on its own,
  which is a deliberate consequence of the no-tracking promise: a user has to
  choose to share the log. The cost is that a crash nobody reports is a crash
  nobody knows about.
- **A `catch` that builds its own SnackBar bypasses all of this.** Anything that
  does not route through `failureMessage` shows a message and records nothing.
  Fixing one of these in the Fuelio import is why the pattern is worth stating.
- **`debugMessage` may contain backend detail** and must never be shown to a user;
  that is what the kind-to-sentence mapping is for.
- **Screens hold `AppFailure`, never raw exceptions.** A widget that catches
  `PostgrestException` directly has reached around the repository boundary.
