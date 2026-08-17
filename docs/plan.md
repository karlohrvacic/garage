# Building a Public Multi-Tenant, Multi-Vehicle Tracking App: Competitive Analysis, Data Sources & Architecture

## Project decisions (locked in)
- **Name/domain: garage.hrva.cc** — clearly distinct from the existing drive.hrva.cc (trip/driving analysis), positioning this app around vehicle ownership/upkeep (fuel, maintenance, expenses) rather than driving behavior.
- **Distribution: public on Google Play Store** (not a private/home-server tool) — this means multi-tenant architecture, GDPR compliance, and Play Store submission requirements apply.
- **Scale: unbounded vehicles per household.** Not fixed at 2 — some households will track a handful of vehicles, others many more. The data model, UI, and dashboards need to work for N vehicles from day one, not be retrofitted from a 2-vehicle assumption.
- **Localization: multi-language from v1.** Since it's public and not Croatia-only, the app needs proper i18n infrastructure (not just Croatian + English) so it's usable by anyone who installs it, not retrofitted later.
- **Monetization: free, no ads.** No in-app billing, no ad SDK integration needed — simplifies the build significantly.
- **Platforms: Android + web dashboard.** No iOS for v1.
- **Backend: Supabase Cloud, EU (Frankfurt) region.** Managed Postgres + Auth + Realtime + Storage, with row-level security enforcing tenant (household) isolation across an arbitrary number of independent households, each with an arbitrary number of vehicles and members. Free tier is sufficient for a hobby-scale public app; costs only start if you get real adoption.
- **Framework: Flutter**, targeting Android + Flutter Web from a single codebase — this covers both required platforms without maintaining two frontends.

## TL;DR
- No mainstream consumer app cleanly solves your exact problem — multiple people sharing an arbitrary number of household vehicles with real-time bidirectional sync — while also being something you can ship publicly to many independent households at once. LubeLogger (self-hosted, open-source) remains a great feature/data-model reference, but since you're publishing to Play Store, you're building your own multi-tenant service, not deploying one instance per household on a home server.
- For manufacturer maintenance schedules there is **no cheap, clean, EU-friendly API**: the free NHTSA vPIC API only decodes VINs (no schedules), CarMD/Vehicle Databases are US-market and gated behind opaque credit pricing, and the one complete downloadable dataset (cardatabases.com) is priced "From $1000" — so you should ship user-editable interval presets rather than integrate a paid API.
- Recommended build: a **Flutter app (Android + Web) on a Supabase (Postgres) backend** with row-level security enforcing tenant/household isolation across any number of households, each with any number of vehicles and members, a shared "household" data model (vehicles owned by a household, not a person), Supabase Auth (email + Google Sign-In) for account management, and Supabase Realtime for sync across all of a household's devices.

## Positioning & differentiation

You're the primary user (you + your wife, N vehicles), but the app is public. **Core focus, by your own priority: excellent fuel logging, a real maintenance calendar, and smart scheduling suggestions (bundling nearby maintenance items instead of scattering shop visits).** Everything else in this section is secondary — worth having, but not at the expense of the core.

**Tier 0 — the actual product, get these right before anything else:**
1. **Fuel logging done well.** Table stakes relative to competitors, but must be flawless: full/partial tank handling, correct economy math, no friction on entry. This is the foundation everything else (cost-per-km, trend charts) is computed from.
2. **Maintenance calendar + reminders.** Real calendar view (not just a list), configurable per-item intervals, due/overdue/upcoming states. This is your primary daily-use surface.
3. **Smart maintenance bundling.** Genuinely novel — no competitor clusters upcoming maintenance items to suggest combined shop visits. Cheap to build (pure comparison of computed due-dates within a proximity window) and directly matches what you described wanting. This is your headline feature, more than the multi-tenant sync architecture is.

