# Garage documentation

The living architecture and decision record for Garage: a household vehicle
tracker (fuel, maintenance, running costs) shared live between everyone in a
household, built as one Flutter codebase on a Supabase backend.

These are working docs. Every non-trivial claim cites `path:line`. **If the code
and a doc disagree, the code wins, and the doc should be fixed in the same change
that made it wrong.**

Start with [`architecture/01-system-overview.md`](architecture/01-system-overview.md)
if you are new. Read [`operations/known-bugs-and-risks.md`](operations/known-bugs-and-risks.md)
before you trust anything in production.

## The shape of it

```
   Android (Play)          Web (Cloudflare Worker)
          \                        /
           \   one Flutter app    /
            +--------------------+
            |  screens / widgets |   localized: en + hr
            |  providers (Riverpod)
            |  repository interfaces  <-- tests swap fakes in here,
            +----------|---------+       never the network
                       | Supabase client       realtime postgres_changes
                       v                       invalidate providers
            +---------------------------------------------+
            |  Supabase, EU (Stockholm)                   |
            |  Postgres + RLS  <-- the security boundary  |
            |  Auth (email + Google)                      |
            |  Storage (attachments, vehicle photos)      |
            |  Edge functions:                            |
            |    public-api, dispatch-webhooks,           |
            |    delete-account, push-due-reminders       |
            +---------------------------------------------+
                       |                      ^
      pg_net trigger   v                      |  MZOE fuel prices,
      -> a household's webhooks               |  NHTSA VIN + recalls
```

Four rules explain most of the code:

1. `lib/domain/` is pure Dart. No Flutter import reaches it.
2. Screens read providers over repository *interfaces*, so tests never touch a network.
3. Values are stored canonical (kilometres, litres, the household's currency) and
   converted only for display.
4. The database enforces tenancy. A UI check is a convenience; the RLS policy is the rule.

## Architecture

| Doc | What is inside |
|---|---|
| [01-system-overview.md](architecture/01-system-overview.md) | Targets, layers, startup, deployment topology, what runs where |
| [02-domain-model.md](architecture/02-domain-model.md) | Household, vehicles, the six entry kinds, members, invites, tyres, attachments |
| [03-fuel-economy.md](architecture/03-fuel-economy.md) | The full-tank algorithm, partial and missed fills, odometer bounds |
| [04-maintenance-projection.md](architecture/04-maintenance-projection.md) | Rules to due dates via observed km/day, the due window, visit bundling |
| [05-data-access-and-sync.md](architecture/05-data-access-and-sync.md) | Repository and provider seam, realtime invalidation, unit conversion |
| [06-security-and-tenancy.md](architecture/06-security-and-tenancy.md) | RLS, admin actions, invites, API keys, storage, account deletion |
| [07-integrations.md](architecture/07-integrations.md) | Fuel prices, VIN and recalls, Fuelio and any-CSV import, CSV/JSON/PDF out |
| [08-reminders-and-notifications.md](architecture/08-reminders-and-notifications.md) | Local scheduling, and the push half that is deliberately unwired |
| [09-errors-and-diagnostics.md](architecture/09-errors-and-diagnostics.md) | Failure mapping, what a user sees, what gets recorded |
| [10-localization-and-units.md](architecture/10-localization-and-units.md) | The ARB pair, Croatian plurals, where conversion happens |
| [11-statistics.md](architecture/11-statistics.md) | Periods, rates, breakdowns, and why sections can be hidden |
| [12-navigation.md](architecture/12-navigation.md) | The five tabs, the "More" tab, reachability, app-bar width, and the launcher's way in |

## Decisions and risks

| Doc | What is inside |
|---|---|
| [decisions/decision-log.md](decisions/decision-log.md) | Why the system is shaped this way, including the decisions worth arguing with |
| [operations/known-bugs-and-risks.md](operations/known-bugs-and-risks.md) | Confirmed bugs, sharp edges, and gaps, with severities |

## Operations, and what is not here

These already existed and are not duplicated above:

| Doc | What is inside |
|---|---|
| [`RELEASE.md`](../RELEASE.md) | First-time release setup: Supabase project, keystore, Play listing |
| [RUNBOOK-update.md](RUNBOOK-update.md) | The release loop: versioning, tracks, staged rollout, data safety |
| [RUNBOOK-closed-testing.md](RUNBOOK-closed-testing.md) | Play's 12-tester requirement and how to satisfy it |
| [RUNBOOK-push.md](RUNBOOK-push.md) | Activating push notifications when they are wanted |
| [public-api.md](public-api.md) | The read-only JSON API and webhook payloads, for API consumers |
| [play-store-listing.md](play-store-listing.md) | Store copy and the Data safety answers |
| [plan.md](plan.md) | The July 2026 research and product plan: competitor analysis, the reasoning behind the feature set. Historical, deliberately not restated in these docs |
| [wishlist/README.md](wishlist/README.md) | The August 2026 parity pass against Drivvo and Fuelio: what was built, and what was deliberately left out and why |
| [`CLAUDE.md`](../CLAUDE.md) | Commands and conventions for working in the repo |
