# Decision log

Why the system is shaped the way it is, including the decisions worth arguing
with. Each entry records what was decided, why, and what it cost. Where a decision
turned out badly it says so.

Dates are when the decision was made, not when it was written down.

---

## 1. Supabase and Postgres RLS as the tenancy boundary

**July 2026.** Managed Postgres with row-level security, EU region, rather than a
hand-written API in front of a database.

**Why.** The sharing model is the product ([02-domain-model.md](../architecture/02-domain-model.md)),
so the isolation rule is the thing most worth making impossible to get wrong. Put
in Postgres, it holds against a modified client, a direct REST call, and a bug in
any screen. A hand-written API would put the same rule in code that has to be
correct on every endpoint forever, which is a much larger surface.

**Cost.** Tenancy bugs are now SQL bugs, and SQL is the part of the stack with the
least test tooling. The suite that proves it (`test_rls/rls_test.dart`) needs a
live Postgres, which for a while meant it ran by hand, on the honour system,
exactly where forgetting costs most. That is closed: the `rls` job in
`.github/workflows/ci.yml` stands up a throwaway stack, and `deploy-web.yml`
waits on it. What remains of the cost is that policies and their tests live in
different files and drift silently — four tables sat with policies and no test
until August 2026. See
[known-bugs-and-risks.md](../operations/known-bugs-and-risks.md).

---

## 2. Pure domain layer with no Flutter import

**July 2026.** Economy, projection, bundling, settlement, and status rules live in
`lib/domain/` as pure functions over plain data.

**Why.** These are the parts that are actually hard, and the parts a user notices
when they are wrong. Pure code is tested in milliseconds without a widget tree,
which is why the algorithm docs
([03](../architecture/03-fuel-economy.md), [04](../architecture/04-maintenance-projection.md))
can describe behaviour precisely: it is all pinned by tests.

**Cost.** Nothing enforces the purity. No lint, no test, no build step fails if
someone imports `package:flutter` into `lib/domain/`. It has held so far by
convention.

---

## 3. Repository interfaces between screens and Supabase

**July 2026.** Screens read providers over repository interfaces; only
`lib/features/*/data/supabase_*.dart` knows the backend exists.

**Why.** Widget tests hand in a fake and run offline in seconds. The same seam
covers platform capabilities (file picker, URL launcher), which is what makes
"tapping this opens the right URL" a test rather than a manual check.

**Cost.** A layer of indirection per feature, and a real trap: a provider that
reaches for `Supabase.instance` directly compiles fine and fails only in tests,
sometimes in tests unrelated to the change.

---

## 4. Canonical units in storage

**July 2026.** Kilometres, litres, household currency in the database; conversion
only at display.

**Why.** A display preference must not be able to corrupt history. Switching a
household to miles should relabel, never reinterpret.

**Cost.** Every read path must convert, and forgetting is invisible in metric
(the conversion factor is 1). The bugs this produces surface only for imperial
households.

---

## 5. Local notifications rather than push

**July 2026.** Reminders are scheduled on the device. The server half exists but
is not wired.

**Why.** No Firebase project, no device tokens stored, nothing extra to declare on
the Play Data safety form, and it fully covers the common case where the person
who logs the car is the person who maintains it.

**Cost, and this is the questionable part.** Reminders are per device, so a
household member who did not create a reminder never hears about it, which
undercuts the app's central claim of being genuinely shared. The fix is built and
deliberately switched off ([08](../architecture/08-reminders-and-notifications.md)).

---

## 6. Invite codes in the app, not Supabase invite emails

**July 2026.** Joining a household uses an 8-character code redeemed through a
definer function.

**Why.** Codes get read aloud across a kitchen table, which is the actual use
case. It needs no email delivery, works for someone who signed in with Google, and
avoids depending on deliverability for onboarding.

**Revisited August 2026.** The first version minted a fresh code on every tap and
never listed them, so a household accumulated live codes it could not see or
revoke. The data and the RLS policies to list and delete had existed since
`supabase/migrations/0002_invites.sql:20` and the app simply never read them. Now
an existing code is reused and all codes are listed and revocable.

---

## 7. Webhooks as a database trigger, not a dashboard Database Webhook

**August 2026.** `supabase/migrations/0024_webhook_dispatch.sql` adds `pg_net`
triggers on the three entry tables.

**Why.** Supabase's dashboard feature does the same thing but lives only in that
project's dashboard: a fresh project silently has no webhooks until someone
remembers to click it, and the trigger it writes embeds a service-role key in its
arguments where any schema reader can see it. As a migration it is reproducible
and reviewable.

**Cost.** It diverges from the documented Supabase feature, so a future maintainer
looking in the dashboard will find nothing and may add a second one.

---

## 8. Configuration in a table, after a failed attempt at a GUC

**August 2026.** The webhook endpoint lives in a single-row
`webhook_dispatch_config` table with RLS on and no policy.

**Why, and what went wrong.** Migration `0024` first read the endpoint from
`app.settings.*` via `current_setting`. That cannot be set on Supabase: defining a
custom parameter at database level needs superuser, which the managed role is not.
The migration had already been applied to production, so it was fixed forward in
`0025` rather than edited, which is the general rule for anything that has run
anywhere.

**Worth keeping.** The table has the better property anyway: the value is visible
to a `select` when someone is asking why no webhook fired, instead of hiding in a
session GUC.

---

## 9. The tag is the version

**August 2026, revised the same week.** CI passes the release tag as the
marketing version and `git rev-list --count HEAD` as the build number. Neither
is typed into a file that ships.

**Why.** Play permanently rejects a re-used build number, and hand-maintaining it
is a step that gets forgotten precisely when a release is urgent. The commit count
only increases and cannot repeat. `github.run_number` was rejected because it
resets if a workflow is renamed or recreated.

**What the first version got wrong.** Only the build number was automated; the
marketing version stayed hand-kept in `pubspec.yaml` and `lib/core/app_info.dart`,
guarded by a workflow step that compared it against the tag. That guard fired on
the first real release, `v1.3.1` against a pubspec still saying `1.3.0`, and
correctly stopped it. The lesson was that a guard against two sources of truth
is worse than having one: the tag now supplies the version, and both files are
merely the fallback a local build shows.

**Cost.** The build number is meaningless to humans and jumps by however many
commits happened; a squashed or rewritten history could in principle move it
backwards. And `pubspec.yaml` is no longer authoritative for a release, which is
mildly surprising to a Flutter developer reading it.

---

## 10. Free, with no ads, no analytics, no subscription

**July 2026.** Stated as a product principle and visible in the app on the About
screen.

**Why.** It is the differentiator against every competitor surveyed in
[`plan.md`](../plan.md), where sync or export is routinely paywalled. It also makes
the privacy position simple: with no analytics there is nothing to disclose, no
consent banner, and no third party in the data path.

**Cost.** There is no revenue, so every recurring cost has to be near zero. That
is why maintenance intervals are user-defined rather than licensed from an OEM
data provider, and why the free Supabase tier shapes what is affordable.

---

## 11. Croatian as a first-class locale

**July 2026.** Two languages, with Croatian reviewed as prose rather than
translated string by string.

**Why.** The intended users are Croatian households. A stilted translation reads
as a foreign product and undermines trust in an app that asks you to record your
spending.

**Cost.** Every user-visible string is double work, ICU plural forms are required
for counted messages ([10](../architecture/10-localization-and-units.md)), and
some surfaces (store listing, release notes, auth emails) sit outside the ARB
tests and must be carried by hand.

---

## 12. One Android OAuth client per signing certificate

**August 2026.** Separate OAuth clients for the Play App Signing certificate and
the local debug certificate.

**Why.** Play re-signs uploads with its own key, so the fingerprint the device
presents is not the upload key's. Without the Play certificate registered, Google
sign-in fails only in the shipped build, which is the worst place to discover it.
Registering the debug certificate as well is what makes the flow testable locally
at all.

**Related.** The bug that exposed this had a different cause
([known-bugs-and-risks.md](../operations/known-bugs-and-risks.md), item 1), and
the signing configuration was correct all along.

---

## 13. The web deploy waits for the test suite

**August 2026.** `deploy-web.yml` calls `ci.yml` as a reusable workflow and
depends on it, so a push to `main` deploys only over a green suite.

**Why, and what it replaces.** The original arrangement ran checks and deploy in
parallel, on the stated grounds that a household's app going out a minute earlier
mattered more than blocking it, with a note to wire `needs:` if the trade ever
flipped. It flipped for two reasons: the web build is now the first place a
backend mistake shows up, since it ships ahead of every Play release, and people
other than the author are about to use it. It was also inconsistent: the Play
workflow already refused to ship without a green suite, so the product that
deploys automatically was the one with no gate.

**The trap this hit on the way.** Adding `workflow_call` while `ci.yml` still
triggered on push to `main` made it run twice per push, and with
`cancel-in-progress` on a shared concurrency group the second run could cancel
the deploy's own checks and fail the release. `ci.yml` therefore has no `push`
trigger: on `main` the checks are the deploy's first job, and on pull requests
they run standalone.

**Cost.** Deploys are slower by the length of the suite, and a flaky test now
blocks a release rather than merely reporting. `flutter build web` was also
restricted to pull requests, since on `main` the deploy compiles the same thing
a minute later; the Android debug build still runs on both, because nothing else
compiles Android until a release tag.

---

## 14. Layout intent per screen, not one content width

**August 2026.** `AdaptiveContent` takes a `ContentWidth` of `reading` (840) or
`wide` (1440), and screens declare which they are. A second breakpoint,
`desktop` at 1200, turns the icon rail into a labelled sidebar and enables the
two-column `AdaptiveColumns`.

**Why.** The app was already responsive: there was a rail and a max width. The
values were the problem. A single 840 cap applied to every screen, so a 1500px
browser window showed a phone app in a column beside an icon strip, which is
what "the website looks like an Android app" actually meant.

The obvious fix, raising the cap, is wrong. 840 is *correct* for an entry form
or a settings page: a text field spanning a monitor is harder to use, not
easier. Only some screens genuinely want width. So the width became a property
of the screen rather than of the app.

**Cost.** Every screen now has to declare its intent, and the default is
`reading`, so a new screen that wants width and forgets to say so silently gets
a narrow column. That is the safer default of the two, since the failure is
"too narrow" rather than a form sprawling across a monitor, but it is a step
that will be forgotten.

**And it was**, within the month: the vehicle detail screen — charts, an economy
series, four views to compare — was the only tabbed screen still on the default,
so on a monitor it drew its charts and its tab strip inside a text column. The
failure mode is exactly as predicted, and it is silent: nothing looks broken,
only cramped. See decision 32 for the half of it that was not just an omission.

**Related.** The sidebar shows the household name rather than the app name,
because the dashboard destination is already labelled "Garage" and a header
repeating it says the same word twice.

---

## 15. The tag names the track as well as the version

**August 2026.** A bare `v1.3.1` releases to **alpha**, the closed test.
`-internal`, `-beta` and `-production` suffixes send it elsewhere, and an
unrecognised suffix fails the job.

**Why alpha is what a bare tag means.** Internal testing is the tempting default:
it is instant and needs no review. It also counts for nothing. The wall between
this app and production is Play's requirement of twelve testers opted in to a
**closed** test for fourteen consecutive days, and only the closed track advances
it. Defaulting to internal would mean the easy path is the one that never
finishes.

**Why the suffix rather than only a dropdown.** Choosing a track was previously a
separate trip to the Actions tab, which makes it a thing you forget and then
wonder why testers saw nothing. Putting it in the tag makes the release name say
where it went, and leaves a permanent record in the tag itself.

**Why an unknown suffix fails.** Guessing here means shipping to the wrong
audience. A typo like `-alfa` stops the job instead of quietly landing on the
default.

**Cost.** The suffix list is a closed set, and Play's `alpha` identifier is only
correct for the *default* closed track. A second, custom-named closed track would
need the list extending, and nothing in the workflow would notice that on its own.

---

## 16. One number for "how due is this"

**August 2026.** `ReminderProjection.dueness` is the single measure of
closeness to due: zero freshly done, one due or overdue. Every surface reads
it.

**Why.** Two screens had independently invented a proportion, in opposite
directions, and showed the same item as 100% and 26%. A shared widget then
coloured danger at the wrong end. When two places compute the same idea, the
question is not which is right but where the idea should live.

**Cost.** A rule with no interval, a one-off with only a date, has no interval
to consume, so its closeness is taken over a 90-day approach instead. That is a
different kind of measurement wearing the same clothes, and the constant is a
judgement rather than a fact.

---

## 17. Sample data rather than a demo mode

**August 2026.** Settings loads a year of history for one car, through the
ordinary repositories, and Delete all data removes it.

**Why.** An empty app cannot demonstrate itself: economy needs two full tanks,
projections need history, running cost needs both. A separate demo mode would
be a second code path that drifts from the real one and has to be kept out of
production builds. Sample data is the real app with rows in it.

**Cost.** It writes into the household's real backend, so "just looking" leaves
traces until deleted. The alternative, a fake in-memory session, was rejected
as the more expensive lie.


---

## 18. The window picks the page transition, not the platform

**August 2026.** `_WindowAwarePageTransitions`
(`lib/core/theme/garage_theme.dart:203`) wraps every platform default in the
`PageTransitionsTheme`. Below the wide breakpoint a push keeps the platform's
transition and its back gesture; above it, every route cross-fades.

**Why.** The desktop sidebar lives inside each page rather than around them, so
the platform push animated it: opening Statistics on the web slid the whole
window in from the right and dragged the sidebar behind it out to the left, and
the reader saw one sidebar leave and an identical one arrive. Tab switches were
already immune because they build their own fading page
(`lib/core/router/app_router.dart:122`); the ten pushed screens that also draw a
sidebar were not.

**Why not a shell route.** The correct fix is a `ShellRoute` holding the sidebar
once, outside the pages, so only the content animates. That is the larger change
— every screen scaffold, plus the pushed pages' own back affordance — and it
would land on top of a layout that is otherwise doing its job. The transition is
where the symptom is *visible*, but the sidebar-inside-the-page arrangement is
the actual cause, and it is still there.

**Cost.** The theme now knows about a breakpoint, which is a layout idea living
in the type-and-colour layer, and a wide window animates nothing directionally
even where direction would have helped — a vehicle's detail page arrives the
same way the calculator does. The wrapper also has to keep pace with
`PageTransitionsBuilder`: it forwards `transitionDuration`,
`reverseTransitionDuration` and `delegatedTransition` by hand, and a new member
on that class would be silently dropped.

---

## 19. An odometer reading is an entry kind, not a field

**August 2026.** `odometer_entries` is a fourth entry kind alongside fuel,
service and cost, carrying a date, a reading, and nothing else. Every source
that records an odometer is merged into one series by `OdometerHistory`
(`lib/domain/fuel/odometer_history.dart:33`), and both the current reading and
the daily rate are taken from that series.

**Why a kind rather than a field on the vehicle.** The vehicle already has a
`baseline_odometer_km`, and the obvious cheap move was to let people overwrite
it — which is what the detail screen's odometer button used to do. That loses
the one thing the baseline is for: where the car stood when it was added, which
is what projects maintenance that has never been done on record. It also throws
away the date, and a reading without a date measures nothing.

**Why merge rather than add a fourth call site.** The rate was read from
fill-ups alone, which quietly broke every projection for a household that
services its car but pays cash at the pump — recorded as a known bug for months.
Fixing that by adding services, then costs, then readings to the one call site
that needed them would have left the next call site to make the same mistake.
`currentOdometerProvider` had in fact already grown its own near-copy of the
merge, subtly different from the projection's.

**Cost.** The series is opinionated in ways that are right on average and wrong
in cases: one reading per day (the highest) discards a genuine second reading
later the same day, and dropping a reading that goes backwards silently hides a
typo instead of flagging it. Both are judgements, not facts, and neither tells
the user anything happened. The alternative — surfacing conflicts for the user
to resolve — is a screen nobody asked for on top of a number most people never
look at.

---

## 20. Trips and income are their own kinds, not tags on a cost

**August 2026.** `trip_entries` and `income_entries` are two more tables beside
fuel, service, cost and odometer, rather than a `direction` column on
`cost_entries` and a `purpose` tag on anything with a distance.

**Why income is not a negative cost.** It would work arithmetically and read
wrongly everywhere else: a category picker offering "Insurance, Parking, Sold
the car", a timeline column where a refund and a bill are the same shape, and a
running-cost figure that a mis-signed row turns into nonsense. The signed
presentation is a display decision made once, in the timeline and the vehicle's
money tab, over a table that only ever holds positive amounts.

**Why a trip is not an odometer reading with places on it.** A reading is a
point; a trip is an interval, and several trips can sit between two readings.
Conflating them would make "how far did I drive for work last month" unanswerable
from data the app had actually collected.

**Why the private/business split is a constrained column.** It is the only
reason to keep a logbook for tax. As free text it would be spelled three ways
inside a month and the split would quietly stop adding up.

**Cost.** Six entry kinds is a lot of tables for one car, and three places now
have to know about all of them — the timeline, the odometer series, and the
statistics aggregate. Each is a place a seventh kind can be forgotten, which is
why the test harness for them is shared
(`test/support/vehicle_entries.dart:28`) rather than repeated: the shared helper
is the only thing that makes forgetting one fail loudly.

**Also true:** the balance figure the wishlist deferred is now meaningful and is
built, but it is a *section* rather than always-on, because for a household that
never logs income it is the cost total with a minus sign in front of it.

---

## 21. A garage is switched on the device, and a car really moves

**August 2026.** Which household the app shows is stored per device
(`lib/features/household/providers/current_household.dart:15`), and transferring
a vehicle changes its `household_id` rather than copying its history.

**Why the device and not the account.** Two people share a household, and which
garage *this phone* was last looking at is a property of the phone. Storing it on
the account would mean switching on a laptop yanks the phone in somebody's pocket
to a different garage mid-journey. It also needs no migration and no write on a
switch.

**Why the fallback is silent.** A stored id that is no longer among the user's
households — after leaving one, or being removed — falls back to the first rather
than showing nothing. Showing nothing would route the user through onboarding as
though they had no garage at all, which is a much worse failure than showing the
wrong one.

**Why a move rather than a copy.** Drivvo sends the buyer a copy. A copy leaves
the seller holding a car they no longer own, and two records of one vehicle that
diverge the moment either is edited. A move is also almost free here, because
every child row hangs off `vehicle_id`: one column changes and the whole history
goes with it.

**Cost, and it is real.** The transfer is irreversible from the seller's side —
only the new owner can send it back — and the vehicle photo does not follow,
because storage objects are keyed by household and SQL cannot move them. Both are
disclosed on the screen before a code is minted, which is the last point at which
anything can be stopped.

---

## 22. "Household" is not renamed to "garage" — *reversed, see 35*

**August 2026.** The wishlist proposed renaming the concept now that a user can
belong to several. It is deliberately not done. **This was reversed within the
month; the reasoning below is kept because the way it failed is the useful
part.**

**Why not.** The app is called Garage and its dashboard destination is labelled
"Garage". A second thing with that name in the same sidebar makes the navigation
worse, not better, and the pervasive half of the rename — tables, RLS policies,
edge functions, the public API's documented shape — buys nothing a user can see.

**What was taken from it anyway.** The user-facing strings that needed new words
got them: "Your garages", "Switch garage", "Create another garage". Those read
naturally *because* they are about the set rather than about the thing, which is
where the wishlist's instinct was right.

**Cost.** The vocabulary is now mixed: the screen is "Household", the switcher
talks about garages. If that proves confusing in testing, the honest fix is to
rename the *strings* consistently and still leave the schema alone.

---

## 23. A generic CSV importer instead of a Drivvo importer

**August 2026.** `CsvSchema` and `CsvImport`
(`lib/domain/import/csv_import.dart:38`) read any table the user can point at,
with the columns mapped by hand and guessed where possible. There is no
Drivvo-specific parser.

**Why.** Drivvo's export is behind its paywall, so there was no sample to write
against — column names, date format, decimal separator and the way it marks a
partial fill were all unknown. Guessing at them produces an importer that
silently mangles data, which is the worst possible failure for the one operation
people do with their entire history. Asking which column is which takes a minute
once and works for a spreadsheet somebody kept by hand.

**What it has to get right, and does.** The delimiter is sniffed by trying each
and taking the one that splits the header widest, so a comma inside a quoted
field cannot beat the real semicolon. Numbers read by treating whichever of `.`
and `,` appears *last* as the decimal point, which handles `1,234.56` and
`1.234,56`. Ambiguous dates are a **question**, not a guess — 03/09 is two
different days depending on where the file came from. A date that does not exist
(31 February) is refused rather than rolled forward. And a row that cannot be
read is reported with its line number **before** anything is written.

**Why re-runnable.** The first attempt often looks like it failed. Every kind is
matched against what is already stored by the natural key a human would use, so
importing the same file twice leaves one copy.

**Cost.** The mapping screen is one more thing to understand than a one-tap
import, and the Fuelio importer stays alongside it precisely because that
format *is* known. Two importers is more code than one; it is also the only
honest arrangement.

---

## 24. The backup is not the export

**August 2026.** `GarageBackup` (`lib/domain/export/garage_backup.dart:66`)
writes versioned JSON that can be restored. The CSV export stays exactly as it
was.

**Why two.** They answer different questions. The CSV is data portability: plain,
readable in a spreadsheet, no app-specific encoding, which is what the GDPR right
actually asks for. It also cannot be restored — it loses which service types one
visit covered and whether a tank was full, and those are not decoration, they are
what the economy and projection algorithms run on. A file that comes back has to
carry the shape.

**Why restore is additive.** Nothing is deleted and an entry already present is
skipped rather than rewritten. Restoring is what people do when they are already
worried about their data; a restore that could remove something would be the
worst possible moment to be wrong.

**Why vehicles are matched by name.** A backup restored into a different
household carries ids that mean nothing there. Matching by nickname is what a
person would do, and its failure mode — a second car called "Golf" — is visible
rather than silent.

**Cost.** The version is refused rather than tolerated when it is newer than the
build, so a file written by a future release cannot be read by an old one at
all, not even partly. That is the right trade for data but it will surprise
somebody.

---

## 25. The station pick that prices the detour

**August 2026.** The stations screen names three: nearest, cheapest, and **best
value** — the cheapest fill once the fuel burned getting there and back is paid
for (`lib/domain/stations/station_picks.dart:36`).

**Why it matters.** Fuelio's "best price" pick will send somebody twenty
kilometres to save three cents a litre, which is a loss presented as a saving.
The data to do better was already here: the vehicle's tank size and its own
measured consumption.

**Why it falls back rather than guessing.** A household without a consumption
figure gets plain cheapest. Inventing a rate to make the clever pick appear would
be worse than not having it, because the number would look measured.

**Why the card is hidden outside Croatia.** The dataset is Croatian. Opened from
elsewhere, every station in the country is "nearby", and a pick naming one a
continent away is worse than no pick — the same trap the list already guards
against.

**Cost.** The pick uses the *first* vehicle's figures when a household has
several, which is wrong for anybody whose second car drinks differently. Asking
which car on a screen that is about where you are standing felt worse than the
error.

---

## 26. An entry outlives the person who logged it

**August 2026.** Every `created_by` and `redeemed_by` reference to `auth.users`
is `on delete set null`
(`supabase/migrations/0033_account_deletion_unblocked.sql:39`), and the columns
are nullable.

**What forced it.** Deleting an account failed outright for anyone who shared a
household — seventeen foreign keys with the default `no action` refused while
any row pointed at the user. It worked for a solo household only by accident, so
it survived to a Play compliance requirement unnoticed.

**Why `set null` and not `cascade`.** The log belongs to the household. One
member deleting their account must not remove the fill-ups they logged from the
shared history — that is data loss wearing tidiness as a disguise. What is lost
is the attribution, which is the part that stops being true anyway.