**Tier 1 — architectural differentiators, already "free" given decisions already made, keep them but don't let them distract from Tier 0:**
4. **True equal multi-user sync for shared vehicles.** Household model + Supabase Realtime + RLS — already the plan, no extra work, still valuable since nobody else does it well.
5. **EU-native design** (multi-currency, multi-unit, multi-language) — already the plan via the localization section.
6. **Free without subscription creep** — already the monetization decision.

**Tier 2 — good extensions, build only after Tier 0 is solid and genuinely used by you day-to-day:**
7. **Public read API / webhooks.** Cheap given Supabase/Postgres, useful for your own Home Assistant integration — but secondary to getting the core maintenance/fuel experience right first.
8. **Mixed-fuel household normalization (EV + ICE).** Relevant if/when you or others go electric; not urgent otherwise.
9. **Household expense splitting/settlement.** Nice differentiator, low cost given existing attribution data, but not core to your stated priority.
10. **Scales cleanly to large household fleets.** Already covered by the unbounded-vehicles decision; no extra work needed.

**Tier 3 — defer well past v1:**
11. **Country-specific compliance calendars beyond Croatia.**
12. **Data portability / no-lock-in as an explicit stated principle** (open-sourcing, about-page messaging).





### The multi-user shared-vehicle gap is real
Nearly every competitor treats a vehicle as belonging to one account. Fuelio has never solved shared-vehicle sync well — its user forum is full of long-standing complaints that syncing between a husband and wife's phones either fails or creates duplicate vehicles. Fuelio's sync is file-based (Google Drive/Dropbox on Android, iCloud on iOS), which is fundamentally single-user backup, not multi-user collaboration.

The apps that do support multi-driver sharing (Simply Auto, Drivvo Pro) put it behind a paid tier and use a "one owner shares out to added drivers" model with full-sync semantics that can overwrite data — workable but clunky for two equal co-owners.

The only tool architected from the ground up for multiple equal users collaborating on shared vehicles is **LubeLogger** — but it's a self-hosted tool, not a publishable app, so it informs your data model rather than being a deployment option here.

### Maintenance-schedule data is the hardest requirement to satisfy cheaply
Manufacturer-specific service schedules are proprietary, US-centric, and expensive to license. The genuinely free government API (NHTSA vPIC) gives you VIN decoding only. Every source that actually contains OEM intervals is either a paid credit API with unpublished per-call pricing (CarMD, Vehicle Databases, TorqueNode) or a four-figure bulk dataset. For a free public app with EU users, user-defined intervals (with sensible presets) are the pragmatic answer — and avoid a recurring cost you'd have to absorb yourself since there's no monetization.

## Details

### 1. Competitive analysis

**Fuelio (Sygic)** — Freemium. Android + iOS.
- Core: fill-up logging (full/partial tank, bi-fuel/two-tank support), fuel-economy calc (full-tank algorithm), multi-vehicle, cost module with custom categories (service, insurance, wash, parking, tolls), charts (consumption, monthly cost, gas price, cost/km, cost categories), reminders/notifications (distance- or date-based), crowdsourced fuel prices/station map, GPS trip log with GPX export, CSV import/export, widgets, dark mode, OBD-II support (via dongle).
- Maintenance: user-defined reminders by distance or date; no manufacturer schedule database.
- Sync: cloud backup to Google Drive/Dropbox (Android) or iCloud (iOS) — not true multi-user sync. Well-documented failures sharing a vehicle between two people.
- Pricing: historically free/ad-free with no data collection. Since June 2023 (Android) a Premium tier (~€5–6/yr) adds route planning with fuel stops; core logging remains free.
- Strengths: clean, fast, mature, no ads, EU-friendly units/currency. Weakness: no real multi-user sync — the exact thing you need.

