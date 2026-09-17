# Known bugs and risks

What is broken, thin, or sharp enough to bite. Read this before trusting anything
in production.

Severity means:

| | Meaning |
|---|---|
| **Critical** | Data loss, or one household's data reachable by another |
| **High** | A feature is broken or unavailable for a whole class of users |
| **Medium** | Works, but wrong or confusing in a way people will hit |
| **Low** | Annoyance, or a trap for the next developer rather than a user |

Last reviewed: 6 September 2026.

---

## Open

### The dashboard logs a "setState during build" from its reminder listeners

Seen once in a debug web build, at the moment the first vehicle was saved:
Flutter's "setState() or markNeedsBuild() called during build" assertion,
pointing at the `ref.listen(bundlesProvider, …)` block in
`lib/features/dashboard/screens/dashboard_screen.dart`. Debug-only red box in
the console, no visible break, but it lands in `garage.failure`. Not
reproduced on a second run and not understood: the listener's own work
(`syncNotifications`) returns immediately on web, so whatever marks a widget
dirty is upstream of it, in how a provider invalidated by the vehicle save
notifies a listener registered during a build. Worth a look with Riverpod's
`ProviderObserver` the next time it fires; do not "fix" it by wrapping the
listener in a post-frame callback without knowing what it is deferring.

**The harness that was missing now exists, 6 September 2026, and the assertion
still does not fire.** `test/features/dashboard/dashboard_live_providers_test.dart`
pumps the dashboard over the **real** provider graph with only the repositories
faked, and drives the exact sequence that produced it: a car appears in
startup's fetch and `garageBootstrapProvider` is invalidated under a mounted
dashboard. No assertion, and the screen updates. So the bug stays open and
unexplained, but the listeners it lives in are covered for the first time — the
projection chain resolving, and the notification sync actually being reached.

Building that harness cost seven repository fakes, and the reason is worth
knowing: `odometerSamplesProvider` merges **every** source that records a
reading — fuel, services, costs, standalone readings, trips, income — and the
seasonal-swap rule asks the tyre repository what the car is shod with. Miss one
and the whole projection chain lands in `AsyncError`, the listeners never fire,
and a test that looks like it covers them covers nothing. The test asserts the
projections resolved, for exactly that reason.

**Attempted again, 4 September 2026, and not reproduced — with a reason worth
writing down.** The dashboard's own harness cannot produce it: `pumpDashboard`
(`test/features/dashboard/dashboard_screen_test.dart:133`) overrides
`bundlesProvider`, `householdProjectionsProvider`, `allVehiclesProvider` and
every provider they derive from, so the listeners fire against futures the test
supplies and never against the real graph being invalidated mid-build. Any
reproduction needs a harness that drives the actual providers from fake
*repositories*, which no screen test in this repo does. That is the work, and
it is worth more than the assertion: it is the only way any of these listeners
gets tested at all. The mitigation was deliberately **not** applied — the code
works, the assertion is debug-only and invisible to users, and deferring a
notification sync without knowing what it defers risks a feature that cannot
be verified without a device.

### The sign-in spinner ran for a minute after a sign-out, once

On the first sign-out → sign-in of a headless-browser session the Sign in
button was already spinning before anything was typed, and a wrong password
took between 60 and 90 seconds to be refused; the same request through curl
took 0.18 s. A clean browser session refused it in 0.3 s and the sequence did
not reproduce. Filed as unconfirmed rather than fixed: it may be the browser
(the same session later crashed a tab) or the auth state carried over from the
signed-out session. If a person reports a stuck sign-in right after signing
out, this is the trail.

### On a desktop window the dashboard once showed "—" for its totals

Seen once in the third walk at 1280 × 800 after a twenty-second spinner: the
metrics strip showed "—" for total spent while the phone layout showed
€61.63, and the vehicle card had no odometer. Not reproduced; may be a
partial load in a headless debug session. Unconfirmed.

### Vehicle page loose ends from its first critique

Found by the September 2026 critique of the vehicle page, planner and
statistics: everything it raised is addressed in decision 82, including the
two that were open longest (the economy ring's unstated reference and the
reminder form not prefilling "last done"). One item in the report was
mistaken: one-time reminders do show a progress bar, since it is `dueness`,
defined for a date-only rule, not `fractionConsumed`.

### An attachment can still be orphaned, in two narrow cases
**Low.** A receipt can be attached before its entry is saved, and the sheet
deletes what it attached when the entry never happens (decision 90). Two
paths leave a file behind on purpose:

- **A save that timed out.** The request may have landed, so the cleanup
  stands down rather than risk deleting a receipt off a real entry.
- **A save that was refused.** Same rule: a write was attempted, so nothing
  is deleted.

Nothing sweeps orphans — `entry_id` has no foreign key and there is no job —
so they sit in the bucket. A periodic sweep of attachments whose entry does
not exist is the fix if the bucket ever grows enough to matter.

**Deleting an entry used to leave its attachments too, and no longer does**
(6 September 2026). That one was not narrow: it was every deletion of a
fill-up, a service, a cost or a document, and it contradicted `PRIVACY.md`,
which says attachments are deleted with the entry they belong to — a claim the
Play listing links to. `sweepAttachments`
(`lib/features/attachments/providers/attachment_providers.dart:74`) now runs at
all seven delete sites, **after** the entry is gone, so a failed entry deletion
never takes files with it. A failed sweep is recorded and swallowed: the
deletion the user asked for has already happened, and the leftover is a storage
cost rather than something they can act on.

`test/ci/attachments_swept_test.dart` fails any screen or sheet that deletes an
attachment-bearing entry without sweeping. Both directions of this bug are
invisible — the entry disappears, the file stays in a private bucket, and
nobody sees either — so the delete sites are checked rather than trusted.

### 0. Attachment uploads can fail at the TLS layer
**Medium.** Reported from the field, with the log the new Diagnostics screen
made it possible to hand over:

```
network: ClientException: SSLV3_ALERT_BAD_RECORD_MAC, error 268436476,
uri=…/storage/v1/object/attachments/…
```

(The alert also names a line inside BoringSSL's own TLS record code, which is
where the check failed, not anywhere in this repo.)

`BAD_RECORD_MAC` means a TLS record failed its integrity check. Nothing was
refused and nothing was decided — the connection went wrong in transit, below
HTTP, so the app's "no connection" message is accurate even though it reads
like a diagnosis. In the wild the usual causes are environmental: a middlebox
or proxy rewriting TLS, a captive portal, a VPN, or a flaky link.

**What was done:** the upload is retried up to three times on a fresh
connection (`lib/core/errors/retry.dart:24`), against the same storage path
with `upsert`, so an attempt that reached storage and lost its response is
overwritten rather than orphaned. Only `AppFailureKind.network` is retried —
repeating a refusal only wastes the user's battery to be told the same thing.

**What is unproven:** whether retrying is enough for the reporter's network,
and whether the cause is that network at all. Worth asking for: does it fail on
mobile data as well as Wi-Fi, and on another network? That distinguishes an
environmental problem from a device or server one, and nothing in the app can
tell them apart.

**Not the cause, but fixed alongside:** nothing checked the file size, while
the bucket caps at 10 MB and a phone photo routinely exceeds it. An oversized
body has its connection cut rather than earning a clean refusal, so that failed
the same way and was equally unactionable. It is now refused on the device with
the size and the limit named.


### 0. The confirmation-link redirect is unverified against the live project
**Update, August 2026.** The Android half of this is now structural rather than
configuration: the emailed link points at `garage.hrva.cc/auth/confirm` and
carries the token hash, so it is an app link the manifest claims and the tap
opens the app. That also removes the cross-device PKCE problem described below,
since `verifyOTP` needs no verifier from the phone that registered. What is
still unverified is the dashboard side — **the templates must actually be
pasted into Authentication → Emails**, and the Site URL must be
`https://garage.hrva.cc`, or `{{ .SiteURL }}` interpolates to something else
and every link in the email points at the wrong host.

**High.** Sign-up now passes `emailRedirectTo` explicitly
(`lib/features/auth/data/supabase_auth_repository.dart:34`) so the destination
is visible in code rather than only in a dashboard. **Supabase ignores it
unless the URL is in the project's redirect allow-list**, falling back to the
Site URL — so this is only half a fix until someone checks
*Authentication → URL Configuration* and confirms both the Site URL and
`https://garage.hrva.cc/` are listed.

The reported symptom was a **blank page** at garage.hrva.cc after following the
link. Two different causes produce that and they need telling apart:

- The redirect carries an *error* rather than a session (expired link, already
  used, wrong flow). That is now visible — the sign-in screen says the link
  failed instead of showing a bare form — but only once this ships.
- The page genuinely renders nothing, which would be a Worker or build problem
  and has nothing to do with auth. Check the browser console before assuming
  the first.

There is also a flow mismatch worth knowing: registering on Android and opening
the link on a laptop cannot complete a PKCE exchange, because the verifier is
on the phone. If the project uses PKCE for email links, that path fails for
everyone who reads mail on a different device — which is most people.


### 1. Invite-link verification is unproven until the next web deploy
**Medium.** `web/.well-known/assetlinks.json` now carries the real Play App
Signing fingerprint, but nothing has served it yet. Two things make this fail
quietly rather than loudly:

The Worker sets `not_found_handling: single-page-application`, so a missing path
returns **200 with `index.html`**. Today `curl https://garage.hrva.cc/.well-known/assetlinks.json`
returns HTML with a 200, which is what "not deployed" looks like — and it is
indistinguishable from success to any check that only reads the status code.
Android fetches HTML where it expects JSON and declines to verify without
reporting anything to the app. Check the body, not the status.

The fingerprint published is the *App signing* key. A locally built debug or
profile APK is signed with the debug keystore, so it will never verify on this
machine; that is expected, not a regression. Fire the intent directly at the
package to exercise the routing.

Neither blocks a release: an unverified link opens the web app, which is the
intended fallback for someone without the app. The verification steps are in the
[listing doc](../play-store-listing.md).

`test/ci/invite_links_test.dart` keeps the link, the intent filter and the
assetlinks file agreeing on host and path, and asserts the fingerprint is 32
upper-case hex bytes rather than a placeholder, since a rename or a bad paste in
one of the three is otherwise invisible until someone follows a link.

### 2. Push is finished in code and switched off in the world
**Medium.** Every piece is now written: the token registers, the function sends,
the device displays what arrives, and settings say which mode is in force. What
is missing is account work nobody can do from the repo — a Firebase project,
five values, `supabase functions deploy push-due-reminders`, and the cron row.
Until then `PushConfig.isConfigured` is false, the receiver is a no-op, and
reminders stay per device. [RUNBOOK-push.md](../RUNBOOK-push.md) is the whole
list.

**Do not do half of it.** Configuring Firebase makes the app stand its local
scheduling down in favour of the server
(`lib/core/notifications/notification_providers.dart:117`), so a build with the
dart-defines but no scheduled cron sends nobody anything — worse than not
starting. The runbook does both in one sitting for that reason.

### 3. Reminders are per device until push is switched on
**Medium.** A household member who did not create a reminder never hears about
it, which undercuts the shared-household premise. This is decision 5 in the
[decision log](../decisions/decision-log.md), recorded here because from a
user's point of view it is indistinguishable from a bug.

What changed: the app now **says so** rather than leaving people to guess —
Settings → Reminders reads "Only this device is notified", and flips to
"Everyone in this garage is notified" the moment push is real. The silence was
the worse half of this, and it is closed. The limitation itself ends with
item 2.

### 4. An assumed driving rate is now named where it is used

**Closed, recorded because the shape recurs.** A vehicle with fewer than two
odometer sightings has no rate to measure and falls back to 30 km/day
(`lib/domain/maintenance/reminder_projection.dart:111`).

The maintenance screen has said which it is using for a while
(`maintenanceRateAssumed` / `maintenanceRateMeasured`). What still did not was
the **tyre wear estimate**, where the two halves have different standing: the
distance left is a measurement — tread lost over kilometres actually driven —
while the date is that distance divided by the driving rate. Substituting the
fallback produced one sentence, "About 22,000 km left, around 3 June 2028", in
which half was measured and half was invented.

`TyreWearProjection.projectedReplacementDate` is now nullable and null when
there is no measurable rate, and the card falls back to
`tyresWearEstimateDistanceOnly`. No fallback is substituted there, unlike the
maintenance projector, because that screen has a banner to explain itself and
this one has nowhere to put one.

**What to check when adding the next projection:** whether every number in the
sentence has the same standing. Mixing a measurement and an assumption in one
line is invisible to the reader and to the tests.

### 5. Two fuels still share one distance, and now the screen says so

**Half closed.** Each fuel gets its own chain of full tanks, so a petrol figure
is computed from petrol volumes alone. What no app can fix from this data is
that the chains overlap: an LPG span from 1000 to 1500 km includes whatever was
driven on petrol in between. Each figure approximates that fuel's consumption
over a period rather than measuring it.

That much is unfixable without per-fuel odometer tracking nobody is going to
type in. What *was* fixable is that the card stated two confident numbers and
none of the caveat; `economyByFuelOverlap` now sits under them
(`lib/features/vehicles/screens/vehicle_detail_screen.dart`).

### 6. Realtime now covers the household surfaces too

**Closed in `0042`.** The publication carries vehicles, all six entry kinds,
reminder rules, attachments, tyre sets, vehicle transfers, and now **invites,
api keys and webhooks** — the three a household actually revokes, where a code
still reading as live on a second device is backwards for the half of issuing
you do because it reached somebody it should not have.

Still outside it: `attachments` and `tyre_sets` are published but nothing
subscribes, and `tyre_readings` is not published at all.

`vehicle_transfers` was added in `0034` for a reason worth generalising: **you
are never told about a row leaving your scope.** A redeemed transfer moves the
vehicle to the buyer's household, so the seller's policy rejects the very
update that would have told them, and the car simply stopped appearing —
eventually, and never with an explanation. Anything that moves a row *between*
households needs a second, staying row to carry the news.

Worth knowing for the next entry kind: **four places have to be told about it**
— the realtime publication, `replica identity full`, the webhook trigger, and
the `entryKinds` map in `dispatch-webhooks`. Missing any is silent.
`test/ci/realtime_replica_identity_test.dart` now covers the first two.

### 7. Release notes and store copy sit outside the tested strings
**Low.** `distribution/whatsnew/` and [play-store-listing.md](../play-store-listing.md)
duplicate feature names that also exist in the ARB files, and no test relates
them. A rename reaches users inconsistently.

**The length half is closed** — `test/ci/deploy_workflow_test.dart` now caps
the full description at Play's 4000 characters as well as the release notes at
500. All three languages sit near the cap, Italian 34 characters under it, so
the next feature worth a sentence has to mean trimming one.

**The vocabulary half bit on 17 September 2026.** Decision 153 moved the app's
Croatian to *ti* and a test holds the ARB files to it; the Croatian listing went
on saying *vi*, *tankiranje*, *kućanstvo* and *nadzorna ploča* for a fortnight,
because nothing reads the store copy. It was caught by rewriting the listing for
the launch (decision 158), not by a guard, and the next rename will drift the
same way.

**Two entries removed from this list on 4 September 2026, both already
closed in code and still listed here as open:** `lib/domain/` purity is
enforced by `test/ci/domain_purity_test.dart`, and the store-copy length by
the test above. This is the failure mode the doc itself warns about, one
level up: a list of open problems that keeps a solved one is believed the
same way a stale citation is.

### 8. Nothing in this repo can run the launcher entry points
**Medium, and unproven rather than broken.** The app-icon shortcut and the
home-screen widget (decision 58) are native. `flutter test` cannot reach them,
and `test/ci/launcher_entry_points_test.dart` only reads the files and checks
they agree. What that leaves untested, in the order it would be noticed:

- **Whether the widget renders at all.** Its layout, drawable and provider info
  compile into the APK — `flutter build apk` was run — but nothing here places
  it on a home screen. A `RemoteViews` layout that uses an unsupported view or
  attribute fails at inflation time, in the launcher's process, showing "Problem
  loading widget" and logging nowhere the app can see.
- **Whether the shortcut appears.** Static shortcuts need API 25 and are parsed
  at install time; a malformed one is dropped with a log line and an empty
  long-press menu, which is also what a device below API 25 shows.
- **Whether a cold start delivers the intent.** The URL only becomes a route if
  `flutter_deeplinking_enabled` is honoured and go_router reads the platform's
  initial route. That path is exercised in production today by `/join` and
  `/auth/confirm`, so it is the least doubtful of the three — but it has been
  exercised on a *warm* app as often as a cold one, and `taskAffinity=""` plus
  `singleTop` plus `FLAG_ACTIVITY_NEW_TASK|CLEAR_TOP` is not a combination
  anything here has watched resolve.

**Worth doing once on a device:** long-press the icon, place the widget, then
`adb shell am start -a android.intent.action.VIEW -d https://garage.hrva.cc/log/fuel cc.hrva.garage/.MainActivity`
with the app killed, and again with it open on another tab.

### 9. `flutter_deeplinking_enabled` was relied on without being set
**Low, now closed, recorded because the failure mode is invisible.** Every link
into the app — invites, confirmation mails, and now both launcher entry points
— depends on Flutter turning the intent's data URI into the initial route. The
manifest never said so; it worked on the engine's default. When that flag is
off nothing errors: the activity starts, the URL is dropped, and the app opens
on the dashboard, which is exactly what a successful launch looks like. It is
now written down in the manifest and asserted by
`test/ci/launcher_entry_points_test.dart`.

### A failed provider is `AsyncLoading` carrying an error, not `AsyncError`
**Was a trap, caught in the writing.** `QuickFuelScreen` decides what to do the
moment the garage stops loading, and the first version asked with a pattern
match — `AsyncData` for the value, `AsyncError` for the failure. The failure
branch never ran. In Riverpod 3 a provider whose *first* load throws settles as
an `AsyncLoading` **carrying** the error, so the class never becomes
`AsyncError` and a screen waiting for it waits forever: here, a launcher
shortcut that opened a blank page and stayed on it. Ask `hasValue` and
`hasError`, not the class (`lib/features/fuel/screens/quick_fuel_screen.dart:70`).

Two neighbours of the same version, worth knowing separately:

- **`ref.read(someProvider.future)` from a callback tears the fetch down.**
  Every provider auto-disposes in Riverpod 3, so a bare read with no listener
  disposes the provider mid-flight and the await never returns — it fails with
  "disposed during loading state, yet no value could be emitted", *after* the
  test that provoked it has finished. Watch it in `build` instead.
- **`AsyncValue.valueOrNull` does not exist here**; it is `.value`, and `.value`
  returns null on an errored state (only `requireValue` throws), so a null
  check after it swallows the error as "not loaded yet".

### An unknown stored drivetrain, kind, final-drive or fuel key blanks its dropdown
**Low.** The vehicle form's timing-drive, gearbox and fuel pickers are
`DropdownButtonFormField`s (`lib/features/vehicles/screens/vehicle_edit_screen.dart`),
which assert in a debug build and render blank in a release one when the stored
value matches none of the items. For a key this version does not know,
`drivetrain_labels.dart` and `fuel_type_labels.dart` fall back to the raw key,
which protects display, not the field's selected value. For `timing_drive` and
`transmission` this is unreachable while the check constraints from migration
0046 hold, since nothing can store a key the form does not offer. `fuel_type_key`
has no such guarantee: migration 0031 constrains it only to a regex, so a backup
restored from a newer build, or a newer app in the same household, can store a
fuel key this build's list lacks, and this build's form then shows the blank
field. Widening a constraint, or adding a fuel key, means also adding a
pass-through item for the stored key, or the older build shows an empty field
and saves whatever it was told.
The same applies to `kind` and `final_drive` from migration 0047, guarded by
their own check constraints; decision 71 anticipates a newer build adding a
kind, which is exactly the case that reaches this.


### The stations price chart printed two axis labels on top of each other
**Closed, recorded because only real data showed it.** `PriceTrendChart` set
its axis to the fortnight's range padded by a tenth and its label interval to
the unpadded range. fl_chart walks titles up from `minY` by the interval *and*
contributes positions of its own, so on a 120-pixel band two of them could
land a few pixels apart and overprint.

Whether it happened depended on where the high and the low fell, which is why
no test and no screenshot with fixture data ever showed it — it appeared the
first time the screen was driven against the live Croatian feed, while taking
store screenshots.