**The interaction that made this hard, and worth remembering.** `pin_created_by`
(decision-era migration `0008`) reverts any update of `created_by` so a crafted
client cannot forge authorship. `on delete set null` *is* an update. The trigger
reverted it, the delete reported success, and a **dangling foreign-key reference
was left behind** — a worse outcome than the failure it replaced, and invisible.
The trigger now permits exactly one new case: nulling an author who no longer
exists. That is true for the referential action, which fires after the parent
row is gone, and false for every client.

It then had to become `security definer`, because reading `auth.users` is
something `authenticated` cannot do, and without it every edit of a fill-up
failed. Both of those were found by running against a real Postgres, not by
reading the SQL.

**Cost.** `createdBy` is now empty rather than absent in the eight repositories
that read it, using the same empty-string convention this codebase already has
for "no author yet".

---

## 27. Spend from a deleted account is counted, but is not part of the split

That empty author initially became a participant in household settlement: a
nameless row in the list, the fair share divided by one head too many, and
transfers addressed to nobody. Dropping the money instead would rewrite what
everyone else owes, which is worse — it went into these cars.

**Decision:** unattributed spend is *sunk*. `Settlement.of` takes it as a
separate `unattributed` figure
(`lib/domain/household/settlement.dart:51`), keeps `total` and `fairShare` over
attributed spend only, and exposes `householdTotal` for what the household has
spent altogether. The settlement card shows it as a note above the divider
rather than as a member row.

**Why this is the honest arithmetic, not just the tidy one:** money that nobody
will ever be repaid for benefits every remaining member equally, so by
definition it cannot shift the balance between them. Excluding it from the split
is what leaves the debts correct; including it was what made them wrong.

**The line drawn:** *deleted* is not the same as *departed*. Someone who has
left the household but still has an account stays in the split, because they can
still be paid. Only a null author — which after `0033` means the account is
gone — becomes unattributed.

---

## 28. A backup carries reminders and tyres, and stays version 1

The file grew two lists — `rules` and `tyres` — because "Back up everything"
was not true without them, and both are losses a restore cannot show: the
notifications simply never come back, and a tread reading from two winters ago
cannot be measured again.

**The format version stays at 1.** It is bumped when an older build would read
a file *wrongly*, and an older build reading a newer file here skips two keys
it does not know — which is exactly what it would have done before they
existed. Bumping would have made every older build refuse a file it can read
perfectly well.

**What restore gives up.** A tyre set has no id until it is created, so the
restore adds sets, reads back what the ids turned out to be, then fills in the
readings — two passes rather than one. Fitting and retiring go only to sets the
restore itself created: a household that has swapped tyres since the backup was
taken knows better than the file does. A retired set comes back retired but
loses the date it was retired on, because the repository sets that itself.

**Attachments stay out.** They are files in storage, not rows, and a JSON
backup that carried them would be a different artefact — one nobody could open
in a text editor, which is the property that makes this one trustworthy.

---

## 29. A vehicle picker falls back rather than insisting

Three screens keep a chosen vehicle id in their own state while the fleet is
free to change underneath them. Flutter's dropdown asserts on a value that is
not among its items, so a car leaving the household took the screen with it.

**Decision:** the chosen id is filtered through the current list on every build
(`lib/features/vehicles/vehicle_choice.dart:10`) rather than being cleaned up
by whatever removed the car. The screen cannot know every way a car can go —
transfer, delete, garage switch, realtime refresh — and a guard at the point of
use covers all of them at once, where a listener per cause would not.

**The fallback is "all vehicles"**, not the first car: it is what the screen
showed before anything was picked, and it never silently shows one car's
figures under another car's name.

---

## 30. Push replaces local scheduling rather than joining it

Turning push on gives a household two things that both want to notify it: the
server, which reaches everyone, and each phone's own schedule, which reaches
only itself. The obvious answer — run both, the local one as a fallback — is
wrong here, and it took working out why.

**They cannot be made to agree.** The server projects a distance-based due date
from the 30 km/day fallback because it does not compute a driving rate; the app
measures the real one from the odometer history. The same oil change therefore
falls on different days in the two calculations. A household running both is
told about one visit twice, days apart, by two halves of one feature.

**Decision:** when `PushConfig.isConfigured`, `syncNotifications` returns
without scheduling anything
(`lib/core/notifications/notification_providers.dart:117`). The server is the
only source. Local scheduling remains exactly as it was for every build without
push, which today is all of them.

**What makes this safe rather than merely tidy:**

- A notification's id is now derived from the reminder — car, sorted service
  keys, due day (`lib/core/notifications/notification_scheduler.dart:37`) —
  rather than a counter. A push lands on the id the device would have used
  itself, so even if both paths ever ran, the second would replace the first
  instead of stacking beside it.
- One lead time, seven days, held in both languages by a CI test. The server
  used to push at 14, 7, 1 and 0 days against the app's single 7.
- The server groups by car and due day so a visit is one message, keeping the
  property that bundling exists for. It cannot use the app's bundling window,
  which needs the measured rate.

**The cost, accepted knowingly:** a build with Firebase configured and no cron
scheduled notifies nobody, because the fallback has stood down. It is written
at the top of the runbook and in the known-bugs list. The alternative — keeping
a fallback that fires on a different day — trades a loud, one-time setup error
for a quiet, permanent duplicate.

---

## 31. A push carries keys, and the phone writes the sentence

The message has no `notification` block and no text: service type keys, the
car's nickname, the due day. The device looks the strings up in its own locale
(`lib/core/notifications/push_reminder.dart:15`).

The alternative is a server that composes the text, which means storing a
language per user, keeping it true when they change it, and shipping a second
copy of every notification string to a place where no ARB test can see it. The
cost of doing it this way is that a data-only message displays nothing unless
the app handles it — hence a handler on both delivery paths, foreground and
background isolate — and that is a cost paid once in code rather than forever
in translations.

---

## 32. A tab strip belongs to the pane, not to the text column

**August 2026.** `GaragePageScaffold` now places its `bottom` — in practice a
`TabBar` — outside `AdaptiveContent`, so on a desktop window the strip and its
divider run the full width of the content pane while the tab's *contents* stay
in whatever column the screen asked for.

**Why.** The same widget behaved differently in the two layouts: on a phone the
strip is the `AppBar`'s `bottom` and runs edge to edge, and on a desktop window
it was capped at the reading width along with everything else. That reads as a
control floating in the middle of the page, above a rule that stops short of
both sides, and it made the tabs look like part of the content rather than the
thing that switches it.

Tabs are a property of the surface, not of the text on it. Material puts them
directly under the top bar, spanning it. The reading cap exists for prose and
forms; a row of four words is neither.

**Related, and deliberate:** these tabs stay at the top rather than moving into
the sidebar. The rail is for app destinations; tabs are peer views of one car.
Mixing them would answer "where am I in the app" and "what am I looking at
about this car" in the same control.

**Cost.** Labels lost their icons in the process. That was the point — the icon
above each label doubled the strip's height and took the room that made
"Maintenance", and Croatian "Održavanje", run out of space on a phone, which
the scrolling strip existed to work around. Four words fit across 360 pixels;
four words under four icons did not. A test asserts the longest label is not cut
off rather than trusting that.

---

## 33. Two nudges, and a third that a reading raises

**August 2026.** Reminders fire at **30 days and 7 days** before a due date
(`lib/core/notifications/notification_scheduler.dart:44`), and an odometer
reading that brings a distance rule within **500 km** raises one of its own
(`notification_scheduler.dart:61`).

**Why not one lead time.** Seven days was chosen with the comment "enough
notice to book a shop visit". It is not: a service centre rarely has an
appointment inside a week, which the household found out by using it. A month
is enough to arrange one and too long to be remembered on its own, so both are
sent — 30 to arrange it, 7 to keep it. This restores something the server used
to do, badly, at 14/7/1/0 days while the app nudged once at 7; the difference
is that both halves now read the same list and only one of them is ever active.

**Why a reading is its own trigger.** A distance rule comes due at an odometer,
not on a date. The projector turns one into a date by guessing a driving rate —
30 km/day when history is thin — so a household that drives more than the guess
reaches the odometer long before the date arrives, which is exactly the case
where a week's notice becomes no notice. The moment a reading lands, the
distance is known exactly and worth saying out loud: *"Oil change — Golf, due in
300 km"*. No projection involved.

**What keeps it from nagging.** The distance notification is keyed on the
odometer the item is due at, not on the reading that revealed it, so every
subsequent fill-up updates the same notification instead of stacking a new one;
and it is posted with `onlyAlertOnce`, so it counts down quietly and buzzes once.

**Why the distance half ignores the push/local split.** Decision 30 stands the
device's *schedule* down when the server owns it. A reading is not a schedule —
it is a response to something that just happened on this device, and nobody else
can know a car reached 59,700 km at the moment it did. So the dated half stands
down under push and the distance half always runs.

**Cost.** A notification's identity now includes which nudge it is, or the
notification for 30 days out would have silently replaced the one for 7 while it
was still pending. Two constants live in two languages; a CI test compares the
lists and fails if they drift, and also checks that the sentence in Settings
still quotes the right numbers, because that sentence promises a schedule.

---

## 34. Reminders fire at nine, and say when they are for

**August 2026.** A scheduled reminder fires at **09:00 local**
(`notification_scheduler.dart:52`), and its body names the car and how far off
the visit is rather than repeating its own title.

**Why.** `plan` built its fire moment from a *date*, which is midnight, so the
app woke people at 00:00 to tell them an oil change was due in a week. The body
was worse: for a single item it was the title again, word for word, because
there was nothing else to put there. Two nudges made that unbearable — the
month's notice and the week's notice would have read identically.

A notification's job is to be readable without opening the app: *what*, *which
car*, *when*. The push half already carried the car's nickname and the days
remaining, so the local half was taught the same shape.

---

## 35. The user-facing word is "garage"; the schema keeps "household"

**August 2026, reversing decision 22.** Every string a person reads now says
garage. The dashboard destination became **Dashboard**, and the tables,
policies, edge functions and API shape still say household.

**What 22 got wrong, and what it got right.** It refused the rename on the
grounds that the dashboard destination was already called "Garage", so a second
"Garage" in the same sidebar would make navigation worse. That was true, and it
turned out to be an argument about the *dashboard's* name rather than about the
household's: the dashboard is a dashboard, and calling it one frees the word
entirely. 22 also predicted its own reversal — "if that proves confusing in
testing, the honest fix is to rename the strings consistently and still leave
the schema alone" — which is exactly what happened and exactly what was done.

The mixed vocabulary was the thing that gave it away: the switcher offered
"Create another garage" while the screen it lived on was titled "Household".
Nobody has to reason about which is which when there is only one word.

**Why the schema stays.** Renaming `households` reaches migrations that have
already been applied, every RLS policy, four edge functions, the public API's
documented shape, and any script a household has already written against it.
None of that is visible to a user, so all of it is cost without benefit. The
ARB keys stay `household*` for the same reason: they name the thing the database
calls a household, and a key is read by developers, who also read the schema.

**What it opens up**, and this was the argument that carried it: "garage" scales
where "household" does not. A company with a fleet is not a household, and a
garage with several cars, several drivers and a shared cost split is exactly
what fleet management looks like from the outside. The word costs nothing now
and fits the larger thing later.

**Croatian.** *Kućanstvo* → *garaža*, which declines cleanly and reads as
naturally as the English. The dashboard is *Pregled* rather than the literal
*Nadzorna ploča*: the bottom bar has room for one short word, and a test that
keeps tab labels on one line in Croatian caught the long one immediately.

---

## 36. AGPL-3.0, with a contributor licence agreement

**August 2026.** The project is open source under the GNU Affero GPL v3, and
contributions are covered by a CLA that grants the right to relicense
([CLA.md](../../CLA.md)).

**Why Affero rather than MIT or plain GPL.** Garage is not only an app people
install; it is a service at garage.hrva.cc that people reach over a network.
Under MIT, a competitor could fork it, close the source, and sell the result.
Under plain GPL they could do very nearly the same thing, because running a
modified copy as a web service is not *distribution* and triggers no obligation
at all — the loophole Affero exists to close. Section 13 is therefore not a
detail of the licence, it is the reason for choosing it: anyone who hosts a
modified Garage owes its users the source.

**What that obliges us to do, in code.** Section 13 binds this instance too, so
the app has to offer its own source to the people using it. That is the **Source
code** row on the About screen (`lib/features/settings/screens/about_screen.dart:63`),
linked through the same `urlOpener` seam as the privacy policy and pinned by a
test — a licence term that can regress silently is worth a test more than most
features are.

**Why a CLA, which is not free.** CLAs carry a real reputational cost in open
source and add a step that deters drive-by contributions. It buys one specific
thing: the AGPL is incompatible with Apple's App Store terms, so an iOS build
could never ship under it. As sole copyright holder that door stays open — but
only until the first outside contribution is merged, after which relicensing
would need every contributor's agreement, traced and obtained one by one. The
CLA keeps the option without needing to exercise it, and the acceptance is a
line in a pull request rather than a signed form.

**Cost, and what this does not do.** The licence choice is a one-way door: code
already released under the AGPL cannot be un-released. It also does less than
people assume — internal use is always exempt, so an outfit that forks Garage
and never distributes it and never lets outsiders use it owes nothing. What it
prevents is a *closed hosted competitor*, which is the realistic threat rather
than the theoretical one.

**Not done: per-file licence headers.** The FSF recommends them. A single
`LICENSE`, a declared licence in `README.md` and `pubspec.yaml`, and a source
link in the app are legally sufficient, and 192 header comments would be the
largest single block of noise in a codebase that currently has none.

---

## 37. Observe errors on the device, report them nowhere

**August 2026.** Uncaught errors are routed into the existing failure log, the
log survives a restart, and a user can read and share it from About →
Diagnostics. No crash reporter, no Sentry, no Crashlytics.

**Why not a crash reporter**, which is the obvious answer and the one most
projects take. The app promises no tracking, no analytics, no profiles, and says
so on the very screen this feature lives on. A crash reporter is an SDK that
sends data off the device automatically, and installing one would make that
promise false in the small print — for the benefit of the developer, funded by
the user's expectation. So the log stays local and the user has to *choose* to
share it. The cost is real and worth stating plainly: a crash nobody reports is
a crash nobody knows about, and this trades away the whole class of bugs that
only show up in aggregate.

**Why the handlers chain rather than replace.** `FlutterError.onError` already
has an occupant: the framework's red-screen dump in debug, and `flutter_test`'s
own handler that fails a test when the framework errors. Replacing either would
be a silent failure of its own — the second one would have turned every future
red test green, which is the kind of bug that hides all the others. The platform
handler returns `false` for the same reason: this observes, it does not resolve,
and claiming an error was handled would stop the console logging it.

**Why persistence is best-effort.** A crash is a restart, so an in-memory log
forgets exactly the failure worth reading — hence `shared_preferences`. But a
failed write is logged and otherwise ignored: storage can be full, and on the
web it can be denied outright in a private window. An app that fell over because
it could not save its own error log would be a worse app than one with no log.
The dishonest version of this would be to swallow the write failure silently;
instead it goes to `garage.failure` like everything else.

**Cost.** `reportFailure` now touches a plugin, so a plain `test()` that calls it
needs a binding and `SharedPreferences.setMockInitialValues({})`. That is a real
tax on a function that used to be free to call, and it was paid immediately by
`test/core/widgets/failure_message_test.dart`.

---

## 38. Edge functions split into an entry point and a testable handler

**August 2026.** Each function is now a three-line `index.ts` calling
`Deno.serve(handler)` over a `handler.ts` that exports `makeHandler(deps)`. The
Supabase client, `fetch`, the clock and the FCM token exchange arrive as
dependencies. CI runs `deno fmt --check`, `deno lint`, `deno check` and
`deno test` over all of it.

**Why it had to be a refactor and not just tests.** A module that calls
`Deno.serve` at top level starts a server in whatever imports it, including a
test, and `createClient` called inline cannot be substituted. There was no way
to test these files without changing their shape — which is the actual reason
they had no tests, rather than anyone deciding they did not need any.

**Why it was worth the risk.** These functions deploy *by hand*
(`supabase functions deploy <name>`), while migrations apply themselves on push,
so a mistake here breaks production quietly and at a distance. Against that: the
push sender runs unattended on a cron and the dispatcher runs from a database
trigger, so nobody is watching when they fail either. The first test written
against `public-api` found a crash on every browser preflight that had been
there since the function was written. The risk of touching them was smaller than
the risk of continuing not to.

**How the risk was actually handled.** The transformation was diffed against the
original with whitespace ignored, to show that nothing but indentation and the
injected dependencies had changed; then all four were served with
`supabase functions serve` and exercised over HTTP. Passing unit tests would not
have caught a bundling or import mistake, because the fakes do not care whether
Supabase can deploy the result.

**Cost.** Two files per function instead of one, and a small type tax: the
client arrives as `SupabaseLike` (an `any` alias) rather than the real generic
client, so a couple of callbacks need annotations the compiler used to infer.
The alternative — threading Supabase's generated types through a dependency
interface — would be a page of noise for a project with no generated types.

**A cheaper option was rejected**: extracting only the pure helpers and leaving
each `Deno.serve` untouched. It would have tested the date maths and the role
check, and left every HTTP path — the 401s, the routing, the status codes —
exactly as untested as before. The preflight crash lived in one of those paths.

---

## 39. One word for the thing: vehicle, and *vozilo*

**August 2026.** The app says **vehicle** in English and **vozilo** in Croatian,
everywhere it means a car in the garage.

**What was actually wrong.** It looked like a translation problem — the
dashboard said *Dodajte svoj auto* and the screen it opened was titled *Dodaj
vozilo* — but the Croatian was faithful: English said "Add your car" and "Add
vehicle" in exactly the same two places. Across the whole ARB the split was
disciplined, EN "car" → *auto* and EN "vehicle" → *vozilo*, with 7 divergences
out of 43. The source was inconsistent and the translation mirrored it.

**Why it reads worse in Croatian, which is why it surfaced there.** The register
gap between *auto* and *vozilo* is wider than between "car" and "vehicle":
*vozilo* is registration-form language. Mirroring an English wobble faithfully
produces a bigger wobble in Croatian, so the same defect was invisible in one
language and glaring in the other.

**Why *vozilo* rather than *auto*,** which is the warmer word and the one the
app's voice otherwise reaches for. The schema, the API, the tab and every
formal label already said vehicle; moving those down to "car" would have been
the larger edit and would have been wrong the first time a garage holds a
motorbike or a van. The cost is real and worth stating: a few sentences now
read more stiffly in Croatian than they did.

**Two deliberate exceptions.** *Autoplin* is the name of a fuel, not a word for
a car. *Pranje auta* / "Car wash" names an external service the way
*autopraonica* does — a fixed term, not a reference to the app's own entity.
Both keep their word.

**The trap for whoever repeats this.** It is not a find-and-replace: *auto* is
masculine and *vozilo* neuter, so participles and adjectives move with the noun
— *koliko je auto prešao* becomes *koliko je vozilo prešlo*, *za auto koji vozi*
becomes *za vozilo koje vozi*. A sed script would have produced fluent-looking
Croatian that is wrong in a way no test would catch, since `arb_consistency_test`
checks placeholders and plurals, not grammar.

---

## 40. Vehicles can be deleted, not only archived

**August 2026, reversing an unstated position.** The vehicle screen offers
**Archive** and **Delete**. Archiving is listed first and the delete
confirmation points back at it.

**What was actually there.** `VehicleRepository.setArchived` existed with the
comment "which is why vehicles are never hard-deleted from the UI" — a decision
recorded in a doc comment and nowhere else. It was also **unreachable**: no
screen called it, and `archivedVehiclesProvider` had no reader at all. So the
position was not "archive instead of delete", it was "neither", and a vehicle
sold or scrapped stayed in every list forever with no way to move it.

**Why both rather than archive alone.** Archiving is the right default and
covers the honest cases — a car sold, a car off the road. Delete covers the one
archiving cannot: a vehicle created by mistake, or a bad import, where the
history is not worth keeping and leaving it in an archive is clutter that never
goes away. The household-wide "delete all data" was the only existing answer to
that, which is a sledgehammer.

**The database was already ready**, which is part of why this was cheap: delete
has been admin-only and cascading since
`supabase/migrations/0020_admin_actions.sql:32`. Only the UI was missing.

**Cost, and the risk taken on.** A cascade delete of a vehicle removes every
fill-up, service, cost, reading, trip, attachment and rule under it, and nothing
in the app can bring them back. Three things hold it: the action sits in an
overflow menu rather than in the app bar, the confirmation names what
goes and offers archiving instead, and the admin-only rule is now proved by
`test_rls/rls_test.dart` rather than assumed — which matters far more now that
a button offers it to whoever is looking.

---

## 41. A cost-born reminder is settled by paying, not by servicing

**August 2026.** Logging a cost in a recurring category now completes the
outstanding one-off rule for that category before scheduling the next one, and
a due reminder offers **Log it as done** — which opens the *cost* sheet when
the reminder came from a cost, and the service sheet when it did not.

**The shape of the mistake.** Registration, insurance and vignettes are
obligations that return, so they raise reminders — and reminders live in the
service namespace, because that is the only thing the projection engine reads.
That was a reasonable reuse of a mechanism. What was not reasonable is what it
implied at the other end: `completeOneTimeRules` was called only by the service
sheet, so the way to clear "Vignette expires" was to record having *serviced* a
vignette. Nobody services a vignette. You buy the next one.

**Why not give these their own kind.** A parallel "obligation" type beside
reminders would need its own projection, its own screen, its own calendar
entry and its own notification path, to model something that behaves exactly
like a dated one-off. The namespace was never the problem; the missing half of
the loop was.

**Cost.** `service_vignette` remains a service type key that is not a service,
which will read oddly to the next person in `recurring_costs.dart`.
`RecurringCosts.categoryFor` is the answer to "which of these are not really
services", and it is the only place that knows — so a fourth recurring cost
added without touching it will silently go back to asking people to service
their insurance policy.

---

## 42. Renaming a garage is an admin's; the other settings are not

**August 2026.** `households_update` stays open to every member. A trigger
refuses a change to `name` from anyone who is not an admin
(`supabase/migrations/0036_admin_renames_garage.sql`).

**Why not simply gate the screen.** A check in the app is a convenience; the
policy is the boundary, and the app has been consistent about that everywhere
else. A rename control shown only to admins, over a table any member can
update, would be the first place that stopped being true.

**Why not make the whole row admin-only**, which would have been one line. The
same write carries currency, distance and volume units, bundling windows,
tracking level and country — preferences a member legitimately sets today.
Closing the table would have quietly taken those away to solve a different
problem. Postgres cannot express "this column, only for admins *of this row*"
as a grant, so the narrower rule has to be a trigger.

**Why the name is different from the units at all.** Units are a display
preference. The name is what every member sees at the top of the app and what
appears on every invite; one member renaming the shared garage out from under
the others is a different kind of act. That line is a judgement, and it is the
one worth arguing with if it turns out wrong.

**Cost.** A trigger is a rule that lives where nobody looks. It raises `42501`
so the app's existing failure mapping turns it into a sentence rather than a
raw error, and `test_rls/rls_test.dart` proves all three halves — an admin can,
a member cannot, and a member can still change the units.

---

## 43. The fifth tab is "More", and Settings is one row inside it

**August 2026.** The bottom bar holds five destinations and Material allows no
more. Four features — Statistics, the trip log, fuel stations, the calculator —
plus the garage's own screen had to live outside the tabs, and they lived under
*Settings*. They now live under **More**
(`lib/features/settings/screens/more_screen.dart`), with Settings as one row in
it and imports, exports and backups moved to `/data`
(`lib/features/settings/screens/data_screen.dart`).

**Why the name mattered more than the contents.** Nobody looks under Settings for
the people they share a car with. For an app whose premise is shared upkeep, the
members screen was the single worst-placed thing in it, and the label was the
reason. The restructure moved almost nothing; it stopped the tab from lying about
what it held.