**Drivvo** — Freemium (subscription Pro). Android + iOS + Web.
- Core: refueling, expenses (insurance, taxes, tolls, parking, fines, financing), services, income tracking (for rideshare), routes, reminders (by km or date), reports/charts, multi-vehicle, offline support.
- Maintenance: user-defined reminders by odometer or date; no OEM schedule DB.
- Sync: cloud backup + cross-device sync is a Pro feature; imports from Fuelio/aCar/Fuel Log etc.
- Pricing: free tier with ads; Pro removes ads, adds multi-vehicle, cloud backup/sync, CSV/Excel export. Subscription pricing has been rising over time.
- Strengths: best-in-class expense categorization/reports, web access. Weakness: sync/export paywalled; owner→driver sharing model, not co-equal.

**Simply Auto (Mobifolio)** — Freemium (Pro). Android + iOS + Web.
- Core: fill-ups, GPS/Bluetooth auto trip logging (tax/business mileage), services, expenses, reminders, receipt photos, stats/graphs, multiple vehicles, CSV import/export, voice input, scheduled reports, EV kWh support.
- Multi-driver sharing: explicitly supported — you add drivers and perform a "full sync"; marketed for families sharing a vehicle. Cloud sign-in syncs data across devices.
- Sync caveat: full-sync semantics overwrite — reviews report sync bugs between co-users.
- Pricing: free tier; Pro (cloud sync, web access, multi-vehicle) low annual/lifetime cost.
- Strengths: closest mainstream app to your multi-user need. Weakness: overwrite-based sync is risky for two active editors.

**Fuelly (formerly Gas Cubby; aCar on Android)** — Freemium. iOS + Android + Web.
- Core: fuel logging with real-world MPG, community MPG benchmarking, service records, customizable reminders, charts, multi-vehicle, CSV email reports, web sync.
- Sync: syncs to Fuelly.com web account (single-user).
- Pricing: free; premium (~$4.99/yr) adds attachments, removes ads.
- Strengths: deep fuel analytics + community benchmarks. Weakness: fuel-first, weaker maintenance; no true multi-user shared vehicle.

**aCar (Android; Zonewalker)** — Freemium. Android only.
- Core: fill-ups, maintenance/services with parts detail, expenses by type, trips, reminders, charts, multi-vehicle (+ boats/motorcycles).
- Strengths: very deep record-keeping. Weakness: Android-only, cluttered UI, no clean multi-user sync.