The axis now runs from the lowest price to the highest, and
`getTitlesWidget` renders nothing for any value that is not one of those two
ends (`lib/features/stations/widgets/price_trend_chart.dart:85`), so the
arithmetic no longer has to be exactly right for the axis to be readable.
`test/features/stations/price_trend_chart_test.dart` covers both.

### `EmptyState` overflows at twice the text size on a short window
**Low, closed on one screen and open on the other nine.** The shared empty
state (`lib/core/widgets/async_value_view.dart:66`) is a `Column` in a
`Center` and does not scroll. Its message is a sentence — sometimes two — and
at a text scale of 2 on a 320 × 640 phone the Documents one overflowed by
**240 pixels**, on the first screen a household ever sees there. Android goes
to 2.0 in accessibility settings, and this is exactly the class the tab-label
fix (decision 82) was about.

**The obvious fix does not work.** Wrapping the widget's own body in
`LayoutBuilder` + `SingleChildScrollView` — centred when it fits, scrollable
when it does not — breaks the stations screen, which puts `EmptyState` inside
a `SliverFillRemaining` that measures its child: *"LayoutBuilder does not
support returning intrinsic dimensions."* Caught by the suite immediately, and
worth writing down because it is the natural first attempt.

The wrapper therefore lives on the Documents screen
(`lib/features/documents/screens/documents_screen.dart:87`) and nowhere else.
The other nine callers keep the behaviour they have had all along.

**What closing this properly needs:** either the stations screen stops using
`SliverFillRemaining` for its empty state, or `EmptyState` gains a scrolling
variant the sliver case opts out of. Neither is hard; both change screens this
change had no other reason to touch.

**And how it was found**, which is the reusable part: pumping the screen at
`Size(320, 640)` with `TextScaler.linear(2)` and asserting
`tester.takeException()` is null. A `RenderFlex` overflow throws in a test
rather than painting stripes nobody in CI can see, so it is checkable — the
new screens and sheets now all have such a test, and nothing else in the app
does.

### A `created_by` on a new table can break account deletion, silently
**Closed for `vehicle_documents`, recorded because the shape recurs.**
`0033_account_deletion_unblocked.sql` made every `created_by` reference
`on delete set null` and nullable, because the default `no action` refuses to
let the referenced user be deleted and `delete-account` relies on the cascade.
It was a one-shot pass over the constraints that existed then.

`vehicle_documents` (`0049`) was the first table added since and got it wrong,
which would have broken Play-required in-app deletion again — **only for a
shared garage**, because a solo household's rows are already gone by the time
the reference is checked (the member cascade drops the household, which
cascades through vehicles). Nothing in the app or the Flutter suite could see
it.

**What to copy, not just what to fix:** the account-deletion setup in
`test_rls/rls_test.dart` now files a document as well as a fuel entry. Every
table added from here should get a row there, and then the invariant is
checked rather than remembered.

### A document's expiry and a paid-for renewal write the same reminder
**Low, and deliberate — recorded because it looks like a bug.** Recording a
registration certificate with an expiry and logging the registration *payment*
in the cost sheet both write a one-time `reminder_rules` row of type
`service_registration`, and each clears the outstanding one before writing its
own. Whichever was saved last is the rule that stands.

That is the intended behaviour (decision 94): the two are halves of one fact,
and two rules of the same type standing side by side would be worse — one of
them permanently wrong and neither identifiable as the stale one. But a
household that pays in January and records a certificate expiring in June will
see the reminder move when either is edited, with nothing on screen saying
why.

**What to check if this is ever reported:** which of the two was saved last,
not which is correct. The document is the better source, so the failure worth
fixing would be a cost edit overwriting a document's date — not the reverse.

### The service-entry sheet blanks its type picker on a fetch error
**Low.** `service_entry_sheet.dart` reads
`availableServiceTypesProvider(vehicleId).value ?? []`, so an error in the
household, service-types or vehicle fetch shows an empty dropdown with no
message. The pattern predates this change; what is new is that the family now
also depends on the vehicle list, so there is one more fetch that can fail into
it. Unlikely in the app, because the screen that opens the sheet has already
loaded the fleet, but the sheet itself says nothing when it happens.

### The app's own reminders count from today, and can repeat daily

**Medium where push is off, which is everywhere today.** The projector dates a
distance-based reminder from today
(`lib/domain/maintenance/reminder_projection.dart:197`), so between readings
its date moves with the calendar. Every launch re-plans every notification, and
the notification id includes the due day, so at exactly 7 or 30 days out, or
closer, a phone opened daily is shown the same notice each day. The server had
the same shape and was fixed by counting from the reading's day (decision
168). Doing that here moves every projected date in the app and lets a car
nobody has logged for a while read as overdue by estimate, so it waits for a
product decision rather than a patch.

### Small things the launch work left, 17 September 2026

Everything the launch review found was fixed the same day and is under
"Recently fixed". These are what that work noticed and left.

- **Low: editing a fill-up in a gallon garage rewrites its litres**, rounded to
  a hundredth of a gallon, even when only the note changed. Older than the
  per-fill-up units of decision 169, which kept it as it was.
- **Low: the pump match only looks at forecourts that sell the car's main
  fuel** (`lib/features/fuel/providers/pump_providers.dart:30`), so a plug-in
  hybrid at a charger, or a petrol-and-LPG car at an LPG-only station, is not
  recognised.
- **Low: statistics by station can list one forecourt three ways.** Fill-ups
  saved before decision 161 say "PM ZAGREB, …", those saved before 170 say
  "Petrol ZAGREB, …", and new ones say "Petrol". Nothing rewrites the old ones;
  editing one does.
- **Low: every webhook subscribes to every event.** The app's form offers no
  choice (`lib/features/api/screens/api_access_screen.dart:194`), so a hook
  pointed at a chat now also gets two reminder messages per job. Since
  `reminder.due` is sent (decision 168) that is a feature to design, not a
  label to fix.

### The seventh critique: a findability walk, 14 September 2026

Twenty-three everyday tasks walked from the dashboard by tap count and label,
from the route table and the screens rather than by hand on a phone. The
report is in `docs/superpowers/critiques/` (outside git). The first pass is
decision 156; what it did not take on, ranked:

- **High, deliberately deferred.** The vehicle tabs do not say what they hold:
  "Reminders" still carries tyres, documents, parts, trip prep, problems and
  recalls (under a "This car" heading now), and a re-cut into Fuel, Upkeep,
  Car and Costs moves where everything on the car lives. Its own decision.
- **Medium.** Nothing on the dashboard or list card says a car is out on
  loan; only its own page does. A garage-wide passes query is the missing
  piece.
- **Low.** The dashboard's "Recent activity" rows all open the top of the
  Timeline and its "Average" tile is inert; each vehicle tab adds entries a
  different way (Costs has a pinned row, the rest a floating button); two "By
  station" cards share one statistics tab; the Tyres screen alone does not
  name the car.

**Fixed in decision 156:** fill-ups on the Economy tab with their economy,
the fuel log one tap below and the tour's "Fuel log" row pointing at it;
"Start a drive" on the car's page and in "+"; the running-cost card on Costs;
"Services" as the third tab; one name for the due list and one verb for
logging; the loan banner on the car's page; the tour's "Lend a car" row
opening the car's lending page.

Decision 75 acted on the last findability table; this is the same method
several releases later.

---

## Recently fixed, worth remembering

### A borrower could read what the owner paid for the car

**Was Medium, and the one to fix before lending is used by strangers.**
`vehicles_select_guest` granted a pass holder the whole `vehicles` row, because
a guest has to see what they are logging against and Postgres cannot mask a
column. The row already carried the purchase price and the owner's valuation
when lending shipped; the app showed a borrower neither, and a borrower's own
token could ask PostgREST for both. Proven with a fuel-only pass reading the owner's 18,500.

Fixed in `supabase/migrations/0072_guest_vehicle_columns.sql:31`: borrowers have
no read on the table, and `guest_vehicles` hands them an allowlist of columns,
which the app fetches at startup
(`lib/features/household/data/supabase_garage_bootstrap_repository.dart:74`).
`test/ci/guest_vehicle_columns_test.dart` fails the build for the next vehicle
column nobody has decided about (decision 164). A borrower on an older build
sees no borrowed car until they update.

### A pass minted in the same instant as a sale could outlive it

**Was Low, and needed two real sessions to see.** Minting took a lock that did
not conflict with the sale's update, so a mint during a sale succeeded at once,
and a sale during a mint withdrew nothing. Fixed in
`supabase/migrations/0074_guest_pass_mint_waits_for_sale.sql:42`, and guarded by
`test_rls/sale_race_check.sh`, which fails all ten of its checks on the old
functions and passes on the new ones (decision 165).

### An electric car in a garage that pours gallons had its charges stored wrong

**Was Medium for the few it reached.** The fill-up sheet converted the typed
quantity from the household's volume unit whatever went in, while its own
plausibility check did not: in a US-gallon garage 50 kWh was stored as 189.27,
and a plug-in hybrid's charges read as litres in every garage. Fixed by
deciding per fill-up (`lib/domain/fuel/energy_type.dart:29`) at every place a
fill-up crosses the unit boundary: the sheet's save
(`lib/features/fuel/widgets/fuel_entry_sheet.dart:683`), edit and guesses, the
row, the timeline, statistics, the reports, the calculator, the CSV import and
the vehicle page's gauge and chart (decision 169). **Entries already saved
wrong are not corrected**: nothing tells 189.27 typed as 50 kWh from 189.27
typed as 189.27.

A review of that fix found two more on the same sheet, both fixed with it:
switching the fuel while editing an old fill-up wrote a guessed station and
price into it, and a forecourt id remembered from the previous fill-up was
saved where nobody could see it (decision 170).

### Storage took any file of any size from anyone with an account

**Was Low, and less so in public.** `vehicle-photos` had no size limit and
neither bucket restricted types. Fixed in
`supabase/migrations/0075_storage_limits.sql:19`: 10 MB and images only, plus
PDFs for attachments, with RLS cases for both refusals and a positive control.
The app now sends what a file's bytes are
(`lib/core/files/content_type.dart:20`), without which a vehicle photo, whose
path has no extension, and every photo a merge copies would have been refused.
The vehicle photo has a picker of its own that offers no PDFs, the screen
refuses a file that is not a photo before sending it, and a storage refusal is
`invalid`, so a queued photo storage will never take is not retried
(decision 166).

### A manual release from a branch called itself 1.3.1

**Was Low.** It took the version from `pubspec.yaml`, which nobody maintains.
It now takes the newest tag's, tested in a throwaway repository because CI
clones without tags (decision 167).

### Every webhook subscribed to an event nothing sent

**Was Low.** `reminder.due` was offered from the start and never dispatched. The
daily reminder run now sends it (decision 168), which is also how the two
reminder bugs below were found.

### A guest pass survived the sale of the car

**Was High, and the kind this file calls Critical once the wrong switch is on:
one garage's data reachable by somebody that garage never let in.**
`redeem_vehicle_transfer` changed the vehicle's garage and nothing else. A pass
is keyed to the vehicle and `guest_vehicle_ids` looks at nothing but the pass
row (`supabase/migrations/0068_return_guest_pass.sql:23`), so whoever the
seller had lent the car to went on holding it in the buyer's garage. Proven
before it was fixed, against a real Postgres: after the sale the borrower still
saw the car, read a fill-up the buyer had just logged, and could log one of
their own.

Fixed in `supabase/migrations/0070_sale_ends_guest_passes.sql:91`: the transfer
withdraws every pass still able to grant anything, claimed or not, because an
unclaimed code would otherwise open the buyer's car the day somebody typed it
in. Seven RLS cases cover it, including the positive control. A merge moves the
same column and keeps its passes on purpose, which is why this is in the
function and not in a trigger (decision 159). **It was found by reading the
migrations for a terms-of-use draft, not by a test or a user**, and the two
tenancy models meeting is exactly where the next one will be.

### Merging garages deleted the absorbed garage's named routes

**Was Medium, and silent.** Routes belong to the garage and cascade with it
(`supabase/migrations/0061_routes.sql:20`); `merge_households` predates them,
moved the cars, the members and the service types, and deleted the absorbed
garage. Its trips survived with `route_id` set to null
(`supabase/migrations/0061_routes.sql:34`), so a commute's whole trend started
again from nothing, in an operation the screen says cannot be undone. Proven
the same way: a route made before a merge was gone after it.

Fixed in `supabase/migrations/0071_merge_carries_routes.sql:119`, which moves
the routes and folds one into its namesake where both garages had named the
same drive. What it cannot do is bring back routes a merge has already
destroyed. `test/ci/merge_covers_garage_tables_test.dart` now fails the build
for the next table a garage owns and the merge has never heard of (decision
160).

### Anybody holding the public key could start the daily reminder run

**Was High where the run is configured, and older than the day it was found.**
0027 revoked `run_due_reminders_push` from `anon` and `authenticated` by name
and never from PUBLIC, which Postgres grants execute on every new function. So
the key that ships in every app could call `rpc/run_due_reminders_push`, and
where the Vault secrets are set that starts the run with the service-role key:
the day's due reminders resent at will, as pushes and now as `reminder.due`
webhooks. Found while giving the scheduled call a longer timeout.

Fixed in `supabase/migrations/0076_push_schedule_timeout.sql:55`. The schedule
runs as the function's owner and keeps its grant; the RLS suite asks as an
anonymous caller and as a member, and both are refused (decision 168). **The
same default is worth checking on any definer function added later**: naming
two roles is not revoking from everyone.

### A reminder due by distance was sent every day until somebody logged a reading

**Was Medium, and on the server's side only.** The daily run dated a
distance-based reminder from today, so between readings the date moved with the
calendar, `days_until_due` stayed at 7 or 30, and the same notice went out each
day. Fixed by dating from the day of the reading the estimate rests on
(`supabase/functions/push-due-reminders/handler.ts:322`); a one-off due at an
odometer, which the run never read at all, is now dated the same way. **The
app's own local notifications have the same shape and are not fixed**; see the
open entry below.

### Anybody holding the public key could put words in a garage's chat

**Was Medium, and older than the day it was found.** `dispatch-webhooks` is
called by a database trigger with the anon key
(`supabase/migrations/0025_webhook_dispatch_config.sql:12`), which ships inside
every build of the app, and it believed the row it was handed. So a POST naming
a vehicle id somebody knew — a former member, a past borrower — was delivered
to that garage's hooks as if the car had logged it. While a chat message was
one line of numbers that was a nuisance. The day messages began carrying notes
and station names it became a sentence of somebody else's choosing in a
family's Discord, and an `entry.created` event in their home automation.

Fixed in `supabase/functions/dispatch-webhooks/handler.ts:101`: the payload may
only name a row, and the function reads it back with the service role and
builds everything from what is stored (decision 163). No new secret, so nothing
to configure on the live project. **What is left:** a real row can be announced
twice by somebody who knows its id and its car's; a receiver that cares can
de-duplicate on `entry.id`.

### The fill-up sheet wrote "PM ZAGREB, JADRANSKA" where the sign says Petrol

**Was Medium, reported twice by the same person in two shapes.** Decision 124
made a station whose name held no word at all fall back to its brand, on the
understanding that Petrol files its forecourts as "PM - 00123". The ministry's
feed holds "PM POREČ, ŽBANDAJ": a real place behind *prodajno mjesto*, for all
202 of Petrol's stations, with Tifon, Lukoil, Adria Oil and AGS doing the same
behind "BP" and "BS" — 363 of the 900 stations the app parses. Each has a word
in it, so the rule never fired, and the fill-up sheet wrote the name into the
log with no operator line underneath to say whose forecourt it was.

Fixed in `lib/domain/stations/fuel_station.dart:112`: an opening "BP", "BS" or
"PM" gives way to the operator's name, unless the name already says who runs
it. The rule was run over the whole live feed before it was kept, which is how
"LPG Autoplin" and Coral's "Shell ..." forecourts came to be left alone
(decision 161). **Fill-ups saved before this keep the old spelling**, so
statistics by station show "PM ZAGREB" and "Petrol ZAGREB" as two places until
somebody edits the old entries; posted prices still match both.

### Four public sentences said more, or less, than the app does

**Was Medium, and legal rather than technical.** None was a bug in behaviour;
each was a promise that had stopped describing it.

- **The privacy policy could not be read before an account existed.** It was
  linked from About and More, both behind the sign-in, and GDPR Art. 13 asks
  for the information when the data is collected. Both auth screens now carry a
  plain link (`lib/features/auth/screens/sign_in_screen.dart:237`), and
  deliberately not a "by continuing you agree" sentence: a policy is
  information, and there are no terms in force to agree to.
- **The policy named nobody and left out a processor.** It now names the
  controller, and lists Cloudflare, which serves garage.hrva.cc and so sees the
  IP address of everybody who opens the web app, this policy or an invite
  link. Whether a private individual's name and email are "identity and contact
  details" enough, without a postal address, is a question for the lawyer who
  reads `TERMS.md`.
- **The policy, the lending sheet and the features page said a borrower sees
  only what they logged.** Every live pass has shown a briefing since
  `supabase/migrations/0066_guest_briefing.sql:16`: the odometer, when the
  insurance, green card and roadworthiness run out, the text of every open
  problem, and the tyres. A sensible decision that three sentences predated.
  `guestLendIntro` (`lib/l10n/app_en.arb:1976`), `PRIVACY.md`,
  `web/privacy.html` and `web/features.html` now say so.
- **The About screen and the features page said deleting an account takes
  every record with it** (`lib/l10n/app_en.arb:1207`). In a garage other people
  are still in, the entries stay, without the author's name, which is what
  `supabase/migrations/0033_account_deletion_unblocked.sql:16` decided and the
  policy already said. And the features tour still promised "how far the tank
  still goes" (`lib/l10n/app_en.arb:1394`), the count-down decision 152 removed
  because it was wrong.

**What found them.** Checking every sentence of a store listing and a terms
draft against the code, rather than against the previous wording. Nothing reads
these strings against behaviour, so the next drift will be found the same way
or not at all (decision 162).

### The runbooks promised a staged rollout that Play does not offer and the workflow could not ask for

**Was Medium, and found one release before it mattered.** `RUNBOOK-update.md`
and `RUNBOOK-closed-testing.md` both said to start production at 20%. Play
stages updates and never an app's first release, so the launch could not have
followed it; and `deploy-play.yml` sent `status: completed` to every track, so
no later `-production` tag could have either. Each would have gone to everyone
while the checklist said "Rollout started at 20%".

Fixed in decision 157: the runbooks say the first release goes to everyone, a
`-staged` tag starts a production update at 20%
(`.github/workflows/deploy-play.yml:132`), and a test runs the workflow's own
shell against real tag names.

**Two sharp edges that stay sharp.** A staged release is raised to 100% by
hand in the Console, and nothing reminds anybody. And **one commit cannot be
tagged onto two tracks**: the build number is the commit count, so the second
tag builds a number Play has already taken. To put the testers' build into
production, promote it in the Console instead.

### "Range left" showed a full tank for the whole tank

**Was High, reported by the user, and it had been on the dashboard.** The tank
count-down read the odometer as `OdometerHistory.currentKm`, which is the
highest reading anybody has *logged*, not the car's. Log only at the pump — how
most people use a fuel app — and the newest reading is the fill-up itself, so
the distance burned since worked out to zero and the tank stayed at capacity
until the next thing was logged.

Measured with the reporter's own numbers: a fortnight and 600 km after a full
tank, with a measured rate of 43 km/day available in the same function call, it
returned 60.0 of 60 litres and 706 km. Not drift — the number never moved at
all, and it was most wrong at exactly the moment somebody checks whether they
can make it home.

Removed rather than repaired (decision 152). Ageing it by the driving rate
would have put an estimate on top of an estimate on the app's most prominent
surface. The statistics screen now answers the question the records *can*
answer: how far a full tank goes.

**The lesson:** "arithmetic, not a projection" is only true while its inputs
are current. The odometer in this app moves when somebody logs something, and
nothing on the phone observes a fuel level — so any figure counting down
towards empty between fill-ups is a projection whether or not it is presented
as one.

### The spend donut's legend overflowed in Croatian at 320px

Found by the Croatian layout test written for the new tank card — on a
different widget. The legend row is a swatch, a label, a percentage and an
amount; the label is `Expanded` and the other three are fixed widths that scale
with the text, so at 1.5x on a 320px phone they overflowed by 12 pixels with
nothing left to take it from. The amount is `Flexible` now and both texts
ellipsize.

**The lesson:** an `Expanded` label does not make a row safe. It can only give
away what it has, and when the fixed siblings alone exceed the width, something
else has to flex.

