# Contributing

Thanks for looking. Garage is a small project with a strict test suite, and the
strictness is the point: it is a record of things people rely on, and a bug in
it costs someone a service interval or a tax figure rather than a page refresh.

## Before you start

- **Open an issue first for anything substantial.** A feature that does not fit
  the shape of the app is a sad pull request to receive and a sadder one to
  send.
- **Contributions are covered by a [contributor licence agreement](CLA.md).**
  You keep your copyright; you grant the right to relicense, which is what
  keeps an App Store build possible under a licence the AGPL cannot reach. Add
  this line to your pull request description:

  ```
  I have read and agree to the Contributor Licence Agreement in CLA.md.
  ```

## Getting it running

```bash
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

`env/*.json` is gitignored; [`RELEASE.md`](RELEASE.md) §2 says what goes in it.
You can run everything except sign-in and sync without a Supabase project.

## What CI will check

All of this runs on every pull request, and all of it has to pass:

```bash
dart format lib test    # checked with --set-exit-if-changed
flutter analyze         # expected to be clean, not merely warning-free
flutter test            # the whole suite
flutter gen-l10n        # generated files are committed; a stale tree fails
```

The edge functions are Deno and have their own suite:

```bash
cd supabase/functions
deno test --allow-env
```

The row-level-security suite runs separately, against a real Postgres:

```bash
supabase start
SUPABASE_URL=http://127.0.0.1:54321 \
  SUPABASE_ANON_KEY=<from `supabase status`> \
  SUPABASE_SERVICE_ROLE_KEY=<from `supabase status`> \
  dart test test_rls/rls_test.dart
```

## House rules worth knowing before you write anything

- **Tests come first.** Write the failing test, then the code that passes it.
- **Screens never touch Supabase.** Every screen reads Riverpod providers built
  on a repository *interface*, so tests override the repository rather than the
  network. Platform capabilities get a provider seam in `lib/core/` —
  `url_opener.dart` is the pattern to copy.
- **`lib/domain/` imports no Flutter.** It is pure logic, and it is where the
  interesting rules are cheapest to test.
- **The database is the security boundary.** A new table needs RLS policies
  *and* a case in `test_rls/rls_test.dart`, including a positive control that a
  member *can* read it — a policy denying everyone passes every "stranger sees
  nothing" assertion.
- **Migrations are append-only.** Once applied, fix forward with a new one.
- **Every user-visible string is localized**, in `app_en.arb` *and* `app_hr.arb`.
  Croatian should read as Croatian, not as translated English. Counted messages
  need one/few/other.
- **Units are canonical in storage**, converted only for display.
- **Documentation is part of the change, not a follow-up.** Changed how
  something works → update `docs/architecture/`. Made a design decision →
  `docs/decisions/decision-log.md`. Hit a sharp edge → 
  `docs/operations/known-bugs-and-risks.md`. Anything a user would notice →
  both files in `distribution/whatsnew/`.

[`CLAUDE.md`](CLAUDE.md) is the full version of the above, and
[`docs/README.md`](docs/README.md) is the way into the architecture.

## Licence

Contributions are released under the [AGPL-3.0](LICENSE), the same licence as
the rest of the project.
