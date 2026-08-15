# Garage

Household vehicle tracking: fuel logs with real full-tank economy, a
maintenance calendar that projects due dates from how the car is actually
driven, running costs, and fuel-station prices — shared live between everyone
in the household rather than tied to one phone.

Android and web from one Flutter codebase, on a Supabase (EU) backend with
row-level security scoping every row to its household. Free, no ads, no
tracking. English and Croatian.

- Web app: <https://garage.hrva.cc>
- Privacy policy: [`PRIVACY.md`](PRIVACY.md) (served at `/privacy`)

## Features

- **Fuel** — full/partial tanks, missed fills, any two of volume/price/total,
  distance-weighted economy, per-station price history.
- **Maintenance** — recurring intervals by distance, time, or whichever comes
  first; one-off items; a planner that clusters items due close together into
  a single shop visit.
- **Costs** — insurance, registration, tyres, tolls and the rest, by category.
- **Stats & timeline** — spend and economy across the fleet, month by month.
- **Stations** — live Croatian fuel prices (MZOE open data), sorted by distance
  when location is granted.
- **Attachments** — receipts and documents kept with the entry they belong to.
- **Household settlement** — who has paid what into the shared vehicles, and
  what would even it up.
- **Depth on demand** — a household can ask to be prompted for parts, labour,
  warranty, fault codes, and wear readings, or stay with date/odometer/cost.
- **Tyre sets** — each set tracked in its own right: season, size, where it is
  stored, which one is on the car, and its tread depth over time.
- **Recalls** — open NHTSA safety recalls for a vehicle's make, model, and year.
- **Import/export** — Fuelio backups in, CSV and PDF reports out, plus a
  read-only [JSON API and webhooks](docs/public-api.md) for your own scripts.

## Getting started

Requires the Flutter SDK matching `environment.sdk` in `pubspec.yaml`.

```bash
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

`env/*.json` is gitignored and holds `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
optionally `GOOGLE_WEB_CLIENT_ID`. See [`RELEASE.md`](RELEASE.md) §2 for the
file's shape and where the values come from.

```bash
flutter test        # unit, domain, and widget tests
flutter analyze     # lints; the tree is expected to be clean
flutter gen-l10n    # after editing lib/l10n/*.arb
```

## Layout

```
lib/domain/      entities and pure logic (economy, projections, bundling, settlement) — no Flutter
lib/features/    one folder per feature: data/ providers/ screens/ widgets/
lib/core/        theme, formatting, router, errors, notifications, export
lib/l10n/        ARB sources and generated localizations
supabase/        SQL migrations and edge functions
test/            mirrors lib/, same folder names
```

State is Riverpod; every screen reads providers derived from a repository
interface, so tests override the repository rather than the network. Values are
stored canonical (kilometres, litres, the household's currency) and converted
only at the presentation edge — see `lib/core/format/unit_format.dart`.

## Releasing

[`RELEASE.md`](RELEASE.md) covers both tracks: web deploys automatically on
push to `main` (GitHub Actions → Cloudflare Worker), Google Play is a manual
bundle upload. Store listing copy lives in `docs/play-store-listing.md`.
