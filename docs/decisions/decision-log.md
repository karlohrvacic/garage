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
(`lib/core/notifications/notification_providers.dart:51`). The server is the
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
