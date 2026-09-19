# 01. System overview

What Garage is made of, what runs where, and the four layers everything else in
this tree assumes. Siblings: [02-domain-model.md](02-domain-model.md) for the
nouns, [05-data-access-and-sync.md](05-data-access-and-sync.md) for how screens
get data, [06-security-and-tenancy.md](06-security-and-tenancy.md) for the part
that keeps households apart.

> Jump to [Sharp edges](#sharp-edges) for the things that surprise people: two
> deploy targets with different auth paths, a config assertion that fails at
> startup, and route ordering that matters.

## Why this exists, and why it is built this way

Garage tracks a household's cars: fuel, servicing, running costs, what falls due
next. The distinguishing requirement is in the word *household*. Every competitor
surveyed in [`plan.md`](../plan.md) treats a vehicle as belonging to one account,
and sharing is either absent, paid, or a one-way owner-to-driver push. Two people
who co-own a car are peers, and the data model starts from that rather than
bolting sharing on later.

Three consequences shape everything:

- **A shared backend is not optional.** File-based sync (what Fuelio does) cannot
  give two phones a consistent view. So there is a server, and the server owns
  correctness.
- **The server enforces the sharing rule, not the client.** Tenancy lives in
  Postgres row-level security, so a client bug cannot leak one household to
  another. See [06-security-and-tenancy.md](06-security-and-tenancy.md).
- **One codebase, two targets.** Flutter builds the same app for Android and web.
  Web matters because it is the fastest way to try the app and because it is free
  to host.

## What runs where

| Piece | Where it runs | Deployed by |
|---|---|---|
| Flutter app | Android, and web as a PWA | Play on a version tag; Cloudflare Worker on push to `main` |
| Postgres + RLS | Supabase, EU (Stockholm) | Supabase GitHub integration, on push to `main` |
| Auth | Supabase Auth, email + password and Google | Configured in the dashboard |
| Storage | Supabase Storage, private buckets | Bucket created by migration `supabase/migrations/0016_attachments.sql` |
| `public-api` | Supabase edge function | GitHub Actions, on a push to `main` touching `supabase/functions/**` |
| `dispatch-webhooks` | Supabase edge function, called by a Postgres trigger | Same |
| `delete-account` | Supabase edge function | Same |
| `push-due-reminders` | Supabase edge function, intended for cron | Same, but the cron that calls it is not scheduled; see [08-reminders-and-notifications.md](08-reminders-and-notifications.md) |

Edge functions are **not** covered by the GitHub integration that applies
migrations, and shipping them by hand was the most common release mistake —
the old function keeps answering, correctly, with last month's behaviour, so
nothing looks wrong. `.github/workflows/deploy-functions.yml` now deploys all
four on a push to `main` that touches them (decision 98).

**It needs two secrets to do anything**: `SUPABASE_ACCESS_TOKEN` and
`SUPABASE_PROJECT_REF`. Without them the job skips with a notice rather than
failing, so until they are set the by-hand path in
[RUNBOOK-update.md](../RUNBOOK-update.md) is still the one that ships.

## The four layers

```
lib/domain/     pure Dart: entities and rules. No Flutter import reaches here.
lib/features/   one folder per feature, each with data/ providers/ screens/ widgets/
lib/core/       theme, formatting, router, errors, sync, notifications, seams
lib/l10n/       ARB sources plus generated localizations (committed)
```

The dependency direction is one way: features depend on domain and core, domain
depends on nothing but Dart. That purity is not decorative. The interesting rules
of this system (economy, projection, bundling, settlement) are pure functions
over plain data, so they are tested directly, in milliseconds, without a widget
tree or a database. [03-fuel-economy.md](03-fuel-economy.md) and
[04-maintenance-projection.md](04-maintenance-projection.md) are the two worth
reading in full.

Within a feature the split is always the same, for example `lib/features/fuel/`:

| Folder | Holds | Depended on by |
|---|---|---|
| `data/` | A repository interface plus its Supabase implementation | providers |
| `providers/` | Riverpod providers, derived state | screens, widgets |
| `screens/` | Routed pages | the router |
| `widgets/` | Pieces used by those screens | screens |

## Startup

`lib/main.dart:24` runs four things before the app appears:

1. `Env.assertConfigured()` (`lib/main.dart:38`) fails fast when the Supabase URL
   or key dart-define is missing, rather than letting the app open and every
   query fail one by one.
2. `initializeDateFormatting()` (`lib/main.dart:39`), because dates render in two
   locales.
3. `Supabase.initialize` (`lib/main.dart:41`) with the publishable key. The
   comment there records that `anonKey` was renamed `publishableKey` upstream and
   is the same public value, still gated by RLS.
4. `runApp` inside a `ProviderScope` (`lib/main.dart:48`), which is what makes
   every provider override in tests possible.

### The first fetch

Once the app is running, one request stands between a signed-in user and a
dashboard. `garageBootstrapProvider`
(`lib/features/household/providers/household_providers.dart:58`) reads every
garage the user belongs to *and* every vehicle they can reach, as two selects
issued together with `Future.wait`
(`lib/features/household/data/supabase_garage_bootstrap_repository.dart`).

It was one embedded select — `households` with `vehicles(*)` nested — until a
guest pass proved that wrong: an embed only nests rows under parents the outer
query returned, so a car lent to you never came back, because the garage that
owns it is not one of yours. Fetching `vehicles` in its own right asks the
question the policies answer. The two requests do not depend on each other, so
the cost is still one round trip's latency. A vehicle whose household is not
among the ones returned is one reached through a pass —
`GarageBootstrap.borrowedVehicles`.

### And before that fetch, a garage from last time

The request above is still one round trip, and one round trip is still a wait —
engine, session, network, *then* a dashboard, on a phone that has just woken up
at a pump. So the bootstrap draws the garage this device saw last and refreshes
behind it: `GarageBootstrapNotifier.build`
(`lib/features/household/providers/household_providers.dart:85`) returns the
cached value as data and starts the fetch without awaiting it, replacing the
state when it lands.

- **The cache stores rows, not entities**
  (`lib/features/household/data/garage_bootstrap_cache.dart:19`), so
  `garageBootstrapFromRows` remains the only reader of a vehicle row anywhere.
  A row that a newer build cannot parse throws, is caught, and counts as no
  cache — which is exactly right, because a fetch is already on its way.
- **It is keyed by user and cleared on sign-out, and on account deletion.** A
  shared phone must not open into the previous account's garage, and refusing
  to *show* it is not the same as not *having* it
  (`lib/features/auth/providers/auth_providers.dart:135`; a deletion ends the
  session without a sign-out, so it clears both copies itself once the account
  is gone, `auth_providers.dart:148`).
- **A refresh belongs to the build that started it.** `build` runs again on the
  same notifier when the account changes, while the previous fetch is still in
  flight; `ref.mounted` stays true throughout. A generation counter discards
  the late answer, or the account that just signed out reappears.
- **A failed refresh leaves the cached garage on screen** rather than replacing
  it with an error page. An offline cold start is the ordinary case, and
  everything the user might write while offline is queued anyway.
- **Nothing older than `bootstrapCacheMaxAge`** (30 days) is shown at all.
- **In tests it must be overridden.** `SharedPreferences.getInstance()` never
  returns in a widget test with no mock values set, and the bootstrap awaits it,
  so the failure reads as "pumpAndSettle timed out".
  `test/support/pump_screen.dart` supplies a `NoGarageBootstrapCache`, and
  `test/ci/bootstrap_cache_overridden_test.dart` fails a scope that stands the
  bootstrap up without one.

`myHouseholdsProvider`, `currentHouseholdProvider`, `allVehiclesProvider`,
`vehiclesProvider`, `archivedVehiclesProvider` and `vehicleProvider(id)` are all
derived from it and issue no request of their own.

It was not always one request. Each of those used to fetch, and each had to wait
for the one above it — `myHouseholds` → `currentHousehold` → `allVehicles` →
`vehicles` — because the household's id was the argument to the next call. That
is three to four sequential round trips before the first card can be drawn, on a
phone, at a pump, which is the scene this app is used in.

The consequence for anything written later: **invalidate the bootstrap, never a
provider derived from it.** A derived provider holds no request to repeat, so
invalidating one rebuilds it against the cached value and silently changes
nothing. `test/ci/garage_bootstrap_invalidation_test.dart` fails the build rather
than letting that ship, because the symptom — a car that does not appear until
the app is restarted — looks like slowness rather than a bug.

Configuration arrives as dart-defines, never as committed files: `env/*.json` is
gitignored and CI passes the same three values as secrets. Both workflows pass an
identical set, and `test/ci/deploy_workflow_test.dart` fails if they ever diverge,
because a define present on one platform and missing on the other means the two
builds talk to different backends.

## Routing

`appRouterProvider` (`lib/core/router/app_router.dart:35`) builds a GoRouter whose
`redirect` delegates to `garageRedirect` (`lib/core/router/app_redirect.dart:13`).
That function is pure and extracted precisely so the decision table (signed out to
sign-in, signed in without a household to onboarding, and so on) can be tested
without a router.

Tab destinations are peers rather than a hierarchy, so switching them cross-fades
instead of playing a directional push, which read as "forward" whichever way the
user moved (`lib/core/router/app_router.dart:217`).

Pushed pages pick their transition from the window rather than the platform.
`_WindowAwarePageTransitions` (`lib/core/theme/garage_theme.dart:228`) wraps each
of Flutter's platform defaults: below the wide breakpoint the platform's own push
transition and back gesture are kept, and above it every route cross-fades. The
reason is the shell — the sidebar is drawn *inside* each page rather than around
them, so a sliding page carries a sidebar in with it and drags the identical one
behind it out.

## Sharp edges

- **Route order is load bearing.** `/vehicles/new` is declared before
  `/vehicles/:id` (`lib/core/router/app_router.dart:97`), because otherwise "new"
  is matched as a vehicle id. Adding a literal route under a parameterised one has
  to go above it.
- **The two targets do not authenticate the same way.** Google sign-in on Android
  is a native ID-token exchange, while web uses the OAuth redirect flow;
  `lib/features/auth/data/supabase_auth_repository.dart:40` branches on `kIsWeb`.
  A change to sign-in has to be exercised on both, and the Android path only works
  when the signing certificate's SHA-1 is registered for the OAuth client.
- **The web build is a real product, not a demo.** It is deployed on every push to
  `main`, ahead of the Play release, so a backend mistake shows up there first.
- **`lib/domain/` purity is a convention with no automated guard.** Nothing fails
  the build if someone imports Flutter into it. Grep before assuming.
