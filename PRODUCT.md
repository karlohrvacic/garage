# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

Android (Google Play, `cc.hrva.garage`) and web (<https://garage.hrva.cc>, Cloudflare
Worker) from one Flutter codebase, Material on both. **There is no iOS target** —
"adaptive" here records that Android and the browser are two first-class surfaces
whose *layouts* genuinely diverge (bottom nav vs. wider viewports), not that the app
switches design language per OS. Design work loads the Android reference; the iOS one
does not apply until an iOS target exists.

## Users

Confirmed centre of gravity: **both the solo owner and the shared garage, deliberately** —
it has to work as well for one person tracking one car as for four people sharing three,
and neither path may read as the afterthought.

- **The solo owner** who wants real fuel economy and a service history that survives
  the sale of the car. Sharing exists and they may never switch it on.
- **The shared garage** — a couple, a family, a pair of housemates — where more than
  one person drives and pays. Attribution ("who logged this", "who paid what") and
  settlement are first-class for them, not a reporting extra.
- Someone can belong to more than one garage and switch between them.

## Product Purpose

Keep a garage's vehicles in order without a spreadsheet: fuel logs with economy computed
properly between full tanks, maintenance whose due dates are projected from how the car is
actually driven, what each vehicle costs to run *and* to own, a mileage logbook for tax, the
paperwork that expires, and live Croatian pump prices — shared live between everyone in the
garage rather than trapped on one phone.

Success is that the record is trusted years later: at resale, at a tax return, and at the
moment the registration is about to lapse.

## Positioning

Three mechanisms a neighbouring tracker could not truthfully copy:

- **Economy that admits what it does not know.** Full-tank calculation between fills, with
  partial fills and an explicitly *missed* fill skipping that stretch instead of printing a
  wrong number.
- **Due dates projected from observed driving.** Intervals by distance, time, or whichever
  comes first, projected through the car's real km/day — so a car that sits all winter is not
  nagged like a daily motorway commute — and items falling due together are bundled into one
  shop visit, re-planned instantly when one is waved off.
- **The cheapest station once the fuel to get there is paid for.** MZOE open data, sorted by
  distance, with the true-cost ranking beside the sticker price. Croatian dataset, so Croatia
  only, and the app says so.

Adjacent: document expiry raises the *same* reminder servicing does, so it lands in the same
planner rather than a second parallel list.

## Operating Context

- **The real scene is the pump.** Standing at a fuel pump, on a phone, one-handed, possibly
  in the cold, wanting the fill logged before the receipt blows away. Speed-to-log and touch
  target size outrank density. This is also where the app most conspicuously fails today —
  it does not work offline (see `docs/roadmap.md`).
- The `+` on the dashboard, and a long-press on the launcher icon, record a fill-up, a service
  or a repair without hunting for a screen.
- Other scenes: at a desk reconciling costs or exporting a period report; at the kitchen table
  settling who owes what; and the once-a-year moment of finding a four-year-old shop invoice.
- Data arrives by import too — Fuelio backups, or any other app's CSV with columns mapped by
  hand — so a first-run garage may be full rather than empty.

## Capabilities and Constraints

**Terminology (decision 35, `docs/decisions/decision-log.md:853`):** the user-facing word is
**"garage"**; the database schema keeps `household`. Never surface "household" in UI or copy.

Shipped surfaces: dashboard, fuel, maintenance, planner, calendar, costs, income, trips
(logbook), odometer, stats, timeline, stations, vehicles, tyre sets, documents, attachments,
garage settlement, reports/export, settings, API keys, auth/onboarding. Navigation is five
tabs plus "More" (`docs/architecture/12-navigation.md`).

Technical constraints future design work inherits:

- **Flutter/Material, Riverpod, Supabase (EU).** Screens read providers over repository
  *interfaces* — never Supabase directly.
- **The database is the security boundary.** RLS scopes every row to its garage; a UI check
  is a convenience only.