**And the fix for it was wrong first, which is the more useful half.** Making
the amount `Flexible` stopped the overflow and quietly broke every legend at
every width: a loose `Flexible` sizes to its content *inside* a slot it was
given, so the unused part of that slot becomes leftover space at the end of the
row. A column of amounts that had ended flush at the card's edge (x=404 on a
420px card) ended ragged at 342 and 327 instead. `Expanded` with
`textAlign: TextAlign.right` is the shape that both shrinks under pressure and
fills its slot; the label keeps `flex: 3` against the amount's `1` so it is
still the part that gives first. `test/features/stats/spend_donut_test.dart`
holds both halves — the alignment and the Croatian overflow — because fixing
either one alone is how this widget broke twice.

### One strict decoder made every non-UTF-8 import fail, including the ones it was written for

**Was High, and it hid behind a doc comment.** `readTextFile` decodes with
`allowMalformed: true` and carries a paragraph explaining why: a file in some
other encoding should import as much of itself as it can. `readTextLines`,
added beside it for streaming a recording, said "the same UTF-8 care as above"
and used a bare `utf8.decoder`, which defaults to the opposite and throws.

What made it more than an inconsistency is the order the import screen reads
in: every picked file is streamed through the recording probe *first*, to find
out whether it is telemetry, so the strict decoder ran over ordinary CSVs too.
A Latin-1 spreadsheet — the exact file the lenient decode exists for — threw
`FormatException` before the lenient reader was ever reached, and was caught
and shown as a generic failure.

**The lesson:** two readers over one file is a liability, and a doc comment
claiming parity is not parity. `test/core/files/file_text_test.dart` now
asserts the two agree on which files are readable at all.

### The join screen could spin for good on an invite it had never described

**Was High on the app's own front door.** `JoinScreen` decides once, from a
post-frame callback in `initState`. Not signed in, it remembers the pending
invite and returns — without setting the flag that says the code has been
described, because describing happens past the signed-in gate. Nothing else
sets that flag, and nothing re-runs the decision.

Harmless while signed out, because the signed-out branch renders first. It
stopped being harmless the moment the session arrived *after* the first frame,
which is what a link tapped on a cold start does while `supabase_flutter` is
still restoring: `/join/:code` sits outside both gates by design (decision in
`app_redirect.dart`), so nothing navigated away and rebuilt the screen. The
same state object rebuilt as signed in, hit `!_described`, and rendered a
spinner labelled "joining" with no path out of it.

**The lesson:** a screen that is deliberately outside the auth gates cannot
assume auth state was settled when it was built. `pumpScreen` can now flip the
signed-in user mid-test (`testUserIdProvider`), which is what the regression
test needed and what nothing in the harness could do before.

### A Car Scanner import minted its id at the moment of the press

**Was Medium, and the comment above it described the opposite.** The trip built
from a recording called `newEntryId()` inline in the save, under a comment
reading "the sheet's own id, so a retry after a timeout is the same row". Every
other entry sheet in the app holds it as `late final _newId`, which is what
makes decision 78's retry safety work: a write that times out cannot be
cancelled, so the second attempt must carry the first attempt's id and be
refused as "already there". Here the second attempt carried a new one, and a
save that had timed out but landed became two trips.

The id is now made when the file is read. Note what it is *not*: one id per
screen would be wrong the other way, since picking a second recording has to
get a fresh one.

**The lesson:** the mutation test is cheap and worth it. Reintroducing
`newEntryId()` at the call site fails the new test in one run, which is the
only proof that the test is testing the fix.

### The invite link named the garage you were in, not the one you were invited to

**Was Medium, and found by a friend.** `JoinScreen` showed somebody already in
a garage "You are already in {name}" with *their* garage's name, and nothing
on the screen said which garage the link was for — only the code. A person in
"Shrekova jazbina" opening a link for "Efficlordic" read that as the link
having put them in the wrong garage. Opening it again after joining made it
worse: the sentence now said "already in Efficlordic" and still offered Join,
and `join_household_with_code` accepts a join by an existing member as a
no-op (0010, deliberately, so the invite is not consumed), so the second tap
was celebrated as "You are in".

Fixed in decision 149: the screen asks `describe_code` first, names the garage
the invite is for, and a caller already in it is offered the door instead of
the join. `describe_code` learned `member` for that (0069).

**The lesson:** a sentence with one `{name}` in it can be read as naming
either side of a relationship. When two garages are in play, say both.


### Deleting an account failed again, for anyone who had lent a car

**Was High, and a Play requirement.** `vehicle_guest_passes` reintroduced the
exact `created_by` refusal decision 0033 had removed everywhere else: a
reference to `auth.users` with the default `no action` will not let that user
be deleted. Deleting an owner who had minted a pass, or a guest who had
redeemed one, returned "Database error deleting user".

It passed every test for the same reason it did the first time: **it only
fails for a shared garage.** A solo one cascades its household away before any
`created_by` is reached.

Fixed in decision 116 (migration 0059), with two tests in
`test_rls/rls_test.dart` covering both sides and
`test/ci/auth_user_references_test.dart` failing the build for any future
reference that does not name its delete rule.

**The lesson, for the third time: a new table with a `created_by` needs
`on delete set null`.** The static guard now says so at the moment the
migration is written.

### The offline banner never appeared, and every test passed

**Found on a device, not by the suite.** The queueing decorator keeps a write
*silently* — that is the whole design, so the entry sheet does not have to
learn about it. But `pendingWritesProvider` read the queue once and nothing
told it the queue had changed, so the banner stayed hidden until something else
happened to refresh it. The entry was safe on the phone and invisible in the
app, which to the person holding it is indistinguishable from lost — the exact
fear the feature exists to remove.

Every unit test passed: they asserted the queue's contents, not that anything
was watching it. Fixed by giving `PendingWriteStore` a `changes` stream that
the provider subscribes to, with two widget tests that add to and remove from a
live queue and assert the banner follows.

**Worth generalising:** a provider derived from something that mutates outside
Riverpod needs a subscription, not a one-off read. The queue is the only such
store today.

### SharedPreferences in a repository will hang every widget test

**Found while building the offline queue.** The queue lives in
SharedPreferences, and the fuel sheet asks it whether the entry it just saved
is waiting. In a test with no mock values, `SharedPreferences.getInstance()`
never completes — so the save never returns and the failure surfaces as
**`pumpAndSettle timed out`**, which reads as an animation problem and sends
you looking in entirely the wrong place.

The fix is the rule CLAUDE.md already states for Supabase: a new global that
reaches a platform gets a default in `test/support/pump_screen.dart`. A test
that builds its own `ProviderScope` has to override
`pendingWriteStoreProvider` itself, and several do.

### A member could never be promoted, and nothing said so

**Was Medium, and completely silent.** `household_members` had no UPDATE policy,
so a role change was filtered out by RLS — and PostgREST reports a filtered row
as *zero rows updated*, not as an error. Any attempt to promote somebody would
have looked like it worked. A garage therefore had exactly one admin, its
creator, forever.

It also weakened two tests written the same day for decision 112: both set up a
second admin, or demoted one, with an update that quietly did nothing, and their
assertions passed either way. **The lesson: when a write is the setup for a
test, assert the setup landed.** Both now do.

Fixed in decision 113, along with the follow-on that stepping down as the last
admin handed the role straight back to the person stepping down, because they
were the longest-standing member.

### A garage could be left with no admin, permanently

**Was High, and silent.** The creator of a garage was its admin and that was
the only route to the role. When they left — or deleted their account, which
removes the membership — the garage survived with every car and all its history
and **nobody who could administer it**. The remaining member could not rename
it, could not remove anyone, could not delete it, and could not promote
themselves. There was no recovery path at all.

The shape of it is completely ordinary: two people share a garage, one of them
created it, that one leaves. A couple, a family, two housemates. Every account
deletion by a creator hit it.

Nothing was red, because nothing tested it: `test_rls/rls_test.dart` had no case
for the last admin leaving, and the app has no screen that would have looked
wrong. Fixed in decision 112 with a promotion trigger and a backfill for the
households already stranded.

### The startup fetch could not see a borrowed car

**Was High for the guest-pass feature, and invisible in every test that
existed.** Decision 108 made startup one embedded select —
`households` with `vehicles(*)` nested — which is genuinely one round trip and
was the wrong question. An embed only nests rows under parents the outer query
returned, and the garage that owns a borrowed car is by definition not one the
borrower belongs to. So the policies returned the car and the app never asked
for it:

```
plain vehicles select : ['Sister Clio', 'My Golf']   <- what RLS allows
households + embedded : ['My Golf']                  <- what the app asked
```

Every RLS test passed, because they used the raw client. Every widget test
passed, because the fake bootstrap was built from a vehicle list rather than
from a query. Nothing was red.

Fixed by fetching `households` and `vehicles` as two selects issued together
with `Future.wait` — the same one round trip of latency, and `vehicles` asks
the question the policies actually answer: everything this caller may see,
however they may see it. Borrowed is then derived — *visible, but not in a
garage of mine*.

**The lesson is the one CLAUDE.md already states and this still got wrong:**
write the test as the read the app actually makes. `test_rls/rls_test.dart` now
has one that performs the startup pair and asserts the borrowed car is in it.

### The web app shipped Flutter's scaffold text as its own description

**Was Low, and public.** `web/index.html` carried
`content="A new Flutter project."` and `<title>garage</title>` — the text
`flutter create` writes — for the app's whole life. It is invisible in the app
and visible in exactly three places that matter: a search result, a browser tab,
and the card somebody sees when the link is shared. `web/manifest.json` had the
same description, so an installed PWA inherited it.

Also missing: a `viewport` meta (the engine inserts one at runtime, which is a
frame of desktop-width layout on a phone), any `theme-color`, and any Open
Graph tags — a shared link to garage.hrva.cc previewed as a blank card.

Fixed, with `test/ci/web_shell_metadata_test.dart` to keep it fixed:
`flutter create` regenerates both files, so this is precisely the class of thing
that comes back.

### A sheet's TextEditingController cannot be disposed by its caller

**Found while building the drive draft, and worth repeating everywhere.** The
"start a drive" sheet was written as a function that created a
`TextEditingController`, awaited `showAdaptiveEntrySheet`, and disposed the
controller on the next line. That reads as correct and is not: the sheet is
still animating out when the future completes, and the `TextField` it belongs to
is built again during that animation — against a controller that no longer
exists.

The symptom is not a null error. It is `Tried to build dirty widget in the wrong
build scope`, thrown from a *later* test in the same file, which makes it look
like test pollution rather than a defect in the widget. Passing the test alone
succeeds.

**The rule: a sheet owns its own controllers.** `_StartDriveForm` and
`_FinishDriveForm` (`lib/features/trips/widgets/drive_card.dart`) are stateful
for this reason alone, which is the same pattern the other entry sheets already
follow.

### Startup was four sequential round trips, and looked like two spinners

**Was Medium, and felt worse than Medium at a pump.** `allVehiclesProvider`
awaited `currentHouseholdProvider`, which awaited `myHouseholdsProvider`,
because each call's argument was the previous call's result. A cold start paid
three to four sequential requests before a first card, then the dashboard's own
providers — timeline, projections, top bundle — each landed on their own clock,
so cards appeared one at a time and the layout moved under whoever was reading
it. On screen that was: spinner, then a second spinner, then content arriving in
pieces.

Fixed in decision 108. One embedded select brings households and vehicles back
together, and the dashboard draws its own outline while it waits, so nothing
moves when the data lands.

**The part worth remembering.** The providers below the bootstrap are now
*derived*, and `ref.invalidate(allVehiclesProvider)` on a derived provider
compiles, reads correctly, and does nothing — it rebuilds against a cached
value. Nothing throws; a car added by hand simply does not appear until the app
is restarted, which reads as slowness rather than as a bug.
`test/ci/garage_bootstrap_invalidation_test.dart` scans the source and fails the
build if one comes back. **Invalidate `garageBootstrapProvider`.**

### The embedded select was checked against a real Postgres, not assumed

Not a bug — recorded because the reasoning is the kind that is usually skipped.
PostgREST applies RLS to an embedded table as well as to the parent, so
`from('households').select('*, vehicles(*)')` returns what the two separate
selects returned. That is documented behaviour, and documented behaviour is not
a test: an embed that ignored the `vehicles` policy would hand out every
garage's cars and would look exactly like a working app. Four cases in
`test_rls/rls_test.dart` cover it against real Postgres — the creator (the
positive control), a member who created none of the rows, a stranger, and
somebody in two garages at once, which is where a leak between two legitimately
visible embeds would be invisible.

### Archive ran on one tap, and the Reminders tab lost its add button

Two P0s from the vehicle-page critique, both fixed (decision 82): Archive
asked nothing, offered no undo and left a page that did not say it was
archived; "Add reminder" lived only in the Reminders tab's empty state.

### A prefilled price appended instead of replacing

The fill-up sheet prefilled the last price with the caret at its end;
typing a new price produced "1.451.47" and the total went blank without a
message. Found by the fifth UX walk. Fixed: the prefilled value is selected
on focus and a malformed amount says "Not a number" as it is typed
(decision 80).

### A three-day series projected a due date next week

With one fill and one guessed "last done" reading three days apart, the
whole-series fallback in `OdometerHistory.kmPerDay` accepted a one-day span
and produced 1,873 km a day; the dashboard showed the oil change due in five
days and the maintenance page claimed "over the last 3 months". Fixed by a
fourteen-day floor and date-only projection below it (decision 79). Found by
the fourth UX walk.

### A retried save no longer doubles the row

`writeWithTimeout` cannot cancel a request that is still in flight, so an
insert could land after the sheet had given up and be saved again on
retry. Entry sheets now choose the row's id on the device and send it; the
second insert conflicts on the key and is taken as "already saved". A
one-time rule gets its id from the sheet too and is upserted by key; a
recurring rule keeps the server's and updates by type first. The one
remaining case is the next-vignette rule the cost sheet schedules after a
vignette purchase (`_scheduleRecurringReminder`), which still inserts with a
server id. Decisions 78 and 80.

### The date picker's first weekday, fixed the right way

Monday-first in English through a `MaterialLocalizations` override of
`firstDayOfWeekIndex` alone, after the British-English route was reverted
for flipping typed dates to day-first. Decision 78.

### Three from the third UX walk, fixed together (decision 78)

The vehicle page's tabs (Costs now counts fuel, History is Service
history), the dashboard's projected date with no basis, and the greyed page
on a slow write. Decision 78 has the reasoning.

### The reminder sheet's service type was one alphabetical list

Thirty-plus types in a dropdown with no search and no order but the
alphabet, "Oil change" seventeenth, and "Fault noted" between the brake
parts and the oil. Both UX passes flagged it. Now a sheet with a search box,
a "Common" group first, then the rest; the two one-off types are not offered
as reminders (decision 77). The service-entry sheet keeps its own flat
picker, which is a smaller list and a different job.

### The invite button did nothing visible on web

`_shareInviteLink` fired the share call and did not await it. On a phone
that is fine, the sheet opens; on web `navigator.share` exists and rejects
asynchronously, so the rejection never reached the clipboard fallback and
neither the copy nor the "Invite message copied" toast happened. The button
created a code and looked inert. Now awaited, and a share that reports itself
unavailable falls back the same way as one that throws. The regression test
overrides the share seam to return false and expects the toast.

### Every log built its whole history on the first frame

**Was Medium, and growing.** The fuel log, trip log, timeline and the vehicle
detail's history and money tabs were all `ListView(children: [...])`: every row
of every year built at once and kept in memory, which a household that
imported years from Fuelio paid for on every open. They now go through
`LazyMonthList` (`lib/core/widgets/lazy_month_list.dart`), a builder-backed
list over `MonthGrouping.flatten`, so a row exists only while it is on screen.
Same widgets, same look; a test pins that 400 rows build fewer than 60.

The rule: **a list whose length is the user's history is `ListView.builder`,
never `ListView(children:)`.** Settings and About pages are fixed-length and
may stay as they are.

### The calculator and the reminder rule sheet ignored miles and gallons

**Was High for an imperial household, invisible to a metric one.** Every other
sheet converts at the edge (`prefs.displayToKm` on the way in, `kmToDisplay`
on the way out). The calculator fed what was typed straight into `TripMath`
as kilometres and litres while converting the *results* on the way out, so a
household reading miles saw a distance box in one system and an answer in the
other; the reminder rule sheet showed and stored its three km fields as
kilometres regardless of preference. Nobody noticed because the app's users
read metric, and every widget test used the default metric preferences.

It surfaced when unit suffixes were put on every numeric field: a box that
says "mi" and stores kilometres is a lie you can see. Both now convert, and
`UnitPreferences` gained `economyToDisplay` / `displayToEconomy` for the
mpg inversion the calculator's consumption box needed
(`lib/core/format/unit_format.dart`). Both test files carry an imperial case.

The rule it reinforces: **a test suite that only ever runs metric proves
nothing about conversion.** Any field that takes a distance, a volume or an
economy figure needs one imperial test.

### The maintenance calendar opened on the real month, not the clock's

**Was Low for users, High for CI.** `MaintenanceScreen` seeded its calendar
month from `DateTime.now()` while everything else on the screen took today from
`todayProvider`. In production the two agree. In the test suite they did not,
and on 1 September the calendar test started tapping "20" in a month whose due
list had been computed for August — a suite that goes red on a date, blamed on
whatever commit happened to be pushed that day. The month now comes from the
provider (`lib/features/maintenance/screens/maintenance_screen.dart`).

The rule it reinforces: **anything a screen derives from "today" comes from
`todayProvider`.** Defaulting a new entry's date to `DateTime.now()` is fine —
nothing is computed from it. A month grid, a due list, an age or a runway is
not, and a screen that computes one from the real clock is a test that will
fail on some future morning.

### A bad VIN said "something went wrong"

**Was Medium.** `vehicles.vin` carries a check constraint (11–17 characters,
`supabase/migrations/0003_vehicles.sql:10`) and the form had no validator for
it, so a typo went to Postgres, came back as `23514`, fell through
`AppFailure.from` into `unknown`, and rendered `errorGeneric`. The person saw a
generic sentence for a mistake they had made in one specific field.

Two fixes, because each covers what the other cannot. The VIN field now
validates the same range and turns red with the rule under it
(`lib/features/vehicles/screens/vehicle_edit_screen.dart`), which is the fix
for the case that was reported. And `23514` now maps to a new
`AppFailureKind.invalid` ("some values were not accepted, check them"), which
is the net for the next check constraint a form has not learned about —
without it, every one of those will read as a mystery until someone finds it in
`garage.failure`.

The shape is worth remembering: **a database constraint with no matching form
validator is a "something went wrong" waiting to be reported.** When adding a
`check (...)` to a migration, add the validator in the same change.

### A tyre set was the only thing you could create and not correct

Every other thing a household creates is editable — all six entry kinds through
their sheets, a vehicle through `vehicle_edit_screen`. A tyre set could only be
added, fitted, retired or deleted, so a typo in the name, a wrong season or a
moved storage box meant deleting the set — and its whole tread history went
with it, which is the one part that cannot be measured again afterwards.

Nothing in the decision log or the architecture docs records this as a choice.
It was an oversight, and the shape of it is worth remembering: the gap was
invisible because each individual verb (`fitSet`, `retireSet`, `deleteSet`)
looked complete on its own.

`_editSet` now serves both add and edit from one form, the way every entry
sheet does, with `TyreRepository.updateSet` behind it. It deliberately does not
touch `fitted`, `fitted_at` or `retired_at`: those are things that happen to a
set and have their own verbs.


### Deleting a cost, trip, income entry or reading never reached the other device

`0007_realtime.sql` set `replica identity full` on the three tables in the
publication at the time and wrote down exactly why: a DELETE's old tuple
otherwise carries only the primary key, so `_vehicleIdFrom`
(`lib/core/sync/realtime_sync.dart`) cannot read `vehicle_id` and the callback
returns having invalidated nothing.

Four entry kinds were published afterwards — `cost_entries` in `0012`,
`odometer_entries` in `0028`, `trip_entries` and `income_entries` in `0029` —
and not one repeated it. Deleting any of those on a phone left the row on
screen on the laptop until that list was reloaded by hand.

**Why it survived so long.** Inserts and updates worked the whole time, on
every table, because their payload carries the new row. Only the delete half
was broken, on four of seven kinds, and the symptom is a row that is still
there — indistinguishable from not having pressed delete hard enough. Nothing
logs, nothing errors.