**Why not a sixth tab**, which would have been the obvious fix. Material caps a
`NavigationBar` at five, and the cap is not arbitrary — six targets across a phone
are too narrow to hit. Spending the fifth on a labelled drawer buys all five
overflow destinations at once.

**Why one list rather than two.** `secondaryDestinations()` feeds both the desktop
rail and the More screen (`lib/core/widgets/secondary_destinations.dart`). The two
had already drifted: the rail's comment said "on a phone these live under
Settings", and only the garage actually did — so on a phone, Statistics, stations
and the calculator were reachable only through unlabelled dashboard icons, and the
trip log only through a timeline row for a trip already logged.

**Cost.** "More" is a weaker word than any of the things inside it, and a menu
named after its own leftovers is a compromise, not a design. It is honest about
being one, which the old label was not. The guard against it silently swallowing
the next feature is `test/features/settings/more_screen_test.dart`, which asserts
every non-tab destination has a labelled entry point.

---

## 44. App-bar actions are icons; labelled controls go in the body

**August 2026.** Statistics carried a vehicle-name dropdown in its app bar
`actions`. At twice the default text size the toolbar overflowed by 46 pixels: a
title, a car's name and an icon in a fixed-width row that cannot wrap. The picker
moved into the body beside the period bar
(`lib/features/stats/screens/stats_screen.dart:104`).

**Why not shrink the control.** Capping the dropdown's width buys one text scale
and fails at the next; the overflow is structural, not a tuning problem. A
toolbar has no give by construction.

**Why this is a better place anyway.** It is a filter, and it now sits next to the
other filter, which is where someone looking for it would look. It is also outside
the async view, so the thing you are filtering by no longer vanishes while the
numbers reload.

**Cost.** One row of vertical space on every visit, spent whether or not anyone
filters. Two tests hold the line
(`test/features/stats/stats_screen_test.dart`): one that nothing throws at
`TextScaler.linear(2)`, and one that the filter is still on screen at that size —
because passing the first by hiding the control would lose the feature for
precisely the people the test is for. Two other screens still put a `TabBar` in an
app bar (`maintenance_screen.dart`, `vehicle_detail_screen.dart`); tab strips
ellipsize rather than overflow, so they are fine, but neither has a text-scale
test.

---

## 45. A controller that swallows an error must hand it back

**August 2026.** `SettingsController.save` catches its failure into
`AsyncValue.error` so a screen watching the provider can render a banner. That
is right for the settings screen and wrong for every one-shot caller: the
rename flow on the garage screen awaited `save`, then read the state back to
decide what to say. Nothing there *watches* the provider, so Riverpod disposed
the notifier between the two statements and rebuilt it — the read saw a fresh
`AsyncData` and the screen announced "Garage renamed" over a rename Postgres
had refused.

`save` now returns `AppFailure?` as well as setting the state.

**Why not make it throw.** The settings screen depends on the swallow: a save
that throws would have to be wrapped at every call site there, and the error
banner is driven from state anyway. Returning the failure adds an answer
without taking one away.

**Why not keep the provider alive** with a `ref.watch` on the garage screen.
That would fix this call site by giving a screen a subscription it has no use
for, and the next one-shot caller would step on the same rake.

**Cost.** Two ways to learn the same thing, which is a smell. The return value
is authoritative for "how did *this* save go"; the state is for "is there an
error to show". The comment on `save` says which is which, because nothing else
will.

---

## 46. What a row does not say out loud, it marks

**August 2026.** History search matched a row's title, its vehicle, who logged
it and its date — everything except the note. The note is frequently the only
place the distinguishing detail lives: which garage, which part, why this
fill-up was odd. Searching every field except the free-text one finds what a
person is least likely to remember and misses what they wrote down. Notes are
now in the haystack, and a row carrying one says so with a marker; so does a
row carrying an attachment.

**Why markers rather than showing the note.** A timeline is a ledger, and a row
that expands to fit prose stops being scannable. The marker answers the only
question the list needs to answer — *is there more here?* — in the width of an
icon.

**Why one query for attachments.** `entryIdsWithAttachments()` fetches the ids
once for the whole history. A row asking on its own behalf would be a request
per visible row, and the markers are worth an icon, not a request storm.

**Cost.** The set is fetched once and not invalidated when an attachment is
added from an entry sheet, so a marker can be one navigation stale.

---

## 47. Filters fold away; a filter that is on does not

**August 2026.** The six kind filters were a permanent wrapped block above the
history: two or three rows on a phone, three at a large text size, spent on a
filter almost nobody has switched on. They now live behind a badge button in
the search field, and the chips shown are the ones actually *on*.

**Why not a scrolling strip**, which is the usual answer. That is what it was
before the previous fix, and it clipped silently at large text sizes and built
only the chips that fit — so the last filters existed with nothing on screen to
say so. Anything that hides a filter behind a swipe has the same defect.

**Why the sheet, not a menu.** Six labels that are long in both languages get a
full line each instead of competing for the width of a phone.

**Cost.** One tap more to reach a filter, in exchange for two or three rows of
history on every visit. The badge is what keeps it honest: an active filter is
never invisible, which is the failure mode that matters — a list quietly
hiding rows.

---

## 48. The settlement is asked for, not assumed

**August 2026.** `settlementProvider` divides every logged expense equally
between members and reports who owes whom. It is now off unless a garage
switches it on (`supabase/migrations/0037_settlement_opt_in.sql`), including
for households that already exist.

**Why the default was wrong.** The split is right for people who share a car
and keep separate money. For a couple with joint finances it is not merely
useless — it reads as one partner owing the other half of everything, decided
by nothing more than who happened to open the app to log the fill-up. A feature
that makes a claim about somebody's money should be asked for.

**Why a column and not a client preference.** It decides what every member of
the garage sees on a shared screen, so it belongs to the garage, next to the
currency and the bundling window, rather than to whichever phone last changed
it.

**Why any member may set it**, rather than admins only. It changes what the
household screen shows, not who may do what; the units beside it are already
every member's to change, and decision 42 is deliberate that the rename is the
narrow exception rather than the rule.

**Why off for existing households too**, which is a behaviour change under
people who may have been using it. Defaulting the column to true would have
preserved it for the households that wanted it and left it wrong for everyone
who had never thought about it — and the ones who want it will find it in
Settings the first time they look for the figure that vanished. Two lines in
the release notes are cheaper than a wrong claim about money.

**Cost.** A household that was using the settlement loses it silently on
upgrade. `test_rls/rls_test.dart` proves the default and that a member can
switch it on; nothing tells an existing user where it went except the release
notes.

---

## 49. Picked files are decoded here, not by the plugin

**August 2026.** Every text file the app imports goes through
`readTextFile` (`lib/core/files/file_text.dart`) rather than
`XFile.readAsString`.

**Why.** `readAsString` accepts an `encoding`, documents a UTF-8 default, and
silently ignores both when the XFile carries bytes instead of a path — it runs
`String.fromCharCodes`, which is Latin-1. Android's picker returns bytes. The
result was not a crash but wrong text, which is worse: an imported Fuelio
reminder whose name needed a `č` to be recognised matched nothing and was
dropped, and the app blamed the user's file.

**Why not pass an encoding**, which is the obvious fix. The parameter is the
trap — it is accepted and discarded on exactly the path that is broken. Reading
bytes and decoding them here cannot be silently ignored by anything.

**Why `allowMalformed`.** A file in some other encoding should import as much
of itself as it can. The alternative is a whole backup refused over one byte,
which is the failure mode people cannot do anything about.

**Cost.** A workaround in this repo for a defect in a dependency, which is a
thing that gets forgotten and left behind.
`test/core/files/file_text_test.dart` therefore keeps a test asserting that
`readAsString` *is still wrong* — the day it starts passing is the day this can
go.

---

## 50. A suggestion nobody can act on for two years is not a suggestion

**August 2026.** `BundlingEngine.bundle` drops any group whose visit date falls
more than `BundlingEngine.suggestionHorizon` — twelve weeks — from today.

**Why.** The engine grouped every projection the rules implied, over all time.
A car with a three-year oil interval and a five-year plug interval produced a
"combine 4 items into one visit on 27 July 2028" card at the top of the
dashboard, and a second for 2030 on the planner beneath it. Both were correct.
Neither was any help, and each would have stayed there for years, occupying the
one place on the screen reserved for the thing to do next.

**Why twelve weeks**, and not six months or a year. The planner's runway
already draws exactly twelve weeks and calls it "what is coming up". Two
answers to the same question sat on one screen disagreeing about how far ahead
they looked. A test now fails if the two constants drift apart.

**Why the engine and not the providers.** Both the dashboard and the planner
read the same `bundlesProvider`, and a horizon applied in one of them is a
horizon the other quietly lacks. It is also the cheapest thing in the codebase
to test where it now lives.

**Why filter on the visit date rather than per item.** A group anchored inside
the horizon can have members falling a fortnight past it; those members are the
reason to make one trip instead of two, and dropping them would shrink the
suggestion to argue itself out of existence.

**Cost.** A household with a genuinely useful long-range grouping — a service
and a roadworthiness test both a year out, say — is no longer told about it
until the year is nearly up. That is the trade being made deliberately: the
suggestion is worth less than the space it occupies until it is actionable. The
items themselves never disappeared; they are on the vehicle's Service tab with
their real dates the whole time.

---

## 51. The driving rate is taken from recent driving, not from a car's whole life

**August 2026.** `OdometerHistory.kmPerDay` measures the last 90 days of the
odometer series and only falls back to the whole series when that window holds
fewer than two readings or spans under 21 days.

**Why.** It divided total distance by total age. That is a defensible number
and the wrong one: it answers "how much has this car been driven", while the
projection asks "at the rate it is being driven now, when does it reach 77,006
km". For a car imported with years of history the two diverge badly, and the
divergence is one-directional — a lifetime average is always behind a driver
who has started driving more, so every distance-based date comes out late.

**The report that surfaced it.** A Clio showed an oil change due 27 July 2028
with 28,977 km still to run. That date is exactly 24 months after the previous
service, so it was the *calendar* deadline: the lifetime rate put the odometer
deadline even later, and `_earliest` therefore picked the calendar. At the car's
measured recent rate — its last eight fill-ups ran 4,276 km in 63 days, or **68
km/day** — it reaches 77,006 km around 19 September 2027, ten months sooner. So
the lifetime rate did not merely push a date out; it hid which deadline was
binding at all.

(An earlier draft of this entry said the 2028 date back-solved to 41 km/day.
That was an inference from the date alone, and the anniversary match makes the
calendar branch the far likelier source. The fix and its justification stand;
the mechanism above is the corrected one.)

**Why 90 days.** Long enough that one holiday does not double the figure, short
enough to follow a car that changed hands, changed commute, or came off the
road. It also matches `_approachDays`, the horizon a dateless one-off ramps up
over, so the file has one meaning for "recent".

**Why a 21-day floor on the window.** Two fills a week apart on a road trip are
a real measurement of a week nobody repeats. Without the floor they would set
the rate for the whole car and treble every projection on it.

**Why anchored to the last reading, not to today.** It keeps the function pure
— no clock parameter into the domain — and a car parked for a season reports
the rate it was last driven at rather than nothing. That matches what the
projection already assumes: `currentOdometerKm` is also a last-known figure,
not a live one.

**Why the whole series is still the fallback** rather than the assumed 30
km/day. A car logged twice a year has no usable window, and a car added last
week has nothing but the fortnight it has. Both are better served by their own
thin history than by a constant.

**Cost.** Due dates are livelier than they were: ninety days of unusual driving
now moves every distance-based date on the car, where the lifetime average
absorbed it. Projections were already recomputed on every fill-up, so this
changes the size of the movement, not whether there is any. The older
`ReminderProjector.kmPerDay` still exists with no window and no production
caller — a trap recorded in `04-maintenance-projection.md`, not yet removed.

---

## 52. A rule with two deadlines says both

**August 2026.** `ReminderProjection` keeps `dateFromDistance` and
`dateFromTime` alongside `projectedDueDate`, and the maintenance row prints the
one that did not bind.

**Why.** `ReminderProjector.project` computed both and threw one away. "Every
30,000 km or 24 months" is two deadlines, and which one binds is the whole
question a driver plans around — the odometer history exists precisely to
answer it. A single collapsed date could not say "the calendar says July 2028,
but you will be at 77,006 km by autumn 2027", which is the prediction the data
already supported. Decision 51 is the same failure seen from the other side:
when the rate was wrong, nothing on the row could reveal it.

**Why `projectedDueDate` still holds only the earliest.** Bundling, the runway,
the state chip and notifications all key off it and all want one date. Adding a
second date to the row is a display change; making the rest of the app reason
about two would be a different and much larger one.

**Why only when the two differ.** Most rules carry one interval, and two
deadlines landing on the same day are one deadline. The line appears on the
rows that have something to say and nowhere else.

**Why the rate is on screen with it.** The extrapolated date is a claim about
the future, and the sharp-edges list has carried "the fallback rate is
invisible in the UI" since these docs were written. A row that says autumn 2027
should say what it worked that out from, and a car running on the assumed 30
km/day should say that instead.

**Cost.** The app now makes a visible sixteen-month prediction from a
ninety-day sample. The hedges are the wording ("not until", a plain date rather
than a range) and the rate line under it, but a driver who reads the estimate
as a promise will occasionally be wrong by weeks. The alternative — knowing
which deadline binds and declining to say — was worse.


---

## 53. After an await, reach for the container, not `ref`

**August 2026.** Where a `ConsumerState` method has to touch a provider after
an `await`, it captures `ProviderScope.containerOf(context, listen: false)`
before the first await and reads through that.

**Why.** `ConsumerState.ref` is a view onto the widget's element, and the
element dies with the widget. Three crashes in the field came from this
(`known-bugs-and-risks.md`), and the sign-in one shows why `mounted` is not
automatically the answer: *success* is what removes the auth screen, so the
work after the await is exactly the work that matters, and returning early on
`!mounted` would silently drop it. The container is scope-lived, so it answers
the real question — "does the app still have these providers?" — rather than
"is this particular widget still on screen?", which is a different question the
code was accidentally asking.

**When `mounted` is still right.** When the only thing after the await is
`setState`, or work whose sole purpose is to update this screen. A prefill that
lands on a screen the user left is wasted, not wrong; a sign-in that finishes
after the redirect is neither.

**The trade-off.** A captured container will keep working against a scope the
widget no longer belongs to, so it is genuinely less safe as a default — it
cannot warn about a stale read the way `ref` does. It is used where the
side-effect must outlive the widget, not everywhere.

---

## 54. Statutory tyre dates, but only for countries actually checked

**August 2026.** `service_tire_swap_seasonal` is projected onto the country's
winter-tyre window rather than a six-month interval, keyed on
`Household.countryCode`. Six countries have a verified entry; every other
country keeps the interval.

**Why.** The six-month interval anchors on whenever the last swap was logged,
so it drifts: a swap done in late June puts the next one on 20 December, a date
nothing in the world happens on. The window is national and fixed — the same
kind of fact as the registration and inspection cycles the schema already
carries per country.

**Why not all of Europe.** Because the honest answer differs by country and
several do not fit a two-fixed-dates model at all. Germany's obligation is
purely conditional (§2(3a) StVO, no dates); Italy's is set per road by
ordinance; Austria's and Serbia's have dates but bind only on a wintry road.
The app already refuses to offer another country's statutory service types for
exactly this reason: a plausible date for a country nobody verified looks
authoritative and is wrong. So the table is six entries long and the UI says
which of the three kinds of rule the household is under.

**Why the copy avoids "required by law".** Croatia's window binds on winter
road *sections* rather than every road, and summer tyres with 4 mm of tread
plus chains satisfy it. "Winter tyres 15 Nov – 15 Apr" is true; the stronger
claim would not be, and a maintenance app is a bad place to be wrong about a
fine.

**Cost.** The table exists twice — Dart for the app, TypeScript for the push
sender — because Deno cannot import Dart. That is a real duplication and it is
guarded rather than removed: `test/ci/winter_tyre_twin_test.dart` fails if the
two drift. Adding a country now means three edits and a hand deploy of the edge
function.

---

## 55. A predicted date says "Expected"; a deadline says "Due"

**August 2026.** The maintenance row words a distance-derived date differently
from a calendar one — *Expected 12 Jun 2027* against *Due 1 Jan 2028*.

**Why.** They are different kinds of claim and the row stated both identically.
A distance date is remaining kilometres over a measured driving rate: it moves
every time somebody logs a reading, and after decision 51 it moves *more*,
because the rate now follows recent driving instead of the car's whole life. A
registration expiring on 1 January does not move at all. Presenting the first
as the second is the app being more confident than its own arithmetic.

**Why a word and not a symbol.** A tilde or `≈` is shorter and language-neutral,
and nothing on the row would say what it means. The row already carries four
lines; a word that reads as a word costs nothing to learn.

**Why not when both deadlines land on the same day.** Nothing is gained by
hedging a date the calendar also guarantees.

**What it does not fix.** The row says the date is a prediction; it does not say
how good one. The measured rate and its window are still a footnote under the
whole list rather than something per-row, so a car with three weeks of history
and a car with three years look equally confident.

---

## 56. Exports are saved to the device; sharing sits beside them

**August 2026.** Tapping an export writes the file wherever the user points a
save dialog. Sharing stays available as a second, explicit action.

**Why.** "Get my data out" is about *having a file*. Every export went straight
to the share sheet, which made keeping one a detour through whichever app
happened to accept it — and renamed the file on the way, since `XFile.fromData`
discards its `name` off the web and share_plus falls back to a UUID.

**Why a second package.** `file_selector` is already here for *opening* files,
and cannot do this: `file_selector_android` implements exactly `openFile`,
`openFiles` and `getDirectoryPath`, so `getSaveLocation` falls through to the
platform interface's `UnimplementedError` on the one mobile platform this app
ships to. `file_picker`'s `saveFile` works on **Android** (SAF
`ACTION_CREATE_DOCUMENT`) and on the **web** (a download), which is both of
the app's targets.

**The cost, stated plainly.** Two file-picking packages in one app is worse
than one: two native pickers, two sets of platform quirks, and a next
developer with no way to guess which to reach for. This is not the end state.
The opening side should move to `file_picker` too — three call sites, each
carrying hard-won MIME-type workarounds for Android's picker, which is why it
is a change of its own rather than something done quietly alongside a feature.
`file_picker` 12 is also days old and a federated rewrite; if it misbehaves,
the seam in `lib/core/files/file_saver.dart` is the only thing that has to
change.

**Why cancelling does nothing.** Backing out of the save dialog used to fall
through to a share sheet in an early draft of this. That is the app arguing
with a decision the user just made. A report is cheap to rebuild and the
button is still there.

**Known gap.** Vehicle reports now save and have no share action at all, while
the two exports kept one. That is an inconsistency, not a decision — it is
here so it is not mistaken for one.

---

## 57. The mileage chart draws one line, not six colours

**August 2026.** `OdometerChart` draws every reading in one colour and has no
legend. It used to colour each point by which table the reading came from —
fuel, service, cost, odometer, trip, income — with a six-item key underneath.

**Why it was built that way.** Never a recorded decision — the reasoning lived
only in the widget's doc comment, which is part of why it survived unexamined:
a household
seeing only fuel-coloured points learns that its maintenance projection rests
entirely on remembering to log fill-ups. That is a real thing to know, and it
is the kind of thing this app tries to make visible rather than assume.

**Why it is being reversed.** It did not pay for itself in use. Nobody asks
"which table did this come from" while looking at a mileage curve — they ask
"how much have I driven". Six colours at a 3-pixel dot radius are not
distinguishable anyway, and the key occupied more of the card than the chart
did. The good intention produced a worse chart.

**What the reversal costs.** Data-source coverage is now invisible. If it is
worth surfacing it belongs somewhere it can be said in a sentence — "your
mileage comes almost entirely from fill-ups" — not encoded in dot colours that
need a six-item key to decode. Nothing says it today, and that is a gap, not a
solved problem.

**Fixed alongside.** The y-axis interval was left to the chart library, which
put its lowest label a hair below the first gridline and printed "19k" on top
of "20k". Bounds and step are set explicitly now.

**Removed alongside.** `ChartLegendDot` was orphaned by this and deleted. Its
doc claimed it was shared by every chart on the screen; it never was —
`monthly_spend_bars.dart` has always had its own private `_LegendDot`.


---

## 58. A shortcut widget, not a data widget

**August 2026.** The Android launcher gets two entry points for logging a
fill-up: a long-press shortcut on the app icon
(`android/app/src/main/res/xml/shortcuts.xml`) and a 1x1 home-screen widget
(`android/app/src/main/kotlin/cc/hrva/garage/LogFuelWidget.kt`). Both are
`ACTION_VIEW` intents naming this app's activity, carrying one URL that
resolves to `/log/fuel` and, through `QuickFuelScreen`, to the fuel sheet.

**Why the widget shows a label and nothing else.** The obvious widget for this
app displays something: the odometer, the last fill's economy, what is due next.
It cannot. A widget is inflated by the launcher's process as `RemoteViews`,
where there is no Flutter engine, no Riverpod container, no signed-in session
and no household — so every figure on it would have to be written somewhere
native code can read, by the app, on a schedule the app does not control. That
is a second copy of the data with its own staleness, its own refresh failures,
and its own answer to "which household am I looking at". The widget would show
yesterday's number, or a blank tile, precisely when the app had not been opened
— which is the situation a widget exists for.

So the widget is a button. It is exactly as useful as the shortcut and costs
one layout, one drawable and forty lines of Kotlin, none of which can go stale.
`test/ci/launcher_entry_points_test.dart` asserts it never learns to write into
its own layout, because the day it does is the day all of the above becomes
true quietly.

**Why the intents are explicit rather than app links.** `/join` and
`/auth/confirm` are `autoVerify` web paths because they are followed from
somebody else's mail client. These are not: they are tapped on a phone the app
is installed on. Naming `cc.hrva.garage.MainActivity` directly means the tap
cannot be taken by a browser, `/log` never has to be a claimed web path, and a
device where link verification failed still gets a working shortcut.

**Why it asks which car.** With more than one vehicle the route shows the
dashboard's own vehicle picker instead of guessing. The fuel sheet does not
name the vehicle it is writing to, so a guess is not one the driver can catch
in the moment — they would find it weeks later in the timeline, as a fill-up on
the wrong car with an odometer reading that corrupts that car's economy.
One tap is cheaper than that. A remembered "last car fuelled" would remove the
tap, and was left out: it means a new persisted preference and a write on the
sheet's save path, for a saving of one tap in a flow that is already three taps
shorter than it was.

**Why the empty cases all fall back to `/`.** Signed out, no household, no
vehicle, or a garage that failed to load — the answer to each is the app's
ordinary start-up destination. The first two are `garageRedirect`'s job and
need no code here at all; the last two land on the dashboard, whose empty state
is the screen that explains how to add a car and whose error state already
knows how to retry. Nothing opens a sheet with no vehicle behind it, and
nothing throws: a shortcut is tapped by people who have not opened the app in a
month, and a crash on the way in is the whole app as far as they can tell.

**Why `flutter_deeplinking_enabled` is now stated in the manifest.** It was
absent, and the engine's default made it work. That is a bad thing to depend on
silently: when the flag is off, nothing errors — the activity starts, the URL
is dropped, and the app opens on the dashboard, which is indistinguishable from
a normal launch. Every link into this app rides on it, so it is written down.

**Cost.** Native surface in a project that had almost none: a Kotlin file, four
resource files and two string files that the ARB consistency test cannot see,
so Croatian on the home screen is guarded only by
`test/ci/launcher_entry_points_test.dart`. None of it can be exercised by
`flutter test` — the widget rendering, the launcher accepting the shortcut, and
the cold-start intent all need a device. The Dart half (route resolution, the
vehicle rule, every fallback) is covered; the native half is checked by reading
the files and by the APK compiling.

