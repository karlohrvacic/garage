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
| `public-api` | Supabase edge function | `supabase functions deploy`, by hand |
| `dispatch-webhooks` | Supabase edge function, called by a Postgres trigger | `supabase functions deploy`, by hand |
| `delete-account` | Supabase edge function | `supabase functions deploy`, by hand |
| `push-due-reminders` | Supabase edge function, intended for cron | Not deployed; see [08-reminders-and-notifications.md](08-reminders-and-notifications.md) |

Edge functions are **not** covered by the GitHub integration that applies
migrations. Forgetting them is the most common release mistake, which is why
[RUNBOOK-update.md](../RUNBOOK-update.md) leads with it.

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

`lib/main.dart:16` runs four things before the app appears:

1. `Env.assertConfigured()` (`lib/main.dart:18`) fails fast when the Supabase URL
   or key dart-define is missing, rather than letting the app open and every
   query fail one by one.
2. `initializeDateFormatting()` (`lib/main.dart:19`), because dates render in two
   locales.
3. `Supabase.initialize` (`lib/main.dart:21`) with the publishable key. The
   comment there records that `anonKey` was renamed `publishableKey` upstream and
   is the same public value, still gated by RLS.
4. `runApp` inside a `ProviderScope` (`lib/main.dart:28`), which is what makes
   every provider override in tests possible.

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
user moved (`lib/core/router/app_router.dart:122`).

Pushed pages pick their transition from the window rather than the platform.
`_WindowAwarePageTransitions` (`lib/core/theme/garage_theme.dart:203`) wraps each
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