`0042` sets FULL on all four. `vehicles` is deliberately left alone: a delete
there sends the primary key, and the primary key *is* the id the client
refreshes on.

**The guard.** `test/ci/realtime_replica_identity_test.dart` reads the tables
`realtime_sync.dart` subscribes to and asserts each is published and carries
FULL, with `vehicles` the one named exemption. It is a static check over the
migrations rather than a query against a running database, because the mistake
is made when a migration is written. It carries a third test asserting the
regexes still match something, since a parser that quietly stops matching would
make the other two pass on an empty set.


### A distance setting was stepped and shown in kilometres to everyone

"Group items within (distance)" names no unit deliberately, and `_Stepper`
rendered a bare `$value` beside it — so a household reading miles saw `500` and
was setting five hundred *kilometres*, with nothing on screen that could have
told them. Every other distance in the app converts at the edge; this one was
the household's own setting and did not.

`_DistanceStepper` (`lib/features/settings/screens/settings_screen.dart`) now
shows the value through `formatDistance` and steps in the displayed unit —
stepping by a hundred kilometres under a miles reader walks 311, 373, 435,
which is arithmetic nobody asked for. Storage stays kilometres. The round-trip
can move the stored figure by a kilometre or so, which does not matter for a
grouping window measured in hundreds.

The plain `_Stepper` is still right for the days setting beside it, where the
label names the unit.

### The purchase price could be set but never unset

`vehicle_edit_screen.dart` saved
`purchasePrice: _purchasePriceAmount() ?? existing.purchasePrice`, so emptying
the box put the old figure straight back — a wrong price could not be taken out
again, only overwritten. Every other optional field on that form goes through
`_emptyToNull` and clears. Now so does this one.

`trim` and `photoUrl` keep their `?? existing` and are not the same bug: `trim`
is filled only by the VIN decoder and never typed, and `photoUrl` has an
explicit `_photoRemoved` flag for the clearing case.


### The CSV export covered two entry kinds; the importer covered six

`csv_export.dart` wrote fuel and services and nothing else, while
`CsvEntryKind` imports fuel, cost, service, odometer, trip and income — so a
household could bring its costs and trips in from another app and had no way to
take them back out, from the file whose own docstring calls itself the GDPR
portability mechanism.

`costEntriesToCsv`, `incomeEntriesToCsv`, `tripEntriesToCsv` and
`odometerEntriesToCsv` now exist and `DataScreen._csv` writes a section per
kind. Language-neutral keys throughout: the cost category, the trip purpose and
the vignette pair store their stable keys, never their translated labels — the
vignette pair specifically, so this did not repeat the omission the JSON backup
had just been fixed for.

Tyre sets are still out. They are not a `CsvEntryKind` either, so the export and
the import agree; a tyre set with its readings is a nested shape a flat table
does not hold well, and the backup carries it.

**A unit test per exporter was not enough.** They all passed while nothing
called them. `export_saving_test.dart` now asserts the written file carries a
section for all six kinds, which is the assertion that would have failed before.

### Cost per distance was shown in kilometres to households reading miles

`UnitFormat.formatCostPerDistance` exists exactly for this, and its docstring
records the bug being fixed once already: "a household reading miles was shown a
per-kilometre number under a heading that said km". It was applied to the fuel
log screen and to nothing else.

Two screens still had it. The vehicle detail running-cost card printed three
per-kilometre figures — the headline, the fuel share and the upkeep share —
through `formatMoney`, under a fixed "Per kilometre" caption. The stats summary
cards printed a per-kilometre figure under "By distance", a label that does not
lie about the unit because it does not name one, leaving a number roughly a
third too low with nothing to say so.

Both now go through `formatCostPerDistance`, which converts and appends `/km` or
`/mi`. The `runningCostPerKm` caption is gone from both ARBs — the figure says
it itself, which the caption could not.

`formatCostPerDistance` gained an optional `decimals`: the running-cost headline
needs three, because at two a cost per kilometre rounds to a couple of
significant digits and two quite different cars read the same.

**The first version of the test did not catch it.** Asserting "something on this
screen contains /mi" passed on the fuel and upkeep shares while the headline was
still unconverted. The headline now carries `Key('running-cost-per-distance')`
and the test asserts its exact text; reverting the fix fails it.

### `lib/domain` purity and the store-listing caps had no test

Two of the open items in this file were "a test would close it", and neither had
one. Both now do:

- `test/ci/domain_purity_test.dart` fails on any `package:flutter` import or
  export under `lib/domain/`. Verified by planting one.
- `deploy_workflow_test.dart` now measures the full descriptions against Play's
  4000, the short descriptions against 80 and the store titles against 30, read
  out of `docs/play-store-listing.md` rather than duplicated. Both full
  descriptions sit at 3990, which was the point: there were ten characters of
  headroom and nothing watching them.

The section-scoping matters — title and short description are written
identically, and a regex over the whole file measures one against the other's
cap.


### A fat-fingered year silently wrecked every distance-based projection

Nothing rejected a reading dated in the future, and one was enough. `_window`
anchors the rate to the series' own last reading, so a fill-up mistyped as next
year opened the 90-day window in the future, left the real driving outside it,
and dropped the measured rate to a fraction of the truth — every distance-based
date pushed months out, reminders quietly going silent. `currentKm` takes the
highest reading whatever its date, so the current odometer jumped forward at the
same time, in the opposite direction.

`OdometerHistory.sorted` now takes `asOf` and drops anything dated after it,
supplied by `odometerSamplesProvider` — the single funnel the rate, the current
reading and the projections all come through.

**The tempting fix was the wrong one.** Capping `lastDate` on the seven entry
sheets' date pickers looks like the answer and protects almost nothing: the
Fuelio and CSV importers and a restored backup all write entries without going
near a picker, and `parseFuelioBackup` accepts whatever `DateTime.tryParse`
returns. See decision 66.

**Watch the timezone edge if this is ever touched.** `todayProvider` is a local
`DateTime.now()`; sample dates are UTC date-only. Both are reduced to a calendar
date and rebuilt as UTC before comparing. Compare them raw and a household east
of UTC loses its own today's entry.


### Tyres and API access built their own dialogs

The two surfaces still calling `showDialog` with a hand-built `AlertDialog`,
so on a phone the same act of typing a few fields arrived as a centre-screen
dialog there and as a bottom sheet in all six entry sheets. Both now go
through `showAdaptiveEntrySheet` with a shared `EntrySheetBody`
(`lib/core/widgets/entry_sheet_body.dart`), which also gets them the
phone/desktop split the entry sheets already had. Both screens carry a test
asserting the sheet body is present and no `AlertDialog` is.

`EntrySheetBody` is deliberately *not* a generalisation of the entry sheets'
own bodies: those own controllers, validation and a repository call and are
properly stateful. This is only for the short prompts that collect a value and
hand it back through `Navigator.pop`.

`dialog_actions.dart` stays — `confirm_delete`, `text_prompt`, settings and
household still use it for genuine confirmations, which are dialogs on purpose.


### Every entry sheet titled itself "Add" while editing

There were no `*Edit` keys in the ARBs at all — only `commonEdit` and
`vehicleEdit` — so all six sheets showed their add-title in both modes: "Add
cost" on a form that was simultaneously offering a Delete button. Six pairs of
strings now exist (`costEdit`, `fuelEdit`, `incomeEdit`, `odometerEdit`,
`tripEdit`, `maintenanceEditService`) in both languages, each sheet picks on
`widget.existing == null`, and every sheet test asserts both titles.

Alongside it, the cost sheet's amount field was the only numeric field in the
app without an `onChanged` clearing its error, so "Enter an amount." stayed
under the box while the household was correcting it — which reads as though
the correction is not being accepted. It also had no `Key`, unlike the
equivalent field in every other sheet, so the test for this had nothing stable
to type into; it is now `cost-amount`.


### The backup silently dropped the deeper service fields and both vignette fields

`_service` wrote eight fields while the repository persisted thirteen, and
`_cost` wrote five while the entry carried seven
(`lib/domain/export/garage_backup.dart`). Back up, wipe, restore, and the
household lost every brake-pad, tread and battery reading it had taken, every
warranty date and fault code, whether a job was DIY, what parts went in, and
what each vignette was for. The restore reported success, because it had
written every field it knew about.

The measurements were the sharp end: they are only meaningful as a series, and
the tyre-wear estimate needs two readings before it says anything, so a restore
quietly reset the one feature whose value is cumulative.

**No version bump was needed.** Both readers already tolerated absent keys, so
adding fields is compatible in both directions, and `currentVersion` only
guards against files from the *future*. `measurements` goes through
`Measurements.toStored` / `fromStored` rather than a raw map, so an unknown key
cannot ride in from a hand-edited file; the vignette pair stores `code` and
`key`, the stable forms, and resolves to null for anything unrecognised.

**Why nothing caught it, and what now does.** The fixture the round-trip tests
used was sparse — a backup that drops a field nobody populated round-trips
perfectly. There is now a `fullyPopulated()` fixture with every optional field
set on both entry kinds, and tests asserting each one survives
(`test/domain/export/garage_backup_test.dart`). Anything added to
`ServiceEntry` or `CostEntry` from here belongs in that fixture, and the tests
will say so if it does not also reach the serializer.

`_trip`, `_income`, `_reading`, `_rule` and `_tyres` were complete throughout,
tyre readings included. This was two serializers that stopped being updated as
their entities grew, not a design gap.


### Editing or deleting a cost rewrote the reminder behind it

Two faults in the same sheet, both silent, both losing a decision the
household had made.

**The switch was seeded from the category default on an edit.**
`initState` set `_remindAgain = _defaultRemindAgain(_category)` for an
existing entry as well as a new one, and the sheet never read the rule
standing on the vehicle — it only ever invalidated `reminderRulesProvider`.
So a vignette whose reminder had been deliberately switched **on** reopened
showing **off**, and `_scheduleRecurringReminder` wrote that back: correcting
an amount retracted the reminder. A registration whose nag had been declined
reopened **on** and saving recreated it. Now seeded from whether an active
one-off rule for that category actually exists
(`_seedRemindFromStandingRule`), applied only if the household has not
touched the switch or changed the category in the meantime, and a *completed*
rule does not turn it back on — settled history is not a preference.

**Deleting the expense left its reminder standing.** `_submit` was careful
about the rule and `_delete` touched none of it, so removing the vignette you
logged by mistake left "Vignette expires" in the planner with no cost behind
it — and since only buying the next one or logging a *service* of a thing
nobody services settles such a rule, the orphan was effectively permanent.
`_retractOwnReminder` now clears it, matched on `issuedDate` against the
entry's own date rather than on the category alone: a household that buys a
second vignette and then deletes the first, older entry keeps the reminder the
newer purchase raised.

Both swallow their errors, as scheduling always has: the expense is what the
user came to record, and failing it over the courtesy on top would invite a
retry and a duplicate row.

### Dialog controllers leaked, and disposing them at the dialog's future did not fix it

`_addSet` created three `TextEditingController`s and `_recordTread` four
(`lib/features/tyres/screens/tyres_screen.dart`), and `_createKey` and
`_addWebhook` one each
(`lib/features/api/screens/api_access_screen.dart`); none were disposed, so
every open leaked a `ChangeNotifier`.

The obvious fix is wrong and worth remembering. Wrapping the body in
`try`/`finally` and disposing when `showDialog`'s future completes disposes
too early: that future lands when the route is *popped*, while it is still
animating out and the field still depends on the controller, and the
framework asserts `_dependents.isEmpty` while tearing the overlay down. Ten
tests across the two screens went red, most of them with a cascade that hid
the real cause.

They are now owned by the screen's `State`, allocated once, `..clear()`ed
before each open and disposed in `dispose()` — the same ownership every entry
sheet already uses, and no per-open allocation at all.


### A backdated premium read as freshly issued

**Was Medium**, caught from a screenshot: a household's insurance and
registration reminders both showed 0% used while sitting at the top of "due
soonest," which does not add up — 0% used should read as furthest away, not
closest.

The projector for a one-time reminder (vignette, registration, a yearly
premium) needs an anchor date to measure "how much of the cycle has passed."
Nothing better than the reminder row's own `created_at` was available, so
that is what it used — correct only when a payment is entered the same day
it was made. Both reminders here were backdated: entered into the app in
August for premiums actually paid in May, so `created_at` (August) sat only
days before "today," while the real anchor (May) was months back. The fix
anchors on an explicit `issued_date` set from the cost entry's own date
(`supabase/migrations/0040_reminder_rule_issued_date.sql`,
`lib/domain/maintenance/reminder_projection.dart:169`) instead of a database
timestamp that only happens to match reality when nothing is backdated.

**Checked for the same shape elsewhere and found it isolated** — every other
date-driven calculation (tyre wear, cost proration, distance rate) already
read each entry's own date field, never a row's insert time, so this was not
a symptom of a wider pattern.

### `created_by` could be forged on any table added after the fix that stopped it

**Was Critical** by this doc's own bar loosely read, though not a
cross-household leak: a household member with API access could rewrite who
an entry is attributed to, within their own household. Real stakes here
specifically because of the settlement feature — attribution decides who
owes what.

Migration 0008 discovered that an RLS `with check` cannot see a row's
*previous* values, so an UPDATE policy scoped to `vehicle_id`/`household_id`
cannot stop `created_by` being rewritten to point at someone else — and
fixed it with a `before update` trigger pinning `created_by` to its old
value, on the three tables that existed then. Every table added after
(`cost_entries`, `tyre_sets`, `trip_entries`, `income_entries`,
`odometer_entries`, `api_keys`, `webhooks`) has the identical shape and
never got the same trigger, because the fix was a one-off patch rather than
a rule applied to every new table with a `created_by` column.