---

## 59. Economy by station is an observation, and usually says nothing

**August 2026.** Fuel economy is grouped by where the fuel was bought, and the
section is hidden unless two stations each have at least three attributable
tanks and differ by at least five per cent.

**Why gate it so hard.** This is the statistic most likely to teach somebody
something false about their own car. Fuel brand is a small effect. Route, load,
season, traffic and tyre pressure are large ones, and they correlate with where
people fill up — a driver who tanks at the motorway station on long trips and
in town the rest of the time will measure a difference that is entirely about
the driving. A confident-looking number would be believed, acted on, and wrong.

**Why hide rather than caveat.** A card reading "INA 6.1, Shell 6.2 — not a
meaningful difference" invites exactly the comparison the sentence is refusing
to make. Silence is the only honest rendering of "we cannot tell".

**Why attribution needed a change to `EconomyPoint`.** The obvious
implementation — group points by the station on their own entry — is right for
the common case and quietly wrong when a partial fill inside a span came from
elsewhere. Rather than approximate, `_computeChain` now tracks the set of
stations that contributed volume to a span and records one only when there is
exactly one. Spans with mixed or unnamed fuel are dropped rather than credited.

**What it still cannot do.** Nothing here controls for anything. Three tanks is
not significance and the code says so in as many words; it is the point below
which a single unusual tank *is* the average.

**Cost.** `EconomyPoint` grew a field that only one feature reads, and the
chain walk grew two more accumulators. Cheap, but it is core code touched for a
peripheral statistic — worth remembering if the chain logic ever gets harder.

---

## 60. Automatic backups run on foreground, into a folder the user picks

**August 2026.** With a folder chosen, opening the app writes a backup into it
if the last one is more than a day old. Off until asked.

**Why not a background task.** Android's background execution is a negotiation
this app would lose — Doze, per-manufacturer battery killers, and a
`WorkManager` job that may or may not fire. A backup running at an
unpredictable time is harder to trust than one that runs when you open the app,
which is at least a moment the user can reason about. Nobody who opens their
car app less than once a day is relying on a same-day backup.

**Why the user picks the folder.** The point is a file a sync tool
(Syncthing, Nextcloud) can pick up offline. The app's own external files
directory would need no permission at all, and is deleted on uninstall — which
makes it exactly the wrong place for the thing you want when the phone is gone.

**Why one file per day, overwritten.** The app can be opened many times a day.
`AutoBackupSchedule.fileNameFor` (`lib/domain/export/auto_backup_schedule.dart:51`)
returns the same name all day, and the write passes `overwrite: true` because
SAF's default on a collision is to invent `garage-backup-2026-08-22 (1).json`.
Yesterday's file is still there; today's is the newest.

**Why failures are loud.** A backup feature that quietly stops is worse than
none: the user finds out at the moment they needed it. A revoked folder grant
is checked for explicitly and a failed write is reported through
`reportFailure`, so it reaches the Diagnostics screen and `garage.failure`.
The success timestamp is written **only** on success, so a transient failure is
retried on the next foreground rather than waiting a day to fail identically.

**Which SAF package, and a reversal inside one session.** `saf` was added
first — one package, MIT, 160/160 pub points, a clean API. That was the wrong
call and was challenged immediately. Two numbers decide it:

| | `saf` | `saf_util` + `saf_stream` |
|---|---|---|
| Weekly downloads | 1.68k | 16k + 26.9k |
| Built-in Kotlin | legacy KGP config | both Kotlin-ready |

Download count is the field-exposure proxy that matters most for code owning
somebody's backups, and "it is a single package" is a weak counterweight to a
tenfold difference. The Kotlin row is the decisive one: `saf` still applies its
own Kotlin Gradle Plugin, which pub's own analysis flags, and that is a Gradle
conflict waiting for the next Android toolchain bump — in a project that has
its own Kotlin. `saf_stream`'s 145/160 is a short pubspec description and a
stale CHANGELOG heading, not a quality signal.

**What the swap cost:** one file at the time — `backup_folder.dart`, with no
test touched, which is what the seam was for. It cost two more later:
`saf_stream` depends on `jni`, which imports `dart:ffi`, which dart2js cannot
compile, and that broke the **web** build while analyze and the whole test
suite stayed green. A runtime `kIsWeb` guard does not help — the import itself
is the problem — so the seam is now a conditional import over
`backup_folder_io.dart` and `backup_folder_web.dart`. `saf`, the package that
was swapped out, has no such dependency and would not have hit this; that does
not reverse the decision, but it is the cost of it and belongs here. The loud-failure rule
above still stands — a thinly-used dependency was never the only reason for it.

**Sharpened by the swap.** `SafUtil.hasPersistedPermission` defaults to
checking *read* only. A read-only grant would have passed the check and then
failed at the write, which is exactly the silent-stop failure this feature
exists to avoid, so the call passes `checkWrite: true` explicitly.

**Android only.** A web page cannot hold write access to a directory across
sessions, so the row does not appear there rather than appearing and failing.

---

## 61. A vignette does not default to "remind me"; registration and insurance still do

**August 2026.** The "remind me again" switch on a cost entry starts on for
registration, insurance and comprehensive cover, and starts **off** for a
vignette. Category is a decision, not a fixed default: switching it re-applies
the right default rather than carrying whatever the switch happened to be set
to.

**Why.** Registration and insurance recur for every car, every year, near
certainly — forgetting one is the thing worth nagging about. A vignette recurs
only if the same trip does, and the common case is a single crossing: buy it
once, use it once, never again. A household that bought a seven-day Slovenian
vignette for one holiday, with the switch defaulting on the way every other
category's did, got told a year later that a payment was late for a trip that
was long over — reported from the field, and the report is what this fixes.

**Why the field data mattered here.** This was not a design review catching a
bad default in the abstract; it was a real household reading "payment is late"
about a road they were not on. The two other bugs found alongside it —
`vignette_country`/`vignette_validity` never being persisted, and no way to
retract a reminder already scheduled — came from tracing that one report back
to its cause, not from auditing the feature independently.

**Retraction, not just a better default.** A household with an *existing*
stale reminder from before this fix needed a way to clear it, and turning the
switch off on a fresh entry cannot do that on its own — the entry it applies to
does not exist yet. `_scheduleRecurringReminder` now calls
`completeOneTimeRules` **unconditionally** whenever the category has a next-due
date, whether or not the switch is on, and only *adds* a new rule when it is.
Re-opening the stale vignette entry and saving it — switch left at its new,
correct default of off — retracts the reminder that was nagging. This is also
why the fields had to be persisted first: retraction needs the validity to
compute which service-type key to clear, and before this change that value was
never there to restore.

---

## 62. One month-grouping widget, not four house styles

**August 2026.** Timeline's month headers — grouped-by-calendar-month, an
eyebrow-styled label above each run — moved out into `MonthGrouping`
(`lib/domain/format/month_grouping.dart`, pure, tested) and `MonthHeader`
(`lib/core/widgets/month_header.dart`), and Fuel, the vehicle's History tab and
its Costs tab now use both. Timeline itself was refactored onto the shared
pair rather than left as a fifth, slightly different implementation.

**Why extract rather than duplicate.** A household reading their Fuel log
already knows what a month header looks like from Timeline; a second,
almost-but-not-quite-identical implementation would be a second thing to keep
visually in sync by hand, and the first place they would drift is exactly the
kind of change nobody remembers to make twice — a padding tweak, an eyebrow
style update. One widget cannot drift from itself.

**Why grouping does not sort.** `MonthGrouping.of` buckets consecutive runs in
whatever order it is given; it does not re-sort the input. Every caller already
has an order it wants (newest first, in every case so far) and imposing a sort
here would silently override that — quietly wrong for a caller that reasonably
expects its own ordering to survive. An input that revisits the same month
non-adjacently produces two groups for that month, which is the honest
rendering of what the caller's own order says happened, not a bug to paper
over with a sort the function was never asked to do.

**Cost.** Fuel, History and Costs all moved from `ListView.separated` (lazy,
virtualized) to `ListView(children: …)` (eager, builds every row up front) to
interleave headers with rows — the same trade-off Timeline has made across
several feature releases already. A years-long fuel log is the one list here
actually large enough for this to matter; nothing so far has reported it as a
problem.

---

## 63. The automatic backup says so, once, the day it actually runs

**August 2026.** Writing an automatic backup shows a "Backed up
automatically" toast — but only on the foreground that actually wrote one, via
`runAutoBackupIfDue`'s return value, never on a foreground where nothing was
due.

**Why the return value and not a side-channel.** The alternative was watching
`autoBackupLastRunProvider` for a change and toasting on that, which would
also fire from a *second device* writing a backup and this one merely
re-reading the timestamp — the household did not do anything on this phone,
and telling them otherwise would be reporting somebody else's action as their
own. A plain `true`/`false` from the call this device actually made has no
such ambiguity.

**Why the messenger is captured before the await, not `context` after it.**
This is the same rule as decision 53, applied to a new case: `context` belongs
to whichever widget is on screen when it is read, and a backup can take long
enough to write that the dashboard is gone by the time it finishes.
`ScaffoldMessengerState` is captured synchronously, before `runAutoBackupIfDue`
is even called, and outlives the widget that captured it.

**Found alongside, unrelated to the toast:** the manual "Back up everything"
row's save confirmation read "Backup shared" — wording written for the share
button, left in place after decision 56 split saving from sharing. Nothing was
shared; it was saved. Fixed to "Backup saved", with a test asserting the two
messages are not each other's.

---

## 64. Feedback is a mailto:, addressed to the support email already on file

**August 2026.** The About screen's "Send feedback" row opens a `mailto:`
draft to `garage@hrva.cc`, subject and a version line pre-filled, with any
recent recorded failures riding along in the body.

**Why that address and not a new one.** It is already the Play listing's
declared support contact (`docs/play-store-listing.md`) and `PRIVACY.md`'s
own contact address. Standing up a second inbox (`feedback@`) would be a
second thing to check, and a driver mailing in a bug report reaches the
address the store already told them to expect.

**Why `mailto:` and not a form.** This app has no backend that takes
arbitrary user text, and building one — an endpoint, spam handling, a place
for replies to land — is a disproportionate amount of infrastructure for
"let someone say something to the developer." The device's own mail app
already does authentication, threading and replies for free.

**Why recent failures ride along, visible, not sent separately.** The same
reasoning as the Diagnostics report `_report()` builds
(`lib/features/settings/screens/diagnostics_screen.dart:114`): a bug report
with no version and no error is a report nobody can act on three releases
later. Composed into the draft the user sees before it sends, never
collected anywhere on its own — this app's stance throughout is that nothing
leaves the device the user did not choose to send.

**The one platform requirement it needed.** `url_launcher` resolving a
`mailto:` link on Android 11+ needs a `<queries>` declaration
(`android/app/src/main/AndroidManifest.xml`) or package-visibility
restrictions make the mail app invisible to the resolution query even though
it is installed — the link would silently do nothing on a real device while
working fine in an emulator with looser visibility. Easy to miss because
nothing local catches it; the same shape of gap `flutter build web` exists to
close for the conditional-import bug in decision 60's follow-up.

## 65. The dashboard leads with what happened, not with what is due

**Decision.** The Due soonest list sits above Recent activity only when at
least one projection is `ReminderState.due` or `ReminderState.overdue`.
Otherwise recent activity comes first and Due soonest follows it
(`lib/features/dashboard/screens/dashboard_screen.dart`).

**Why.** A garage in good order has nothing pressing, which is the normal
case, not the exception — a registration eleven months out and an oil change
fourteen months out are both real, both dated, and neither is news. Leading
with them put five rows nobody can act on above the fold and pushed the
fill-up logged yesterday off the bottom of the screen. The dashboard was
answering "what will eventually happen" when the question a household opens
it with is "what did we just do".

**Why `state` and not the gauge fraction.** `dueness()` is a display
proportion and deliberately ramps a dateless one-off over a 90-day approach
(`lib/domain/maintenance/reminder_projection.dart:88`), so thresholding it
would invent a second, disagreeing definition of "urgent" next to the one
the projector already publishes. `ReminderState` is that definition:
`overdue` is past, `due` is inside the notice window, `upcoming` is
everything else. The screenshot that prompted this showed 27% / 26% / 15% /
5% — all `upcoming`, none actionable.

**What it costs.** `AdaptiveColumns` alternates its children between two
columns on a desktop window, so the swap also moves which side each section
lands on. That is the layout doing what it says it does rather than a
regression, but it means the desktop arrangement is not stable across the
urgency flip. Left as is: a household with something overdue should see the
arrangement change.

## 66. A reading dated in the future is ignored, and the guard is in the domain

**Decision.** `OdometerHistory.sorted` takes an optional `asOf` and drops any
sample dated after that calendar day. `odometerSamplesProvider` supplies
`todayProvider`. The date pickers on the entry sheets are unchanged: they still
accept any date up to 2100.

**Why not cap the pickers, which was the obvious fix.** Because the sheet is
not the only door. `parseFuelioBackup` resolves a date with `DateTime.tryParse`
and no upper bound (`lib/domain/import/fuelio_backup.dart:428`), the CSV
importer does not validate one either, and a restored backup bypasses the UI
entirely. A cap on the picker would have protected none of those paths while
looking like it had solved the problem — the worst outcome available.

**Why it does real damage.** `_window` anchors the rate to the series' own last
reading, so one future sample opens the 90-day window in the future and leaves
the real driving outside it; the rate falls back to the whole series and reads
far too low, pushing every distance-based date out. Meanwhile `currentKm` takes
the highest reading whatever its date, so the current odometer jumps forward.
Opposite directions, both wrong, and nothing on screen to explain either.

**Dropped, not clamped.** The true date is unknowable — a year typo could be
any year — and clamping to today would invent a reading on a day the car may
not have been driven. Ignoring it leaves the series honest and smaller.

**The timezone detail that had to be right.** `todayProvider` is a local
`DateTime.now()` and sample dates are UTC date-only. Both sides are reduced to
their calendar date and rebuilt as UTC before comparing, the same transform
`DateRange._day` uses, so a household east of UTC logging its own today is not
quietly ignored. `asOf` is optional and null means no filtering, which keeps
`sorted` pure for callers with no clock.

**What it cost.** `todayProvider` had to move from
`maintenance_providers.dart` to `lib/core/clock.dart`: the odometer providers
now need it, and the maintenance library already imports them, so leaving it in
place would have made an import cycle. `maintenance_providers.dart` re-exports
it, so the fourteen files importing it from there are untouched. The clock is a
platform seam and belongs in `core/` anyway, next to the url opener and the
file picker.

**Left alone.** `rawOdometerSamplesProvider` stays unfiltered: the fill-up
sheet's odometer bounds check exists to catch a reading that contradicts the
log, and the contradiction is precisely what this filter removes.

## 67. Tyre age is asked for, estimated when it cannot be, and never nags

**Decision.** `tyre_sets` gains `manufactured_on`, filled from the DOT code on
the sidewall. The tyres screen shows a passive line — muted from six years,
danger-coloured from ten — and nothing else: no reminder, no push, no entry on
the due list.

**Why a stored date rather than the code.** The four digits (`3419` = week 34
of 2019) are an input format. A date sorts, subtracts and serialises like every
other date in the schema, and the week is recoverable from it — so the code is
parsed at the edge and kept canonical in storage, the rule the units already
follow. `TyreDotCode.format` is the inverse, because a field showing the code
back can be checked against the tyre and a field showing a date cannot.

**Why it falls back to the fitted date, and says so.** Most sets already in the
app will never have a DOT code read into them. Falling back to `fitted_at`
keeps the check useful for them, but it errs *low* — a set fitted in 2020 may
have been made in 2016, four years of shelf life the app cannot see — so it is
marked as an estimate. Same distinction as the assumed driving rate and the
tyre-wear date: a measurement and an assumption must not be rendered as one
sentence.

**Why passive.** The wear estimate is deliberately passive because tread has no
deadline. Age arguably does, but a threshold that is often an estimate should
not be driving a notification. If the note turns out to want teeth it can grow
them; the reverse is harder.

**Why six and ten.** Manufacturers converge on ten years as replace-regardless,
and about six as inspect-annually; several European winter-tyre recommendations
treat six as the practical limit. Both boundaries are pinned by test, because
an off-by-one here is a warning that arrives a year late.

**The edit sheet came first, and had to.** A DOT field only in the add sheet
would have been inert for every set that already exists, since a tyre set was
the one thing in the app that could not be edited (see the operations note). So
the edit was built first as its own change, and the field went into the shared
form.

**The ISO week trap.** Week 1 is the week containing 4 January, so its Monday
can fall in the previous December — week 1 of 2026 begins on 29 December 2025.
Both halves of the printed code therefore come from the week's Thursday, not
from the date; taking the year off the date prints the previous one and the
code stops matching the sidewall. Caught by a round-trip test over every week
of a year, having first got it wrong.


## Amount fields do arithmetic (August 2026)

**What.** Money fields accept `2*1.50` as well as `1.50`, evaluated by a small
pure function in the domain layer and offered through an operator row under the
field. Applied to the cost amount, fuel unit price and total, service, parts and
labour cost, income, and the vehicle purchase price — not to odometer readings,
years, or tread depths.

**Why an operator row rather than a text keyboard.** The fields ask for
`TextInputType.numberWithOptions(decimal: true)`, whose Android keypad has no
`*` or `/`, so the feature would have been unreachable as typed input. Switching
those fields to a full text keyboard would have made every ordinary amount —
which is the overwhelming majority — slower to enter, to serve the occasional
sum. The row keeps the number pad and adds four buttons that insert at the
cursor.

**Why no parentheses.** `*` and `/` binding tighter than `+` and `-` covers what
anyone types into a receipt. Brackets would buy a grammar, an unbalanced-input
error class, and a wider result line, for a case nobody has.

**Why a comma can never be a separator.** Croatian writes 12,50. An evaluator
that treated the comma as an argument or list separator would read `2*1,50` as
something other than three euros for exactly the users the app is written for.
The comma normalises to a decimal point and nothing else does.

**Why the result line is silent for a plain number.** Echoing `= €12.50` under a
field reading `12.50` is noise on every entry in the app to serve the few that
are sums. It appears only once the text contains an operator, and goes quiet
again while the sum is half-typed, because a total that is briefly wrong is
worse than no total.

**What it does not do.** The evaluated number is what gets stored; the
expression is not persisted, because the column is numeric. Reopening a parking
entry entered as `2*1.50` shows `3.00`, so extending it a third time means
typing `3+1.50`. That is a running total, not a record of how many hours were
bought. Recording the hour count would be a different feature.

## A fill-up starts from today's price, not the one you last paid (August 2026)

**What.** Opening a new fill-up looks the last-used station up in the MINGOR
dataset and offers *today's* posted price for that car's fuel, falling back to
the previous fill-up's price when the lookup finds nothing.

**Why.** The pump match already offered a live price, but only within 200 m of a
forecourt. Most fill-ups are logged later, sitting at home, where that never
fires — and the fallback was the price of the last fill-up, which could be weeks
old. The app was holding today's number for every station in the country and not
using it, purely because the phone was in the wrong place.

**Why the name, and not the position.** No permission is needed to match on the
station name the previous fill-up already recorded, and the sheet has that name
before it has anything else. It is weaker evidence than standing somewhere, so
the pump match still wins where both apply.

**Why it refuses on a duplicate name.** Chains repeat a name across forecourts
that charge differently. Two matches with two prices is not an answer, and a
wrong number in an amount field is worse than an empty one.

**Why new entries only.** An edit shows the price that was actually paid.
Quietly moving a recorded amount to today's would be a data-loss bug wearing a
convenience's clothes; the guard is that `initState` runs no prefill when
`existing != null`, and there is a test named for it.


## The timeline says what it adds up to (August 2026)

**What.** Each month header in the timeline carries that month's net figure, and
the list closes with "N transactions, spent X" over everything currently shown.

**Why net rather than spend.** The app already tracks income, a taxi being the
motivating case, and a screen that listed a €180 fare and then headed the month
with a spend figure ignoring it would be showing two different truths a
centimetre apart. Signed and coloured the same way the income rows already are.

**Why the count excludes readings and trips.** They are rows without amounts. A
"12 transactions" that counted odometer entries would not match the twelve
amounts printed under it, and the number exists to be checkable against the list.

**Why the totals follow the filter.** Filtering to Fuel and seeing an all-kinds
total would make the header contradict its own rows. The cost is that the
footer is not a fixed "this is your year" figure; it answers "what am I looking
at", which is the question a filtered list poses.

**Why an optional slot on `MonthHeader` rather than a second widget.** The same
header groups the fuel log and two vehicle-detail lists, none of which has
anything to total. An optional `trailing` leaves those three untouched, which a
new timeline-specific header would not have.

**Left undone deliberately.** `_monthlySpend` in the stats screen still buckets
money by month on its own, ignoring income. Two implementations of one idea is
a known duplication, recorded rather than fixed here because the stats screen's
bars have a different shape (fuel vs other) and folding them together is its own
change.


## Four things the app already knew and never said (August 2026)

Four features shipped together, all of the same shape: the data was already on
the phone and nothing joined it up.

### Range left, and when to fuel up next

**What.** The dashboard row, the vehicle's economy tab and the fuel log header
show how far the fuel in the tank still goes.

**Why it refuses more than it answers.** Tank capacity is optional, economy
needs two full tanks, and a `missedFill` breaks the arithmetic outright. All
four unknowns render as *nothing at all* rather than an em dash: "we cannot
tell", repeated on three screens for every car without a tank capacity, is
noise. The cost is that a driver who never set a tank size sees no explanation
of why there is no figure — accepted, on the grounds that nagging people to fill
in a field is worse.

**Why km left but no date without a measured rate.** Projections elsewhere
assume 30 km/day when they must. A distance is arithmetic; a calendar date is a
promise, and one made from a guessed rate is invented.

**What this changed.** `Vehicle.tankCapacityL`'s own comment said it "only
powers the more-than-the-tank-holds check". It is now an input to a prediction.

### Today's price where you last filled up

Covered under its own entry above; the tank-range work did not change it.

### What the cheapest station nearby charged that day

**What.** Migration `0045` adds four columns to `fuel_entries`; a fill-up
records the cheapest station within 5 km of the one it names, and the fuel log
says "12c cheaper 3.2 km away, at Petrol Ilica".

**Why now, before the feature was obviously valuable.** Under the current
Croatian price caps the gap is usually nil, so on the day it shipped this mostly
records zero. It went in anyway because the loss is irreversible: prices are
fetched live and kept nowhere, so every day without it is a day that can never
be compared. A feature that will matter later has to be built before then.

**Why the station name, not the position.** Anchoring on the name needs no
location permission and asks the better question — what was cheap near that
pump, rather than near wherever the phone was when the entry got typed. It also
reuses the name matching `postedPriceAt` already had.

**Why all four columns or none.** A price with no date it was read on cannot be
interpreted later; the table constrains them together and an RLS test proves a
half-snapshot is refused.

**Why create-only.** Re-snapshotting on edit would overwrite what was true then
with what is true now — the same class of bug as prefilling an edited price.

### Which way prices are moving

**What.** A smoothed chart of the national average with "up 3c on last week"
under it.

**Why smoothed, why weekly, and why a median.** Reading the actual feed settled
all three. 254 rows over ten weeks; petrol's daily figure moves a median of 5
cents and once 43. The large moves are spike-and-return pairs landing on the
days when one to three fuel types report instead of five or six — a thin
sample, not a price. Corroborated by the cap: as of August 2026 Croatia revises
a price cap weekly, so the real figure is close to flat between revisions, which
is what LPG (the consistently-reported grade) actually shows at one cent a day.

The cap is temporary policy, so the reasoning is deliberately not built on it.
The spikes and the weekday gaps belong to the feed's collection rather than to
the market, and outlive any decontrol; only the two-cent floor wants revisiting
if prices are freed.

