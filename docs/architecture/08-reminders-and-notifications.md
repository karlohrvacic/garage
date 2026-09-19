# 08. Reminders and notifications

How a projected due date becomes something that interrupts you, why the push
half of it is built but not switched on, and how the same daily run tells a
household's webhooks. Siblings:
[04-maintenance-projection.md](04-maintenance-projection.md) for where due dates
come from, [RUNBOOK-push.md](../RUNBOOK-push.md) for activating push.

> Jump to [Sharp edges](#sharp-edges): notifications are per device, not per
> household, and that is the whole reason the push half exists.

## Why this exists, and why it is built this way

A maintenance calendar nobody opens is a maintenance calendar that does not work.
The projection in [04](04-maintenance-projection.md) is only useful if something
tells you before the date rather than after.

The design decision worth knowing is that reminders are **local notifications
scheduled on the device**, not server-sent push. Local scheduling needs no server,
no Firebase project, no device token to store, and therefore nothing to declare on
the Play Data safety form. For the common case (the person who logged the car is
the person who maintains it) it is complete.

## How it works

Two layers, split so the interesting half is testable:

| Piece | Role |
|---|---|
| `lib/core/notifications/notification_scheduler.dart:133` | Pure logic: turns due items into a list of `ScheduledReminder` |
| `lib/core/notifications/notification_service.dart:7` | Thin wrapper over the plugin, keeps its types out of the rest of the app |
| `lib/core/notifications/notification_ledger.dart:13` | Which notices this device has already given, kept in its preferences |

The wrapper exists specifically so `plan` stays pure and testable
(`lib/core/notifications/notification_service.dart:5`). Scheduling logic in a
plugin call is scheduling logic nobody can test.

**A bundle fires once, not once per item**
(`lib/core/notifications/notification_scheduler.dart:130`). The entire point of
bundling is to replace several scattered nudges with a single one; firing both
would undo the feature.

The lead times are a named constant
(`lib/core/notifications/notification_scheduler.dart:59`): a month's notice to
book a shop visit, which is too long to be remembered on its own, and a week's
to keep it.

**A notice is given once, not on every launch** (decision 174). Every sync
cancels and re-plans, and a notice whose moment has passed is shown at once
(`lib/core/notifications/notification_service.dart:39`; the plugin refuses
to *schedule* a moment in the past, which is what the old clamp to "now" asked
it to do), so the plan alone cannot tell what was already given. The ledger
keeps what was scheduled for when, and a sync leaves out any notice every
item of which is recorded as given or was scheduled for a moment already past
(`lib/core/notifications/notification_scheduler.dart:248`). A cycle is the
rule, the odometer it is due at and the date its interval gives
(`notification_scheduler.dart:235`), with the window, 30 or 7 days. None of
them moves while a distance date moves with the calendar, and all of them move
when the work is logged, so the next cycle is announced like the first; a key
is kept for as long as its cycle is projected
(`notification_scheduler.dart:263`). Nothing is recorded while
notifications are refused, so a notice the system dropped is given once they
are allowed.

Android needs two permissions for this to work, both already in the manifest:
`POST_NOTIFICATIONS` for Android 13 and later, and `RECEIVE_BOOT_COMPLETED` so
schedules survive a restart (`android/app/src/main/AndroidManifest.xml:2`).

## The push half, and why it is off

The server side is written and in the repo:

| Piece | State |
|---|---|
| `supabase/migrations/0013_device_tokens.sql` | Applied. Table exists |
| `supabase/functions/push-due-reminders/handler.ts` | Deployed by `.github/workflows/deploy-functions.yml` once its secrets exist; called daily by the job `supabase/migrations/0027_push_schedule.sql` schedules, which does nothing until two Vault secrets are set — and whether production has them is unchecked |
| Client registration of a device token | Wired (`lib/core/notifications/push_registration.dart:122`), inert until configured |
| Displaying a push that arrives | Wired (`lib/core/notifications/push_receiver.dart:34`), inert until configured |

This is a deliberate stopping point, not an unfinished sprint. `firebase_core`
and `firebase_messaging` are in `pubspec.yaml` and the four Firebase values are
dart-defines rather than a `google-services.json`, so a build without them
compiles and simply hands back `PushDisabled`. What still needs a decision is
the Firebase project itself — see [RUNBOOK-push.md](../RUNBOOK-push.md).

**Data-only, and why.** The function sends no `notification` block: only keys —
which car, which service types, which day. Android shows nothing for such a
message unless the app handles it, which is the point. The device turns keys
into words in its own language (`lib/core/notifications/push_reminder.dart:16`),
so nothing has to store a language per device and keep it true. Both delivery
paths are handled, because Android uses a different one depending on whether the
app is in front: `onMessage` for the foreground, and a top-level
`vm:entry-point` handler for the background isolate
(`lib/core/notifications/push_receiver.dart:82`).

## One source of reminders, never two

When push is configured, **the device stops scheduling its own reminders**
(`lib/core/notifications/notification_providers.dart:138`), and the server is the
only thing that decides when anything fires.

Not because local scheduling stopped working, but because the two cannot be made
to agree. The server projects a distance-based due date from the 30 km/day
fallback, counted from the day of the furthest reading; the app measures the
real rate from the odometer history and counts from today. The same oil change
therefore falls on different days in the two calculations, so a household
running both would be told about it twice.

Two things make that switch safe to reason about:

- **A notification's id is the reminder itself** — car, sorted service-type
  keys, due day, hashed (`notification_scheduler.dart:88`). A resync replaces
  the notification it already showed rather than numbering a new one, and a
  push lands on the same id the device would have chosen, so even if both paths
  ever ran they could not stack up as a pair.
- **One list of lead times**, `[30, 7]`, written once in each language and held
  together by a test (`test/ci/entry_kinds_wired_test.dart`). The server used to
  push at 14, 7, 1 and 0 days while the app scheduled at 7; that is four nudges
  against one for the same event. Two nudges are deliberate — see decision 33 —
  and the identity of a notification includes which of them it is, or the
  month's notice would replace the week's while it was still pending.

The server groups by car and due day, one message per visit, because firing one
per item would undo the bundling the app exists to do. It cannot reproduce the
app's own bundling window — that needs the measured rate — so it groups by what
it knows.

**The risk this creates, stated plainly:** configure Firebase and leave the
daily job without its Vault secrets, and nobody gets anything, because the
local fallback has stood down. The runbook does both in one sitting for that
reason.

## The same run tells the webhooks

The daily run is also what sends the `reminder.due` webhook event, which every
hook has been subscribed to since the table was made and which nothing sent
until September 2026. It is the one place that already knows what falls due,
so a hook hears about the same visits the phones do, on the same two days
(`supabase/functions/push-due-reminders/handler.ts:439`). The event itself —
body, chat text, who is told — is in
[07](07-integrations.md#reminderdue-the-event-every-hook-was-promised).

**Firebase is needed for the pushes and for nothing else.** The run used to
refuse to start without the `FCM_SERVICE_ACCOUNT` secret, answering 500 before
it had read a rule. It now reads the secret first and acts on it last
(`supabase/functions/push-due-reminders/handler.ts:540`): the due items are
worked out, the hooks are told, and only then are the pushes sent — or, with
no secret, skipped (`supabase/functions/push-due-reminders/handler.ts:696`).
Hooks first because everything after needs Firebase and can fail for reasons
of its own — a secret that does not parse, a token exchange Google refuses —
and none of that is any business of a household's webhooks. Since 0079 the
run tells them by writing one `webhook_outbox` row per visit and draining the
outbox itself (`supabase/functions/push-due-reminders/handler.ts:503`), the
way an entry's trigger does, so the deliveries are posted one at a time; a
receiver that is switched off costs the pushes one ten-second timeout per
drain, not one per delivery, because the drain skips the rest of that hook's
rows once one has come back unreachable — and the scheduled call that starts
the run waits a minute for its answer rather than pg_net's five seconds
(`supabase/migrations/0076_push_schedule_timeout.sql:50`).

What the run answers, always with status 200 unless the rules cannot be read:

| Body | When |
|---|---|
| `{"pushed": 0}` | Nothing is due today |
| `{"pushed": n, "stale": n}` | Pushes were sent and no hook listens |
| `{"pushed": n, "stale": n, "delivered": n}` | …and hooks were told; `delivered` is the drain's count of deliveries answered in the 200s — these reminders, and whatever else was due at that moment |
| `{"pushed": 0, "delivered": n, "push_skipped": "FCM_SERVICE_ACCOUNT secret not configured"}` | No Firebase: hooks were called, pushes were not |
| `{"pushed": 0, "push_skipped": "…"}` | No Firebase and nothing due |

`delivered` appears only when a hook was listening and a row was written, so
a project with no webhooks gets exactly the answer it always did; a row that
could not be written is logged and answered as `delivered: 0`. `push_skipped` appears on every
run without the secret, even one with nothing to send, because that is the run
an operator forcing a send by hand (the runbook's step 4) is looking at — and a
household whose phones have stood their own reminders down is waiting on
exactly the pushes it names.

A secret that is present but does not parse still fails the run, as before —
now after the hooks have been called.

## The reminder a reading raises

Everything above is a *schedule*. One kind of reminder is not.

A rule with a distance interval comes due at an odometer, and the projector only
turns that into a date by guessing a driving rate. A household that drives more
than the guess arrives at the odometer well before the date does — which is
precisely the case where a week's notice becomes no notice at all. So when a
reading lands and leaves an item within `notificationLeadKm`
(`lib/core/notifications/notification_scheduler.dart:76`), the app says so in
kilometres: *"Oil change — Golf, due in 300 km"*. Nothing is projected.

Two details make it liveable rather than noisy:

- It is keyed on the odometer the item is due at
  (`notification_scheduler.dart:107`), not on the reading that revealed it, so
  every following fill-up updates the notification already on screen instead of
  posting another beside it.
- It is posted `onlyAlertOnce`, so that update is silent. It buzzes once, then
  counts down.

**It runs whether or not push is on.** The one-source rule above is about
schedules; this is a response to something that just happened on *this* device,
and no server can know a car reached 59,700 km at the moment it did. The
consequence is the honest one: a household member who did not log the reading
does not hear about it until the dated nudge.

The case that justifies turning it on is specific: **a reminder reaching a
household member whose phone did not create it**. Local notifications
structurally cannot do that, because the schedule lives on the device that made
it. Nothing else about push improves on what is there.

Turning it on has a compliance consequence that must ship in the same release: an
FCM registration token stored server side is a device identifier, so the Play Data
safety form has to declare "Device or other IDs". [RUNBOOK-push.md](../RUNBOOK-push.md)
has the sequence.

## How the daily run dates what is due

The run reads the odometer from the highest reading across every table that
records one
(`supabase/functions/push-due-reminders/handler.ts:278`), not the newest fill-up.
It read fill-ups alone until the sweep of August 2026, which would have
projected every distance-based reminder for an EV — or for anyone who stopped
logging fuel — off a number that had stopped moving.
`test/ci/entry_kinds_wired_test.dart` fails if a kind is left out of that list.

It takes the **day** of that reading too, and counts the distance still to go
from there (`supabase/functions/push-due-reminders/handler.ts:325`): of two
readings at one odometer the later, since the car stood still in between.
Until September 2026 the count started on the day of the run, so a car with no
new reading kept the same days to go, and a notice that was seven days out on
Monday was seven days out on Tuesday and went again — a new notification each
time, because the due day is part of its id. Now the date holds still between
readings. A new reading still moves it, and the run keeps no record of what it
sent, so a notice can come round twice, or be skipped, when a reading lands.

Two more rules are the app's own (`OdometerHistory`): the odometer the owner
gave when the car was added counts as a reading, and nothing dated after the
day of the run does, so a year typed as 2062 cannot put every distance date
decades out.

**What the run considers**, rule by rule:

- A recurring rule by months: the matching service's date plus the interval.
  A rule with no matching service on record is not sent; the app projects one
  from the car's baseline instead.
- A recurring rule by distance: the matching service's odometer plus the
  interval, dated from the furthest reading as above. With both intervals, the
  earlier date.
- A one-off: its own `due_date`, its own `due_odometer_km` dated the same way
  (`supabase/functions/push-due-reminders/handler.ts:610`), or the earlier of
  the two. The app takes the odometer beside a date only once it has measured
  how the car is driven, which the run never has. The odometer target was not
  read at all until September 2026, so a one-off due only at an odometer was
  never pushed.
- The seasonal tyre swap: the country's statutory date where it has one, as
  below.

Anything whose date has already gone, or which is already past its odometer,
is not sent.

## The seasonal tyre swap, and the two places it lives

Winter-tyre periods are national and statutory, so the swap is the one rule
whose date is not a matter of habit. `lib/domain/maintenance/winter_tyre_period.dart`
holds the table, keyed on `Household.countryCode` — the same field that already
decides which statutory service types a household is offered.

| Country | Window | How it binds |
|---|---|---|
| HR | 15 Nov – 15 Apr | Regardless of weather, on winter road sections |
| SI | 15 Nov – 15 Mar | Fixed, and any time conditions are wintry |
| BA | 1 Nov – 1 Apr | Regardless of weather |
| RS | 1 Nov – 1 Apr | Within the window, only on snow or ice |
| AT | 1 Nov – 15 Apr | Within the window, only in wintry conditions |
| DE | none | Whenever the road is wintry (§2(3a) StVO) |

**Only verified countries get a window.** Italy sets its obligation per road by
ordinance rather than nationally, Great Britain has none, and the United States
varies by state — so all three get nothing and keep the six-month interval. A
plausible date for a country nobody checked would look authoritative and be
wrong, which is the same rule the statutory service types already follow.

The maintenance row says **which** of the three kinds of rule applies
(`maintenance_screen.dart:490`), because a driver told "15 Nov" has no way to
know whether that is the law, a habit, or something the app made up. The
wording deliberately stops short of legal advice: Croatia's rule binds on
winter *sections*, not every road, and summer tyres with 4 mm plus chains
satisfy it too.

### The table exists twice, and a test says so

The push sender is Deno and the app is Dart, so neither can import the other:
`supabase/functions/push-due-reminders/winter_tyre_period.ts` is a hand-kept
twin. `test/ci/winter_tyre_twin_test.dart` parses the TypeScript table and
fails if the two disagree — the same guard `REMINDER_LEAD_DAYS` has, for the
same reason. Wherever push is configured the client stops scheduling dated
reminders entirely, so a date changed on one side and not the other would put
one day on the maintenance row and a different day in the notification, and
nothing else would say so.

### Which way the swap goes travels in the payload

A push carries `swap_direction` (`to_winter` / `to_summer`) so the device can
say *Fit winter tyres* rather than *Seasonal tyre swap*. It is sent rather than
derived because the device cannot derive it: a push is handled in a background
isolate with no provider container, so the household's country is out of reach.
A bundle covering more than the swap keeps the visit title — naming a two-item
visit after one of its items would hide the other.

## Sharp edges

- **Reminders are per device.** Two phones in a household each schedule their own
  from their own copy of the data. If one person has notifications off, they get
  nothing, and nobody can tell.
- **A schedule is only as fresh as the last time the app ran.** Projections move
  when a fill-up is logged, and the device reschedules when it next opens. A phone
  left closed for a month holds stale reminders.
- **The daily run is silent until two secrets exist.** Migration `0027`
  schedules it and the functions workflow deploys what it calls, but
  `public.run_due_reminders_push()` returns quietly until `push_endpoint` and
  `push_service_role_key` are in Vault ([RUNBOOK-push.md](../RUNBOOK-push.md)
  §3). Without them no push is sent and no `reminder.due` webhook either, and a
  missed day is a missed notice: nothing catches up.
- **The app's own schedule still counts a distance date from today.** The
  projector adds the days to go to today
  (`lib/domain/maintenance/reminder_projection.dart:198`), so without a new
  reading the date moves on with the calendar there, as the server's did. Where
  push is off (a build without the Firebase defines; the Play builds have had
  them since August 2026, so on Android the server schedules instead), every
  launch cancels and re-plans the local notices, and what
  that does depends on how many days are left. More than seven, other than
  thirty, and each launch plans the notice as many days ahead as the last one
  did, so a phone opened daily never reaches it. Exactly seven or thirty, or
  fewer than seven, and the notice fires, the last case through the fallback
  that gives an item past all its windows a nudge today
  (`lib/core/notifications/notification_scheduler.dart:169`). Until decision
  174 it fired again every day the app was opened, under a new id each day
  because the moving due day is part of it; the ledger now gives it once per
  cycle and window. The notice a reading raises is keyed on the odometer
  instead, and never did this.
- **`flutter_local_notifications` needs desugaring** for `java.time` on older
  Android; `isCoreLibraryDesugaringEnabled` is on for that reason
  (`android/app/build.gradle.kts:28`). Removing it breaks the build in a way that
  does not obviously point at notifications.