- **Values are canonical in storage** (kilometres, litres, the garage's currency) and
  converted only at the presentation edge.
- **Layouts must survive a 2.0 text scale at 320 logical pixels** — Android offers 2.0 in
  accessibility settings and this class of overflow has bitten before
  (`docs/operations/known-bugs-and-risks.md:614`).
- Free, no ads, no in-app purchases, no tracking, AGPL-3.0 — factual today per `PRIVACY.md`,
  `README.md` and the roadmap's explicit non-goals. Recorded as product truth; **not** confirmed
  by the user as a binding design constraint, so treat the non-goals list as the authority.

Explicit non-goals already decided (`docs/roadmap.md:281`): ads or data sale, a social feed,
booking garage appointments, guessing repair costs, background GPS trip detection.

Undecided / open: push notifications are built but deliberately unwired
(`docs/architecture/08-reminders-and-notifications.md`); offline support does not exist and is
the largest gap in the code.

## Brand Commitments

User-confirmed as binding:

- **The "Night Shift" visual identity** —
  `docs/superpowers/specs/2026-07-28-night-shift-visual-identity-design.md`. Dark-first
  instrument-cluster aesthetic: asphalt darks, dash-amber accent, JetBrains Mono tabular
  readouts as the identity carrier, `GaugeArc` for interval consumption, uppercase mono
  eyebrow labels. The light theme is the same cockpit in daylight, not an afterthought.
  `GarageTokens` (ThemeExtension) is the only file with raw hex literals. Future work
  **preserves and extends** this world rather than replacing it.
- **English and Croatian, both, always.** Every user-visible string in `lib/l10n/app_en.arb`
  and `app_hr.arb`; Croatian reads natively rather than as translated English, needs
  one/few/other plurals, and its longer strings must not break layout.
  `test/l10n/arb_consistency_test.dart` enforces the mechanical half.
- **Usable at the pump.** See Operating Context.

Existing identity assets: `assets/icon/` (launcher + foreground), `assets/store/play-icon-512.png`,
`assets/store/feature-graphic.png` (HTML source at `assets/store/sources/feature-graphic.html`).
Name is "Garage" / "Garaža"; store title `Garage: Fuel & Maintenance`.

## Evidence on Hand

Real, in-repo, and usable — nothing here needs inventing:

- `docs/` — a maintained architecture and decision record (12 architecture docs, a decision log,
  known bugs and risks, roadmap). Non-trivial claims cite `path:line`.
- `docs/play-store-listing.md` — approved store copy in both languages, pre-trimmed to Play limits.
- `distribution/screenshots/phone-en/` (8 shots) and `assets/store/screenshots/` — real screens.
- `.impeccable/critique/` — seven prior critique snapshots (onboarding, vehicle detail, timeline),
  September 2026.
- `docs/plan.md` (July 2026 competitor and product research) and `docs/wishlist/` (August 2026
  parity pass against Drivvo and Fuelio, including what was deliberately left out and why).
- 2497 passing tests as of this writing, including domain, widget and citation checks.

**Absences future work must not paper over:** there are no testimonials, no named customers, no
usage or install numbers, no press, and no pricing or licensing tiers. Do not fabricate them.

## Product Principles

1. **Never print a number the data does not support.** A missed fill skips the stretch; an
   unknown cost stays unknown. Being trusted at resale is worth more than looking complete.
2. **The pump beats the desk.** When speed-of-entry and information density conflict, entry wins.
3. **One person and four people are the same product.** Attribution is always recorded; it is
   just quieter when there is only one of you.
4. **Numbers are the identity.** Monospace tabular readouts are the one loud element; everything
   around them stays disciplined.
5. **The record outlives the app session.** Export, backup, transfer to the next owner, and a
   read-only API exist so the data is never hostage.

## Accessibility & Inclusion

- Layouts must hold at **2.0 text scale on a 320 × 640 phone** — a documented, previously-shipped
  failure class, not a hypothetical.
- WCAG **AA** for all text token pairs (4.5:1 body, 3:1 large/bold), verified by computed ratio
  when token values change; 48dp touch targets; visible focus states.
- **Reduced motion is respected** — `GaugeArc` does not animate its sweep when the platform asks
  for less motion.
- Semantics are already in use on settings, fuel log and timeline; read-only settings lines are a
  single screen-reader stop by design (decision log).