So: a 7-day window, because coverage varies by weekday and only a whole week
samples each one once; and a **median** rather than a mean, because a mean does
not reject a thin day, it spreads it — a 30-cent spike over seven days is still
four cents of apparent movement, double the two-cent floor under which the
screen says "steady". The first cut used a mean and would have announced
movements that never happened; the fix came from checking the endpoint rather
than reasoning about it.

**A pre-existing bug fixed on the way past.** The screen's national average was
`series.last` on an unsorted list — a single noisy day, not necessarily even the
newest one.

### By how much a tank was off

**What.** A muted line under a fill-up: "18% more than this car's usual".

**Why explanation rather than a warning.** The row already colours the economy
figure green or red. A second signal would say what the colour says and disagree
with it at the edges — the colour is best-versus-worst-ever, an outlier flag is
deviation-from-average. So the number explains the colour instead of competing
with it.

**Why against the other tanks.** A tank inside its own baseline pulls that
baseline towards itself and under-reports how odd it was.

**Why three tanks and five percent.** Borrowed wholesale from `StationEconomy`,
whose comment already stated the reason: below three, one unusual tank *is* the
average.


## The API docs had to be reachable (August 2026)

**What.** `docs/public-api.md` is now mirrored at `web/api.html`, served at
`garage.hrva.cc/api`, and linked from Settings → API access.

**Why.** The app would issue a `grg_` key and then say nothing: the repository
is private, the website had no API page, and the API screen linked nowhere. A
credential with no reachable documentation cannot be spent — the holder would
have had to guess endpoint names.

**Why a mirrored page rather than a link to the repo.** The repo is private, and
making it public to publish one file is the wrong trade. The privacy policy
already solves this shape of problem the same way — a Markdown source, a hosted
HTML copy, and a test that fails when they drift — so this follows it rather
than inventing a second pattern.

**What the test pins** (`test/docs/api_docs_test.dart`): every endpoint in the
docs table appears on the page, every reader-facing section heading appears,
the four new `/fuel` snapshot fields appear, the page says a key is shown only
once, and — the inverse — deploy commands stay *off* it. "Deploying it" is
explicitly listed as maintainer-only, so the test does not demand it.

**Left as is.** The page is hand-written HTML rather than generated from the
Markdown. A generator is the obvious next step if a third copy ever appears; for
two files a drift test is cheaper than a build step.

## 68. The planner can add a reminder, and asks which car only when that is a question

**Decision.** The planner gets an "Add reminder" action — in the app bar, and
again inside the empty state, where it matters most. With one active vehicle
it opens `ReminderRuleSheet` directly; with several it first shows the shared
`showVehiclePicker`. With no vehicles the action is absent rather than
disabled.

**Why.** The planner is the screen that answers "what is coming up", and the
only way to change that answer was to leave for a vehicle's maintenance
screen. Somebody reading an empty twelve-week runway is exactly the person
about to add a rule, and they were being sent three taps away to do it.

**Why the shared picker and not a dropdown.** The dashboard's quick-add and
the launcher's fill-up route already ask "which vehicle?" with
`showVehiclePicker`, and decision-log entries before this one insist that the
same gesture be the same control on every surface. A third variant of the
same list was not worth having.

**Why the action is hidden with no vehicles.** A disabled button says "you
cannot do this" without saying why; the empty planner already says there is
nothing due, and the getting-started card on the dashboard says to add a car.
Offering a rule with nothing to attach it to would only lead to an empty
picker.

**Not done.** "Log service" is not added to the app bar. The per-bundle "Log
this visit" button already exists where a service is actually being planned,
and logging a visit from nowhere in particular is what the dashboard's
quick-add is for.

## 69. The garage name is offered, not demanded

**Decision.** The onboarding name field starts filled with the surname of
whoever signed in (`GarageName.fromPerson`: the last word of the account's
display name, or the whole of a single-word one). A dice button beside the
field replaces it with a draw from a small localized pool — the person's own
name in the form "{name}'s garage" / "Garaža {name}", then five ready-made
names that differ between languages rather than translating one another. A
draw is never the name already in the field. The field stays editable and
clearable, and an empty one is still refused.

**Why.** Naming the garage is the first thing the app asks and the one
question nobody arrived to answer. A colleague's observation, recorded here
because it is the whole reason: some people simply do not want to name a
garage, and the required empty field was where they stalled.

**Why the surname, not the full name.** "Hrvačić" is what a household's garage
is called in speech; "Karlo Hrvačić" is a person. When the display name is a
single word the word is used as it is. The exception is a handle: an account
with no display name is called by the local part of its address, and
"karlo.hrvacic" is nobody's garage, so anything containing a dot, underscore,
hyphen or digit leaves the field empty and the dice as the way in.

**Why the pool is in the ARB files and not in the domain.** They are
user-visible strings, and the rule that every one of those lives in
`app_en.arb` / `app_hr.arb` has no exceptions. The domain helper knows only
how to pick from a list; the list itself is the screen's, so the Croatian pool
can be Croatian names rather than translated English ones.

**Cost.** One test that previously tapped Create on an untouched form to prove
an empty name is refused now has to clear the field first. That is the
behaviour change, stated: an untouched form now creates a garage named after
you.

## 70. Interval defaults know the car: drivetrain first, fuel second, make third

**Decision.** A new reminder rule starts from `IntervalDefaults.resolve`, which
looks at the vehicle's timing drive and gearbox, then its fuel, then a
hand-built per-make overlay, and only then at the type's generic preset. Two
nullable columns, `vehicles.timing_drive` and `vehicles.transmission`, carry
the first of those. The overlay lives in Dart
(`lib/domain/maintenance/make_intervals.dart`), not in a table.

**Why the overlay is code and not a table.** It is under sixty rows, changes a
few times a year, and each row needs a citation. In code the citation sits
beside the number and a test checks it against the spike; in a table it would
be a column nobody reads. The resolver's interface does not care where the
rows come from, so moving them to a table for the public API later is a
data-source change, not a redesign. The alternative of a `make` column on
`service_types` was rejected: a make-specific default is not a *type*.

**Why the timing belt keys on the drivetrain and not the make.** One make
sells chains, dry belts and belts-in-oil in the same model year, with
intervals from "never" to 100,000 km, and manufacturers have revised the
wet-belt figures downward after the fact. A make-level belt default would be
wrong for a large share of that make's fleet, on the one item whose wrong
answer costs an engine. So the person is asked, once, on the vehicle.

**Why the shorter official regime.** VAG LongLife and Renault TCe both allow
30,000 km / 2 years. The person on the long regime knows they are and edits
once; the person who is not must not be told to wait two years.

**Why BMW and Ford oil are generic.** Both are condition-based. The car's own
indicator is the authority, and a number beside it would compete with it.

**Two figures and one note were adjusted at review.** Nissan's cabin and air filter went
from the spike's 29,000 km (a straight 18,000-mile conversion) to 30,000 km,
because a prefilled default with false precision reads as a typo; the spike's
Nissan row also cites 30,000 km from auto-abc. BMW's air filter likewise went
from 58,000 km (36,000 miles) to 60,000 km. CVT gearbox oil carries the
`advisory` note like the manual and automatic, because the spike sources it only from a
US advisory hub.

**`MakeKey` drops letters it does not know.** It folds the diacritics of
European make names and discards anything else, so "Łada" becomes "ada". No
overlay make is affected; add the letter to the table before adding such a
make.

**The 0046 migration comment is already stale.** It says nothing but the
reminder sheet reads the columns; the public API now does too. Migrations are
append-only, so the comment stands and this entry corrects it.

**Known gap, accepted.** `ServiceType` does not carry `householdId` on the
client, so a household's own type cannot be told from a preset. If a household
ever creates a type whose key equals a preset's, it will get the overlay. The
app never creates such a key, and the fix — surfacing `householdId` — is a
small follow-up if it is ever needed.

**Cost.** `availableServiceTypesProvider` became a family keyed by vehicle,
which touched every test that overrode it. And the vehicle form is two
dropdowns longer, both defaulting to "Not set", because the only wrong answer
to "belt or chain" is a guessed one.

## 71. A vehicle knows what it is, and a motorcycle is not a small car

**Decision.** `vehicles.kind` (`car`, `motorcycle`, `van`, default `car`) and
a nullable `final_drive` (`chain`, `belt`, `shaft`) for motorcycles, both from
migration 0047. Four motorcycle presets are seeded. The service-type list
hides the motorcycle items from a car and the car-only items from a
motorcycle, hides the chain items from a shaft- or belt-driven motorcycle,
and the per-make interval overlay is skipped for a motorcycle.

**Why now.** Nothing broke for a motorcycle before this: it was a vehicle
with an odometer, and decision 42 chose the word "vehicle" so the copy would
fit one. But two things quietly misled a rider: the reminder defaults were
car figures under the same badge, and the type list offered a cabin filter
and no word for a chain. Both are the kind of wrong that makes someone
conclude the app is for cars.

**Why a kind column and not a flag.** "Is a motorcycle" would have been
enough today, but a van is the next thing a household garage holds, and it
is a car for every rule here — same engines, same overlay, same items — so
the honest shape is a small enum with `van` behaving as `car`, rather than a
boolean that would need a second boolean the first time a van differs.

**Why final drive is its own column** rather than more values on
`transmission`. A motorcycle's gearbox is a gearbox; how the rear wheel is
driven is a separate fact, and it is the one that decides whether a chain
exists to lubricate. Overloading the gearbox column would have made the
resolver's gearbox-oil branch lie for a chain-driven bike with a manual box.
It is shown on the form only when the kind is motorcycle, and a car saves
null even if one was picked before the kind was changed.

**Why unknown kinds hide nothing.** The same reasoning as an unknown fuel
(decision 70): the column is a check constraint today, but a newer build may
add a kind this one has no case for, and guessing "car" would hide the
motorcycle items from a vehicle that may need them.

**Not done, and recorded as open.** Tyres still assume four corners. A
motorcycle has a front and a rear of different sizes and wear rates; the
tread sheet asks for four readings. That is a schema change on `tyre_sets`
and its readings and waits for a rider to ask. Also not done: motorcycle
rows in the make overlay. A motorcycle gets the generic presets, which is
correct rather than precise.

## 72. "What Garage can do" is a page of entry points, not a walkthrough