**CARFAX Car Care / MyCarfax** — Free. iOS + Android.
- Core: service history (auto-populated via VIN/plate from CARFAX's dealer/shop network), model-specific service reminders, registration/inspection reminders, recall alerts, repair cost estimates, shop finder, mileage/fuel tracking.
- Maintenance: the differentiator — model-specific recommended schedule + auto-imported professional service records.
- Sync: single account; no collaborative multi-user roles.
- Pricing: free (monetized via vehicle-history reports). **US/Canada-centric** — of little use in Croatia.

**LubeLogger (Hargata Softworks)** — Free, open-source, self-hosted. Web (PWA), Docker.
- Core: garage/multi-vehicle, dashboard, planner, service records with attachments, fuel tracker (l/100km supported), supplies inventory, reminders (date, odometer, or whichever first), taxes, GET/POST API, webhooks.
- Multi-user: first-class — multiple accounts, invite-by-token, OIDC/SSO.
- Backend: LiteDB or Postgres; .NET; Docker image.
- Relevance here: **not deployable as your public app** (self-hosted, single-instance-per-owner design), but its data model (household/garage-scoped vehicles, per-entry attribution, flexible reminders) is the best reference you'll find for your schema design.

**Other notable apps:** AUTOsist, FIXD (OBD-II), Road Trip (iOS), Car Minder Plus (iOS), and newer AI-assisted entrants (Carvetka, MyAutoLog, GarageHub) — mostly single-user or US-focused.

#### How competitors handle maintenance schedules
- **User-defined intervals** (most: Fuelio, Drivvo, Simply Auto, Fuelly, aCar, LubeLogger): you set the reminder distance/date.
- **Fixed presets** (CARFAX, Car Minder Plus): pick from common intervals, sometimes model-aware.
- **Manufacturer-specific/OEM** (CARFAX US, some AI apps): pulled from a licensed database or AI-generated.

### 2. Maintenance schedule data sources

**Free / government:**
- **NHTSA vPIC API** — free, no registration, no hard daily cap (throttled above ~5 req/s), Model Years 1981+, downloadable in Postgres/MS SQL format. Contains **no maintenance schedules** — VIN decode only (make/model/year/trim/engine). US-market vehicles primarily; limited coverage for EU-spec cars. Best use: VIN → autofill vehicle details.

**Paid APIs (all US-centric, opaque pricing — not worth it for a free app):**
- **CarMD API** — credit-based, free tier ~10 credits/day (insufficient for real use), North America only, unpublished paid pricing, still in Beta.
- **Vehicle Databases (vehicledatabases.com)** — 15 free trial credits, coverage ~1999–2023, cost estimates included, unpublished paid pricing.
- **TorqueNode** — VIN/YMM-based maintenance API, no published pricing or free-tier limits, newer/unproven.

**Bulk dataset (one-time, not viable for a free app):**
- **cardatabases.com** — "From $1000," 58,681 trims / 54 makes / 1983–2025, US-market, SQL/CSV/JSON. Great data, wrong economics for a no-revenue app.

**Other:**
- **Edmunds Maintenance API** — retired its open program in 2018; partners-only now.
- No well-maintained open-source dataset of OEM intervals exists.

**Feasibility verdict — reinforced by the free/no-ads decision:** since there's no revenue to offset a paid data subscription, integrating any of the above is a non-starter. Ship: (a) free NHTSA vPIC for VIN→vehicle metadata autofill; (b) a built-in table of generic, editable interval presets (oil ~10,000–15,000 km, brake fluid ~2 yr, timing belt per model, cabin filter yearly, etc.); (c) full user editing of intervals per vehicle. This matches what every successful competitor except CARFAX actually does.

### 3. Recommended feature set

**Fueling logs**
- Full/partial tank flag; missed-fill flag (needed for correct economy math).
- Enter any two of {price/unit, volume, total}, auto-calc the third.
- Fields: date, odometer, volume (l), price/l, total, station, fuel type, notes, receipt photo.
- Auto-compute l/100km, cost/km, cost/fill.

**Multi-vehicle (unbounded — households may track anywhere from 1 to many)**
- Vehicle entity: make/model/year/trim/VIN/plate/photo/nickname, per-vehicle fuel type, active/archived state.
- **UI must scale beyond "a couple of cards."** Below ~4 vehicles a tab bar or simple dropdown switcher works; beyond that, a proper vehicle list screen with search/filter, sort (by name, by upcoming maintenance, by last activity), and archiving for vehicles no longer in active use.
- **Cross-vehicle aggregation views**, not just per-vehicle: total household fuel/maintenance/expense spend across all vehicles, side-by-side fuel-economy or cost-per-km comparison, "what's due soonest across the whole fleet" combined maintenance view. These become genuinely useful (not just nice-to-have) once a household has more than 2–3 vehicles.

**Multi-user shared access**
- Data model: **Household** owns vehicles; any number of members can belong to a household; any member can log entries for any vehicle in it.
- Real-time sync via Supabase Realtime (Postgres change streams pushed to all household members' clients, not just two).
- Per-entry attribution (who logged it) — more valuable as household size grows.
- Invite flow: a household creator sends invites (email or code) to add members — this is your account-linking mechanism for a public app, and needs to support inviting more than one additional person.
- Consider a lightweight **role/permission model** later (e.g., all members can log entries, but only an "admin" can remove a vehicle or member) — not needed for v1, but worth keeping the schema flexible enough not to preclude it, since larger households are more likely to want this than a 2-person household.

**Odometer & stats**
- Odometer tracking with anomaly warnings.
- Fuel-economy trend charts, cost/km, monthly/yearly summaries, cost-by-category breakdown, price-per-litre history.

**Maintenance tracking & reminders — this is the core focus of the app**
- Service history log (date, odometer, description, cost, parts, shop, attachments).
- Reminders by distance OR time OR whichever-first, recurring.
- Editable interval presets per service type, per-vehicle overrides (oil, oil filter, air filter, cabin filter, spark plugs, brake fluid, timing belt, tires, etc.). Optional VIN decode via NHTSA to prefill vehicle.
- **Calendar view**, not just a due/overdue list — see all upcoming maintenance (and expenses like registration/insurance) laid out on a real calendar, per vehicle and household-wide. This is a more useful mental model than a flat list once you have several recurring items per vehicle.
- **Smart maintenance bundling (core differentiator, not just nice-to-have):** when two or more maintenance items fall due within a configurable proximity window (e.g., within 500 km or 3–4 weeks of each other), surface a suggestion to do them together instead of separately — "Oil filter due in 2 weeks, spark plugs due in 5 weeks → do both now, save a second shop visit / labor charge." This is genuinely something no competitor does; it only requires comparing the computed due-dates/due-mileages of a vehicle's active reminders and clustering ones within the threshold.
    - Implementation approach: on every reminder recalculation (new odometer reading logged, or daily cron for date-based items), compute projected due-date and due-mileage for all active reminders on a vehicle, then group any that fall within the proximity window and surface as a single combined suggestion card rather than N separate notifications.
    - Threshold should be configurable per household (some people want tight bundling, others don't care), with sensible defaults (e.g., ±3 weeks or ±500 km).
    - Extend later to a simple "typical labor overlap" table (e.g., oil change + filter + spark plugs are commonly done in the same shop visit; timing belt jobs often bundle water pump/tensioner) to make suggestions smarter than pure date proximity — this is exactly the "check oil, do filters and plugs together" instinct you described, formalized as a rule.
- Due/overdue/upcoming dashboard, in addition to the calendar view.
- **Country-specific compliance templates (secondary, start small):** built-in reminder templates for legally-mandated items — starting with a Croatia-accurate template (tehnički pregled cadence, insurance renewal norms) since that's what you can verify firsthand. Generalize to other countries opportunistically as/if users from those markets show up, rather than pre-building an unverified library.

**Tracking depth: beginner defaults, advanced opt-in (per household, or even per member)**

The app should default to a simple, low-friction feature set but let anyone toggle on deeper tracking without needing a different app. This also directly improves the smart bundling feature (Tier 0 above) — the more granular the tracked components, the better bundling can reason at the component level instead of just "a vague item is due."

*Beginner tier (default — visible to everyone, minimal input):*
- Fluid levels & swap dates: engine oil, coolant, brake fluid, power steering fluid, washer fluid.
- Tire basics: pressure checks, seasonal swap date (summer/winter — directly relevant in Croatia/EU), rotation history.
- Battery replacement date (batteries have a rough lifespan; almost nobody tracks this otherwise).
- Wiper blades, bulbs/lights replaced.
- Legal dates: registration, insurance, tehnički pregled (already covered above).
- Simple issue log: free-text note + date/mileage for "check engine light came on, shop said X" — valuable even with zero OBD-II integration.

*Intermediate tier (opt-in, one toggle):*
- Oil/fluid spec used (brand + viscosity, e.g. 5W-30) and filter part — solves "what do I buy again."
- Brake pad/rotor thickness readings over time (trend, not just a binary "replaced").
- Tire tread depth per corner, to catch alignment/suspension issues early.
- Parts by brand/part number for easy reordering.
- DIY vs. shop-done flag, with labor cost vs. parts cost split per entry.
- Warranty tracking — which parts are covered and until when.
- Photo attachments per service entry (already in the base feature list; surfaced more prominently here).

*Advanced tier (opt-in, for serious DIY/enthusiast users):*
- DTC (diagnostic trouble code) history log — manually entered now, structured for future OBD-II integration later.
- Torque specs / procedure notes per repair, so the info is there next time instead of re-searched.
- Battery voltage/CCA readings tracked over time, not just a replacement date.
- Suspension component age (bushings, shocks/struts) — items that degrade without obvious symptoms.
- Used-oil-analysis (UOA) results, for the subset of users who send samples to a lab.
- Modification/tuning log (aftermarket parts, ECU tunes) and its effect on fuel economy/maintenance needs.
- Seasonal tire sets tracked as independent inventory (e.g., "Set A – studded," "Set B – all-season") with their own tread history and storage location, distinct from the vehicle's primary tire record.
- Recall tracking tied to VIN.
- Part price history over time, to spot shop markup or track inflation on parts you buy repeatedly.

*Implementation note:* model this as optional field groups/entry types rather than a hard schema split — a beginner and an advanced user are logging the same underlying `service_entry`/`fluid_check`/`tire_status` records, just with more or fewer fields populated. An "Advanced tracking" setting per household (or per member, if you want one spouse to see detail the other doesn't) simply changes which input fields and dashboard widgets are shown, not the data model.

**Expense tracking beyond fuel**
- Custom categories: insurance, registration/tehnički pregled, tires, parts, repairs, car wash, tolls/vignettes, parking, financing.
- Recurring expenses (annual insurance, registration) auto-generate reminders.
- **Household settlement (differentiator):** running balance per household member across shared-vehicle spend — who's paid more into fuel/maintenance/expenses, with a simple "settle up" view. Built on top of existing per-entry attribution, no new data model needed.

**Mixed-fuel household support (differentiator)**
- Per-vehicle energy type (petrol/diesel/LPG/electric/hybrid), with electric vehicles tracked in kWh rather than liters.
- Home charging cost entry (kWh × electricity rate) alongside/instead of fuel fill-ups.
- Normalized cross-vehicle comparison: cost-per-km and cost-per-month computed consistently regardless of energy type, so an EV and an ICE car in the same household are directly comparable on the aggregation dashboard (see multi-vehicle aggregation views above).

**Data export/import**
- CSV export/import (Fuelio/Drivvo-compatible columns).
- Account data export (also doubles as your GDPR "right to data portability" mechanism — see below).

**Notifications**
- Push notifications (Firebase Cloud Messaging, standard for Flutter/Android) for due/overdue reminders.

**Nice-to-haves worth borrowing**
- Receipt/document photo attachments (Supabase Storage).
- Web dashboard for heavier entry/reporting (Flutter Web reuses the same codebase).
- Dark mode; l/100km + EUR defaults.
- OBD-II integration, GPS trip log — defer to v2+.

### 5. Localization architecture

Multi-language from v1 touches more than UI strings — get these decisions right early since retrofitting units/currency later is painful once real user data exists:

**UI strings**
- Flutter's built-in `intl` package + ARB files (`.arb`) is the standard approach — generates localized string lookups at build time, well-supported tooling.
- Structure strings by feature area (fuel, maintenance, expenses, onboarding) in separate ARB files for maintainability as the string count grows.
- For an open/community-friendly project, consider **Weblate** (free for open-source projects, self-hostable) or **Crowdin** (free tier) to let volunteer translators contribute without touching code — relevant since as a public app for "everyone," community translation is realistically how you'll cover more than 2–3 languages as a solo dev.
- Launch scope: pick 2–4 languages you can verify yourself (e.g., Croatian + English, plus maybe German/Italian given neighboring markets) and add more via community contribution post-launch, rather than trying to launch with many unverified machine translations.

**Units & formats (not just strings)**
- **Distance:** km vs. miles — must be a per-user or per-household setting, not inferred from language (a US-based Croatian speaker still wants miles; plenty of non-US English speakers want km).
- **Volume:** liters vs. US/UK gallons — same logic, independent setting.
- **Currency:** free-text currency symbol/code per household is simpler than trying to auto-map language→currency (a household could be EUR, USD, GBP, etc. regardless of app language). Store amounts as decimal + currency code; don't hardcode EUR.
- **Date/number formats:** use `intl`'s locale-aware formatting (`DateFormat`, `NumberFormat`) rather than hand-rolled formatting, so decimal separators (1.234,56 vs 1,234.56) and date order follow locale conventions automatically.
- **Fuel types:** petrol/gasoline naming varies by region (petrol vs. gas vs. benzin) — handle via the string localization layer, not separate logic.

**Database/schema implications**
- Store all user-facing enums (fuel type, expense category) as language-neutral keys (e.g., `fuel_petrol`) with localized display labels resolved client-side — never store the translated string itself, or you can't add languages later without a data migration.
- Store measurements in a canonical unit internally (e.g., always km and liters in the database) and convert for display based on the user's unit preference — avoids unit-conversion bugs from mixed-unit data.

**Play Store implications**
- Store listing (title, description, screenshots) can and should be localized per-market in Play Console — this is separate from in-app localization and improves discoverability in each language's Play Store.
- The Data Safety form and privacy policy should have at least an English version regardless of how many in-app languages you support, since Google's review process expects it.

### 6. Technical architecture for a public Play Store app

**Backend: Supabase Cloud, EU (Frankfurt) region**
- Postgres + Auth + Realtime + Storage, managed — no server ops burden for a solo dev.
- **Row-level security (RLS)** is the core of multi-tenant safety: policies scoped to `household_id` via a membership table, so Postgres itself enforces that household A can never read/write household B's rows, even if there's a bug in your Flutter code.
- **Auth:** email/password + Google Sign-In (expected by Android users). Supabase Auth handles both natively.
- **Free tier** (500MB DB, 1GB file storage, 50k MAU as of current pricing — verify at supabase.com/pricing before committing) comfortably covers a free hobby app well past just you and your wife. You'd only hit paid tiers (~€25/mo Pro) with real adoption, at which point a free app might warrant reconsidering monetization.
- **Public read API (differentiator):** since the backend is already Postgres + RLS, exposing a documented, household-scoped, auth'd read-only REST endpoint is low marginal cost (Supabase's auto-generated PostgREST API already does most of this). Directly useful for your own Home Assistant integration (fuel-cost dashboards, low-fuel alerts) and a meaningful draw for other self-hosting-minded users if the app gets outside adoption. Consider adding basic webhook support (e.g., "notify on new maintenance due") once the core API is stable.

**Frontend: Flutter**
- Single codebase → Android APK/AAB for Play Store + Flutter Web for the dashboard. This is the main reason to pick Flutter over React Native here: RN's web story (React Native Web) is comparatively weaker.
- `supabase_flutter` package gives you auth, realtime subscriptions, storage, and Postgres queries with minimal boilerplate.
- Charts: `fl_chart`. Local caching/offline: start online-first (simpler); add `drift` (SQLite) + a sync queue later only if offline entry proves painful.

**Sync model**
- Two users, low write contention → **last-write-wins with server timestamps** is sufficient; no need for CRDTs or a dedicated sync engine (PowerSync/ElectricSQL) unless you later go offline-first.
- Supabase Realtime pushes Postgres changes to both subscribed clients — this is your "both phones update instantly" mechanism, essentially free with the managed plan.

**Play Store & compliance checklist**
- **Google Play Developer account:** one-time $25 registration.
- **Privacy Policy:** mandatory, publicly hosted URL — required because you collect location (fuel stations), photos (receipts), and account data. A simple static page is sufficient.
- **Data Safety form:** Play Console requires accurate disclosure of what you collect and whether it's shared (Supabase as a processor counts).
- **Target API level:** must meet Google's current minimum target SDK requirement at submission time — check Play Console before building your release, as this changes annually.
- **GDPR:** since you're in the EU with likely EU users — right to access/export/delete data (build a simple "export my data" and "delete my account" flow, this also satisfies Play Store's account-deletion requirement introduced a few years back), clear consent for data collection, EU data residency (covered by choosing the Frankfurt Supabase region), and a Data Processing Agreement with Supabase (they provide a standard DPA — no extra cost on paid or even review on free tier, but confirm current terms).
- **App signing:** Play App Signing (Google-managed) is the default and recommended path.
- **Store listing:** app icon, screenshots (phone + optionally tablet/web), short/long description, support email.
- **No ads/no billing:** simplifies this list considerably — no AdMob integration, no Play Billing Library, no ad-content policy review.

**Realistic scope for a public app vs. your original 2-user plan**
- Onboarding flow (sign up, create/join household).
- Account recovery (forgot password — Supabase Auth handles this).
- DB migrations that don't break existing users' synced data across app updates.
- A support channel (even just an email address in the store listing).
- Ongoing store listing maintenance and periodic target-API-level updates to stay compliant.

## Recommendations

1. **Build on Supabase (EU) + Flutter (Android + Web) as scoped above.** This is the leanest path that satisfies "public, free, multi-tenant, Android + web" without taking on infrastructure ops.
2. **Design the RLS policies and household/membership schema first**, before writing UI — this is the part every competitor gets wrong for your use case, and it's much harder to retrofit multi-tenant security after the fact than to build it in from the first migration. Since scale is unbounded per household, avoid any schema or UI assumption that hardcodes "2" anywhere (e.g., no fixed two-tab layout, no `car_1`/`car_2` columns) — model vehicles and members as ordinary one-to-many relations from the start.
3. **Skip all maintenance-schedule APIs.** Ship editable presets + NHTSA VIN autofill. Revisit only if the app gains real traction and you're willing to add a paid tier to offset data-licensing costs.
4. **Start online-first.** With Realtime sync and both phones normally connected, you don't need offline-first complexity for v1. Add local caching/offline queue later only if real usage shows it's needed.
5. **Handle the compliance checklist (privacy policy, data safety form, account deletion, GDPR export) as part of the MVP, not an afterthought** — Play Store review will reject submissions missing these, and retrofitting GDPR-compliant deletion into a live schema is more work than building it in from day one.
6. **Guarantee CSV export from day one** — besides being a useful feature, it's your cheapest GDPR data-portability compliance path.

**Benchmarks that would change the recommendation:**
- If you outgrow Supabase's free tier → move to their paid tier first (still low ops) before considering self-managed Postgres.
- If real users report offline pain (spotty signal at fuel stations) → invest in `drift` + a proper sync queue, or evaluate PowerSync/ElectricSQL.
- If you later want OEM-accurate maintenance schedules at scale → that's the point where a paid data source or a monetization model to fund it becomes worth reconsidering.

## Caveats
- **Pricing is fluid and often unpublished.** Several maintenance-data vendors (CarMD paid credits, Vehicle Databases, TorqueNode) do not publish prices. Supabase's free-tier limits and pricing tiers also change periodically — verify current numbers at supabase.com/pricing before committing to the architecture.
- **US vs. EU coverage** is a recurring limitation across competitor data sources: CARFAX's auto-populated data, NHTSA vPIC, and OEM-schedule datasets are US-market-oriented and may not cover EU-spec vehicles or newer (2024+) model years well.
- **Google Play policy requirements** (target API level, data safety form specifics, account-deletion requirements) change periodically — confirm current requirements in Play Console at submission time rather than relying on this document.
- **Sync-quality claims** for commercial competitor apps come largely from app-store descriptions and user reviews, not independent testing.
- This report reflects information available as of July 20, 2026.