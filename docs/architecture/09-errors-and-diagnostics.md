# 09. Errors and diagnostics

What happens when something fails: what the user is told, and what is kept so the
failure can be answered later. Siblings:
[05-data-access-and-sync.md](05-data-access-and-sync.md) for where failures
originate, [10-localization-and-units.md](10-localization-and-units.md) for the
message text.

> Jump to [Sharp edges](#sharp-edges): the recorded log is memory-only and not yet
> reachable from the UI, and an unmapped exception reads as a generic one.

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
```

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

**Recording.** `reportFailure` (`lib/core/errors/failure_log.dart:22`) writes the
kind and the debug message to `dart:developer` under the name `garage.failure`,
and keeps the last 20 in memory (`failure_log.dart:7`).

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
- **The recorded log is memory-only.** It does not survive a restart and is not
  reachable from any screen. A tester still cannot copy it to you, which is the
  obvious next step and is not built.
- **A `catch` that builds its own SnackBar bypasses all of this.** Anything that
  does not route through `failureMessage` shows a message and records nothing.
  Fixing one of these in the Fuelio import is why the pattern is worth stating.
- **`debugMessage` may contain backend detail** and must never be shown to a user;
  that is what the kind-to-sentence mapping is for.
- **Screens hold `AppFailure`, never raw exceptions.** A widget that catches
  `PostgrestException` directly has reached around the repository boundary.
