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

Last reviewed: 22 August 2026.

---

## Open

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
(`lib/core/notifications/notification_providers.dart:51`), so a build with the
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

### 4. Nothing on screen distinguishes a measured rate from an assumed one
**Low.** A vehicle with fewer than two odometer sightings, or none that moved,
has no rate to measure and falls back to 30 km/day
(`lib/domain/maintenance/reminder_projection.dart:74`). The projection then
reads exactly like a measured one. The coupling to *fuel* logging is gone —
see "Maintenance accuracy was coupled to fuel logging" below — but the silent
fallback is not.

### 5. Two fuels still share one distance
**Low.** Each fuel now gets its own chain of full tanks, so a petrol figure is
computed from petrol volumes alone. What no app can fix from this data is that
the chains overlap: an LPG span from 1000 to 1500 km includes whatever was
driven on petrol in between. Each figure is an approximation of that fuel's
consumption over a period rather than a measurement of it, and nothing on
screen says so.

### 6. Realtime covers the entry tables, not the schema
**Low.** The publication now carries vehicles, all six entry kinds, reminder
rules, attachments, tyre sets and **vehicle transfers**. Still outside it:
**invites, api keys and webhooks** — so a code revoked on a laptop still looks
live on a phone until that screen is revisited. Fine today, surprising if you
assume everything streams.

`vehicle_transfers` was added in `0034` for a reason worth generalising: **you
are never told about a row leaving your scope.** A redeemed transfer moves the
vehicle to the buyer's household, so the seller's policy rejects the very
update that would have told them, and the car simply stopped appearing —
eventually, and never with an explanation. Anything that moves a row *between*
households needs a second, staying row to carry the news.

Worth knowing for the next entry kind: **three places have to be told about it**
— the realtime publication, the webhook trigger, and the `entryKinds` map in
`dispatch-webhooks`. Missing the last two is silent, and it happened between
migrations `0028` and `0032`.

### 7. `lib/domain/` purity has no automated guard
**Low.** Nothing fails if someone imports Flutter into the domain layer. The rule
is stated in [`CLAUDE.md`](../../CLAUDE.md) and holds by convention. A one-line
test over the directory would close it.

### 8. Release notes and store copy sit outside the tested strings
**Low.** `distribution/whatsnew/` and [play-store-listing.md](../play-store-listing.md)
duplicate feature names that also exist in the ARB files, and no test relates
them. A rename reaches users inconsistently.

**And the full description has no length test, unlike the release notes.** Play
caps it at 4000 characters; both languages now sit at 3990, so the next feature
worth a sentence has ten characters to say it in and nothing will warn whoever
writes it. Adding one has to mean trimming one. A test over the fenced blocks
would close this the way `deploy_workflow_test.dart` closed the 500-character
one.

### 9. Nothing in this repo can run the launcher entry points
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

### 10. `flutter_deeplinking_enabled` was relied on without being set
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
  is not a safe read on an errored state.

---

## Recently fixed, worth remembering

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
(`lib/features/fuel/screens/fuel_log_screen.dart:248`), reading the same
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

- **Sign-in and sign-up** (`lib/features/auth/screens/sign_in_screen.dart:61`,
  `sign_up_screen.dart:36`). The worst shape of it: a sign-in that *works* is
  precisely what makes the router replace the screen, so the read after the
  await raced the redirect and the crash landed on the success path. Whether it
  threw depended on which of the two won, which is why it was intermittent
  rather than constant.
- **The calculator's prefill**
  (`lib/features/calculator/screens/calculator_screen.dart:57`), which walks a
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
(`lib/core/router/app_router.dart:165`). `/more` was added later with a plain
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
`finally` (`lib/features/settings/data/fuelio_import_action.dart:126`). Worth
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
parse boundary (`lib/domain/stations/fuel_station.dart:90`) rather than in
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
in `test_rls/rls_test.dart:50` need `SUPABASE_SERVICE_ROLE_KEY`, because they do
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
(`supabase/functions/push-due-reminders/handler.ts:86`), which the platform has
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

Both fixed in `lib/features/settings/data/csv_import_action.dart:26`:
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
(`supabase/functions/push-due-reminders/handler.ts:196`), mirroring
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
(`lib/core/theme/garage_theme.dart:203`), because the same slide was on all ten
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

### The privacy policy named the wrong hosting region
**Was Medium.** `PRIVACY.md` and the hosted page said Frankfurt; the project runs
in `eu-north-1`, Stockholm. Both are in the EU so residency was never affected,
but the statement was false on a page the Play listing links to.

---

## Non-issues (checked, turned out fine)

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
  decision recorded at `supabase/functions/dispatch-webhooks/handler.ts:11`. A
  receiver that missed one can read the same data from the API.
- **Supabase's built-in email limit.** Two messages per hour project-wide looked
  like a blocker for onboarding testers. Resolved by configuring custom SMTP and
  raising the limit; worth knowing that the limit is only raisable *with* custom
  SMTP.