Fixed by extending the same trigger to all seven
(`supabase/migrations/0041_pin_created_by_everywhere.sql`), with a
regression test per table (`test_rls/rls_test.dart`, group "created_by is
pinned on every table that carries it"). **The rule going forward:** any new
table with both a `created_by` column and an UPDATE policy needs a
`before update … execute function public.pin_created_by()` trigger in the
same migration that creates it — `reminder_rules` has no `created_by`
column at all, which is why it is exempt rather than missing one.

### There was no way to reach the developer without filing a GitHub issue

**Was Medium.** The About screen offered Diagnostics (see the recorded
failures) and a source-code link, but nothing for the ordinary case: a
suggestion, a small confusion, a "does this do X" — none of which is a bug
report and none of which the AGPL's source obligation has anything to do
with. The only route was finding the repository and opening an issue, which
almost nobody who is not already a developer will do.

Fixed with a "Send feedback" row addressed to the support inbox already on
file (`docs/play-store-listing.md`), pre-filled with the app version and any
recently recorded failures. See decision 64.

**Needed a manifest change to actually work.** `url_launcher` resolving a
`mailto:` link on Android 11+ needs a `<queries>` declaration
(`android/app/src/main/AndroidManifest.xml`), or the mail app is invisible to
the resolution query despite being installed — the tap would do nothing, and
nothing local would catch it, the same shape of gap as the `dart:ffi` web
build failure in the automatic-backup work above.

### A vignette bought once nagged forever

**Was High for anyone paying for a vignette on a single trip**, reported from
the field: a household bought a seven-day Slovenian vignette, used it, and
months later the app said a payment was late for a road they were not on.

Three bugs, found by tracing that one report back to its cause rather than by
auditing the feature cold:

1. **The country and validity were never saved.** The sheet asked for both,
   computed the reminder's due date from them, and threw them away the moment
   it closed — `CostEntry` had nowhere to put them. Editing an existing
   vignette restored the amount and the notes and silently forgot what it was
   even for. Fixed by two new columns
   (`supabase/migrations/0038_vignette_details.sql`) and restoring both fields
   in the sheet's `initState`.
2. **The reminder defaulted to on, for every category alike.** Registration
   and insurance recur for every car, every year — a vignette recurs only if
   the trip does, and the common case is one crossing. See decision 61.
3. **There was no way to retract one already scheduled.** Turning the switch
   off only stopped a *new* reminder from being created; an existing one sat
   there regardless. `_scheduleRecurringReminder` now clears the outstanding
   rule unconditionally and only re-adds it when the switch is on — which is
   also how a household with an existing stale reminder can clear it: reopen
   the entry, leave the switch at its new default, save.

All three needed to land together: retraction needs the validity restored
(bug 1) to know which service-type key to clear, and the new default (bug 2)
is what makes re-saving the stale entry the fix rather than a second copy of
the same mistake.


### Backing up said "shared" when it had only been saved

**Was Low**, and dated back to decision 56, which split saving a backup from
sharing it but left both actions pointing at the one snackbar string written
for sharing. `settingsBackupDone` = "Backup shared" then started firing after
a successful **save to device** too, where nothing had been shared anywhere.
Reworded to "Backup saved", with a test that pins the wrong string as
`findsNothing` so a future split cannot silently reintroduce the mismatch.

### A dependency broke the web build and nothing local noticed

**Was High for the web deploy**, and it reached CI. Adding `saf_stream` for
automatic backups pulled in `jni`, which imports `dart:ffi`, which **dart2js
cannot compile**:

```
Error: Dart library 'dart:ffi' is not available on this platform.
Info: The unavailable library 'dart:ffi' is imported through these packages:
```

`flutter analyze` was clean. All 1700 tests passed. Neither can see it — the
analyzer resolves against the host platform and the test runner is a VM. Only
`flutter build web` runs dart2js, and it is not part of the local loop.

**A runtime `kIsWeb` guard is not enough.** The seam already checked
`backupFoldersSupported` before calling anything; the *import* is what breaks
the build. The fix is a conditional import
(`lib/core/files/backup_folder.dart:5`), which is the standard Dart mechanism
for exactly this: a web-safe file by default and the real implementation behind
`if (dart.library.io)`, so `saf_stream` never reaches the web compiler at all.

**What to do about it:** run `flutter build web` before trusting any change
that adds a dependency. Recorded in `CLAUDE.md` beside the other commands. CI
does catch it — `deploy-web.yml` is what failed — but after a push rather than
before one, and web deploys on every push to `main`.


### Every exported file arrived with a UUID for a name

**Was Low**, and it had always been true. All three exports — the CSV, the JSON
backup, and a vehicle's PDF report — passed a perfectly good name:

```dart
XFile.fromData(bytes, name: 'garage-backup.json', mimeType: 'application/json')
```

`cross_file` **ignores `name` on every platform except web** — the name it
reports is the basename of `path`, and a `fromData` file has no path. share_plus
documents this in the doc comment for `fileNameOverrides`, and then falls back
to `"${Uuid().v1().substring(10)}.$extension"`
(`share_plus_platform_interface/lib/method_channel/method_channel_share.dart`).

So the code was right, review would pass it, and the device got `3f9a1c-8e21.json`.

Fixed by passing `fileNameOverrides` at all three call sites, and by naming
files through `exportFileName` (`lib/domain/export/export_file_name.dart:36`)
so they carry the subject and the day and sort in a folder:
`renault-clio-report-2026-08-22.pdf`. Croatian diacritics are **folded**, not
stripped — "Škoda" must not become "koda".

**How it hid:** nothing in the type system or in any widget test can see it.
The name is chosen inside the plugin, after the last line of app code runs.
`test/ci/share_file_names_test.dart` is a source-level check, which is crude
and is the only thing that would have caught it.

**Still true:** exports go through the share sheet rather than being saved to a
folder. `file_selector_android` implements `openFile`, `openFiles` and
`getDirectoryPath` and **not** `getSaveLocation`, so a save dialog needs a
dependency this project does not have yet.


### The fuel log hid the two things worth opening a row for

**Was Low.** Decision 46 put note and receipt markers on timeline rows, because
a row carrying either was indistinguishable from twenty that were not. The fuel
log — the screen a driver actually reads their fill-ups on — never got them,
and did not show the station either, so a fill-up said date, odometer, volume,
cost and economy and nothing about where or why.

Now the same two icons with the same semantic labels
(`lib/features/fuel/widgets/fuel_entry_row.dart:130`), reading the same
`entriesWithAttachmentsProvider` the timeline uses — one query for the history
rather than one per visible row. The station joins the subtitle, and the line
is **assembled from the parts that exist** rather than interpolated, so a
fill-up without one does not show a dangling separator.


### One tap wrote a demo garage into a real one

**Was Medium**, and it happened to the person who asked for the fix. The sample
garage had no confirmation at all — from the Settings row *and* from the
getting-started card on the dashboard, where a mis-tap costs nothing to make.

What turns that from untidy into a real problem is the demo car's name: it is a
**Renault Clio** (`lib/domain/demo/sample_garage.dart:16`), which is a car the
people this app was built for actually own. So the accident is not "somebody
got some demo data", it is "somebody now has two cars called Renault Clio and
has to work out which one holds their real history before deleting the other".

`confirmAction` (`lib/core/widgets/confirm_delete.dart:75`) now stands in
front of it, and **names the car** — the detail that would have prevented it.
It is a plain confirmation rather than the red `confirmDestructive` one:
loading the sample adds, it does not delete, and dressing an additive action in
deletion styling is how red stops registering when it matters.

**Not fixed:** there is still no undo. Deleting the demo vehicle cascades its
history, which is what the reporter did, but nothing says so at the time.


### An imported Fuelio log had nowhere attached to any fill-up

**Was Low**, and invisible until you went looking for it. Fuelio's export
carries a `City (optional)` column and a `StationID (optional)` column, and a
real export leaves **both empty on every row** — the app it came from does not
preserve the station in any form this file keeps. The importer mapped `city` to
`station` faithfully and imported null fifty times.

The fix is at import rather than after it: the file is parsed before the import
dialog opens, so `FuelioBackup.hasAnyStation`
(`lib/domain/import/fuelio_backup.dart:144`) decides whether to offer a single
station field, and `importFuelioBackup` applies it as a **fallback** — a row
that named its own station keeps it, and a blank answer writes nothing rather
than empty strings over a column that means "unknown" when null.

`test/domain/import/fuelio_station_test.dart` asserts it against the real
export in `docs/wishlist/`, so if a future Fuelio version starts filling `City`
in, the test fails and the prompt should stop being offered.


### The push sender told all-season households to swap their tyres

**Was Medium**, and it had shipped to everyone with push configured — which is
the only population it could affect, and the one where it was the *whole* of
what they got.

Two halves of the seasonal swap lived only in the client:
`TyreSeasons.swapsSeasonally` suppressed the reminder for a car recorded as
running all-season tyres, and nothing on the server had ever heard of
`tyre_sets`. That would have been harmless if both scheduled — but wherever
Firebase is configured the client deliberately stops scheduling dated reminders
altogether (decision: one source, one nudge), so the server's copy is the only
one. An all-season household was therefore reminded twice a year, forever, to
do a job it does not have, and the screen it would check said nothing was due.

The date was wrong in the same place for the same reason: the server projected
the swap from `interval_months = 6`, anchored on whenever the last swap was
logged.

Both now live in the handler —
`supabase/functions/push-due-reminders/handler.ts` reads
`households.country_code` and `tyre_sets` for a vehicle that actually has a
seasonal rule, so a fleet without one costs no extra query. Proven by removing
each half and watching the tests fail: five of them do.

**How it hid:** the client and the server disagreeing is invisible from either
side. Nothing compares them, no screen shows what the server decided, and the
only symptom is a notification somebody did not want — which reads as the app
being noisy rather than as a bug.

**Needs a hand deploy.** Migrations apply themselves on push to `main`; edge
functions do not. `supabase functions deploy push-due-reminders`, and passing
Deno tests do not prove the result still bundles — serve it locally first.


### `ref` after an await outrode the screen that owned it
**Was Medium**, and it reached the field: three diagnostics reports across four
days, each of them

```
unknown: Bad state: Using "ref" when a widget is about to or has been
unmounted is unsafe.
```

with nothing naming a screen — the failure log records the message, not the
stack, so the reports said only that it happened.

`ConsumerState.ref` is the widget's element. It throws once the element is
gone, so any `ref` written *after* an `await` is a bet that the screen outlives
the call. Three places lost that bet:

- **Sign-in and sign-up** (`lib/features/auth/screens/sign_in_screen.dart:74`,
  `sign_up_screen.dart:43`). The worst shape of it: a sign-in that *works* is
  precisely what makes the router replace the screen, so the read after the
  await raced the redirect and the crash landed on the success path. Whether it
  threw depended on which of the two won, which is why it was intermittent
  rather than constant.
- **The calculator's prefill**
  (`lib/features/calculator/screens/calculator_screen.dart:`), which walks a
  chain of five provider reads with awaits between them. Leaving the screen
  mid-chain threw on the next read.

Fixed by reading through `ProviderScope.containerOf(context, listen: false)`,
captured before the first await. Guarding on `mounted` instead would also stop
the crash, but on the auth screens it would drop
`TextInput.finishAutofillContext()` on exactly the sign-ins that succeeded —
the password manager is then never offered the credential that just worked. The
container outlives the widget, so both survive.

Covered by `test/features/auth/auth_unmount_test.dart` and one case in
`test/features/calculator/calculator_screen_test.dart`: the repository is
gated on a `Completer`, the router is sent elsewhere, and only then does the
call finish. Each reproduced the exact message before the fix.

**Found alongside, same root:** `reminder_rule_sheet.dart` caught its save
failure and then called `setState` with no `mounted` check, so a sheet
dismissed mid-save threw *out of the catch block that existed to contain the
failure*. Guarded like its sibling sheets.

**Still open, same family, lower stakes:** several `ref.invalidate(...)` calls
sit after an await *inside* a `try`, so on an unmount they throw, are caught,
and are silently swallowed — no crash, but the list the user returns to is
stale until something else refreshes it. Affects the entry sheets and the
`_run` helpers in `tyres_screen.dart`, `api_access_screen.dart` and
`entry_attachments.dart`. The same container capture fixes it.


### Tapping "More" slid a page in over its own navigation bar
**Was Low**, and purely visual. The bottom nav's five destinations are peers,
so four of them were registered with `_tabPage` and cross-fade
(`lib/core/router/app_router.dart:215`). `/more` was added later with a plain
`builder:` and so fell back to the platform push transition — the animation a
*detail* page gets. Tapping it slid a new page in sideways over the very
navigation bar it was launched from, while every other tab dissolved in place.

One line, and now asserted for every tab rather than for the one that was
noticed: `test/core/router/tab_routes_test.dart` walks `tabRoutes` and requires
each path to be registered with a `pageBuilder`. The route table is the only
place this is visible; nothing about the screen itself is wrong.


### A setting said "On" in the colour that means "unavailable"
**Was Low.** The pump-autofill row set `enabled: false` once location
permission had been granted, because there was nothing left to ask for. A
disabled `ListTile` greys its title and subtitle, so the row read "On" in the
same grey the app uses for controls you cannot use, beside an accent tick —
three signals, two of them contradicting each other. It is a normal row with no
`onTap` now: nothing left to do is not the same as nothing you may do.

### The dashboard spent a card to say it had nothing to say
**Was Low.** Having nothing to bundle is the ordinary case, and it was
rendering a full card, with card padding, on every visit to say so. The
sentence stays — it is the only thing that tells someone bundling exists before
they ever have two jobs due together — but as a line rather than a panel.


### Every imported file was decoded as Latin-1
**Was High**, silent, and the real cause of "the Fuelio import didn't bring in
all my intervals". `XFile.readAsString` takes an `encoding` parameter and
defaults it to UTF-8 — and then ignores it when the XFile holds bytes rather
than a path, running `String.fromCharCodes`, which is Latin-1
in the `cross_file` package (`XFile.readAsString`, version 0.3.5+4). Android's document picker
hands back bytes.

So every Croatian letter in an imported file arrived mangled: `č` (UTF-8
`0xC4 0x8D`) as `Ä` plus an unprintable byte. Nothing threw. `mapFuelioServiceTitle`
then failed to match any needle containing a diacritic, and exactly those
reminders vanished — spark plugs, brake fluid and the cabin filter — while
every rule matched by an ASCII needle imported fine. The user was shown a
snackbar naming the three as "not recognised", spelled in mojibake.

Reproduced on an emulator against a local stack: 7 of 10 reminders before,
10 of 10 after. Fixed by decoding the bytes directly
(`lib/core/files/file_text.dart`), which also strips a byte-order mark and
tolerates malformed input rather than failing a whole import over one byte.
The same call was used by the **backup restore** and the **any-app CSV import**,
so both had it too — a restored garage's name, notes and station names were all
affected.

**Why no test caught it:** the import tests build their fixture with
`XFile.fromData(utf8.encode(csv))`, which is precisely the broken path — but
every CSV in them was pure ASCII. `test/core/files/file_text_test.dart` now
pins both directions, including a test asserting that `readAsString` still gets
it wrong, so the workaround can be removed when cross_file fixes it.


### The Fuelio import hung forever, and lost the tail of the work
**Was High.** The progress spinner was dismissed through the calling widget's
`context`, guarded by `context.mounted` — and the import is the thing that
unmounts it: creating the household's first car invalidates the vehicle
providers, which swaps out the dashboard empty state the import was started
from. The guard then returned early and left a `barrierDismissible: false`
modal with nothing to tap. The import had usually *succeeded*.

The second half is worse and explains a separate report of "it didn't import
all my intervals": faced with a spinner that never ends, people force-quit the
app — and reminders are imported last, after fills, costs and services. Killing
it mid-run therefore loses exactly the tail. The import is idempotent, so
re-running it fills in what is missing.

Fixed by capturing the navigator before the first await and popping in a
`finally` (`lib/features/settings/data/fuelio_import_action.dart:212`). Worth
repeating the shape elsewhere: **a progress dialog must never be dismissed
through a context the work itself can invalidate.**

### Fuelio's accessory belt was imported as the timing belt
**Was Medium**, and expensive to believe. `mapFuelioServiceTitle` matched on
`remen`/`belt`, so Fuelio's Croatian preset "Zamjena remena za pogon dodatnih
agregata i napinjača" was filed as `service_timing_belt` — a different part on
a very different interval. The belts are now told apart, and the fifteen
service types added in migration 0035 (brake discs, drums, glow plugs, DPF,
AdBlue, fuel filter, clutch, differential oil, water pump, shocks, alignment,
A/C, bulbs) are matched too; the mapping had not been revisited when they
landed, so a backup naming any of them imported as nothing.

`klime` is deliberately ambiguous in Fuelio — it names both the cabin filter
and servicing the air conditioning — so only the filter wording claims it.

### Croatian broke the vehicle action row mid-word
**Was Medium.** Three buttons in a `Row` of `Expanded`s take a third of the
width each regardless of how long a word is, and a button narrower than its own
label does not shrink the text — it breaks it, mid-word, because that is the
only break available. "Kalendar" rendered as "Kalenda / r" and "Garniture guma"
as "Garnitur / e guma". A `Wrap` sizes each button to its content.

Fixing it surfaced a pre-existing overflow underneath: the tab's column had the
projection list in an `Expanded` and the recalls card and action row as fixed
children, so at twice the default text size it overflowed by 56 pixels before
the buttons wrapped and 176 after. The footer was capped and scrollable after
that, and is gone entirely now — see "The Service tab's footer took the height
the schedule needed" below.

### A rule with two deadlines showed one and hid the other
**Was Medium**, and the reason the rate defect above was so hard to see. The
projector computed both a distance-derived date and a calendar one, kept the
earlier as the due date, and discarded the other. So a car whose oil change was
30,000 km *or* 24 months away showed "27 July 2028" with no indication that the
date was the calendar deadline, that the odometer deadline existed, or that at
its actual driving rate the odometer one lands ten months sooner. Both dates
now live on the projection, and the row prints the non-binding one — with the
driving rate the prediction rests on stated above the list. Decisions 51 and 52
are two halves of the same story.

### Every distance-based due date was late, by the same mechanism
**Was High**, and invisible: the numbers on screen all agreed with each other.
The driving rate divided a car's total distance by its total age, so a vehicle
imported with years of history barely registered its owner's current driving. A
Clio was told its oil change was due 27 July 2028 with 28,977 km still to run,
while its last eight fill-ups ran 4,276 km in 63 days — 68 km/day. That 2028
date is exactly 24 months after the previous service, so it was the calendar
deadline winning by default: the lifetime rate pushed the odometer deadline out
past it. At 68 km/day the odometer deadline lands around 19 September 2027, ten
months sooner. The rate now comes from the last
90 days of the odometer series, falling back to the whole series when that
window is too thin to trust. Decision 51 has the trade-off, and the sharp-edges
list in `04-maintenance-projection.md` notes that a second, unwindowed
`kmPerDay` still exists on `ReminderProjector` with no production caller.

### One 200 EUR visit read as four 200 EUR visits
**Was Low**, and only ever wrong in the reader's head — nothing summed it. A
service entry carries a list of service types, and the Service list printed the
entry's whole cost against every type it covered, so a single bundled visit put
"200,00 €" on the oil change, the oil filter, the cabin filter and the brake
fluid. It now says "200,00 € za 4 stavke" when a visit covered more than one.

### The due line said "Due" twice
**Was Low.** `_dueLabel` joined two complete sentences with a separator, so
every row read "Due 4 Sep 2026 · Due at 60,000 km" — and in Croatian
"Dospijeva 27. srp 2028. · Dospijeva pri 77.006 km". The odometer half no
longer carries a verb of its own.

### The planner kept the exclude button the dashboard had already replaced
**Was Low**, and a good example of a fix landing in one of two places. The
dashboard's bundle card records at length why "Not this one" became an icon
with a tooltip: as a word beside the row it read like a decision about the
service rather than about the suggestion. The planner showed the same bundles
with the same string as a visible `TextButton` — rendering in Croatian as
"**Preskoči**", Skip, a thumb's width from a brake fluid change — and without
the reassurance line the card added. Both screens now use the same control and
the same note.

### Bundling suggested visits years away
**Was Medium**, and looked like a bug because it was indistinguishable from
one. `BundlingEngine.bundle` grouped every projection over all time, so a car
with a three-year oil interval got "combine 4 items into one visit on 27 July
2028" at the top of the dashboard and a second group for 2030 on the planner —
both correct, both years from being actionable, both occupying the space
reserved for what to do next. Suggestions now stop twelve weeks out, the same
horizon the planner's runway draws. Decision 50 has the trade-off.

### The Service tab's footer took the height the schedule needed
**Was Medium.** The tab ended in a fixed block — the recalls card plus a
wrapped row of three buttons — capped at 60% of the tab's height. The cap
stopped it overflowing; it did not stop it *taking*, and on a phone the list of
what the car actually needs was squeezed into the strip above it, showing three
items where four were due. The recalls card scrolls inside the list now,
logging a service is an extended FAB, and the calendar and tyre sets moved into
the vehicle menu with the other once-in-a-while actions.

### The fuel header quoted an amount with no unit, under a label with the wrong one
**Was Low**, and wrong for imperial households rather than merely unclear. The
running figure rendered as a bare "0,09 €" beneath a heading assembled in code
as `'${l10n.fuelPricePerUnit} / km'` — so the number carried no unit, and the
label named a unit a household reading miles is not in, over a figure that was
per kilometre regardless. `UnitFormat.formatCostPerDistance` now converts and
prints "0,09 €/km" or "$0.15/mi", and the label says what is being measured
rather than what it is per.

### The calendar hid the last day of a six-row month
**Was Medium.** The month grid was an `Expanded` scroller, so it took whatever
height was left over and clipped its last row against the divider below: in a
month starting late enough — August 2026 — the 31st rendered as half a circle.
Shrink-wrapped and non-scrolling, the grid asks for the height it needs.


### A refused rename reported success
**Was High**, and silent. `_renameGarage` awaited `SettingsController.save`,
which swallows its error into the notifier's state, then read that state back.
Nothing on the garage screen watches `settingsControllerProvider`, so under
Riverpod's auto-dispose the notifier was disposed and rebuilt between the two
statements: the read returned a fresh `AsyncData` and the screen said "Garage
renamed" over a rename the database had rejected.

`save` now **returns** the failure as well as setting the state
(`lib/features/settings/providers/settings_providers.dart:94`). The state is
what a screen watching an error banner needs; the return value is what a
one-shot caller needs, and it survives the round trip. Worth checking any other
"fire the controller, then read its state" pair for the same shape.

### Dead features: built, shipped, and unreachable
A sweep for the `deleteHousehold` pattern (a capability with no caller) found:

- **`TyreRepository.deleteSet`** — interface, Supabase implementation and two
  test fakes, no caller. A tyre set could be retired, never deleted. Now wired.
- **Tyre "Retire" used the shared delete confirmation**, so it asked "Delete
  entry?" and warned it could not be undone — of an action that keeps the set
  and every reading on it. It has its own words now.
- **`fittedTyreSetProvider`** — computed which set was on the car; nothing ever
  showed it. Removed rather than kept warm.
- **`memberNamesProvider`** — unused because `timeline_screen.dart` rebuilt the
  same map inline. The screen watches the provider now.
- **15 orphan ARB strings.** Two were real gaps and are now shown:
  `attachmentsSaveFirst` (a new entry rendered *nothing* where attachments go,
  which reads as "not supported" rather than "not yet") and
  `householdRenameAdminOnly`. The other thirteen were leftovers and are gone.

The sweep is cheap to repeat: unreferenced ARB keys, providers whose name
appears once, and repository methods with no caller outside `data/`.


### Statistics overflowed its own toolbar at large text sizes
**Was Medium**, and invisible to anyone reading at the default size. The app bar
carried the title, a vehicle-name dropdown and the customise button; at
`TextScaler.linear(2)` on a 420-pixel phone that row overflowed by 46 pixels —
an exception, not a wrap. A toolbar is a fixed-width row by construction, so no
amount of shrinking the dropdown fixes it, only moving the labelled control out.

Found by adding the accessibility test the audit said was missing, and worth
noting that the test initially blamed the wrong widget: four fixed-width tabs
looked like the obvious culprit, and a control pumped in isolation proved they
ellipsize cleanly. The 46 reproduced exactly with the app bar's actions.
Fixed in decision 44; the picker now sits with the period bar.

### A screen test hung for four hundred seconds over a deleted line
**Was a self-inflicted Low**, recorded because the symptom pointed nowhere near
the cause. `setUp(() => SharedPreferences.setMockInitialValues({}))` was dropped
from `settings_screen_test.dart` while splitting the screen. Without it,
`SharedPreferences.getInstance()` waits on a platform channel with no handler —
a future that never completes, inside a test with no timeout of its own. The run
did not fail; it stopped, and the first test to touch preferences was five tests
in, so the output looked like an infinite scroll in an unrelated helper.

Two lessons. A widget test that stops rather than fails is usually waiting on a
platform channel, not looping. And killing a stuck `flutter test` leaves
orphaned `flutter_tools` processes that make every subsequent run look slow —
17 had accumulated before anyone counted, which turned one real hang into
apparent hangs everywhere.

### Four features had one way in on a phone, and the fix shipped desktop-only
`_SidebarLinks` gathered Garage, Statistics, the trip log, fuel stations and
the calculator, under a comment stating the problem — "Width a phone does not
have is width to stop hiding things: these are otherwise reachable only through
Settings" — and rendered only above 1200px. On a phone, three of those were
unlabelled dashboard icons and the **trip log had a single conditional entry
point**: a timeline row that exists only once a trip has already been logged. A
feature reachable only after you have used it is not reachable.

The list now lives in one place (`lib/core/widgets/secondary_destinations.dart`)
and feeds both the sidebar and the **More** tab, so the phone and desktop
navigation graphs cannot drift apart again. They already had: the sidebar's own
comment claimed these lived under Settings, and only the garage did.

### Timeline answered "find the thing I logged" with a list to search again
Rows pushed the *screen* an entry lives on, and cost, odometer and income rows
pushed `/vehicles/:id`, which opens on Economy — not even the tab holding the
entry. Timeline is the app's only search surface, so this was the one place
that had to land on the thing itself. `TimelineItem` now carries `entryId` and
a row opens its own sheet, the way every sibling list already did.

The tap handler is wrapped: an entry that cannot be loaded now reports through
`failureMessage` instead of throwing out of a callback where nothing is
listening — which is what happened the first time this was wired up.

### The Service tab showed what was due and offered nothing to do about it
A read-only copy of the Maintenance screen's list — no row menu, no add action
— while the Costs tab beside it carried two inline add buttons, so there was no
rule about where "add" lives. Logging a service from the car you were looking
at took six taps through two screens; it now takes one. The tab reuses
`MaintenanceProjectionList` rather than duplicating it, and the button beside
it now says Calendar, which is what the Maintenance screen uniquely offers.

### The design detector never covered a single line of Flutter
Proven by a byte-identical control: the same file as `.html` produces findings,
as `.dart` produces `[]` and exit 0, because `.dart` is not in
`SCANNABLE_EXTENSIONS`. **That exit 0 is a false negative, not a pass.** The
hook that runs after UI edits has only ever checked `web/*.html`, so every
Flutter screen in this repo is outside its reach. Worth knowing before trusting
a clean hook run on Dart work.

### Two defects introduced and caught in the same day
Both from the same session's UI work, both found by review rather than by tests:

- The dashboard's "Set what it needs, and when" opened the *log a past service*
  sheet, which has no interval in it. Reminder rules feed Due soonest, the
  planner runway and bundling, so a new user followed the instruction and found
  three surfaces still empty.
- The timeline's filter chips sat in a fixed `height: 40` box. Chip height grows
  with the system font and the box does not, and a horizontal `ListView` clips
  rather than overflowing — so it would have shipped visibly broken at 1.3×
  without throwing anything. Now a `Wrap`, which also renders all six chips
  instead of the three that fit.

**Nine `IconButton`s had no tooltip**, including the password-visibility toggle
in `labeled_field.dart` — a shared widget, so that one was unlabelled on every
password field in the app — and two dashboard buttons that navigate while
announcing only "button". All 27 are labelled now.

### Recall lookups left the EU on every screen visit
The recalls card called `api.nhtsa.gov` automatically whenever a vehicle with
make, model and year was opened — an undisclosed transfer to a **United States
government** API, while `PRIVACY.md` said NHTSA is contacted "only when you
press **Look up**". The string for a button, `recallsCheck`, had been sitting
unused in both languages, which suggests it was designed this way and shipped
otherwise. It is now behind that button, asked once per visit rather than
remembered, and both the policy and its hosted copy describe it.

**Worth generalising:** an automatic third-party call is a disclosure, not a
feature detail. The privacy tests compare `PRIVACY.md` against
`web/privacy.html`; nothing compares either against what the code actually
does, so this class of drift is invisible to CI.

### A dialog with fields lost one behind the keyboard
Six `AlertDialog`s put their fields in a plain `Column`. A dialog shrinks when
the keyboard opens, an unscrollable column then clips its last field and
squeezes the buttons into what is left — reported as "buttons get mushed and
one input field gets covered", on the tyre-set dialog, which has three fields
and a dropdown. All six now pass `scrollable: true`, which is Flutter's own
answer: it wraps title and content in a scroll view and handles the inset.

### A garage could not be renamed, joined or ended
Three gaps in the same screen, all of them missing UI over plumbing that
already existed:

- **Rename.** `householdSettingsToRow` has carried `name` since the beginning
  and no screen ever offered a field. Now admin-only, enforced by a trigger
  (`supabase/migrations/0036_admin_renames_garage.sql`) rather than by a check
  in the app — `households_update` deliberately stays open to members so they
  keep the units and currency that are genuinely theirs, and the name is the
  garage's identity rather than a preference.
- **Joining a second garage.** "Create another garage" was offered and joining
  one was not, so somebody handed a code for a garage that already exists could
  only make a third. `joinHousehold` existed on the controller; only onboarding
  ever called it.
- **Deleting one.** `households_delete` has been admin-only since `0001` and no
  repository method or screen ever used it, so an admin could leave a garage
  but never end one.

### Onboarding's join half was below the fold
Both halves were always there — "Create a garage" and "Join with a code",
stacked in a scroll view — and on a phone the second sat off-screen with
nothing to say it existed, so somebody holding an invite code saw a form for
making a garage and concluded that was the only option. A two-segment control
now puts the choice first.

### A dialog disposed its controller while the dialog was still using it
Introduced and fixed in the same sitting, and worth recording because the
tempting fix is the wrong one: disposing a `TextEditingController` as soon as
`showDialog` returns tears it out from under the exit animation ("A
TextEditingController was used after being disposed"), and the existing code
avoided that only by never disposing at all. `_TextPrompt` owns its controller
and disposes it in its own lifecycle, which is the only place that is correct.

### The brakes could not describe most cars
Presets shipped with brake **pads** front and rear and no discs at all — the
wrong half of the job, since discs are replaced with pads — and no drums, so
cars with rear drums, which is most small European hatchbacks, could not record
their rear brakes. Fifteen presets added in `0035`, including the things a
*European* fleet needs that American checklists omit: glow plugs (there was no
diesel counterpart to spark plugs), DPF, AdBlue, a clutch, and a fuel filter,
which was missing while air, cabin and oil filters were all present.
`test/features/maintenance/service_type_labels_test.dart` reads the keys out of
the SQL, so a preset added without a label cannot ship.

### The vehicle app bar became a row of grey glyphs
Report, odometer, transfer and edit each had an icon button, and archive and
delete then added a menu beside them — five targets on a phone's app bar, four
of them small outlined shapes that are hard to tell apart at a glance. One icon
stays, and it is the everyday one: a reading is logged far more often than a
car is edited, transferred or reported on. The rest moved into the menu, which
gained icons of its own so it reads at a glance rather than as five lines of
similar-length text.

The menu labels needed `Expanded` around them: a popup menu is 256 logical
pixels wide, and the Croatian labels overflowed it by 72.

### A car you sold stayed in your garage
See the realtime note above: the seller's device was never told, because the
update that moves the vehicle belongs to the buyer by the time it is checked.
The transfer row stays readable by the seller, is now in the publication, and
invalidates the vehicle list when it changes. The seller also gets a notice
naming the car — which meant recording the nickname on the transfer row, since
the vehicle itself is unreadable the moment it moves.

### A fill-up could contradict every reading that was not a fill-up
The odometer guard read the fuel log alone, so a household that logs services
or bare readings and pays cash at the pump could type any number into a fill-up
and be told nothing — exactly the household odometer entries were added for.
It now measures against every kind of reading.

**The subtle half:** it cannot use `odometerSamplesProvider`, which runs the
samples through `OdometerHistory.sorted` — that keeps one reading per day and
**drops anything going backwards**, which is right for measuring a rate and
exactly wrong here, because the contradicting reading is the one being looked
for. `rawOdometerSamplesProvider` exists for that distinction.

### "Not this one" was a one-way trim that explained nothing
The bundle card's per-item button sat a thumb's width from the row it removed,
was worded like a decision about the service itself, mutated the bundle in
place so there was no way back, and did nothing whatever to the underlying
schedule. It is now an icon with a tooltip, trimmed items can be put back, and
a line says what trimming does and does not do.

The card also **does** something now: it offers to log the visit with the
bundled items already ticked. Its whole premise was that these are happening
together, and it said so and then left you to tick them off by hand elsewhere.

### Clearing a vignette meant logging a service for it
Registration, insurance and vignettes raise reminders in the *service*
namespace, because that is where the projection engine looks — but they are
paid, not performed. Logging the cost created the *next* reminder and never
completed the outstanding one, so the only way to be rid of "Vignette expires"
was to record having serviced a vignette. Paying now settles the reminder that
asked you to, and a due item offers **Log it as done**, which opens the cost
sheet for a cost-born reminder and the service sheet for a real one.

### The public face of the app was a password box
garage.hrva.cc redirects an unauthenticated visitor straight to sign-in, so
nothing anywhere said what Garage is for. `web/features.html` is a static page
— static so that neither a person evaluating the app nor a search engine has
to run a Flutter bundle to read it — linked from the sign-in screen and
guarded by `test/ci/showcase_test.dart`.

### Registering appeared to do nothing
A sign-up that needs a confirmed address succeeds and hands back **no session**,
so nothing on screen changed: the form sat there looking as though the button
had failed, and the confirmation email went unmentioned. `signUp` now answers
whether confirmation is pending instead of discarding the response, and the
screen says which address it went to.

### Signing in before confirming blamed the password
Every `AuthException` mapped to one message — "Sign-in failed. Check your email
and password." — which is false for an unconfirmed address and unhelpable: the
credentials are right, and no amount of retyping fixes it.
`AppFailureKind.emailNotConfirmed` now carries its own sentence, matched on the
error code *and* the message because older projects answer without a code.

### A failed email link landed on a silent sign-in form
Supabase reports the reason in the URL — `error_description` in the fragment or
the query, depending on the flow — and nothing read it, so someone who did
exactly what the email asked arrived at a screen that said nothing at all.
`authErrorFromUrl` (`lib/core/links/auth_link.dart:19`) reads both, the raw
wording goes to the failure log, and the user gets a localized sentence.

### Archiving a vehicle was built and reachable from nowhere
`setArchived` had no caller in any screen and `archivedVehiclesProvider` no
reader at all, so a vehicle sold or scrapped stayed in every list forever and
the button the user went looking for did not exist. Both now live in an
overflow menu on the vehicle screen, and archived vehicles appear in a section
of their own on the list — archiving with nowhere to see the result is a
one-way trip.

**Per-vehicle delete now exists too**, which reverses a stated position: the
repository comment read "vehicles are never hard-deleted from the UI". The
database has allowed it, admin-only and cascading, since `0020`; only the UI was
missing. The confirmation names what goes and points back at archiving.
`test_rls/rls_test.dart` now proves a non-admin member cannot do it, which
matters more now that a button offers it.

### The cheapest station in the country was free
The ministry's feed carries `cijena: 0` for a pump a station is not currently
selling from, and the parser rejected only `null` — so zero was read as a real
price, won every comparison there is, and the app announced a station as the
cheapest around at 0.00 €, in the largest text on the screen. Dropped at the
parse boundary (`lib/domain/stations/fuel_station.dart:383`) rather than in
`cheapestFor`, so it cannot reach the station's own price list either. Negative
prices go the same way.

### Offering a vehicle for transfer asked you to confirm a deletion
`_offer()` called `confirmDelete`, which is hard-wired to "Delete entry? / This
cannot be undone." over a red **Delete** button. Nothing is deleted by handing
a vehicle over, and a seller could reasonably read that dialog as being about
to destroy the car's history. `confirmDelete` is now a thin wrapper over
`confirmDestructive`, which takes its own title, body and button label
(`lib/core/widgets/confirm_delete.dart:36`); the transfer passes its own.

**Worth generalising from:** a shared confirmation that hard-codes its verb
will be borrowed by something that does a different thing. The other nineteen
callers really do delete, which is why this went unnoticed.

### A transfer code you had already handed out was invisible
The code lived in the screen's local state, so leaving and coming back offered
to generate one — with the seller unable to see the code already in a buyer's
hands. The server has reused an outstanding code since migration `0030`
(`supabase/migrations/0030_vehicle_transfer.sql:72`); the seller was the only
party who could not see it. The screen now reads it on load through
`outstandingTransferCode`, which is a read where `offerTransfer` is a write.

### Password managers could not fill either credential form
Sign-up had no `AutofillGroup` and no `autofillHints` at all; sign-in had the
hints and no group. Proton Pass, Bitwarden and the platform's own manager could
therefore neither fill nor offer to save, which pushes people toward a password
they can type from memory. Both forms are now one group with every field
hinted, sign-up asks for `newPassword` so a manager offers to generate one, and
`TextInput.finishAutofillContext()` fires on success so the credential is
offered for saving.

### A calculator field asked for a quantity of nothing in particular
The fuel box appears in two modes and means opposite things — fuel still in the
tank when computing reachable distance, fuel already burned when computing
consumption — and was labelled "Volume" in both, borrowed from the fill-up
sheet where the surrounding form supplies the context. Now labelled per mode.

### The empty dashboard promised a checklist and delivered one link
Of its three steps only the first was tappable, and the other two hard-coded
`done: false` so they could never tick however much you logged. It now offers
the four ways a vehicle actually gets into a garage — by hand, from Fuelio,
from any CSV, or handed over by its previous owner — three of which were buried
in Settings, which is the last place someone staring at an empty screen looks.
A garage that has a vehicle but no history gets a different, shorter card.

### Every browser preflight to the public API crashed the function
`public-api` answered `OPTIONS` with `json({}, 204)`. A 204 may not carry a
body, so constructing that Response throws
`TypeError: Response with null body status cannot have body` — the handler died
before returning anything, and no browser could ever call the API. It survived
because the documented consumers are scripts and home servers, which send no
preflight; the CORS headers the function sets so deliberately were therefore
decoration. Found by the first test ever written against that function, and
confirmed against the real edge runtime. Now `new Response(null, …)`.

**The general shape**, worth more than the bug: a code path only reachable from
a client nobody in the project uses is a path nobody has run. The four edge
functions had no tests at all, which is what let a crash on a documented entry
point sit there indefinitely.

### The edge functions had no tests and could not have had any
Each was one `Deno.serve(async (req) => …)` with `createClient` called inline —
nothing exported, so importing one to test it would have started a server. Each
is now a three-line `index.ts` over a `handler.ts` that exports `makeHandler`,
taking its client, `fetch`, clock and FCM token exchange as dependencies. 50
Deno tests run in CI (`.github/workflows/ci.yml`), which also formats, lints
and type-checks them — nothing else type-checks these files, so an error in one
used to reach production and surface as a 500 when the scheduler fired.

**Verified against the real thing, not just the fakes.** The split changes
files that deploy by hand, so all four were served with
`supabase functions serve` and exercised over HTTP before this was called done.

### Nothing caught anywhere was reported at all
The failure log only ever saw what a screen chose to hand it. A build that threw,
a future nobody awaited, a plugin failing on a background isolate — all printed
to a console no user has, and the diagnostics then reported the run as clean.
`installGlobalErrorHandlers` (`lib/core/errors/global_error_handler.dart:24`)
routes both `FlutterError.onError` and `PlatformDispatcher.onError` into
`reportFailure`, chaining onto whatever was already installed rather than
replacing it.

Two things this deliberately does **not** do. It does not mark errors handled —
the platform handler returns `false`, so everything still reaches the console.
And it does not send anything anywhere: there is still no crash reporter, by
choice, so a crash the user never reports is still a crash nobody sees.

### The failure log was memory-only and unreachable
It is now written to `shared_preferences` and read back at startup, which matters
because a crash *is* a restart — the old log forgot exactly the failure worth
reading. Settings → About → **Diagnostics** lists it, shares it with the version
prepended, and clears it. Persisting is best-effort: a failed write is logged and
ignored, because an app must not fall over over its own error log.

### Four tables had policies and no test
`service_entries`, `tyre_readings`, `device_tokens` and `profiles` were all
scoped by RLS and none of it was proved — against the rule in `CLAUDE.md` that a
new table needs policies *and* a case in `test_rls/rls_test.dart`. Each now has
one, with a positive control. Two were worth writing for their own sake:
`device_tokens` is scoped to a **person**, not a household, so a fellow member
who can see every car in the garage still cannot read another member's push
token; `profiles` is deliberately the other way, readable across a shared
household because the member list and entry authorship both come from it.

`webhook_dispatch_config` remains untested on purpose: RLS is on with no policy
at all and the grants revoked, so no signed-in user can reach it, and the
dispatcher reads it as definer (`supabase/migrations/0025_webhook_dispatch_config.sql:27`).

### An RLS test that could only ever pass once
The first `device_tokens` test used a literal token string. `token` is the
primary key and the suite runs against a database that outlives it, so the second
run collided with the row the first had left behind — owned by a different user,
so RLS refused the write and the failure read like a policy bug. Tokens are now
derived from the user's id. **Anything this suite inserts under a natural primary
key has to be unique per run**, and `supabase db reset` between runs hides the
problem rather than fixing it.

### CI failed twice on things nobody had written
**Was Low** each time, and both were the same shape: the checks that decide
whether code may ship were configured less carefully than the deploy they gate.

**A floating SDK.** The three CI jobs asked for `channel: stable` with no
version while both deploy workflows pinned `3.44.6`, so CI ran on whatever
Flutter was newest that morning. A formatter change in a later SDK reported
`test/core/theme/page_transitions_test.dart` as unformatted on a tree that
formats clean locally — a red build with no commit behind it. All three jobs
now pin the same version the release builds with
(`.github/workflows/ci.yml:45`), and a test fails if any Flutter setup step
anywhere loses its pin.

**A key the suite needs and the job never passed.** The account-deletion cases
in `test_rls/rls_test.dart:63` need `SUPABASE_SERVICE_ROLE_KEY`, because they do
what the `delete-account` function does. The job exported only the anon key, so
`setUpAll` threw and the run reported `0 tests passed, 2 failed` — which names
neither the key nor the reason. The job now reads `SERVICE_ROLE_KEY` out of
`supabase status -o env` alongside the other two, and a test derives the
required names from the suite itself and fails if the workflow does not pass
one of them.

Verified locally the way CI runs it: `supabase db reset` from scratch, then the
suite with all three variables — 57 passing.

### The push sender rejected the only caller it has
**Was High** the moment push was switched on, and invisible until then: every
scheduled run would have been refused.

The function gated itself on `authHeader.includes(SUPABASE_SERVICE_ROLE_KEY)`,
matching the injected env value as a string. On a project with the newer secret
keys that value is an `sb_secret_…` string, while the platform's own
`verify_jwt` lets only a JWT reach the function at all — so no caller could
satisfy both. Proven against production: the legacy service-role JWT passed the
gateway and failed the comparison (403), the secret key failed the gateway
(401).

It now checks the **role** carried by the token
(`supabase/functions/push-due-reminders/handler.ts:124`), which the platform has
already verified the signature of, and still refuses an anon token — the one
every copy of the app holds. Verified by calling
`select public.run_due_reminders_push()` and reading `net._http_response`:
`200 {"pushed":0}`, where it had been `403 Forbidden`.

**How it hid:** nothing calls this function except a cron job whose wrapper is
silent by design when unconfigured, so the first real evidence would have been
a household never being notified.

### A car going away while you were looking at it crashed the screen
**Was Medium**, and it shipped: the vehicle picker on Statistics and on the
calculator has been there for releases. The screen keeps the chosen id in its
own state, and a `DropdownButton` whose `value` is not among its `items`
asserts rather than degrading. So when a car left the fleet while a screen held
it selected — another member transfers or deletes it, realtime refreshes the
list — the screen threw instead of falling back.

Fixed with one guard, `chosenVehicleId`
(`lib/features/vehicles/vehicle_choice.dart:10`), used by Statistics, the trip
log and the calculator: a car that is gone reads as "all vehicles", which is
what the screen showed before anything was picked. Proven by reverting the
guard — the test fails on the framework assertion, not on a missing widget.

It is not in the release notes. Every line there is a feature this release
gives everyone, the file is at 487 of its 500 characters, and this needs a
household to delete a car while a second device sits on the statistics screen.
Worth adding if that turns out to be less rare than it sounds.

### A CSV in gallons imported a price per litre it never said
**Was High for anyone importing an imperial file**, and silent. `CsvUnits`
converted the volume of a fill-up and left `pricePerUnit` alone, so ten gallons
at 4.20 per gallon were stored as 37.85 litres at "4.20 per litre" against a
total of 42 — an entry contradicting itself, and every price-per-litre figure
out by nearly four times.

Worse, "gallons" meant the US one whatever the household reads. A UK household
importing UK gallons had every volume understated by a fifth, which nothing
downstream could detect.

Both fixed in `lib/features/settings/data/csv_import_action.dart:27`:
`pricePerVolume` divides where `volumeL` multiplies, and the factor comes from
the household's own volume unit (`litresPerGallon`,
`lib/core/format/unit_format.dart:23`) rather than a constant. A household
reading litres that ticks the box still gets the US gallon, which is what an
unqualified "gallons" means in most exports.

### The backup called itself everything and left two things out
**Was Medium.** `buildBackup` carried the six entry kinds and the vehicles, but
not the reminder rules or the tyre sets — under a button labelled "Back up
everything". Losing reminders is the silent kind of loss: the log comes back
after a restore and the notifications simply never do. Tread readings are worse
still, being the one thing nobody can measure again afterwards.

Both are now in the file and in the restore, additively as everything else is
(`lib/features/settings/data/backup_action.dart:78`). Tyres restore in two
steps because a set has no id until it is created; a set already there is left
alone and only gains readings it lacks.

**Still out:** photo attachments, which are files in storage rather than rows,
and which a JSON file cannot carry without becoming something else.

### Distance-based reminders would have pushed off a stale odometer
**Was Low only because the function is not deployed.**
`push-due-reminders` read the current odometer from the newest **fuel** entry,
which is exactly the coupling the app itself was fixed to remove: a household
recording readings without buying fuel — an EV, or anyone who stopped logging
fill-ups — would have had every distance-based reminder projected from a number
that stopped moving.

It now takes the highest reading across all six tables that record one
(`supabase/functions/push-due-reminders/handler.ts:279`), mirroring
`OdometerHistory`. The highest rather than the newest, because an odometer only
goes up and a lower later number is a typo. `test/ci/entry_kinds_wired_test.dart`
fails if a kind is left out of it.

**Deployment:** edge functions do not deploy themselves. This one is dormant
until somebody runs `supabase functions deploy push-due-reminders`, and the fix
is dormant with it.

### Opening a sidebar link slid the whole browser window
**Was Low**, and only on a desktop-width window. Household, Statistics, Fuel
stations and the calculator are pushed routes with no custom page, so they took
the platform's push transition — which on the web in a Mac browser is the
Cupertino slide, since Flutter reports `TargetPlatform.macOS` there. The sidebar
is drawn inside each page, so the whole window slid in from the right while the
page underneath, sidebar and all, parallaxed out to the left: one sidebar left
and an identical one arrived. The five tab routes were immune only because
`_tabPage` gives them a fading page of their own.

Fixed in the theme rather than route by route
(`lib/core/theme/garage_theme.dart:228`), because the same slide was on all ten
pushed screens that draw a sidebar, not only the four in the sidebar itself.
Phone-width windows keep the platform transition and its back gesture.

**Still true underneath:** the sidebar is part of every page rather than a shell
around them. The cross-fade hides it — two identical sidebars fading into each
other look static — but a `ShellRoute` is what would make it actually so, and
anything that animates a page will keep having to work around this.

### Bi-fuel vehicles produced mixed economy figures
**Was Medium.** `FuelEconomy.compute` treated every fill as the same fuel, so a
car alternating petrol and LPG produced spans that averaged the two into a
figure that was neither.

A vehicle may now name a second fuel it takes
(`supabase/migrations/0031_bi_fuel.sql:12`), a fill-up may name which went in,
and the algorithm computes one chain per fuel
(`lib/domain/fuel/fuel_economy.dart:54`). Both columns are nullable and null
still means what it always did: one fuel, no question to ask, existing history
untouched.

The subtlety worth remembering is what `primaryFuelKey` is for. A household that
turns on the second tank part-way through has older rows with no fuel on them,
and those belong to the chain of the fuel the car mainly runs on rather than to
a chain of their own. The economy provider passes the vehicle's own fuel — but
only when the car is bi-fuel, so a single-fuel car's points stay unlabelled.

### Deleting an account failed for anyone who shared a household
**Was High**, and a Play compliance problem: in-app deletion has to work.

Seventeen `created_by` and `redeemed_by` columns referenced `auth.users` with
the default `no action`, so Postgres refused to delete a user while any row
pointed at them. A **solo** household worked only by accident —
`household_members` cascades, the cleanup trigger drops the empty household, and
that cascades through vehicles to every entry before those references are
checked — which is why it was never noticed. Sharing the household exposed it:
`delete-account` returned "Database error deleting user".

Fixed in `supabase/migrations/0033_account_deletion_unblocked.sql` with
`on delete set null` rather than `cascade`. The entries belong to the
**household**, not to whoever typed them; cascading would mean one member
leaving takes half a shared log with them.

**Two traps found while fixing it, both on a live Postgres and both worse than
the original bug:**

1. **`pin_created_by` silently defeated the fix.** That trigger (migration
   `0008`) reverts any update of `created_by` to stop a crafted client forging
   authorship — and `on delete set null` *is* an update. The delete then reported
   success and left a **dangling foreign-key reference** behind. The trigger now
   permits exactly one thing it did not: nulling `created_by` when the user it
   pointed at no longer exists, which is true for the referential action (fired
   after the parent row is gone) and false for any client.
2. **The rewritten trigger broke every edit.** It reads `auth.users`, which
   `authenticated` cannot select from, so editing a fill-up failed with
   "permission denied for table users" until the function was made
   `security definer`. Caught by the regression test, not by inspection.

Four tests in `test_rls/rls_test.dart` now cover it: the delete completes, the
entries survive, nothing is left dangling, and a *live* member still cannot
erase their own authorship. They need `SUPABASE_SERVICE_ROLE_KEY` as well as the
anon key, because they exercise what the edge function does.

**A follow-on bug this caused, now fixed.** The eight repositories read
`created_by` as nullable and map it to the empty string, which this codebase
already uses for "no author". That empty key reached
`householdSpendByMemberProvider` and became a *participant* in the settlement:
the fair share was divided by one head too many, and the household could be told
it owed money to a blank name. Spend with no author is now kept in
`Settlement.unattributed`
(`lib/domain/household/settlement.dart:134`) — outside the split, because there
is nobody to pay or be paid, and shown on its own line in the settlement card so
the difference from `householdTotal` does not look like an arithmetic mistake.
Leaving it out cannot change who owes whom: money nobody will be repaid for
benefits every remaining member equally.

Spend from someone who has *left* the household but still exists stays in the
split, deliberately — they can still be settled with.

### A member could not join a second household
**Was Low.** The schema always permitted belonging to several — `household_members`
is keyed on the pair — but every screen read `myHouseholds().first`, so a second
membership was invisible and the join screen refused rather than appearing to
work. Two people who had each already made a garage could only merge by one of
them leaving.

`selectedHouseholdIdProvider`
(`lib/features/household/providers/current_household.dart:15`) now holds which
garage this device is showing, and `chooseHousehold`
(`current_household.dart:56`) falls back to the first when the stored choice is
not among the user's — which is what leaving, or being removed, looks like from
here. A switcher appears in the sidebar header and on the household screen, and
only when there is more than one garage to switch between.

**The race this had to close:** the stored choice is read asynchronously while
the app is already usable, so a switch made in that window was being undone by a
value that was stale before it arrived. The notifier tracks whether this session
has chosen and ignores the load if so.

### Vehicles can now change hands
Not a bug — a gap. `vehicle_transfers`
(`supabase/migrations/0030_vehicle_transfer.sql:15`) moves a car and its whole
history to another garage by changing one `household_id`; everything else hangs
off `vehicle_id` and follows. Worth knowing: the vehicle **photo does not
follow**, because objects in the `vehicle-photos` bucket are keyed
`<household_id>/<vehicle_id>` and SQL cannot move a storage object. The path is
cleared on transfer.

### Maintenance accuracy was coupled to fuel logging
**Was Medium.** The daily driving rate, and the vehicle's current odometer, were
read from fill-ups alone. A household that services its car but pays cash at the
pump had nothing to measure from, so every distance-based projection used the
30 km/day fallback however much the car was actually driven.

Two changes closed it. `OdometerHistory`
(`lib/domain/fuel/odometer_history.dart:33`) merges every source that records a
reading — fill-up, service, cost entry, standalone reading — into one series,
and both the rate and the current reading are taken from that. And
`odometer_entries` is a new entry kind with no money attached, so somebody who
never buys anything the app tracks can still say how far the car has gone.

The series is deliberately opinionated: one reading per day (the highest), and
nothing that goes backwards. Several entries on one day are normal — a fill-up
and the service that prompted it — and two points zero days apart would drag any
rate towards nothing. A reading below one already recorded means one of the two
is a typo, and which is unknowable.

### The push sender skipped every dated reminder
**Was High**, and unnoticed because nothing had ever pushed. `push-due-reminders`
selected only `interval_km` and `interval_months` and projected a due date from
the last matching service. A one-off carries neither: it has `one_time` and its
own `due_date`. Both branches were skipped, `dueDate` stayed null, and the loop
`continue`d — so a vignette running out, and registration, insurance and casco
falling due, were exactly the reminders that would never have been pushed.

Fixed by reading `one_time, due_date` and using the date on the rule. Verified
against the schema and the writer in `cost_entry_sheet.dart`, **not** end to end:
sending needs the `FCM_SERVICE_ACCOUNT` secret, which does not exist yet.

### Vignette expiry was a day late
**Was Medium.** A period covers its own first day — ASFINAG sells the 10-day
vignette as "the 1st day of validity plus 9 additional calendar days", and DARS
sells seven consecutive days — but `nextDue` added the full period to the
purchase date. Every vignette therefore claimed one more day of validity than it
had, which is the direction that ends in a fine. The date is now the last day it
is still valid, and the sheet says "Valid through" rather than "Runs out".

Times of day are still not modelled: Romania sells in 24-hour periods from
purchase, and an Austrian vignette bought at midday does not lapse at midnight.
Landing the reminder on the morning of the last certainly-valid day is the safe
side of that.

### Loading the sample data looked like nothing happened
**Was Medium.** The load writes about twenty rows one at a time, which is
seconds against a real backend, and the screen did not change while it ran. The
first person to try it tapped five times and got five sample cars. There is a
spinner in both places that offer it now, and `sampleDataLoadingProvider` makes
the action itself refuse to start twice, so the guard does not depend on a
screen remembering to disable its button.

### The RLS suite ran on the honour system
**Was High.** `test_rls/rls_test.dart` is the only thing that proves one household
cannot read another's data, and because it needs a live Postgres it sat outside
CI and was run by hand. It had already caught real decay once: the suite used Bob
as its "stranger" while a test halfway down made him a household member, so a run
of isolation assertions was quietly measuring a member and proving nothing.

`.github/workflows/ci.yml` now has an `rls` job that runs `supabase start` and the
38 tests against it. Because `deploy-web.yml` calls this workflow and waits on it,
the site can no longer go out over a tenancy regression. Standing the stack up
from scratch also proves every migration still applies to an empty database.

### Sample data made the app look broken
**Was Medium.** Every litre figure in `SampleGarage` was its distance times a flat
0.06, so all twelve spans came out at exactly 6.0 l/100km. The economy chart was
a flat line, the car's summary read "Best 6.0 · Worst 6.0", and the ring showed a
scale of nothing. This was the first screen anyone loading the demo saw.

Underneath it was a real defect: `EconomyRange.of` rejected a degenerate range
with `best == worst`, an exact comparison on numbers that come out of
floating-point division. Twelve "identical" tanks differed by 9e-16, which passed
as a range, and the ring then scaled a rounding error and read full. It now needs
a spread of at least 0.05 l/100km, which is what the screen can print.

### The scale on the economy chart repeated itself
**Was Medium.** Y-axis ticks were rounded to whole numbers, but a car's whole
range fits inside one or two l/100km, so several ticks printed the same label: a
scale reading 7, 7, 6, 6, 5 down the side. One decimal now, matching every other
economy figure in the app.

### The floating button covered the end of every list
**Was Medium.** None of the four screens with a floating action button left room
for it, so the last row sat underneath and any control on that row could not be
tapped at all: on the dashboard, the last vehicle's fuel and maintenance buttons.
`GarageTokens.fabClearance` is now the bottom padding on all four.

### Entry forms opened under the status bar
**Was Low.** `showAdaptiveEntrySheet` opened a scroll-controlled sheet, which is
laid out over the whole screen, and the route strips the top inset from the
MediaQuery it passes down, so the `SafeArea` inside each form could not see it.
"Add fill-up" came to rest against the clock. Fixed with `useSafeArea: true`.

### A list of dates could read as though it were out of order
**Was Low.** `formatShortDate` always omitted the year, so a car serviced in
October and again the following April listed "Apr 16" above "Oct 16": correct,
newest first, and indistinguishable from a list sorted backwards. The year is
named now whenever the date is not in the current one.

### The national average was one noisy day, not an average
**Was Low.** The stations screen took `series.last` from the trend feed in
whatever order it arrived, so the headline "national average" was a single day's
figure — and that feed moves a median of 5 cents a day, once 43, depending on
how many stations reported. It now reads a 7-day trailing mean off an explicitly
sorted series (`lib/domain/stations/price_trend.dart`).

Worth knowing before trusting anything derived from that endpoint: it returns a
rolling ~10-week window, not history, with missing calendar days and fuels
absent on some dates.

### The price trend feed spikes on days when few stations report
**Was Medium, and caught before shipping.** As of August 2026 Croatian fuel
prices sit under a cap revised weekly, so the real figure barely moves between
revisions — policy that may be withdrawn, which is why nothing in the code rests
on it. The feed does not look like that: petrol's national average swings a median of 5 cents a day
and once 43. Every large move is a spike and an immediate return — 1.88 → 2.20
→ 1.89 across 30–31 July 2026 — and they land on Thursdays, Fridays and
Sundays, which are exactly the days when one to three fuel types report instead
of five or six. LPG, which reports consistently, moves a median of one cent.

The first implementation smoothed with a **7-day mean**, which does not reject
such a day but dilutes it: a 30-cent spike still shifts the week by four cents,
double the two-cent floor under which the screen reports "steady". It would have
announced week-on-week price movements that never happened. Changed to a
**median** before release, with a test built from the actual 30 July figures.

If the cap is lifted, re-measure before trusting the two-cent "steady" floor —
real daily movement returns, but the spikes and the weekday coverage gaps belong
to the feed and will still be there.

Anything else derived from that endpoint needs the same care: it is a rolling
~10-week window, not history, with missing calendar days, weekday-dependent
coverage, and no timestamp of its own.

### A new fill-up offered a price that was weeks old
**Was Low.** Opening the sheet at home prefilled the unit price from the previous
fill-up, so a driver saw 1.54 for a pump charging 1.66 and had to correct it
every time. The live-price path existed but only fired within 200 m of a
forecourt, which is not where most fill-ups get logged. It now looks the
remembered station name up in the same dataset and offers today's price
(`lib/domain/stations/posted_price.dart`), falling back to the old behaviour
when the name is unknown, unpriced, or ambiguous.

Worth knowing when reading a report about it: this is only ever a *prefill*.
Editing a saved fill-up still shows what was paid, guarded by a test named for
it — the alternative would silently rewrite history.

### Fuel prices claimed to be nearby from anywhere on earth
**Was Medium.** The dataset is the Croatian ministry's, but nothing said so on
screen. Opened from outside the country it listed the whole of Croatia, nearest
first, with "average nearby" over the top: a station 9,671 km away offered as
somewhere to fill up. Beyond 300 km the screen now says which country the prices
cover, and the nearby average is computed only inside that radius. The national
average, which is true from anywhere, stays.

This entry replaces an older one claiming the screen was "simply empty" outside
Croatia. It never was, which is the more useful half of the lesson.

### The calculator labelled a field with its own default answer
**Was Low.** The vehicle picker's label was the string "All vehicles", the name of
the option already selected inside it, while every field below named what it was
for.

### Fuelio import stopped halfway and reported nothing useful
**Was High.** `upsertRule` asked Postgres for `on conflict (vehicle_id,
service_type_key)`, but migration `0024` had replaced that constraint with a
*partial* unique index (`where not one_time`) so two dated tyre swaps could
coexist. A partial index only satisfies ON CONFLICT when the statement repeats
its predicate, which PostgREST cannot express, so every recurring rule failed
with 42P10. An import wrote its fill-ups, services and costs, then died on the
first reminder. Replaced with update-then-insert, covered by three RLS tests.

### One item showed two different percentages
**Was Medium.** The dashboard measured *time remaining over 90 days* while the
maintenance list measured *interval consumed*, so the same tyre swap read as
100% in one place and 26% in the other. Worse, the gauge's danger colour was at
the empty end, so a freshly serviced item glowed red. One meaning now
(`ReminderProjection.dueness`): zero is freshly done, one is due.

### The economy ring was a proportion of nothing
**Was Low.** It scaled against a hardcoded 4 to 12 l/100km, which flattered a
small diesel, pinned a thirsty car at empty, and was meaningless for an
electric one. It now scales against the car's own best and worst, and prints
that range underneath.

### Google sign-in never worked in a shipped build
**Was Critical.** "Continue with Google" failed on every release build with a
generic error. The cause was `authorizationForScopes([])`: an empty authorization
request, which the platform rejects *after* the account picker has already
succeeded. Every plausible-looking culprit (signing certificate, OAuth client,
Supabase authorized client IDs) was correct all along.

Two things made it expensive. The exception matched no branch in `AppFailure.from`
and so rendered as a generic sentence, and `debugMessage` was recorded nowhere, so
the app knew exactly what went wrong and discarded it. Both are now fixed
([09](../architecture/09-errors-and-diagnostics.md)); the second is the more
valuable fix.

### Editing an older fill-up was impossible
**Was High.** The odometer guard compared against the newest reading in the log, so
editing any historical entry was rejected for being "before the last fill-up", as
was backdating one. Replaced with a date-bracketed window
(`lib/domain/fuel/odometer_bounds.dart:10`).

### Importing from Fuelio did nothing
**Was High.** The importer returned early when the household had no vehicles, so a
new user arriving from Fuelio, the exact person it is for, tapped it and saw
nothing at all. It now reads the backup's `## Vehicle` section and creates the car.

### Dialogs stretched to full height
**Was Medium.** `LabeledField` used a `Column` with the default `MainAxisSize.max`,
so inside an `AlertDialog` one label and one text field measured 856 logical
pixels tall. It affected every dialog using it, not just the one reported.

### Receipts could only be attached on a second visit to an entry
**Was Low.** Every sheet said "Save the entry first, then attach files to
it", so the paperclip appeared only when editing and nobody found it. The
sheets mint their own entry ids, and the attachments table keys on kind and
id rather than pointing at a row, so a receipt can now be attached while the
entry is being typed. A sheet abandoned without saving deletes whatever it
attached (decision 90).

### A recurring paperwork reminder could never be marked done
**Was Medium.** The service sheet hides registration, insurance and
inspection chips on the argument that the cost sheet settles them. It settles
only categories it maps, and only one-off rules — a technical inspection has
no category at all — so a recurring paperwork reminder had nothing anywhere
in the app that could complete it. The chip is offered again whenever an
active rule on the car asks for that key.

### The lifetime breakdown did not add up to the lifetime total
**Was Medium.** The vehicle page listed fuel and servicing as paid and
everything else amortised, so "Where it went" summed to €326.55 under a
printed €468.66. Every row is now what was paid; the per-month and per-year
rates above it keep the spread figures, which is where amortisation belongs.

### A motorcycle was shown the car's legal tread minimum
**Was Medium.** The tyre card printed "At or below the 1.6 mm legal minimum"
on a bike, which is held to 1.0 mm. A wrong legal claim in both directions:
it sends a rider to buy tyres they do not need, and teaches a figure no
roadworthiness test will agree with. The minimum now comes from the vehicle
kind, on the card and in the wear projection.

### A tread reading taken twice on one day showed the first one for ever
**Was Medium.** Readings carry a date only, the sheet stamped today, and the
newest-reading test was strictly "after". A correction measured minutes later
tied and lost. The sheet now takes a date and an odometer, ties go to the
later row, and saving says so.

### The spreadsheet export was not openable
**Was Medium.** "Export as CSV" wrote twelve differently shaped tables into
one file separated by `#` comments; every spreadsheet and parser reads that as
one broken table. It also left out the tyre history and the vehicles
themselves. It is now a zip of one CSV per car per kind plus `vehicles.csv`,
and the row is called "Export as spreadsheets".

### A motorcycle's tread sheet asked for four corners
**Was Low.** A tyre set stores front-left, front-right, rear-left and
rear-right, and the sheet asked for all four whatever the vehicle was. A bike
has a front and a rear of different sizes and wear rates, so a rider left two
boxes empty on a form that plainly belonged to a car. The sheet now asks a
motorcycle for two, stored in the front-left and rear-left columns; the table
has no separate shape for a bike, and everything that reads a reading takes
the shallowest of whatever is there.

### A fill-up could be dated next week
**Was Low.** Every entry sheet's date picker ran to 2100, so a mistyped or
mistapped date put a fill-up, service or trip in the future, where the
projections treat it as history that has not happened. The pickers on records
of past events stop at today; warranty and reminder dates still run forward.

### The privacy policy named the wrong hosting region
**Was Medium.** `PRIVACY.md` and the hosted page said Frankfurt; the project runs
in `eu-north-1`, Stockholm. Both are in the EU so residency was never affected,
but the statement was false on a page the Play listing links to.

### A drive begun after midnight was logged on the day before
**Was Medium.** `finishDraft` took the calendar day straight off `startedAt`,
which is UTC. East of Greenwich that is still yesterday until the offset
elapses, so a drive started at 00:30 in Zagreb was dated the previous day — in
the logbook, in the trip list, and in whichever period a route trend put it in.
It now converts to local time first (`dateOfDrive`,
`lib/domain/entities/trip_draft.dart:128`).

The test that should have caught it wrote both instants in UTC, so it asserted
the correct answer in the one time zone where the bug cannot happen. **A test
about a local calendar day has to build its fixtures in local time**, or it is
testing the arithmetic it was meant to check the boundary of.

### An edit erased the fields the form did not ask about
**Was Medium.** `TripEntrySheet` rebuilds a `TripEntry` from its own fields, so
anything the form does not carry is written back as its default. Adding
`route_id`, `comparable` and `started_at` to the table therefore meant an edit
silently unfiled a journey from its route, un-marked an unusual run, and threw
away the departure time a drive had recorded for itself. Caught by writing the
test before believing the sheet, and now guarded by one that fails if any of the
three is dropped.

**The general shape:** any sheet that reconstructs an entity rather than copying
it forward will quietly delete the next column somebody adds. The alternative is
`copyWith` from the existing row, which these sheets do not do because they also
serve the new-entry case.

### Startup threw twice and scheduled no reminders
**Was High.** `syncNotifications` read half its providers *after*
`await service.requestPermission()`. On a first run that call puts the system
permission dialog on screen, and by the time it is answered the dashboard that
lent its `WidgetRef` has been rebuilt — so the next `ref.read` threw `Bad
state: Using "ref" when a widget is about to or has been unmounted is unsafe`,
twice, and every reminder after that point went unscheduled.

Found by launching a profile build on the emulator and reading `adb logcat`,
not by the suite: every test that exercised this path kept the widget alive
across the await. Every provider read now happens before the first await
(`lib/core/notifications/notification_providers.dart:76`), and a widget test
unmounts the screen mid-prompt to prove it
(`test/core/notifications/sync_notifications_test.dart`).

**The general shape:** a `WidgetRef` is only valid until the next await. Any
`async` function taking one has to read what it needs up front, or take values
rather than a ref. This is the same family as the dashboard's "setState during
build" note above, which is still open.

### A partial RLS run poisons the next one
**Low, and a trap rather than a bug.** Running part of the live suite —
`dart test test_rls/rls_test.dart --name routes`, say — leaves whatever rows
that subset created behind, and a later full run fails somewhere unrelated. It
was seen as `new row violates row-level security policy` on
`reminder_rules`, in a test that had passed minutes earlier against the same
code.

The suite creates users and memberships and tears down only what each test
made. **Run `supabase db reset` before a full run, and treat a single
surprising RLS failure as stale state until a reset says otherwise.** The
migrations are append-only, so a reset costs a few seconds and proves the
history applies from scratch at the same time.

### A restore forgets which route a trip was on
**Low, and by decision.** `trip_entries.route_id` points at a household-scoped
`routes` row, and a restore mints new ids, so a restored journey comes back
unfiled. Everything else about it survives, including whether it counted as a
normal run and when it set off.

Fixing it means resolving every route name in the file to an id before any
vehicle is written, and attaching a trip to the *wrong* route would be worse
than leaving it unfiled. Decision 131 has the reasoning.

### Croatian at a large font overflows more than one screen
**Was Low, and would have shipped.** Three horizontal overflows at 320 px with
a 1.5x font, none of them reachable in English: the route picker on both the
trends screen and the start-drive sheet (a long route name pushed the dropdown
arrow off the edge), the departure and driver filters ("Sredinom dana"), and
the Trips toolbar, where the routes button added last night left "Svi
automobili" a pixel and a half too wide.

All of them — five, once the manual trip sheet's own route picker was checked —
are now `isExpanded` dropdowns inside a width cap, with ellipsised labels. That
last one overflowed by 424 pixels, the widest of the night, and it is the same
control copied to a third place. Croatian runs 20–30% longer than English and the ARB tests check only
that a translation *exists*, so nothing else would have caught these.

**The cheap half of a device pass is a widget test.** `pumpScreen` already
takes `locale` and `textScale`, an overflow throws, and
`tester.takeException()` catches it — so every screen added last night now has
a Croatian, 320 px, 1.5x case that runs forever. That is a better guard than
remembering to look at a phone.

**Turned on the dashboard, the same check found an older one.** The recent
activity rows put an `Expanded` label beside an unbounded `Text` carrying the
date and the amount; at 1.5x in Croatian, "15. kol 2026. · 62,00 €" overflowed
by 65 px. A `Row` with one unconstrained child does not share — it overflows.
That row predates last night, and the September layout sweep at 1.5x missed it
because the sweep ran in English.

**Extended to every screen with a harness to hang it on**: timeline, vehicle
detail, statistics, the planner, tyres, the calculator, API access, Settings,
and the fuel, service, cost, trip, income and document entry sheets — fifteen
in all, each with a Croatian, 320 px, 1.5x case. Two more
overflowed and were fixed with them — the trip sheet's route picker, by 424
pixels, the widest of the night, and the currency row in Settings, where a
`ListTile` title sat beside an unbounded dropdown reading "€ · EUR".

**The pattern, not the instance.** The same `DropdownButtonFormField` needed
`isExpanded` in three separate places, and it was found three separate times
because each fix only covered the screen whose test happened to run. A control
that needs a width cap needs it everywhere it is pasted; the app has 30-odd
dropdowns and the only reason to believe the rest are fine is that each screen
now has a test saying so. So the defect was not universal — it was concentrated in
rows written recently and in the one row on the dashboard nobody had measured
in a long language. The guard is cheap enough to keep adding to any new screen,
and `pumpScreen` takes `locale` and `textScale` already.

### The economy chart printed an odometer with decimals on it
**Was Low, and on the app's most-visited screen.** The vehicle page's economy
chart drew `43,245` and `44,011.364` on top of each other along the bottom, and
`5.2` over `5.1` down the side.

Both come from the same property of fl_chart: **it labels each end of an axis
as well as every multiple of the interval, and the multiples are counted from
zero rather than from the axis minimum.** Nothing stops a tick landing a few
hundred metres from the end label. The decimals were the same cause once
removed — a fractional interval put ticks between kilometres, and
`decimalPattern` printed them faithfully.

`_crowded` (`lib/features/vehicles/widgets/economy_chart.dart:199`) now
suppresses any tick within a third of an interval of either end, both axes use
whole-number intervals, and the odometer side formats to no decimals. The
regression test walks five odometer ranges and asserts no label repeats and no
odometer label carries a decimal point.

**The comment already in that file — "the rightmost pair used to overlap into
one unreadable smear" — shows this was fixed once before by widening the
interval.** Widening makes a collision less likely without making it
impossible, which is why it came back.

### The route trend's first-run view looked broken
**Was Low, and only ever visible on a device.** With one journey logged, the
chart's left axis read `1, 1, 1, 0` — fl_chart picks its own tick interval from
the range, and every tick on a chart topping out at one minute rounds to the
same label — and the summary said "Middle half 1–1 min", which reads as a
rendering fault rather than as a sample of one.

Both are the *first* thing a new user sees on this screen. The axis now uses an
explicit whole-minute interval and drops a tick above the tallest box, and the
spread line is hidden when there is less than a minute between the quartiles.

Neither was catchable by the widget tests, which assert on text and widget
types and never on what a chart library decides to draw. Found by taking a
screenshot of a profile build on the emulator — the third defect tonight found
that way and by nothing else.

### The CSV column guesser can be fooled by a substring, and now has more to trip over
**Low, and latent.** `CsvSchema.guess`
(`lib/domain/import/csv_import.dart:220`) normalises a header by stripping
every non-alphanumeric character, then matches a field to the first column
*containing* one of its candidates. The trip field keyed `to` therefore matches
any header containing those two letters — including `route`, `total` and
`photo`.

Nothing is broken today: the exported trip file happens to put `to_place`
before `route`, and the first substring hit wins. **That is column order doing
the work, not the matcher.** A file with `route` before its destination column
— another app's export, or ours with a column deleted — would read the route
name as the place the journey ended.

Not fixed here, deliberately: a minimum candidate length would break `km`
matching `odometer_km`, which the same pass depends on, and word-boundary
matching is impossible once the separators have been stripped. Retuning a
heuristic this load-bearing wants somebody watching the import tests, not a
late-night edit. The example above is the reproduction.

### There are no terms of use for a service that hands people documents
**Low, and a gap rather than a bug.** The AGPL covers the *source*; it says
nothing about the *service* at garage.hrva.cc. There is no acceptable-use
statement, no liability disclaimer for the hosted app, and nothing that says
what the app is not.

The app is careful about this in-product — the seller's report, the handover
sheet and the trip check each disclaim themselves in the document itself, which
is where it matters most. What is missing is the ordinary umbrella a free
public service usually carries: this is provided as-is, figures are computed
from what you typed, do not rely on a due-date projection as a legal deadline,
do not use the API to hammer the backend.

**Not drafted here on purpose.** A terms document is a published legal artefact
and its wording has to be the owner's. It is worth an hour with someone
qualified before a public launch, alongside the Croatian-policy question below.
Offered rather than assumed.

**17 September 2026: the offer was taken up, and the gap is still open.**
`TERMS.md` exists as a draft that says it is one, with every factual sentence
checked against the code. It is not in force, nothing links to it, and the
questions it leaves for a lawyer are in `docs/TODO-manual-steps.md` §7. The gap
closes when it has been corrected and published, not before.

**What was checked and is fine:** no analytics, crash-reporting or tracking
dependency exists (`pubspec.yaml`), and no page under `web/` loads a font,
script or stylesheet from a third-party host — so the "no tracking, no
analytics" claim on the showcase holds, and no cookie banner is owed. Everything
the app stores on a device is functional (the session, the chosen garage, units,
the offline queue, the startup cache), which is the "strictly necessary"
exemption rather than something to ask consent for. **Adding any analytics
changes both of those answers at once.**

### Every public page is English, for an app sold in Croatian
**Medium, and unaddressed.** The app ships in English and Croatian, the Play
listing has a full Croatian description, and the release notes are translated.
Every page on garage.hrva.cc is `<html lang="en">`: the showcase, the API
reference, the account-deletion page, and — the one that matters — the privacy
policy the listing links to.

For the marketing pages that is a product decision. **For the privacy policy it
is worth a second look before a public launch.** GDPR Art. 12 asks for
information "in a concise, transparent, intelligible and easily accessible
form, using clear and plain language"; for a consumer app whose store listing,
interface and support are Croatian, a policy only in English is the weaker
reading of that. The DPA's own guidance is not something this repository can
settle.

**This is not legal advice, and the wording is not a thing to machine-translate
and forget.** A policy is the one document where an approximate translation is
worse than none: it is what a regulator and a user both read as the promise.
Someone should decide whether to have `PRIVACY.md` translated properly and
served at `/privacy?hr`, with `hreflang` on both, and a lawyer should look at a
real EU launch regardless.

The same question, much smaller, applies to `web/features.html`: a Croatian
visitor decides in four seconds, in English.

### Fixed: five menu paths in the public documents pointed at nothing

**Was Medium.** The privacy policy, the account-deletion page Google links to,
the API page and two of the app's own hint strings all told people where to tap,
and five of those instructions were stale: `Settings → Export as CSV` for a row
renamed **Export as spreadsheets**; three `Settings → API access` for a screen
that is two levels below Settings; `Settings → Delete account` and `Settings →
Delete all data` for rows that are real but sit under **More → Settings**. The
deletion page also spoke of *households* and of leaving one "from Settings",
words the app stopped using.

Nothing could have caught these: renaming a row breaks no build, and the
sentences read perfectly. `test/docs/menu_paths_test.dart` now holds every
arrow-path in those files to labels that exist in `app_en.arb`, starting at one
of the five tabs. It cannot check the order of the segments — see decision 136
for what it deliberately does not do.

### Fixed: "More → Waiting to sync" described a screen that was not there

**Was Medium.** `PRIVACY.md` told readers they could see the entries still held
on their device at `More → Waiting to sync`. `/pending` existed, but its only
entry points were the banner that shows while the queue is *not* empty and a row
in the feature tour — so a reader following the policy to confirm that nothing
of theirs was being kept found no such row, and concluded whatever they
concluded. It is now a permanent row on More (decision 137).

### Fixed: lending a car had no button

**Was High.** Guest passes — lend a car for a weekend without adding somebody to
your garage — shipped complete: a screen, a table, policies for both sides, a
test suite, a line in the release notes. `/vehicles/:id/lending` had no caller
anywhere in `lib/`, so the only way to open it was to type the URL. The
borrower's side was on More; the owner's side was not anywhere. Reported as "I
can't find a button to borrow my Clio".

It is now a `Lending` row in the vehicle menu, beside Transfer.
`test/ci/every_route_has_a_way_in_test.dart` fails the build on any route
nothing opens — the third time this shape has happened, after `/routes` behind
an unlabelled toolbar icon and `/pending` behind a banner. See decision 138 for
what the guard deliberately cannot check.

### Fixed: the pass row overflowed the moment it gained a second action

**Was Low.** The status pill and the eight-character code sat in a `Row` on the
lending screen. At 320 px and 1.5x in Croatian that row overflowed by 162
pixels the moment a second button appeared beside it, hiding the code — the one
thing on the card that has to be readable in full, because it is what you read
out. It is a `Wrap` now, and both actions moved into a menu. Croatian *and*
Italian layout tests cover the screen and the sheet.

### Italian ships with one deliberate mistranslation

**Low, and on purpose.** A second model reviewing `app_it.arb` objected that
*bollo* is the road tax and not vehicle registration, which is correct Italian.
It is kept: the concept the app models is the Croatian yearly re-registration,
which is the thing that recurs and expires, and *immatricolazione* names a
one-off act the app never reminds anybody about. If Garage is ever localised
for the Italian market properly, that decision should be revisited with
somebody who registers cars there — see decision 139.

**No translation punctuates with a dash any more**, in either language, and a
test keeps it that way. Rewriting the forty-two Croatian ones meant changing
sentences rather than characters — an em dash in English often stands where
Croatian wants a full stop.

### Fixed: seven features were finished except for the part you can see

**Was Medium in aggregate.** A sweep for messages that exist in three languages
and are rendered by nothing found sixteen, and half of them were features that
had stopped one step short: unlabelled route-trend filters, a borrowed car with
no return date and no explanation of its empty history, a drive that did not
say who started it, an observation that hid which journey it came from, a tank
range without the date it was already computing, and a silent admin hand-over.
All seven are wired up now; the six genuine leftovers were deleted from every
`app_*.arb`. `test/ci/every_string_is_shown_test.dart` fails the build on the
next one (decision 141).

### `cross_file` has fixed the UTF-8 bug the app works around

**Low, and ready to take.** `readTextFile`
(`lib/core/files/file_text.dart`) exists because `XFile.readAsString()`
decoded a picked CSV as Latin-1, turning *svjećica* into mojibake and quietly
breaking every Croatian column name in a Fuelio import. Two tests in
`test/core/files/file_text_test.dart` assert the bug is still there, on purpose:
"if a future cross_file fixes this, the helper is still correct and this test is
what says the workaround can go."

It says so now. Scaffolding the iOS project pulled `cross_file` 0.3.5+4 →
0.3.5+5 as a side effect, and both tests failed — the fix has landed upstream.
**The bump was reverted**: a dependency upgrade that arrived as a side effect of
an unrelated change is not one anybody tested, and it moved eleven other
packages with it (`file_picker` 12.0.0 → 12.2.0 among them).

Taking it deliberately means: bump, delete those two tests, keep the helper
(it also strips a byte-order mark, which nothing upstream does), and re-run the
import fixtures.

### Fixed: lending was broken in five ways at once

**Was High.** Reported as "the second account loses the ability to see his own
cars", and it was five separate faults:

- **Redeeming stranded the borrower.** `router.go` to a pushed vehicle route
  replaced the whole stack: no bottom bar, no back arrow, no way to their own
  cars without restarting. One line.
- **No owner check anywhere on the vehicle page.** Edit, Archive, Delete,
  Transfer, Lending and Reports were offered to a borrower; the policies
  refused every write, so each was a tap that appeared to do nothing.
- **The odometer was the stored baseline**, printed as if it were current.
- **Costs and services were on by default** on a new pass.
- **A pass could not be edited or ended by its holder.** Changing one switch
  meant withdrawing the code and minting another; giving the car back early
  was not possible at all.

All fixed (decision 145), with the read-only briefing, the code box and
`return_guest_pass`. The RLS suite covers the new surface in both directions,
including that the *owner* cannot use the holder's return path and vice versa.

### Fixed: the published privacy policy told its readers it was a draft

**Was Medium.** Both `PRIVACY.md` and `web/privacy.html` opened with a boxed
"not legal advice, this is a good-faith draft, have a lawyer review it" note.
It was written for whoever edits the policy and served to whoever reads it, at
the URL the Play listing links to, so the one document meant to be taken as a
promise announced that it might not be one. Removed from both on 14 September
2026, the date bumped, and `test/legal/privacy_policy_test.dart` fails if
"draft" or "legal advice" returns to either copy. The operator's reminder is in
`docs/RUNBOOK-update.md` §4, where it already was, and the lawyer's review
before a public EU launch is still owed — "Every public page is English, for an
app sold in Croatian" in this file is unchanged. Decision 154.

---

## Non-issues (checked, turned out fine)

### "Desktop More duplicates the sidebar" is by design

At desktop width Garage, Statistics, Trips, Fuel stations and the calculator
appear both as sidebar links and as rows on the More page. The page is the
phone's only way to them and stays the same at every width so that a person
moving between devices finds one layout, not two; the sidebar is the shortcut.
The polish walk flagged it as duplication; it is not a bug.


### A layout sweep at 320 px and at 1.5x font scale
Every screen test was re-run with the shared harness set to a 320 px wide
surface, then to a 1.5x text scale (September 2026). At 320 px nothing
overflowed. At 1.5x one widget did: the three fuel-type chips on the stations
screen, in a `Row` that could not wrap. It is a `Wrap` now, with a test at
1.5x. The remaining 1.5x failures were tests tapping buttons that had scrolled
off a 900 px surface, not layout errors.

### Logging a fill-up does refresh the due-date projections

It looks as though it does not. `_FuelEntrySheetState._submit` invalidates only
`rawFuelEntriesProvider` (`lib/features/fuel/widgets/fuel_entry_sheet.dart`),
while the odometer, trip and service sheets each also invalidate
`vehicleProjectionsProvider` by hand and say in a comment why. The fill-up
records an odometer reading like the others, so the asymmetry reads as a missed
invalidation.

It is not one. `vehicleProjectionsProvider` watches `odometerSamplesProvider`,
which watches `rawOdometerSamplesProvider`, which watches
`rawFuelEntriesProvider` among five others
(`lib/features/odometer/providers/odometer_providers.dart:35`). Invalidating a
dependency rebuilds its dependents, so the projections refresh on their own. The
explicit calls in the other three sheets are redundant rather than load-bearing —
harmless, but they are what makes the fuel sheet look wrong. Do not "fix" the
fuel sheet; if anything, delete the redundant lines.


- **The app appearing in Croatian on an English device.** Found during an
  emulator sweep and it looked like broken locale resolution. It was not: a
  `locale_override` of `hr` was sitting in that AVD's app data from earlier
  manual testing, and `adb install -r` preserves it. `pm clear` and a fresh
  launch come up in English, which is what `supportedLocales` and a null
  `locale` should do. Worth remembering that reinstalling over an old build
  proves nothing about first-run behaviour.
- **The document picker opening on an empty "Recent".** A backup that was just
  put on the device is not in Recents, so the first thing an importer sees is
  "No items" and they have to know to open the drawer. Real friction, but it is
  Android's picker and not something the app chooses; `file_selector` exposes
  no initial directory on Android.

- **The 67.5 MB app bundle.** Alarming until inspected: 96.9 MB uncompressed of it
  is `BUNDLE-METADATA`, debug symbols and the ProGuard map, which Play strips.
  Devices download one ABI. Keeping it is what makes crash reports show Dart
  frames.
- **Location permission versus the Data safety form.** The app requests precise
  location for the Stations screen, which looked like an undeclared data type. It
  is not collected under Play's definition: the position never leaves the device,
  feeding only the distance arithmetic in `nearbyStationsProvider`. Documented with
  the condition that would flip it in [play-store-listing.md](../play-store-listing.md).
- **Webhook delivery is single-attempt.** Looks like missing retry logic; it is a
  decision recorded at `supabase/functions/dispatch-webhooks/handler.ts:20`. A
  receiver that missed one can read the same data from the API.
- **Supabase's built-in email limit.** Two messages per hour project-wide looked
  like a blocker for onboarding testers. Resolved by configuring custom SMTP and
  raising the limit; worth knowing that the limit is only raisable *with* custom
  SMTP.
