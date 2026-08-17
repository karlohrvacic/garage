# 08. Reminders and notifications

How a projected due date becomes something that interrupts you, and why the push
half of it is built but not switched on. Siblings:
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
| `lib/core/notifications/notification_scheduler.dart:26` | Pure logic: turns due items into a list of `ScheduledReminder` |
| `lib/core/notifications/notification_service.dart:7` | Thin wrapper over the plugin, keeps its types out of the rest of the app |

The wrapper exists specifically so `plan` stays pure and testable
(`lib/core/notifications/notification_service.dart:5`). Scheduling logic in a
plugin call is scheduling logic nobody can test.

**A bundle fires once, not once per item**
(`lib/core/notifications/notification_scheduler.dart:28`). The entire point of
bundling is to replace several scattered nudges with a single one; firing both
would undo the feature.

The lead time is a named constant
(`lib/core/notifications/notification_scheduler.dart:22`), chosen as enough notice
to book a shop visit but not so much that it is forgotten again by the time it
matters.

Android needs two permissions for this to work, both already in the manifest:
`POST_NOTIFICATIONS` for Android 13 and later, and `RECEIVE_BOOT_COMPLETED` so
schedules survive a restart (`android/app/src/main/AndroidManifest.xml:2`).

## The push half, and why it is off

The server side is written and in the repo:

| Piece | State |
|---|---|
| `supabase/migrations/0013_device_tokens.sql` | Applied. Table exists |
| `supabase/functions/push-due-reminders/index.ts` | Written, **not deployed** |
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
into words in its own language (`lib/core/notifications/push_reminder.dart:15`),
so nothing has to store a language per device and keep it true. Both delivery
paths are handled, because Android uses a different one depending on whether the
app is in front: `onMessage` for the foreground, and a top-level
`vm:entry-point` handler for the background isolate
(`lib/core/notifications/push_receiver.dart:82`).

## One source of reminders, never two

When push is configured, **the device stops scheduling its own reminders**
(`lib/core/notifications/notification_providers.dart:51`), and the server is the
only thing that decides when anything fires.

Not because local scheduling stopped working, but because the two cannot be made
to agree. The server projects a distance-based due date from the 30 km/day
fallback; the app measures the real rate from the odometer history. The same oil
change therefore falls on different days in the two calculations, so a household
running both would be told about it twice.

Two things make that switch safe to reason about:

- **A notification's id is the reminder itself** — car, sorted service-type
  keys, due day, hashed (`notification_scheduler.dart:37`). A resync replaces
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

**The risk this creates, stated plainly:** configure Firebase and forget the
cron, and nobody gets anything, because the local fallback has stood down. The
runbook does both in one sitting for that reason.

## The reminder a reading raises

Everything above is a *schedule*. One kind of reminder is not.

A rule with a distance interval comes due at an odometer, and the projector only
turns that into a date by guessing a driving rate. A household that drives more
than the guess arrives at the odometer well before the date does — which is
precisely the case where a week's notice becomes no notice at all. So when a
reading lands and leaves an item within `notificationLeadKm`
(`lib/core/notifications/notification_scheduler.dart:61`), the app says so in
kilometres: *"Oil change — Golf, due in 300 km"*. Nothing is projected.

Two details make it liveable rather than noisy:

- It is keyed on the odometer the item is due at
  (`notification_scheduler.dart:92`), not on the reading that revealed it, so
  every following fill-up updates the notification already on screen instead of
  posting another beside it.
- It is posted `onlyAlertOnce`, so that update is silent. It buzzes once, then
  counts down.

**It runs whether or not push is on.** The one-source rule above is about
schedules; this is a response to something that just happened on *this* device,
and no server can know a car reached 59,700 km at the moment it did. The
consequence is the honest one: a household member who did not log the reading
does not hear about it until the dated nudge.

When it is turned on, note where it gets the odometer: the highest reading
across every table that records one
(`supabase/functions/push-due-reminders/index.ts:140`), not the newest fill-up.
It read fill-ups alone until the sweep of August 2026, which would have
projected every distance-based reminder for an EV — or for anyone who stopped
logging fuel — off a number that had stopped moving.
`test/ci/entry_kinds_wired_test.dart` fails if a kind is left out of that list.

The case that justifies turning it on is specific: **a reminder reaching a
household member whose phone did not create it**. Local notifications
structurally cannot do that, because the schedule lives on the device that made
it. Nothing else about push improves on what is there.

Turning it on has a compliance consequence that must ship in the same release: an
FCM registration token stored server side is a device identifier, so the Play Data
safety form has to declare "Device or other IDs". [RUNBOOK-push.md](../RUNBOOK-push.md)
has the sequence.

## Sharp edges

- **Reminders are per device.** Two phones in a household each schedule their own
  from their own copy of the data. If one person has notifications off, they get
  nothing, and nobody can tell.
- **A schedule is only as fresh as the last time the app ran.** Projections move
  when a fill-up is logged, and the device reschedules when it next opens. A phone
  left closed for a month holds stale reminders.
- **The `push-due-reminders` function is deployed by nobody.** It is not in the
  GitHub integration's scope and not in the deploy workflow. Anyone reading the
  repo could reasonably assume it runs. It does not.
- **`flutter_local_notifications` needs desugaring** for `java.time` on older
  Android; `isCoreLibraryDesugaringEnabled` is on for that reason
  (`android/app/build.gradle.kts:28`). Removing it breaks the build in a way that
  does not obviously point at notifications.