**Decision.** A `/features` page lists every feature in one scrolling list —
icon, name, one sentence of what it is for, and a tap that opens the thing
itself. It is linked from the last row of the getting-started card ("See
everything Garage can do") and from the end of the feature list on More. No
first-launch overlay, no coach marks, no carousel, no "seen" state.

**Why.** The getting-started card says how a vehicle gets in and what to log
first. Nothing said what the app can do after that: someone who never tapped
More had no way to learn the planner, the stations or the calculator exist,
and the app has too many quiet features for a five-tab bar to announce.

**Why a page and not coach marks.** Spotlight overlays interrupt, must be
dismissed before anything works, need per-device state, and break the moment a
layout changes — and they can only point at the five tabs, which are already
labelled. A carousel before onboarding sits where nothing can be tapped, so
everyone skips it. A page of real entry points costs nothing to keep, works on
web and phone alike, and is as useful on the tenth day as on the first.

**Why the rows open things rather than describe them.** A row that says
"Stations show today's prices nearby" and does nothing is a brochure. A row
that opens the stations screen is a shortcut, and someone who arrived to look
around leaves having done something.

**Why it closes the More list rather than opening it.** Decision 42's rule
that the garage leads on More still holds; the tour is the row for someone
who does not yet know what the rows above it are, and it names every one of
them.

**Not done.** The rows open screens, never sheets. "Log a fill-up" opens the
dashboard, where the quick-add is, rather than the fill-up sheet itself, which
needs a vehicle to be chosen first. If that turns out to be one tap too many,
the dashboard's quick-action helper is the thing to reuse.

## 73. The icon is the app's own palette: an amber roofline on charcoal

**Decision.** The launcher icon, web icons, favicon, Play icon and feature
graphic are regenerated from one mark — a roofline sheltering a car, amber
`#FFB020` on charcoal `#0F1114`, the "Night Shift" identity the app has used
since decision 40 — replacing the cobalt `#2F6FEB` white-car icon from the
first build. The chosen candidate is kept at `assets/icon/source-candidate-21.png`;
every size is cut from it with exact palette values rather than the generator's
approximations, and `flutter_launcher_icons` produces the Android set.

**Why.** The icon was the one surface still in a colour the app itself never
uses: the theme went amber on charcoal in July and the icon stayed cobalt, so
the thing on the home screen and the thing that opened did not look related.

**How it was chosen.** Three generated rounds of twelve. The first, briefed as
"tech", came back covered in circuit-board lines that die at 48 px and say
nothing to a household. The second dropped the hint and asked for flat
pictograms in cobalt; the third repeated that brief in the app's palette. The
pick was judged at 48 px first: three shapes, thick strokes, no detail that
disappears. The motorcycle is not in the mark — decision 71 makes
motorcycles first-class in the app, but at launcher size a bike beside a car
is a blob, and the roof says "garage" without either.

**What is deliberately not vector.** The mark is a raster cut from a
generated image. A hand-drawn SVG would scale better and is the right next
step if the mark ever needs to appear larger than the feature graphic; at the
sizes shipped today the raster is clean.

## 74. A first save has to land somewhere visible — *the dashboard clause amended, see 108*

**Decision.** Four small things, one rule: nothing a new user saves in their
first ten minutes may disappear without a trace. Saving a reminder shows
"Reminder set: Oil change"; the planner lists what is due beyond its twelve
weeks under "Further out"; saving a fill-up shows the amount and, on the first
full tank, that one more is needed before consumption appears; the dashboard
shows a plain "Opening your garage…" screen instead of a tab bar over spinners
while the household loads (superseded by decision 108, which keeps the reasoning
and replaces the sentence with a skeleton); sign-up validation clears as the field is corrected.

**Why.** The UX review (`.impeccable/critique/`, September 2026) walked the
first-run flows as a stranger and found that the app's most important moment,
the first reminder, saved into silence: a rule a year out is outside the
planner's window and off the dashboard's ninety-day list, so the sheet closed
and every screen looked exactly as before. The reviewer believed the save had
failed. The same pattern, quieter, on the first fill-up and after sign-up.

**Why "Further out" and not a wider window.** The twelve-week runway was
never a logged decision of its own; decision 50 aligned the bundling horizon
to it and gives the reason a wider window would be wrong: a planner that
lists every yearly item is a list, not a plan. The section beneath it costs nothing when empty and answers
the one question the window cannot — "did it take?" — without changing what
the runway is for.

**Why snackbars and not a result screen.** The sheet returns to the screen the
person was on; a line that names what was saved and then leaves is enough
proof, and it is the pattern the delete confirmations already use.

## 75. Features live where people look for them, and each has one name

**Decision.** From the UX critique's findability table: the maintenance
calendar is a toggle on the Planner (garage-wide) as well as per vehicle;
tyres are a row on the vehicle's Service tab; "Hand a vehicle to another
garage" sits beside "Invite someone"; API access moves to the end of Your data
under "For developers"; the location permission for pump autofill moves to
Settings under "Fill-ups"; the privacy policy is linked from More and About, not from Your data; Delete
and Leave garage get their own "Leave or delete" heading at the bottom of the
Garage page. Terminology: "Add reminder" everywhere, "Trips" for the log, and
the Croatian vehicle log tab becomes "Dnevnik".

**Why.** A stranger walking the app found calendar, tyres and transfer only
behind the vehicle page's three-dot menu, four taps from the dashboard;
trips logged under one name and viewed under another; the same word,
"Povijest", on two different tabs; and two red buttons in the list a new
admin uses to invite the first member.

**Why rows and toggles rather than new tabs.** The vehicle page has four tabs
and the bottom bar five; Material allows no more of either on a phone. A row
inside the tab where servicing is looked at, and a toggle on the screen that
answers "what is coming", add no navigation levels.

**Not done at the time — superseded by decision 90.** Receipts were reachable
only after an entry was saved, through edit; the sheets said so ("Save the
entry first, then attach files to it"). The argument was that attaching from
a new entry's sheet needs the saved id back from the repository. That expired
once the sheets began minting their own ids, and 90 removed the sentence.


## 76. The first screens ask for less: one action, a short form, a message to send

**Decision.** Three edits from the critique's second pass, all about what a
new person sees first. The empty dashboard has one filled button, "Add your
first vehicle"; importing from Fuelio or CSV and joining another garage stay
as plain rows beneath it, with the two import formats behind one sheet. The
vehicle form shows seven fields — name, kind, make, model, year, plate,
odometer — and folds engine details (fuels, belt or chain, gearbox, final
drive, VIN) and optional details (tank, price, photo) under two expanders that
start open when editing and closed when adding. The quick-add sheet leads with
fuel, service and cost as three tiles and folds odometer, trip, reminder and
income under "More". Inviting someone shares a short message — the code, the
join link and the date it stops working — instead of a bare link, and the
"copied" toast says a message was copied. On sign-in, a failure from the
previous attempt is hidden while the next one is in flight.

**Why.** Walking the flows as a stranger, the reviewer met three filled buttons
of equal weight on the first screen, a vehicle form of seventeen fields where
four are enough to start, a seven-row quick-add list for a garage with one
car, and an invite link with no words around it to send to a spouse. Each is
a place where the app asked for a decision before it had earned one.

**Why expanders and not a second step.** The vehicle form is one screen with
one Save. A wizard would give the four fields their own page but split the
edit flow, which does want everything at once; expanders that default by mode
(closed when adding, open when editing) keep one form and one test surface.
`maintainState` keeps the folded fields in the form so a VIN typed before
folding is still validated and saved, and a rejected VIN unfolds its section:
a red line behind a folded heading is a Save button that does nothing.

**Why the invite is a message and not just a link.** The link alone lands in a
chat with no explanation; a code alone needs the app first. One message carries
both, plus the expiry, which is the question the recipient asks next. The
invite list is refreshed, not invalidated, before the message is written:
a freshly created code is not in the previous list, and the first version
shared "works until —" to every new garage.

**Polish, from the critique's minor list.** The reminder sheet's unset date
says "Pick a date" rather than the empty-list line "Nothing here yet"; the
planner's sentence about where overdue items sit appears only over a list
that has items; the VIN field explains "Look up" before it is used; the
sign-up name field says it is shown to the people you share a garage with;
and the bottom bar's destinations carry no tooltip, because on web the
default one repeated the visible label and stuck to the bar under the
pointer.

A second walk of the flows against the running build (headless Chromium,
430 × 930 and 1280 × 800) found what the code review could not: the invite
share was not awaited, so on web the button did nothing visible (fixed, and
recorded in known-bugs); a rejected VIN unfolded its section but the viewport
stayed two screens above the red line, so Save now scrolls to the field; the
vehicle form re-validates as a field is corrected, like sign-up; every submit
shows the same small spinner rather than sign-in spinning and the rest
dimming; the + − × ÷ row shows only while its amount field has focus, since
three permanent rows on the fuel sheet read as stray toolbars; the planner's
empty-runway line loses its filled button when a "Further out" card sits
below it; the calendar rings today and says what a tap does; the fuel
sheet's odometer helper falls back to the reading the car was added with;
and the Croatian buttons on the garage and start pages use the same short
imperative as "Spremi" and "Napravi" rather than a mix of ti and Vi.

## 77. The checklist outlives the first entry, and a figure waits for its data

**Decision.** Five changes from the second critique (27/40, up from 25):

- The dashboard's "What next" card is a checklist, not an empty state. It
  shows the rows still undone — log a fill-up, set a reminder, open the tour
  — and goes when all three are done or when it is put away with "Hide".
  "Fill-up logged" and "reminder set" come from the household's data; "tour
  opened" and "hidden" are per device, in SharedPreferences, like the theme.
  Which means every existing garage sees the card once after this ships,
  on each device, with the one row it has never done ("See everything
  Garage can do") and "Hide". That is the tour being offered to people who
  never had it, not a regression.
- The vehicle page's cost per distance obeys the same rule as economy: no
  figure before two full tanks. The totals beneath it ("Since you added it")
  are true from the first entry and stay.
- The fill-up and reminder sheets open with the vehicle as their first row,
  name and plate; with more than one car a new entry can be moved to another
  from there, and what the sheet guessed for the first car (last station,
  last price) is guessed again for the second. A saved entry stays with its
  car.
- The Garage page is members and inviting; handing over, creating another
  garage and joining one sit under "Manage"; Delete and Leave fold under
  "Leave or delete" and open on request.
- The reminder sheet's service type is a searchable sheet: a "Common" group
  (oil, registration, insurance, inspection, seasonal tyres, front pads) and
  then the alphabet. "Fault noted" and "Modification" are not offered as
  reminders: they are logged after the fact on the service sheet, and nobody
  schedules one. A rule that already has such a type still opens.

**Why.** The critique walked the flows again after decisions 74–76 and found
the card that carries the reminder nudge vanishing with the first timeline
item, so anyone who logged fuel first was never told; a three-decimal €/km
after one tank on the page next to a dashboard saying one more tank was
needed; a fill-up sheet that never said which car; eight equal actions, two
of them red, for a garage twenty seconds old; and "Oil change" seventeenth
in a list of thirty.

**Why a per-device flag for the tour and not a column.** Whether a person
has read the tour is a fact about the person on that device, not about the
garage; the same reasoning as the handed-over notices. It costs a re-showing
of one row on a second device, which is cheap.

**Why hide the one-off types rather than group them.** Offering "Fault
noted" as a reminder invites a rule that can never be satisfied by logging
the thing it names. The service sheet still has both.

**From the third critique run (26/40).** The picker had copied the type
list when it opened; opened a second after the sheet on a cold load, that
copy was the empty list the catalogue had not yet filled, and "Nothing
matches" blamed a query nobody had typed. It now watches the catalogue, shows
a spinner while it loads and the standard failure line if it fails. Every
Save and the Invite button show the same spinner as sign-in. The checklist
asks which car when there is more than one instead of taking the first by
name. The vehicle's Service tab, whose empty line said "add a reminder"
while its button logged a service, has an "Add reminder" button under the
line. Leave sits before Delete, and the vehicles list shows its search box
only past three cars.

## 78. A slow save says so, and a tab says what it holds

**Decision.** From the third critique's open list:

- **A slow write is told about.** Every Save shows the spinner; after five
  seconds a line under it says "Still saving…"; a write that has not
  returned in twenty seconds is given up on as a network failure, whose
  message says the save may have gone through and to check before trying
  again; and every failure line on an entry sheet ends "Your entry is still
  here.", because it is. The timeout lives in
  `lib/core/widgets/save_progress.dart` with the note, and a
  `TimeoutException` maps to a failure kind of its own. Every write on those
  sheets is bounded, the price lookup before a new fill-up included.
- **The Costs tab counts fuel**, as a read-only first line ("Fuel €61.63,
  from the fill-ups") that opens the fuel log; its empty state then says "No
  costs beyond fuel yet." The History tab is "Service history" ("Servisi"),
  which is what it always held.
- **The empty economy ring says how far off the figure is**: "1 of 2 full
  tanks logged" under the dash.
- **A due date the odometer decided says what it rests on.** On the
  dashboard's Due soonest, a projection whose distance deadline won carries
  "by distance, about 196 km a day", or "assuming …" when no rate has been
  measured yet. The maintenance page said this already; the dashboard, where
  the date is first met, did not.
- **The date picker starts the week on Monday in English**, like the
  planner, through a `MaterialLocalizations` that overrides only the first
  weekday (`lib/core/widgets/date_pickers.dart`). The obvious route, asking
  Material for British English, was tried and reverted in review: it also
  made the picker's keyboard mode read dates day-first while the rest of the
  English interface writes them month-first, so "09/04/2026" typed the way
  the app shows it would have saved 9 April. Croatian was consistent
  already.

**Why.** Heuristics 1 and 9 scored 2 in the third run on the strength of a
fifty-second spinner ending in "Something went wrong" (the local stack was
reconnecting, but a phone at a pump produces the same) and a Costs tab that
said "nothing yet" one tap from a card counting €61 of fuel. A projected
date presented as fact could be neither trusted nor corrected.

**Why twenty seconds, and what it costs.** Long enough for a bad connection
to finish a small write; short enough that nobody taps Save four times
waiting. The entry survives either way. What a timeout cannot do is cancel
the request: an insert may still land at second twenty-two. So a timeout is
its own failure kind, and its message says the save may have gone through
and to check the list before trying again, rather than "no connection", which
invites the retry that makes a duplicate. And the retry is now harmless:
every entry sheet chooses its entry's id when it opens
(`lib/core/ids.dart`, a version-4 UUID), sends it with the insert, and
treats a primary-key conflict on that insert as "already there", which is a
success. A one-time rule gets its id from the sheet too and is upserted by
key; a recurring rule keeps the server's, since its repository updates by
type first, so its retry updates rather than duplicates. The next-vignette
rule the cost sheet schedules is the one remaining case.

**Why not a segmented control for two or three cars.** Considered and kept
the row: one control for any garage size, named and one tap to switch.

## 79. A rate needs two weeks, and a sheet asks before it forgets

**Decision.** From the fourth critique (28/40):

- **A driving rate needs fourteen days of readings.** Below that
  `OdometerHistory.kmPerDay` is null, and the projector goes by the calendar
  interval alone; a rule that has only a distance interval assumes 30 km a
  day, as before, and says so. The maintenance page's sentence states the
  span it actually measured over ("over 38 days of readings"), not a window
  it did not use; with no rate it says dates come from the calendar and that
  a couple of weeks of readings brings the distance estimate. The dashboard's
  Due soonest row says "by date" for such a rule.
- **Every entry sheet and the vehicle form ask before discarding typed
  fields** (`lib/core/widgets/discard_guard.dart`): Back, Escape and the edge
  gesture open "Discard what you typed?" with Keep editing and Discard. A
  field counts as typed only when it changed while it had focus, so what a
  sheet fills in by itself (last station, last price) does not make an
  untouched sheet ask.
- **The fill-up sheet's hint on the day a car is added** compares against
  the earlier fill of the same day ("Earlier today: 145,620 km"), not the
  baseline it replaced; same-day readings remain unordered and are not a
  bound.
- **The arithmetic row keeps its height while hidden**, so Save no longer
  jumps below the fold when an amount field takes focus.
- **The vehicle chooser shows plate and make and model** under each name;
  the third vehicle tab is "Services", which fits; saving a new vehicle says
  "Golf added"; Recent activity names the car when the garage has more than
  one.

**Why.** One fill and one guessed "last done" reading three days apart gave
1,873 km a day and an oil change due next week, on the dashboard, in a Due
badge, under a sentence claiming three months of history. It was the first
judgement the app made about the car and it was wrong by a factor of thirty.
Separately, a fill-up typed at a pump was thirty seconds of data that Escape
or the back gesture threw away without a word.

**From the review.** Entry sheets no longer close on a drag: the
framework's drag-to-close pops without asking the route, so a flick down
the sheet skipped the guard that Escape, the barrier and Back respect. A
vehicle form prefilled after its first frame no longer counts as touched.
The "last done" service the reminder sheet may log carries its own id.

**Minor, from the same walk.** The sign-in, sign-up and garage-setup forms
sit at the top of the screen rather than floating in its lower half; Settings
opens with Theme and Language; the quick-add "More" list has no unexplained
divider; the checklist row says "Set a reminder"; an unused invite code reads
"Ready to send"; Croatian brake pads are "kočione pločice".

**Why fourteen days.** Long enough that a weekend trip is not the year's
rate; short enough that the first fortnight of a new car's log produces a
figure. The whole-series fallback keeps its role for cars logged twice a year.

**Why date-only rather than the assumed rate.** An assumed 30 km a day
labelled as such was the alternative. For a rule with both intervals the
calendar is a real deadline the person set; the assumed distance date is a
number nobody measured, and the dashboard would show whichever came first.
Going by the calendar until the rate exists is honest and rarely wrong by
more than the calendar itself.

## 80. A prefilled number is a suggestion, and the calculator has one place

**Decision.** From the fifth critique (28/40):

- **A prefilled price is selected when its field takes focus**, so the first
  keystroke replaces it; an amount that is neither a number nor a sum in
  progress says "Not a number" under the field as it is typed.
- **The + − × ÷ row is docked once above Save** (`AmountCalculatorDock`),
  serving whichever amount field has focus, in a slot that is always there.
- **The vehicle page's tabs are Reminders and History** (Podsjetnici,
  Servisi): "Service" beside "Services" forced a guess on every visit.
- **Each vehicle card says what is next** ("Next: Oil change · Sep 2027"),
  however far out, and its pump and wrench icons open the fill-up and
  service sheets, as the same icons do on the checklist. The fuel log is
  headed with the car's name.
- **Revoking an invite code asks first.**
- Dialogs and the date picker sit on the app's own surface; the vehicle
  list keeps "km" with its number.

**Why.** Typing "1.47" over a prefilled "1.45" gave "1.451.47" and a blank
total, silently, on the second most common action in the app. The per-field
calculator rows appeared on focus and pushed Save below the fold; holding
their height instead left blank bands that read as a rendering fault. A
reminder saved from the checklist was invisible on the home screen and read
as a save that failed.

**Why a dock and not a keyboard accessory.** Flutter web has no accessory
bar; a reserved slot above Save is the same idea in the sheet's own layout,
and it is one slot rather than one per field. It keeps showing the last
field typed into once focus moves on, so a sum's running total does not
vanish when the person taps Notes.

**From the review.** Selecting the prefilled price notifies its controller,
and the discard guard took any notification while focused as typing; it now
compares the text. An overdue rule on a vehicle card says "Overdue:" rather
than "Next:" with a past date. The live number check reads an amount the
way the total and the save do.

## 81. A desktop window is not a wide phone

**Decision.** On a desktop-width window (1200 px and up):

- The sidebar lists everything the More page holds, under two dividers:
  Garage, Statistics, Trips, Fuel stations, Calculator, then the tour,
  Settings, Your data, About. "More" is not a destination there; the compact
  rail between phone and desktop width keeps it, as the phone does. Both
  lists come from `lib/core/widgets/secondary_destinations.dart`, which the
  More page also reads, so the two cannot drift.
- The dashboard's app bar has no icons on desktop: the three it had were the
  sidebar's own links a second time, unlabelled.
- The metrics strip sits at its own width instead of spreading three
  figures across a thousand pixels, and the "What next" card lives in the
  left column rather than as a band across the page.
- The planner's List / Calendar control keeps its natural width.
- The vehicle form is capped at a form width (`ContentWidth.form`, 560 px);
  reading width, 840, is right for prose and wrong for a plate field.

**Why.** Every desktop shot in five critique runs said the same thing: the
sidebar repeated the More list under a More that led to it again, three
stats stretched across the window like a table with no rows, and a form of
800-pixel inputs. The phone layout was being served wide, not a desktop one.

**Second look, same day.** The floating button belongs to the content
pane, which is a scaffold of its own. Snackbars could not be scoped that
way: a sheet or dialog is a modal route under the root navigator, so its
messenger is the root one whatever the page below does. Instead
`WindowSnackBars` at the root sizes every snackbar to the window: floating,
at most 560 px, centred, so on a desktop it clears the sidebar and on a
phone it is what it was. The dashboard's garage row keeps its chevron beside
the name on desktop rather than at any fixed width. About renders inside
the shell like every other pushed page. An empty state's button is capped at
360 px, and the vehicles list shows no floating "Add vehicle" while its empty
state offers the same button. The vehicle form's calculator dock sits inside
the Optional section with its one field and reserves no space until the
field is used, rather than as a blank band above Save.

**Why not a different dashboard on desktop.** The same sections in two
columns is what the width buys; a separate layout would be a second product
to keep true. The changes are all about width and duplication, not about
what the page contains.

## 82. The vehicle page keeps its promises: archive asks, reminders can be added

**Decision.** From the first critique of the vehicle page, planner and
statistics (23/40):

- **Archive asks first**, with the same dialog shape as Delete, and its
  snackbar carries Undo. An archived car's page opens with a banner saying
  so and offering Restore. The vehicles list is refetched before it is shown
  after either, so a restored car does not sit under "Archived".
- **The Reminders tab always has "Add reminder"**, as a row above the list;
  it lived only in the empty state, so once one reminder existed the tab
  offered "Log service" and nothing else. **The History tab has its own
  "Log service"** button; it had no way to add what it shows.
- **The menu's "Calendar" opens the calendar**, not the maintenance screen's
  list tab, which is the Reminders tab in different chrome.
- **The planner calendar's grid is capped at seven 64-pixel columns**; on a
  desktop pane square cells made six rows overrun the screen.
- **The economy chart's scale floors at half a litre** and lands its ticks
  on tenths, in the household's numerals; the odometer axis prints the
  reading, not thousands. A 0.02 l/100km wobble was drawn full height under
  "6.3" printed five times, and three fills all read "121".
- **Log service leads with the common jobs and offers no paperwork**:
  registration, insurance and a vignette are paid, not done, and the cost
  sheet owns them and their reminders.
- **Service and cost saves say so**, like fill-ups and reminders.
- **The cost card's "Since you added it" is what was paid.** The per-month
  and per-year rates still spread yearly cover over its year, and a line
  says so when that changed the number: €600 of insurance shown as €1.64
  read as a bug, not as amortisation.
- The fuel log's per-distance figure is labelled as the latest fill-up's;
  the rate note under the reminders names its subject ("Dates below…");
  "Upcoming" is not chipped onto every row; statistics show money to cents.

**Why.** Archive ran on one tap two rows above Delete, dropped the household's
main car from every screen and total, and left a page that did not say it was
archived. The tab named Reminders was where every persona looked for the
next reminder and found no way to add one. The rest were the numbers not
agreeing with each other, which is the fastest way to lose a power user.

**Then the rest of that list.** Planner rows open the car they name, so a
garage with thirty reminders can get from the plan to the rule. The tyre
card keeps Fit, Edit and Add reading as buttons and puts Retire and Delete
behind its own menu. The report dialog says what each report holds and
offers Cancel.

**From the review.** The economy chart's top is derived from the padded
range, not the raw span: computed from the span alone it fell below the
highest point and the thirstiest tanks were drawn outside the border. The
desktop sidebar scrolls, since nine links plus five destinations overflow a
1366×768 laptop's maximised window. The vehicles list keeps its archived
section when nothing is active, so archiving the only car is not a one-way
trip. A failed Undo says so. "Since you added it" and the prorated figure
count the same entries, so a receipt dated before the car was added no
longer makes the total smaller than the row beneath it. A statutory type
already on a service stays offered once unticked. The History list clears
its own button. Duplicate ARB keys are gone, and the consistency test now
fails on one.

**Known cost of the split.** FABs live in the per-tab and per-pane
scaffolds while snackbars are rendered by the root one, so a floating
snackbar does not lift a FAB out of its way; "Service logged." can land on
the Log service button for its four seconds.

**Verified on screen, and four fixes that had not landed.** A walk of the
built app found that the "since you added it" figure still spread the
premium (the provider kept a date filter the change had meant to remove),
the Undo path still had no failure branch, and the Log service sheet still
offered comprehensive insurance and a vignette, because neither is flagged
statutory in the catalogue: cover is optional. Paperwork is now a named set
of keys rather than a database flag. The maintenance screen reached from the
planner carries the car's name in its title, the archive snackbar has an
explicit duration, and the chart's axis labels are drawn through
`SideTitleWidget` at a coarser interval so the rightmost pair no longer
overlaps.

**And the last two.** The economy ring says what it is scaled against
while the car has no range of its own ("The ring runs 4 to 12 l/100km
until this car has a range of its own"); once two tanks exist the line
below already names the car's own best and worst. Picking a service type
in the reminder sheet fills "last done" from the most recent service of
that type, with a line saying where the numbers came from: the sheet asked
for a date the Reminders tab prints two rows below.

## 83. One car's distance, one word for spending, one car's economy

**Decision.** From the first critique of the timeline, statistics, stations,
trips, the calculator and Your data (23/40):

- **A vehicle's starting odometer is a reading.** Statistics built each
  car's span from its logged entries only, so a car with one fill-up
  reported "0 km tracked" beside a non-zero odometer and contributed
  nothing to the fleet distance every per-kilometre figure divides by. The
  baseline counts when it is a real reading; a car added with the box left
  empty has a baseline of zero, and counting that would report its whole
  odometer as distance covered.
- **"Spent" means money out.** The timeline's closing line said "spent" over
  a figure that was net of income, so the dashboard, the timeline and
  statistics disagreed about one number. With income in the list it says
  balance.
- **The stations screen does not claim proximity it has not got.** Without a
  position the average is labelled "Average across the country", which is
  what it is.
- **The calculator does not lend one car's economy to another.** Choosing a
  car with no economy clears the box rather than leaving the previous car's
  figure in it, and a prefilled figure says which car it came from.
- **Export and backup name the file they wrote.**

**Why.** The distance bug is the app's own subject matter reported wrong,
and it silently overstated every cost per kilometre. The rest are the same
failure in different words: a number or a label that asserts more than the
data supports.

**And the three that were open.** A timeline row now carries what it is
about — the station a fill-up was at, a trip's name and route — so searching
"INA" or "Rijeka" finds them; the provider already had the entries, so this
cost no extra query. The filter sheet has a vehicle picker above the six
kinds, and Clear resets both. A price below 0.80 a litre is not treated as a
price at all: the open data has carried figures like 0.67, and the screen
promoted the lowest number it could find to its headline.

## 84. The web pages wear the app's own colours

**Decision.** The four static pages served beside the app — the features
page, the privacy policy, the API reference and the account-deletion page —
use the app's palette rather than Material's defaults: charcoal and off-white
grounds, amber links and buttons (`#FFB020` on dark, `#9C6300` on light),
and the app's own border and surface tones. Nothing else about them changed.

**Why.** They are the first thing a visitor sees and the page an app-store
reviewer opens, and they were blue: a default-blue call to action on the
marketing page for an amber-on-charcoal app reads as somebody else's site.
The type scales stay as they are, each already chosen for its own job (a
skimmed features page wants a voice, a legal document read start to finish
does not).

**Why not more.** These are four hand-written pages with no build step, and
the value here is in matching what the app already looks like, not in
redesigning them.

## 85. Red means gone, and a rename changes only the name

**Decision.** From the first critique of Settings, the Garage page, tyres,
the transfer flow, reports and the API screens (20/40):

- **Renaming the garage changes the name and nothing else.** It rebuilt the
  household row field by field and forgot `settlementEnabled`, so a rename
  silently switched shared costs off: a financial setting disappearing on an
  unrelated action. `Household.copyWith` now exists and the rename goes
  through it.
- **Red is for what cannot be undone.** Deleting all data and deleting the
  account confirmed with the app's amber affirmative, the colour every save
  uses, while retiring a tyre set — which the dialog itself calls reversible
  — confirmed in red. Both are corrected: the account-level deletions are
  red, retiring is amber.
- **A retired tyre set can be brought back**, and stops being offered a tread
  reading. The dialog promised the set and its readings stay, and the only
  way back was to delete it and type it in again.
- **A bad transfer code says so.** The redeem function raises P0001 for a
  code that is unknown, spent or expired, and it surfaced as "Something went
  wrong. Please try again", which is a retry loop that cannot succeed.
- **The dashboard names the garage even when it is empty.** Creating a second
  garage switches into it, and a nameless empty dashboard is what losing
  every vehicle would look like.
- **The tour's tyres row is named for tyres**, not for the vehicle list it
  landed on.

**Why.** Two of these are silent data or state loss, and the rest are the
app telling the user something untrue: that a deletion is the safe choice,
that a reversible act is not, that a valid attempt failed.

**Then the open list, decided.**

- **Deleting the account asks for the garage's name**, typed, before the red
  confirmation. It is the only act in the app with no recovery at all.
- **An outstanding transfer code can be withdrawn.** A code handed to the
  wrong person, or a sale that fell through, stayed live until it expired;
  the delete policy for `vehicle_transfers` already allowed this, and only
  an unredeemed offer is removed, so a completed handover keeps its record.
- **Currencies show their symbol beside the code**, since a list of bare ISO
  codes made "ALL" read as the word.
- **Tyres stay where they are.** A fifth tab does not fit: the strip already
  dropped its icons so that four labels would fit a phone in both languages,
  and "Tyres" as a fifth would bring back the scrolling strip that change
  removed. Tyres are reachable from the vehicle's own row, from the menu,
  and now from the tour.

- **Settings' read-only lines are prose.** Whether reminders reach the
  household or only this phone, and when they arrive, are facts about the
  build, not settings; styled as rows among the dropdowns and switches they
  read as controls that had failed to load.

## 86. What the review of 83 to 85 found

**Decision.** Thirteen findings, all addressed:

- **Redeeming a transfer says which refusal it was.** Every check in
  `redeem_vehicle_transfer` raised a bare exception, so Postgres reported
  them all as P0001. Naming that one code told a member redeeming into the
  garage that already owns the car that their code was invalid, which is the
  retry loop the change set out to end, moved. Migration 0048 gives the
  function the same vocabulary the invite function uses (P0002 unknown,
  P0003 expired, P0004 spent, P0005 already here, 28000 and 42501 for auth
  and membership), and the screen speaks each case. The substitution is
  scoped to redeeming: the same failure kinds mean other things when
  offering or cancelling a code.
- **The timeline's closing line is signed**, like every month header above
  it, and reverts to "received" for a list that is only income, since
  nothing there is net of anything.
- **A stale baseline is not a reading.** The edit screen writes the vehicle's
  baseline from a box labelled "Current odometer" while keeping the original
  date, so an owner correcting it years later would have planted today's
  figure at the car's start. The baseline counts only while it is still the
  lowest reading the car has.
- **Deleting all data is red too.** Decision 85 said both account-level
  deletions were corrected; only one was.
- **Without a position there is no "nearby" average at all.** The figure
  averaged the first twenty rows the feed happened to send, which is one
  town or one brand, and labelling that the country was a second claim with
  no basis beside the ministry's real national figure.
- **A price floor per fuel.** A flat 0.80 a litre would have hidden real
  autogas prices.
- The dashboard has one garage row rather than two copies sharing a key; a
  trip with one named end reads as that place rather than "Rijeka →"; the
  read-only settings lines are one stop for a screen reader; the calculator
  clears a borrowed price as well as a borrowed economy; account deletion
  fails closed when the garage cannot be read.

**Tests.** The transfer delete policy now has a positive and a negative
control in `test_rls/rls_test.dart`: a delete refused by row-level security
returns success with zero rows, so without them the app could not tell a
policy regression from a working cancel. The timeline search test asserts a
query that should hide the row, the stats test pins the stale-baseline case,
and the empty dashboard's garage row is covered.

**Verified on screen, and two more.** A walk of a fresh build confirmed every
one of these: the rename keeps shared costs, both account-level deletions are
red, the deletion asks for the garage's name and refuses the wrong one,
currencies carry a symbol, the reminder lines read as prose, retiring is
amber and reversible, a transfer code can be cancelled, an empty garage is
named, a bad code says which, timeline search finds a station and the filter
sheet has a vehicle picker. Two things the walk found: the refusal to a
mistyped garage name arrived as a snackbar over a dismissed dialog, so it now
shows under the field with the prompt still open, and a currency that writes
itself as its code no longer prints "CHF · CHF".

## 87. A sheet says which car, a total adds up, and a log cannot be dated ahead

The sixth critique of the first-run flows scored 28 of 40 and named four
things worth fixing.

- **A breakdown that does not add up is a bug report.** The vehicle page's
  "Where it went" listed fuel and servicing as paid but everything else as
  amortised, so the three rows read €326.55 under a stated €468.66. Every row
  in the list is now what was paid (`running_cost.dart` already carries both
  figures), and the rates above it keep the spread ones. A widget test pins
  the rows against the total.
- **Every entry sheet names the car.** Fuel and reminders already did; the
  service and cost sheets did not, so with two cars the dashboard's + button
  gave no clue which one was about to be charged. Both now carry the same
  first row, switchable while the entry is new. Switching a service clears
  the ticked jobs: a diesel's filter is not offered on a petrol, and its
  reading would otherwise be saved against a car that never has one.
- **What already happened cannot be dated ahead.** The pickers on fill-ups,
  services, odometer readings, trips, costs and income ran to 2100, and a
  fill-up dated next week is a typo, not a plan. They stop at today —
  stretching only for an entry already dated ahead, since imported data has
  carried such dates and a picker that will not open on one leaves it
  uncorrectable. Warranty and reminder dates are unchanged: those are
  genuinely about the future.
- **"Average around here" needs a here.** The station panel averaged every
  grade regardless of the fuel tab, so a diesel driver read petrol prices,
  and it claimed proximity over a list that said the location was unknown.
  It now follows the tab, and without a position it is titled as a national
  average.

Two smaller ones from the same run. Saving an empty vehicle form scrolled to
the VIN and unfolded the engine section, hiding the one real complaint; it
now goes to whichever field was refused. And an invite on a browser that
refuses both the share sheet and the clipboard showed nothing at all, so the
message is offered as selectable text instead.

## 88. Two tyres on a motorcycle

The tread sheet asked every vehicle for four corners. A bike has a front and a
rear, of different sizes and different wear rates, so a rider filled two boxes
and left two empty on a form that was visibly a car's. It now asks a
motorcycle for two.

The readings go into the `front_left_mm` and `rear_left_mm` columns rather
than into a new shape. The alternative — a nullable pair of bike columns, or a
discriminator on the set — buys nothing: nothing in the app reads a corner on
its own. `TyreReading.shallowestMm` takes the worst of whatever is there,
which is what the wear projection, the card and a roadworthiness check all
want. The cost is that a backup exports a bike's front tyre as
`front_left_mm`, which is documented rather than corrected.

The vehicle is awaited rather than read from the provider's cache: opened
straight from a link the vehicle may not have resolved, and a bike would then
have been asked for four corners after all.

**And what the worst corner cannot say.** The card printed one figure, the
shallowest, which is what the law reads — but a set worn evenly to 3 mm and a
set whose right front is 3 mm while the rest are at 7 mm are different
problems, and only one of them is fixed by buying tyres. `TyreReading` now
reports its spread, and the card names both ends of it past a millimetre.
Below that it is measurement noise: a tread depth gauge read by hand does not
resolve tenths reliably.

## 89. What the review of 87 found

A review of the run-6 fixes turned up six things, four of them real defects
that predate this round or were introduced by it.

- **A paperwork reminder nothing could complete.** The service sheet drops
  registration, insurance and inspection chips because "the cost sheet owns
  them". The cost sheet settles only what a cost category maps, and only for
  a one-off rule. A technical inspection has no cost category at all, and a
  yearly registration rule resets on a service entry carrying its key — so
  the seeded demo reminder, and every recurring paperwork rule a household
  makes, stood for ever with no way to mark it done. A paperwork chip is now
  offered whenever an active rule on the car asks for that key.
- **The ownership total contradicted the line above it.** "Since you added
  it" became what was paid in decision 87 while `costOfOwnership` still added
  the spread figure, so on exactly the cars that show the spreading note the
  ownership figure was less than the price plus the total above it. Both are
  now paid. `hasSpending` moved with them: a policy whose cover falls before
  the baseline prorates to nothing, and the card said "not enough data yet"
  over money actually spent.
- **A picker whose bounds exclude its own date asserts.** Capping the last
  date at today was half the rule. An entry dated before 2000 — a classic
  car's history, or a bad import — tripped the framework's assertion, and so
  did opening the due-date row of any overdue reminder, whose floor was
  today. Both bounds now stretch to the date being edited.
- **Switching the car left the previous car's complaints on screen.** The
  service sheet cleared the ticked jobs and the odometer but kept "Odometer
  required" and the failed-save sentence.

Two smaller ones. Vehicle-form validation inferred which field was refused
from the name being empty, which is right for two validators and wrong for
three; it now walks a list of the fields that can be refused, in order, and
Save is no longer re-entrant while the scroll animates. And creating an
invite reported failure when only the *list* read failed, after the code had
already been made; the refresh is now its own try, and a message with no
known expiry drops the clause rather than sending "works until —".

Also: the area averages on the stations screen now apply the same price floor
the picks do, so a 0.67 diesel that the headline refuses no longer drags the
average printed beside it.

## 90. A receipt can be attached before the entry is saved

Decision 75 left this deliberately: attachments hung off an entry that had to
exist first, so the paperclip appeared only on a second visit to an entry and
the critique rated receipts the least findable feature in the app. The
argument for leaving it was that `add()` returns void, so the sheet could not
know the new row's id.

That argument expired when the sheets began minting their own ids (decision
79, so a save retried after a timeout is the same entry). The id exists
before the first keystroke, and `attachments.entry_id` is a bare uuid column
with no foreign key — it points at nothing, by design, because an attachment
is keyed by kind *and* id. So a receipt can be uploaded while the fill-up is
still being typed, which is when the person is holding it.

The cost is orphans: a sheet closed without saving would leave files hanging
off an id nothing will ever ask about again. Each sheet therefore takes them
back down from `dispose` when the entry was never saved, through
`discardUnsavedAttachments`. Fire and forget, with failures swallowed: the
sheet is already going, there is nothing on screen to report to, and an
orphaned file is not something a household can act on.

`AttachmentsAfterSaving` and its "Save the entry first" sentence are gone.

**What the review of this changed.** Four things, three of them ways to lose
a receipt or a file.

- **The car cannot be switched once something is attached.** An attachment
  carries the car's id in its own row, and that column cascades on delete and
  moves with a vehicle transfer. A receipt left pointing at the first car
  would follow that car to a stranger's garage, and vanish from the entry it
  belongs to. The vehicle row is simply locked from the first upload; the
  alternative, rewriting the row and re-uploading the file, is a lot of
  machinery for a rare correction.
- **A save that times out counts as saved.** `writeNew` gives up after twenty
  seconds on a request that cannot be cancelled and may well have landed, so
  the cleanup stands down the moment a write is *attempted*. An orphaned file
  costs storage; deleting a receipt off a real entry costs the household its
  paperwork.
- **The flag is set immediately after the entry write**, not after the
  follow-up work — completing reminders, scheduling a recurring cost — which
  fails on its own and used to take the receipts with it.
- **The cleanup waits for uploads still in flight**, and an attachment makes
  the sheet dirty, so tapping outside asks first instead of silently
  discarding the upload.

The locked vehicle row says why it is locked ("Remove the attachment to move
this to another car"), because a row that simply stops responding reads as a
bug rather than as a rule.

## 91. What the tyres, stations, data and features critique changed

A walk of four surfaces that had never been critiqued scored them 20 out of
40. Two were wrong rather than merely awkward.

- **A motorcycle was told the car's legal tread minimum.** The card printed
  "At or below the 1.6 mm legal minimum" over a bike measuring 1.4 mm. In
  Croatia and across the EU a motorcycle is held to 1.0 mm. A specific legal
  claim that is not true of the reader's vehicle sends them to buy tyres they
  do not need and teaches a number no inspection will agree with. The figure
  now comes from the vehicle's kind, and the wear projection measures against
  the same floor.
- **A second tread reading taken the same day was written and never shown.**
  Readings are date-only and the sheet stamped today, so a correction tied
  with the reading it corrected and `latestReading` kept the first. A person
  who re-measures because they misread the gauge saw the old figure, assumed
  the save had failed, and recorded it again — the duplicate rows in the
  backup are the fingerprint of exactly that. Ties now go to the later row,
  the sheet takes a date and an odometer, the card says when the tread was
  measured, and saving says so.

The rest were honest-information and layout problems.

- **The stations page scrolls as one page.** The chips, the averages, the
  picks card and the chart were pinned above an expanded list, leaving about
  two and a half rows of the list on a phone and fewer on a desktop window —
  on the screen whose whole purpose is the list.
- **A station row leads with the station.** It led with the legal operator,
  so two rows of one company read identically and the part cut off was the
  name on the sign being driven towards.
- **The grade panel is named for what it is.** "Average around here" sat over
  a per-grade table directly under a headline reading "National average", two
  different quantities under one wording.
- **Without a position the list says what it is**: the cheapest in the
  country, not the nearest, with a button to ask for location again.
- **The spreadsheet export is a zip of real tables.** It was twelve
  differently shaped tables concatenated into one `.csv` with `#` comment
  lines between them, which no spreadsheet or parser opens correctly. It also
  silently omitted the tyre history and the cars' own attributes — the tread
  series being the one history that cannot be reconstructed later. One file
  per car per kind now, plus `vehicles.csv`.
- **The data screen says where "Delete all data" lives**, groups its rows
  into bringing data in and taking it out, and explains the two import rows,
  which were the only ones that explained nothing.
- **"API access" mentions webhooks**, because half the screen behind it sends
  this garage's data to a URL — which is not what "a read-only feed" says to
  a reader who chose this app for not tracking them.
- **The tour is one surface, inside the app.** The sign-in screen's "What
  Garage does" left for a hand-written page on the production host, in
  English only, from any build, with no way back. The route now sits outside
  both gates, like an invite link, because it is read by people deciding
  whether to sign up. With one car in the garage its Tyres row goes to that
  car's tyres rather than to the vehicle list.

**And three more from the same walk.** A set fitted to the car no longer also
claims a shelf to sit on; it can be taken off the car without being retired,
which fitting another set was the only way to do; and the tread figure names
the corner it came from, so four readings entered do not collapse into one
number that could be any of them.

## 92. What the review of 91 found

Thirteen findings, most of them the difference between a change that works in
a test and one that works in the world.

- **The same-day tie-break relied on an order Postgres does not promise.**
  Decision 91 broke a date tie by taking the later row of the list, and the
  readings arrive as an embedded select with no ordering of their own. A
  reading now carries when it was written, the query orders the embed, and the
  tie-break is explicit rather than positional.
- **The zip was shared as `text/csv`.** The save path was updated and the
  share path was not; share targets filter on the MIME type and some refuse a
  mismatch outright.
- **"Use my location" did nothing on a second refusal.** It invalidated the
  position provider, which swallows a refusal and returns null. It now asks
  through the permission gate and says so when the answer is no, reusing the
  sentence the pump-autofill row already had.
- **The tyres screen read the vehicle kind synchronously** while the tread
  sheet awaited it, so a cold open of a motorcycle's tyres — now a direct
  link from the tour — flashed the car's 1.6 mm legal figure before settling.
  The list waits for the vehicle.
- **The tread odometer was parsed as a bare int**, so "124 000" saved as
  nothing at all, silently, for the one field the wear estimate needs.
  Separators are normalised and a figure that is not a number is refused.
- **The whole stations page sat inside its async view**, so a failed feed
  replaced the fuel chips along with the list — the reader could not even
  switch fuel to see whether the other tab had loaded.
- **`/features` collided with `features.html`** on the web host, where a
  reload or a shared link would have served the marketing page instead of the
  screen. The in-app route is `/tour`.
- **The tour's gate check jumped the invite queue**, stranding a code for a
  visitor who detoured through it, and on a desktop window it rendered the
  full navigation rail to a signed-out visitor, every destination of which
  bounces to the sign-in form. Both fixed.
- **Smaller:** `vehicles.csv` was missing `trim`, which the privacy policy
  lists as stored; the zip's file names stripped Croatian diacritics rather
  than folding them, so "Škoda" became "koda"; an export that throws now says
  so instead of failing silently; the station row's subtitle leads with the
  address, since at one line the leading part is what survives; and six dead
  ARB keys went, three of them wired up instead — the timeline says what its
  search covers, and the statistics card says a distance of zero needs a
  second reading.

The privacy policy gained the bullet it never had for tyre sets and tread
readings, and its menu paths now say More → Your data, which is where those
actions actually live.

## 93. A fill-up that cannot describe a journey says so

**Roadmap item, "say when an entry looks wrong".** The odometer guard refuses
a reading below the last one and the volume guard refuses more than the tank
holds. Neither catches the commonest real mistake, because it is not in either
field on its own: a transposed digit in the odometer is a plausible number,
and only becomes nonsense beside the litres next to it. Forty litres over
twenty kilometres is 200 l/100 km, and nothing said so until the economy
figure went strange weeks later — by which time nobody remembers which fill-up
was wrong, and the fix is archaeology.

The sheet now divides the two as they are typed and says what the pair works
out at when the answer is outside what any road vehicle does.

**Bounds are deliberately wide** — 1.5 to 60 l/100 km, 5 to 90 kWh — because
a loaded van towing uphill really does drink 25 litres and a hypermiled diesel
really does manage three. What is left outside is arithmetic that cannot
describe a journey at all.

**A warning, never a refusal.** A jerrycan, a fill after a tow, and a fill-up
somebody forgot to log are all real, and the household is the one who knows
which this is. It is also suppressed while the odometer or volume guards are
already complaining: two red lines about one mistake is worse than one.

## 94. Paperwork is a first-class thing, and its reminder is not a new mechanism

**Roadmap item 5.** The app tracked money and work and knew nothing about
paper. That is the half that carries a fine rather than a repair bill: a
registration a month out of date is a car that may not legally be on the road,
and a lapsed policy is a claim that will be refused.

Reminders and cost entries covered part of this **by accident**. Paying for a
registration raised a one-off rule dated a year on, which is a fact about the
*payment*. It says nothing about a policy bought mid-year, a certificate whose
date does not match the payment, a green card nobody pays for separately at
all, or what the number on the paper actually is.

`vehicle_documents` records the paper: which kind, the number and issuer, the
day it was issued and the day it runs out, and a photo hanging off it through
a fourth `attachments.entry_kind`.

**The reminder reuses the maintenance service types rather than inventing a
parallel due-date system.** `DocumentType.serviceTypeKey` maps registration to
`service_registration`, roadworthiness to `service_technical_inspection`, and
so on; saving a document with an expiry writes a one-time `reminder_rules` row
dated on it. Nothing else had to learn what a document is — the dashboard, the
planner, local notifications, the push sender and `/due` all carry it already.

The consequence is that the cost sheet and the document sheet write the *same*
rule, and the later of the two wins. That is the intended behaviour rather
than a collision: paying for a registration and holding the certificate are
two halves of one fact, and the document is the better source because it
carries the date printed on the paper instead of twelve months from the
payment.

**One of each kind per car**, a partial unique index exempting `other`. A car
holds one current registration certificate; renewing it is a new expiry on the
same row, and what was paid stays in `cost_entries` where the history always
was. The alternative — a row per renewal — would have made "when does it run
out" a query rather than a field, on the one screen whose entire purpose is
that answer.

**A month of notice, not the fortnight maintenance uses.** Renewing paperwork
means booking a slot at a testing station or getting a quote from an insurer.
Both take longer to arrange than an afternoon in a garage.

**The last valid day is still valid.** A certificate valid *until* the 4th
covers the 4th. Calling it expired that morning would send somebody to a
testing station a day early, every year, for as long as they used the app.

**A driving licence is deliberately absent.** It belongs to a person rather
than to a car, and both this table and the attachments bucket are scoped by
vehicle. Filing one household member's licence against whichever car they
happen to drive would be a wrong answer that looks like a right one, and the
one-per-vehicle-per-type rule would make two drivers fight over one row.

**`other` raises no reminder, and says so.** The app has no name for whatever
is being kept there, so it has nothing to call the item that would come due.
A silent absence would read as a broken reminder rather than as a limit.

## 95. Three more entries that cannot describe what happened

**Roadmap item 9, the rest of it.** Decision 93 gave a fill-up an arithmetic
check across two fields. The same shape applies three more times, and each was
a mistake nothing in the app could see:

- **A cost logged twice.** Same day, same category, same amount. Produced by a
  save retried after a timeout or a second tap on a slow button, and
  indistinguishable weeks later from two real payments — which inflates a
  total that is then believed.
- **A service logged twice.** Same day, same odometer, at least one job in
  common. Sharing *one* job is enough, because the second attempt after a
  timeout is often trimmed; sharing none is not a duplicate at all, since
  logging one visit as an entry per job is how some households keep a record.
- **A trip that implies a speed no road allows.** Distance and time are each
  plausible alone. An hour typed into a field that counts minutes only shows
  up in the pair, and a logbook's totals absorb it silently — which is exactly
  where it costs something, since the business half of that total is what a
  tax inspection reads.

**Warnings, never refusals**, on the same reasoning as 93: two parking charges
of the same size on one day are ordinary, a job genuinely done twice in a day
happens, and a trip left timing through a two-hour stop is real. The household
is the one who knows which this is.

**Bounds again deliberately wide**: 3 to 200 km/h. This is not a speeding
check, and an app that tutted at 140 would be ignored by the time it had
something worth saying.

## 96. What the car is worth is typed in, not looked up

**Roadmap item 11.** Depreciation is the largest cost of owning a car and
appeared in no figure this app printed. "€0.31/km to run" is true and
incomplete; the same car is nearer €0.44/km to *own*, and that is the number a
keep-it-or-sell-it decision actually rests on.

The roadmap named the honest options: scrape Njuškalo listings, buy a
valuation feed, or ask. **Asking wins**, and not only on cost. A scraped
listing price would be a number the app invented, sitting on the same card as
numbers the household typed, carrying an authority it has not earned — and the
scraping is fragile and legally awkward besides. A figure somebody wrote down
themselves is one they already believe.

**The date is stamped, not asked.** A valuation is always "what I think it is
worth *now*", so the form stamps today whenever the figure changes and keeps
the old date whenever it does not. Re-stamping an untouched number on every
save would make a three-year-old guess read as this morning's.

**A valuation over a year old is flagged rather than hidden.** Hiding it would
throw away a figure that is still roughly right; quoting it silently would
assert something nobody said. The line under the rate says how old it is.

**Negative depreciation is reported as it is.** A well-kept classic is worth
more than it cost. Clamping the figure to zero would make ownership look more
expensive than it was, and this app does not round in its own favour.

## 97. Two guards that read the repository rather than the app

Both are static checks in the ordinary Flutter suite, and both exist because
the real check lives somewhere a person has to remember to run.

**Every table has RLS on, and either a policy or an explicit revoke**
(`test/ci/rls_enabled_test.dart`). A table created without
`enable row level security` is readable by every signed-in user of the project
the moment a grant reaches it, and *nothing in the app would look different* —
the screens are already scoped by household in their own queries, so a
household would see exactly what it expects while every other household's rows
sat one crafted request away. `test_rls/rls_test.dart` is the real proof and
needs Docker, a Supabase stack and every migration applied. This is the half
that runs on every push.

One table is deliberately policy-free: `webhook_dispatch_config` holds a
dispatch token and is reached by a security-definer function and nobody else.
What makes that a decision rather than an oversight is the `revoke` beside it,
so the test asks for the revoke rather than keeping a list of names.

**Every `path:line` citation in `docs/` resolves** (`test/docs/citations_test.dart`).
The docs tree is written to be believed — it is what a new developer or an
agent reads *instead* of the code — and `CLAUDE.md` asks for a citation check
that lives in a skill directory outside this repository, so it runs only when
somebody remembers. This cannot tell whether line 111 still says what the
paragraph claims, but a citation past the end of a file, or at a file that was
renamed, is unambiguous rot and is exactly what a rename produces.

## 98. The edge functions deploy themselves

They were the last artefact that shipped by hand. Migrations apply through the
Supabase GitHub integration and the web app deploys from this repository, so a
function was the only thing whose deployed version could silently be older
than the code CI had just gone green on — and the failure is invisible: the
old function keeps answering, correctly, with last month's behaviour.

`.github/workflows/deploy-functions.yml` deploys all four on a push to `main`
that touches `supabase/functions/**`. Three properties are deliberate:

- **Path-filtered.** A deploy restarts the function, and there is nothing to
  gain from restarting `push-due-reminders` because a Dart file changed.
- **Checked before deploying, again.** The workflow can be dispatched by hand
  without CI having run, and `deno check` is the only thing that compiles
  these files at all: a type error otherwise reaches production as a 500 in
  front of a cron nobody is watching.
- **Skips rather than fails without its secrets.** A fork, or a clone taken
  before the account work is done, should not carry a permanently red tab over
  an account it does not have. `test/ci/deploy_workflow_test.dart` asserts the
  workflow names every function directory that exists, so a fifth function
  cannot be added and silently never deployed.

## 99. What the RLS suite caught in 94, and what it means for the next table

Documents shipped with a bug the Flutter suite could not see and the live RLS
suite caught on the first run: **a household member could not correct a
document another member had filed.**

The mechanism is worth writing down, because it applies to every table with
the `created_by = auth.uid()` insert policy this schema uses everywhere.

`SupabaseDocumentRepository.save` **upserts**. That is deliberate — one path
for "add" and "correct", and the only shape that survives a save which timed
out and was tried again, since the retry lands on the same client-minted id
(decision 79). But Postgres checks an `insert ... on conflict do update`
against the **insert** policy as well as the update one. Sending the row's
original author refused the write outright: *new row violates row-level
security policy*, on a screen with nothing to say about why.

The fix is the pattern the rest of the schema already had and this table was
missing: **send the caller's own id, and put the original author back with a
`pin_created_by` trigger** (migration 0051, mirroring 0008 and 0041). The
provenance rule and the upsert then both hold.

**The lesson for the next table is about the test, not the code.** A plain
`update` test passes either way — the update policy alone is satisfied — so
the case has to be written as *the write the app actually makes*, by *the
member who did not create the row*. The two-member shape is what made this
visible, and it is the shape to copy.

## 100. The mileage logbook prints, and names a driver it does not infer

**Roadmap item 10.** Trips already carried the private/business split,
distance, time and average speed — everything a *putni nalog* wants except a
document. `ReportKind.tripLog` is that document: every journey in a chosen
period, where it went, what it was for, who drove it, the business and private
totals, and a line to sign.

**A driver is a new field, and had to be.** `created_by` records who *typed*
the row, and the whole point of a shared garage is that one person routinely
logs the journey another one made. A logbook that names the wrong person is
worse than one that names nobody, so the app asks (`trip_entries.driver`,
migration 0052).

**Free text, not a household member.** The driver of a company van is
frequently not in the garage at all — a colleague, an employee, somebody
covering a shift — and a foreign key would have made the common case
unrecordable in order to tidy the rare one.

**Three periods, not a date range.** This month, last month, this year. A
logbook is filed monthly and reconciled yearly; a free range would be a second
dialog for a span almost nobody needs, in front of a report somebody wants
now. The month is built as day 1 to day 0 *of the next month*, which is what
stops a 31-day month quietly losing its 31st — the one day of the month a
logbook is most often printed.

**The report filters the trips itself** rather than trusting the caller to.
The totals and the rows have to come from the same list: a total that
disagrees with the rows above it is the single error a reader of this document
has no way to detect.

**What this still is not.** A real *putni nalog* in Croatia is issued
*before* a journey and carries an advance, a per-diem and an approval; this
prints what was driven, after the fact. It is a mileage logbook that satisfies
the mileage part, and calling it more than that in the interface would be a
promise the app cannot keep — which is why the English name is "Mileage
logbook" and only the Croatian one uses the phrase people search for.

## 101. What the review of 94 to 100 found

Six, and the first one mattered more than the feature it came with.

**A new table reintroduced the bug `0033` was written to remove.** Migration
`0033_account_deletion_unblocked.sql` changed every `created_by` reference to
`on delete set null` and made the columns nullable, because a `not null`
reference with the default `no action` refuses to let the user it points at be
deleted — and `delete-account` relies entirely on the cascade. It was a
one-shot `DO` block over the constraints that existed then. `vehicle_documents`
was the first table added since, wrote `created_by uuid not null references
auth.users (id)` out of habit, and broke Play-required in-app account deletion
again: silently, and **only for a shared garage**, which is the case a solo
test never reaches.

`0049` now matches every other table. The lasting fix is in the test: the
account-deletion setup files a document as well as a fuel entry
(`test_rls/rls_test.dart`), so the next table to get this wrong fails there
rather than in production. **Every table added from here should get a row in
that setup.**

**A label typed under `other` rode along on a named type.** The field only
renders for `other`, but the save wrote whatever the controller held: pick
`other`, type a name, switch back to `registration`, and the card reads as the
name. Worse, the restore keyed documents on type *and* label, so a labelled
registration slipped past a household's unlabelled one and was inserted as a
second `registration` row — refused by the unique index, aborting the whole
restore partway through, before the tyres. The restore is now keyed the way
the index is: on the type, except for `other`.

**A document with no expiry retracted a reminder it never raised.** The save
cleared the standing one-time rule unconditionally, so recording a
registration certificate with just its number took down the reminder the
*cost* sheet had raised when the registration was paid — with nothing on
screen to say why, and nothing but paying again to bring it back. It now
clears only when this document has an expiry to replace it with, or had one
and no longer does.

**Three smaller ones.** `/trips` did not expose the new `driver` column, which
is the whole point of it for anyone building their own logbook.
`/documents` had no `.limit(500)`, so its shape depended on the project's
`db-max-rows` rather than on the code, unlike its six neighbours. And the
logbook PDF printed two columns both headed "Purpose" — the journey's own
description and the business/private flag — in a document meant to be filed
with an accountant; the first is now "Details".

**The pattern worth keeping.** Four of the six are the same shape: a *new*
thing that had to repeat something an *old* migration or convention had
established, where nothing enforced the repetition. `0033` is the sharpest
example, and the answer was not to remember harder — it was to put a document
in the test that already covers the invariant.

## 102. Layout is checked by pumping at a hostile size, not by looking

A `RenderFlex` overflow paints yellow-and-black stripes on a device and
*throws* in a widget test. Nothing in this app was pumping at a size where
that happened, so the check was "somebody notices" — which is how a tab label
came back cut off after decision 82 had already fixed it once.

Every screen and sheet added here now has a test that pumps it at
`Size(320, 900)` — and the empty states at `Size(320, 640)` — under
`TextScaler.linear(2)`, and asserts `tester.takeException()` is null. Android
offers 2.0 in accessibility settings, and 320 logical pixels is the narrowest
window the app supports.

**It found one immediately**: the Documents empty state overflowed by 240
pixels, on the first screen a household ever sees there. The fix and the
reason it could not go in the shared widget are in
[known-bugs](../operations/known-bugs-and-risks.md).

**Worth doing to the older screens too**, and deliberately not done here: it
would be a separate change, and the ones it found something in would each need
a decision about how to fix them rather than a blanket wrapper.

## 103. The new screens use the adaptive system rather than a second one

An audit of the Documents screen against the window-size rules, prompted by
noticing that the app already has all of them and a new screen is exactly
where a parallel set gets invented.

**It needed almost nothing, which is the point.** `GaragePageScaffold` gives
it an app bar on a phone and a rail plus a capped column on a desktop window;
`showAdaptiveEntrySheet` makes the document form a bottom sheet on a phone and
a centred dialog on a desktop; `ContentWidth.reading` caps the list at 840,
which is what the tyres screen beside it does and for the same reason — a
document row is a name at one end and a chevron at the other, and across a
1500-pixel monitor those two ends stop reading as one row.

Three things were checked and are now asserted rather than assumed
(`test/features/documents/documents_screen_test.dart`): the list is capped on
a 1500-pixel window, a 400-pixel phone uses all of it, and the empty state is
centred **in the content area** rather than in the window — the two differ by
the 120 pixels of navigation rail, and only one of them is right.

**One thing did change.** The list was `ListView(children: [...])`, matching
its two sibling screens, and is now `ListView.builder`. Five of the six
document types are capped at one per vehicle, but `other` deliberately is not:
it is the escape hatch, and a household keeping every lease in it has a list
with no ceiling. This repo has already paid for the eager version once — "Every
log built its whole history on the first frame".

**And one thing deliberately did not.** `isWide` requires a shortest side of
600 as well as a width of 900, so a 1280 × 577 browser window gets phone
chrome. That looked wrong when the app was driven in a browser and is right:
decision 81 chose it because a Galaxy S23 Ultra in landscape is 988 wide and
still a phone in somebody's hand.

## 104. Four things a person using the app found in an afternoon

All four were reported from actual use, and all four are the same kind of
mistake: the app knew something and did not say it, or said something it did
not know.

**"Hand a vehicle to another garage" — which vehicle?** From garage settings
that button led to a screen titled "Transfer this vehicle", and *this* was
whatever the previous screen had meant. With one car in the garage nothing
asked, so the only confirmation of the subject was the code coming back — for
an act that moves a car and its whole history out of the garage permanently.
The transfer screen now leads with the same `SheetVehicleRow` every entry
sheet grew for this reason (decision 87), locked because the car is chosen
before the screen; and the button names the car when there is one, or ends in
an ellipsis when a picker follows.

**One DOT code for four tyres.** `0043` gave a set one `manufactured_on`,
which is right for four bought together and wrong for most sets that are not —
a pair replaced after a kerb, a spare rotated in, four off a shelf they had sat
on for different lengths of time. Reported by a household whose four codes are
all different. Migration `0053` adds a date per corner, matching the tread
columns `0023` already had.

Three decisions inside it:

- **The old column stays.** Migrations apply on a push to `main`; a household
  on last week's APK does not. Dropping `manufactured_on` would make that
  build's `updateSet` fail against a column PostgREST no longer knows, and
  editing a tyre set would break for everyone who had not updated. It is kept
  in step with the *oldest* corner instead.
- **The oldest corner is the set's age.** Replacing one tyre does not make the
  other three younger, and the ageing warning exists for the one that is past
  it.
- **The sheet asks once.** Four boxes to fill with the same four digits is a
  form arguing with its user, so it opens with one field and unfolds — and
  opens unfolded for a set that already disagrees with itself. Folding back up
  copies the first code to the rest rather than discarding three sidewalls.

**The quick-add offered a car that had been sold.** `_showQuickAdd` read
`allVehiclesProvider`, which includes archived vehicles, so a garage with one
car and one sold one was asked "which car?" and offered the sold one. The
vehicle row's own shortcut, four hundred lines further down the same file, had
always read the active list. Now both do.

The test harness had the same bug and was hiding it: `pumpDashboard` overrode
`vehiclesProvider` and `allVehiclesProvider` with the same list, so an
archived car behaved like an active one in every dashboard test. It now
filters, the way production derives one from the other.

**A schedule you can print.** Every report looked backwards — what was done,
what was spent. The one a person actually wants to hand a mechanic is the
*forward* one: what this car gets done and how often, the shape a
manufacturer's service sheet takes. `ReportKind.serviceSchedule` prints the
recurring rules with their intervals, when each was last done and when it is
next due, and says in a footnote that the intervals are the garage's own
settings and not the manufacturer's — which is the one thing a printed sheet
must not be mistaken for.

## 105. Empty states are drawn, and the drawing yields

The empty states were a sentence in the muted colour. That is honest and a
little bleak on the screens a household lands on with nothing yet — which is
every screen, on the first day.

**Drawn, not imported.** The identity is a dark instrument cluster (decision
73), and stock illustration — rounded, friendly, faintly corporate — reads as
another app's. A one-pixel stroke in the muted colour with a single amber
accent is the same drawing language as `GaugeArc` and the app icon, and it
costs no asset, no package and no second copy for dark mode: the colours come
from the tokens, so the light theme is free and
`test/core/widgets/empty_state_art_test.dart` asserts the file contains no hex
of its own.

Four motifs, each literal rather than clever: a sheet with a folded corner and
an amber date rule, the icon's own roofline over an empty bay, an instrument
arc at rest, and a nozzle hung up.

**It yields to the words.** On a window under 620 logical pixels tall, or at a
text scale over 1.3, the art renders nothing. An empty state is a sentence and
a button; the drawing is decoration, and decoration that pushes the message
off a landscape phone is worse than no decoration. Four screens carry a motif
— documents, vehicles, fuel, maintenance — and the other five keep the plain
sentence they had, because art belongs where somebody lands with nothing, not
on every branch that happens to return no rows.

## 106. The feature graphic is built from the app's own tokens

The 1024 × 500 Play banner predated the documents and logbook work and said
nothing about either.

**Written as HTML in the token values and screenshotted**, rather than
generated. Every colour is copied from `garage_tokens.dart`, the faces are the
app's own bundled Inter and JetBrains Mono, and the phone in it is a real card
with a real row on it — a registration expiring in 14 days above two service
items — because the product is the app and not a drawing of a phone. The
source is kept at `assets/store/sources/feature-graphic.html` so the next
change is an edit rather than an archaeology exercise.

The instrument arc behind it is the same 270° sweep, starting at the same
135°, that `GaugeArc` draws on the vehicle page.

## 107. The listing screenshots come from the web build, in the dark

The seven shots in `distribution/screenshots/phone-en/` were **light theme**,
taken in August against a build that predated the metrics strip, the "More"
tab, tank range, documents and the logbook. The store icon and the feature
graphic are dark; the screenshots were selling a different app.

**Recaptured from the web build rather than an emulator**, which is the part
worth writing down. `agent-browser set viewport 432 768 2.5` is exactly
1080 × 1920 — Play's cap is 2:1 and 16:9 is safe — and
`agent-browser set media dark` gets the identity right without touching the
app's own theme setting. The web build is the same Flutter widgets as the
Android one, so the shots are the app; only the status bar is missing, and
Play does not require it. The device route stays in the listing doc for when
system chrome has to be in frame.

Eight shots now, and the two new ones are the two features this change added:
the documents list with what runs out when, and a planner showing a document's
expiry bundled with a service into one visit.

**Taking them found a real bug.** The stations price chart printed two axis
labels on top of each other — visible only against the live Croatian feed,
because it depends on where the fortnight's high and low fall. fl_chart walks
its labels up from `minY` by the interval *and* offers positions of its own,
and on a 120-pixel band two of them landed a few pixels apart. The axis now
runs from the lowest price to the highest with no padding, and the title
widget itself refuses to render anything that is not one of those two ends —
so no arithmetic has to be exactly right for the axis to stay readable.

That is the argument for driving the app rather than only testing it: a
screenshot is a review, and this one had never been done against real data.

## 108. The dashboard opens into its own outline, not a spinner — *amends 74*

**Decision.** Startup fetches the garages and their vehicles in one embedded
select (`garageBootstrapProvider`), and the dashboard renders its own shape in
placeholders while that lands, instead of the "Opening your garage…" screen
decision 74 introduced. Everything derived from the bootstrap —
`myHouseholdsProvider`, `allVehiclesProvider` and the rest — fetches nothing.

**Why the splash went.** Decision 74 was right about what it rejected. A tab bar
over three spinners does read as a broken app, and a plain sentence was better
than that. But those were not the only two options: a skeleton with the
dashboard's real shape is neither a spinner nor a blank, it is the layout
arriving before the data. Nothing has to move when the figures land, which was
the second half of the complaint and the half no wording could fix.

**Why the fetch changed at the same time.** A nicer wait is still a wait, and
this one was structural rather than slow. `allVehiclesProvider` awaited
`currentHouseholdProvider`, which awaited `myHouseholdsProvider`, because each
call's argument was the previous call's result: three to four sequential round
trips before a first card, every cold start. `vehicles` has a foreign key to
`households` (`supabase/migrations/0003_vehicles.sql:3`), so PostgREST can
return both in one request, and it applies RLS to the embedded table exactly as
to the parent. Four tests in `test_rls/rls_test.dart` check that against a real
Postgres rather than trusting it — including as a member who created none of the
rows, and for somebody in two garages at once, which is the case where a leak
between embeds would look like ordinary data.

**The trap this created, and the guard.** Derived providers hold no request, so
`ref.invalidate(allVehiclesProvider)` still compiles, still reads correctly, and
now does nothing at all: it rebuilds against the bootstrap's cached value. Every
one of the eighteen call sites that did this was moved to the bootstrap, and
`test/ci/garage_bootstrap_invalidation_test.dart` scans the source and fails if
one comes back. A type could not have caught it, and the symptom — a newly added
car that appears only after a restart — reads as slowness, not as a bug, so it
could have lived a long time.

**What was considered and rejected.** Renaming `allVehiclesProvider` outright
would have made the compiler find those eighteen sites for free, which is
stronger than a source scan. It was rejected because the name is *read* in
another sixteen places that are all perfectly correct, and a fifty-six-site
rename to protect eighteen of them buys the guarantee once while the scan keeps
giving it. The scan is also the pattern this repo already uses for rules types
cannot express (`test/ci/domain_purity_test.dart`,
`test/ci/rls_enabled_test.dart`).

**What is still sequential.** The timeline and the reminder projections still
fetch after the household is known. They render into the skeleton rather than
blocking it, so they cost nothing before the first frame, and folding them into
the same request would mean fetching a whole timeline nobody has scrolled to
yet. Left alone deliberately.

## 109. A drive is started and finished, and a draft is a trip with no distance

**Decision.** A journey can be opened at the moment it begins — the clock is
read from the device, the odometer is one number visible from the driver's seat
— and completed when the car is parked. The unfinished state is not a new table
or a status column: **a trip whose `distance_km` is null is a drive under way**,
and filling the distance in is what finishes it.

**Why that representation.** Every alternative costs more and buys nothing. A
separate `trip_drafts` table would duplicate ten columns and then need a move
between tables at exactly the moment a person is standing in a car park with one
bar of signal. An explicit `status` column would need backfilling across every
existing row, and would let a row disagree with itself — status `open` with a
distance already in it. Nullable distance cannot disagree with itself, and it
needed no backfill at all, because every row that already exists has a distance.

**What guards it.** Two things, both in the database rather than in the app.
`trip_draft_is_started` refuses a row that has neither a distance nor a start
time, so the draft state cannot be entered by an insert that merely forgot a
field. A partial unique index on `(vehicle_id) where distance_km is null` holds
a car to one journey at a time: without it a double tap, or two members starting
a drive on the same car, leaves two drafts of which finishing either looks like
the app lost the other.

**Why not GPS.** Background trip detection stays an explicit non-goal
(`docs/roadmap.md:213`): it drains a battery and needs a permission Croatians
reasonably refuse. Two taps around a journey get most of the value with neither
cost, and this is the shape that makes the manual logbook worth keeping —
nobody remembers an hour later what the odometer said when they set off.

**Who may finish one.** Anybody in the garage. The policies on `trip_entries`
are table-level and already allowed it, and the `created_by` trigger from
decision 0041 means closing somebody else's drive does not make you its author.
That is the shared-garage case rather than an edge: one person takes the car,
another closes the logbook. Four cases in `test_rls/rls_test.dart` cover it,
including that the author survives the finish.

**The trip is dated the day it set off.** A drive over midnight belongs to the
evening it began — that is the day its driver will look for it under, and the
day a *putni nalog* names. The alternative, dating it on arrival, moves a
journey into a day the car was not driven on.

**What is deliberately refused.** Finishing with neither a distance nor an
odometer at both ends throws, and the form refuses it before the domain does.
A trip nobody measured is not a trip of length zero; a silent 0 would be
believed and would drag down every average that reads it.

## 110. A guest pass is scoped, expiring access to one car — a second tenancy model

**Decision.** A vehicle can be lent to somebody who is deliberately **not** a
member of the garage. The owner mints a code that names how long it lasts and
what its holder may do; the holder redeems it and can log against that one car
until it expires. Lending a friend your Golf and renting a car to a customer are
the same mechanism.

**Why this could not be an invite.** Household membership is permanent, covers
every vehicle, and grants the whole history. All three are wrong for a borrower.
The alternative people actually use today — typing in the borrower's fill-ups
yourself afterwards from a photo of a receipt — is the thing worth removing.

**Why the policies are additive, and never edits.** Everything in Garage keys
off `public.user_vehicle_ids()`. Teaching that function about guests would have
been a three-line change and would have silently given every guest everything a
member has, including other vehicles in the same garage. Instead there is a
parallel resolver, `public.guest_vehicle_ids(permission)`, and a parallel set of
policies added alongside the existing ones. Postgres OR-combines permissive
policies, so an additive policy can only widen access for the rows it names, and
every member policy keeps behaving exactly as its tests already assert.

**Expiry needs no scheduled job.** The resolver tests the clock, so a lapsed
pass simply stops granting anything. Nothing is deleted, which is what makes
"everything they logged stays" true by construction rather than by effort — the
confirmed product choice. The owner keeps the fill-ups; the borrower loses
sight of them.

**History is off by default.** A guest sees rows they wrote and nothing earlier.
This is the setting most likely to be wrong in practice: a fuel log showing one
entry may read as broken rather than as private, which is why the screen says
so in words. Flipping the default is one column default and no migration.

**Permissions are independent switches, not a role ladder.** Fuel, trips, costs
and history are separate columns because the useful combinations are not
ordered: a rental company wants fuel and trips but not service entries, and
somebody lending a car for a weekend wants close to the opposite.

**26 tests in `test_rls/rls_test.dart`, against real Postgres.** They prove the
narrow thing works *and* that nothing else does: containment to the one car,
history private by default, a withheld permission genuinely withheld, expiry and
revocation and not-yet-started, entries outliving access, a code refused to a
second holder but re-redeemable by its own, a member refused a pass to their own
car, no onward lending, and no membership gained.

**The anonymous half, and a correction.** This work was scoped on the assumption
that "no account required" meant rows with no `auth.uid()`, which would have
needed a second security model and was called the largest risk in the feature.
**That was wrong.** Supabase anonymous sign-in mints a real user with a real
`auth.uid()`, so an anonymous guest is an ordinary principal and every policy
above already covers it. The remaining cost is operational rather than
architectural: `enable_anonymous_sign_ins` is still **off**
(`supabase/config.toml:178`), because turning it on is a production posture
decision about rate limiting and about reaping accounts nobody will ever sign
in as again. The model is ready; the flag is a separate, deliberate act.

**Deliberately not built.** No marketplace and no booking (`docs/roadmap.md:210`),
no payments, and no route from a pass to membership — redeeming one never writes
a `household_members` row.

## 111. Startup fetches vehicles in their own right — *amends 108*

**Decision.** The startup pair is `households` and `vehicles`, two selects
issued together with `Future.wait`, rather than the single embedded select
`households` with `vehicles(*)` that decision 108 introduced.

**Why the embed was wrong.** It only nests rows under parents the outer query
returned. A car reached through a guest pass (decision 110) belongs to a garage
the borrower is not a member of, so the household never came back and neither
did the car — while a plain `vehicles` select returned it correctly, because the
policies allow it. The database was right and the app was asking the wrong
question.

**Why this is not a regression on 108.** Its point was removing a *chain*: four
requests where each needed the previous one's result. These two need nothing
from each other, so they go out together and cost one round trip's latency, the
same as the embed did.

**How it stayed hidden.** Every RLS test passed — they use the raw client. Every
widget test passed — the fake bootstrap is built from a list, not a query.
Nothing was red, and the feature was simply invisible in the UI. The rule
CLAUDE.md already states, *write the test as the read the app actually makes*,
is the one that would have caught it, and it now has such a test.

**Borrowed is derived, not fetched.** A vehicle whose household is not among the
ones returned is one reached through a pass. That keeps the rule in a single
place and needs no third request. Borrowed cars are deliberately kept out of
`allVehiclesProvider`: a car somebody lent you is not part of your garage, must
not enter its totals, settlement or statistics, and leaves when the pass does.

## 112. The longest-standing member inherits the garage

**Decision.** When a garage would be left with no admin, the longest-standing
remaining member is promoted automatically. Enforced by two triggers on
`household_members` — after a delete, and after a role update — both calling
`ensure_household_has_admin`.

**The bug it fixes.** Creating a garage made you its admin, and nothing else
did. An admin leaving, or deleting their account, therefore left a garage that
was fully populated and permanently unadministrable: the survivor could not
rename it, remove a member, delete it, or promote themselves, and the only
person who could promote them was gone. The path in is the most ordinary one
there is — two people share a garage, the one who created it leaves.

**Why longest-standing rather than newest.** The person who has been in the
garage longest has the most history in it and is the likeliest owner of what is
in it. On the common two-person garage there is exactly one candidate anyway, so
the rule only has to be defensible in the rare case, not clever. `user_id`
breaks a tie, so the result is deterministic rather than whatever the planner
happened to return first.

**Why not ask the user.** There is nobody to ask. The admin is leaving — often
by deleting their account, at which point no UI of theirs will ever run again —
and the survivor cannot be prompted for a decision at a moment they are not
present for. An automatic rule that is occasionally not what a garage would have
chosen beats a garage that is permanently stuck.

**Why a database trigger and not app code.** The membership row can disappear
through leaving, through an admin removing somebody, or through account
deletion in an edge function. Only the database sees all three. Putting the rule
anywhere else means one of those paths silently skips it.

**Ordering, which is load-bearing.** `household_members_cleanup` deletes a
household whose last member has left. The succession trigger is named to sort
after it — Postgres fires same-event triggers in name order — and
`ensure_household_has_admin` also returns early when no members remain, so a
household being torn down is never repopulated by the promotion.

**The migration backfills.** Garages stranded before this shipped cannot recover
on their own, because no future event fires for them. The migration promotes an
admin in each one as it applies, which is why the fix could not be code alone.

**Still deliberate:** making a *second* admin. Succession only fires when the
count would otherwise be zero.

**Not addressed here:** merging two garages into one — moving vehicles and their
entire entry history between households, with attribution intact. The vehicle
transfer code is the seed of it. That is its own piece of work.

## 113. A garage can have more than one admin

**Decision.** Admins may promote and demote members, so a garage can have
several. Enforced by `members_update_by_admin`
(`supabase/migrations/0058_member_roles.sql`).

**What was there before.** There was **no update policy on
`household_members` at all**. The creator was the admin and the role could
never change. Two parents sharing a garage had one permanently in charge and
the other permanently not, and a teenager could not be given a member account
that was deliberately *less* than admin, because everyone else already was one.

**Why it went unnoticed.** PostgREST reports a row RLS filtered out as *zero
rows updated*, not as an error. An app that tried to promote somebody would
have looked like it worked and changed nothing. It also meant two tests written
for decision 112 passed for the wrong reason: both set up a second admin, or
demoted one, with an update that silently did nothing, and their assertions
happened to hold either way. Both now assert the precondition.

**Stepping down has to actually step down.** The succession rule from 112
promotes the longest-standing member, and an admin demoting themselves is
usually exactly that — they created the garage — so the trigger handed the role
straight back and "step down" was a no-op. Whoever gives the role up is now
excluded from inheriting it, unless there is nobody else, in which case they
keep it rather than the garage going adminless.

**A trap worth remembering.** `create or replace function` with a new parameter
creates an *overload*; it does not replace anything. Every existing caller then
fails with "function is not unique". The single-argument version had to be
dropped explicitly, and its trigger function repointed at the new signature.

## 114. Merging two garages is an absorption

**Decision.** `merge_households` empties one garage into another and deletes
it. One RPC, one transaction, admin of both required.

**Why absorption rather than a new third garage.** A new garage would leave
both originals to clean up and doubles the number of things that can
half-happen. The survivor keeps its own settings, and after the merge nothing
records which car came from where — that is inherent, not an omission.

**Currency is refused, not converted.** Money is stored as a bare number and
the currency lives on the garage, so merging across currencies would reinterpret
a whole history at a stroke — a 12,000 HRK repair reading as €12,000. Distances
and volumes are safe, being stored canonical. Conversion was considered and
rejected: one rate applied across years of history is wrong in a quieter way
than refusing is, and refusing has an obvious remedy the user can take first.

**Everything keyed to a vehicle comes free.** Fuel, services, costs, income,
trips, odometer readings, tyre sets, documents, reminder rules, attachments and
any guest pass already handed out all key off `vehicle_id`, so a `household_id`
update carries them. Attachments in particular are stored under `<vehicleId>/`
and need no attention at all.

**Photos are the exception, and they set the ordering.** A vehicle photo lives
under its *garage's* storage prefix — which is why `redeem_vehicle_transfer`
simply nulls it. A merge cannot afford that, so the app copies each photo into
the surviving garage's prefix first. It must be first: the moment the merge
lands the absorbed garage is gone and its prefix stops being readable, so a
photo not copied by then can never be copied. That is also why the currency
check is repeated client-side — a refusal after the copying would leave photos
moved for a merge that never happened. A photo that fails is counted and
skipped; a lost picture is worth less than a garage left half-merged.

**People move keeping their role.** Without them the history survives with its
authorship unreadable: a profile is only visible to fellow members, so entries
they wrote would show an unattributed id.

**API keys and webhooks are revoked, not inherited.** A key minted to read one
garage would, after the merge, read every car in the combined one. Breaking a
script loudly beats broadening a live credential quietly. Invites and
outstanding transfer offers go the same way, by cascade, since both would
otherwise point at a garage that no longer exists.

**Not built:** splitting a garage back apart. Nothing records the seam, and
inventing one to support an undo nobody has asked for would cost every future
merge.

## 115. A write the network could not carry is kept, not lost

**Decision.** Fuel entries and odometer readings are queued on the phone when
the network fails, and replayed on their own. Built as **decorator
repositories** wrapping the Supabase ones, so nothing above the data layer
changed — the entry sheets save, close, and are right to.

**Why a decorator rather than something the sheets call.** Every screen in this
app already reads providers over a repository *interface*; that seam was built
for tests and turns out to be exactly the seam a queue wants. The alternative —
each sheet asking a queue whether to save locally — would have put the same
five lines in seven places and made the offline path something a new sheet
could forget.

**Only `network` and `timeout` queue.** Everything else is the server
answering. Queueing a refusal would replace a message somebody could act on
with an entry that silently never arrives, which is the worst outcome available
to a feature like this. `timeout` queues despite the write possibly having
landed, and that is safe because the entry carries its own id: a replay is the
same row, which is the rule `writeNew` already relied on.

**Terminal failures are dropped, loudly.** `permission`, `auth`, `notFound` and
`invalid` will fail identically forever — the car was handed to another garage,
the session is gone. A queue that retries those is a bug that grinds a battery
flat, so they are removed and counted, and the retry screen says how many. A
write that fails 25 times in some unforeseen way goes the same way.

**Replay stops at the first connection failure.** There is one network. If the
first write cannot reach the server, neither can the next twenty, and marching
through them costs a battery to learn nothing.

**Reads are deliberately not cached.** Offline, a list fails as it always did.
Returning just the unsent entries would hand back something that looks like a
vehicle's history and is not — a worse lie than an error. What a queued entry
gets instead is a **merge into a read that succeeded**, deduped on its own id,
so it appears immediately and cannot double once the server has it. Caching
reads properly would also contradict the realtime decision that refetching
cannot drift while a second local copy can; that is a bigger argument for
another day.

**Photos are kept too**, in the app's own directory, uploaded after their
entry. The web has nowhere private to keep one, so there the photo is refused
with its original failure while the entry still queues —
`QueuedFileStore` is a seam behind a conditional import, because `dart:io`
reaching the web compiler is a mistake only `flutter build web` catches, and
this repository has made it once already.

**`AttachmentQueued` is not an `AppFailure`.** An upload returns a value, so
the decorator cannot quietly succeed, and the widget must say something
different from "that failed" — because nothing did.

**Scope, deliberately.** Fuel and odometer only; new entries only, not edits or
deletes; and no offline reads. Edits raise a conflict question nothing else in
the app answers, and the two entry kinds chosen are the ones actually typed
away from a desk. The pattern is proven on those before it spreads to the other
five repositories that already mint client ids.

