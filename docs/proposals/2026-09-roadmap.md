# A proposal: eight ideas, and what to do with them

**Date:** 2026-09-05
**Status:** Proposal. Nothing here is built.
**Scope:** Entirely within Garage. No integration with another application.

Eight ideas were put forward for making Garage more useful for looking after a
car while typing less into it. This assesses each against what the code
actually does today, proposes a single model that holds most of them, and
recommends an order.

Two of the eight are largely built already, one is much cheaper than it looks,
and one should not be built at all.

---

## What already exists

The most important finding first, because it changes what "finish what is
half-built" means.

### The roadmap is out of date about push

[`roadmap.md:37`](../roadmap.md) says Firebase is not configured and calls it
"the largest gap between what the app says and what it does". **The client half
is wired.** `Firebase.initializeApp` is called from
`lib/core/notifications/push_receiver.dart:67` and
`lib/core/notifications/push_registration.dart:52`, the `FIREBASE_*`
dart-defines are supplied from `env/*.json`, and a profile build on an emulator
starts `FlutterFirebaseMessagingBackgroundService`.

What cannot be verified from inside the repository is the **server** half:
whether `push-due-reminders` is deployed with an FCM service account against
the production project. That is a look at the Actions tab and the Supabase
function list, not a project. **Check it before treating push as a blocker.**

### Two ideas are already most of the way there

| Idea | Status | What is actually missing |
|---|---|---|
| **Vehicle history for a buyer** | **~70%.** `ReportKind.sellers` (`lib/features/reports/report_builder.dart:201`) already renders vehicle facts, average economy, fill-up count, fuel total and the whole service table. | Choosing what goes in; attachments (no report embeds an image); wording that does not imply the record verifies anything. |
| **Mechanic handover** | **~40%.** `ReportKind.serviceSchedule` renders the rules and their projected due dates (`lib/features/reports/report_builder.dart:387`). | Symptoms, photos, selection, and the entire post-visit half. |

### One idea is cheaper than it looks

**Preparing for a trip** needs a subtraction the app already computes.
`ReminderProjection` keeps `dueOdometerKm`
(`lib/domain/maintenance/reminder_projection.dart:31`) and the two competing
deadlines separately — `dateFromDistance` and `dateFromTime`
(`:43`). "Due in about 900 km, and this trip is 1,500" is arithmetic over data
that is already on the dashboard.

### One idea got cheaper last night

**Recurring routes** needed departure and arrival times that nothing recorded.
The drive draft (decision 109) now stamps `started_at` when a journey begins,
and `minutes` has always been on the trip
(`lib/domain/entities/trip_entry.dart:70`). What is left to build is a **route
identity** — not a time-tracking system.

### And the rest

- **Problem diary** and **driving events**: nothing exists. `ServiceEntry`
  carries `notes` and `faultCodes`, but the app has no idea of something
  *unresolved*.
- **Twelve-month expenses**: nothing forecasts cost. `recurring_costs.dart`
  (vignette validity), document expiry dates and the projections are the
  skeleton of one.
- **Receipt recognition** and **offline entry**: neither started. They are
  roadmap items 6 (`roadmap.md:103`) and 2 (`roadmap.md:50`). Offline is
  tractable because every sheet already mints a client-side id (decision 79),
  so a replayed insert is the same row rather than a duplicate.

---

## The model: one new concept, not three

A driving event ("hit a pothole, now there is a vibration"), a symptom
("rattles at the front when cold") and a note for the mechanic are the same
thing described three ways: **something a person noticed, at a date, at a
mileage.** The only real difference is whether it is still open.

So the proposal adds exactly one concept — an **observation** — and no other
new record kind:

```
observations
  vehicle_id      required
  trip_id         optional  -- the pothole happened on a journey
  noticed_on, odometer_km, note
  status          open | watching | resolved
  addressed_by    service_entry_id, nullable   -- work was performed
  resolved_on     date, nullable               -- the symptom actually stopped
  attachments     a fifth entry_kind, following the pattern of
                  supabase/migrations/0049_vehicle_documents.sql:114
```

**The two-field split is the point.** `addressed_by` records that a mechanic
did work; `resolved_on` records that the noise went away. A repair that did not
fix it leaves the first set and the second null — which is exactly the row
worth putting at the top of the next handover sheet. Collapsing them into one
"done" flag would lose the only distinction that matters.

Everything else composes out of it without a second store:

- **Handover PDF** = selected open observations + selected projections + recent
  services + selected photos.
- **After the visit** = one service entry, created the usual way, then tick
  which observations it addressed. Nothing is typed twice.
- **Driving events** = observations that happen to carry a `trip_id`.

### Recommendation on the driving-event journal

**Do not build it as a feature.** Build the observation, and put an "add a note
about this drive" action on the finish-drive sheet
(`lib/features/trips/widgets/drive_card.dart:254`). That delivers the whole of
the idea for the cost of one button, and avoids a second diary that competes
with the first for the same notes.

The question worth asking of any journal is which decision it supports. For
observations the answer is concrete: *what do I tell the mechanic, and did the
last visit actually fix it.* A standalone event log with no such destination is
a list people fill in twice and read never.

---

## Priorities

Effort is in focused days and provisional, based on reading the code cited
above.

| | Feature | Value | Depends on | Effort | Main risk | First version |
|---|---|---|---|---|---|---|
| **A** | Offline write queue | Highest | client ids (done) | 8–12 | Touches every repository; needs its own suite | Fuel and odometer only, with a visible "waiting to sync" |
| **B** | Observations | High | — | 3–4 | Another list nobody visits | Vehicle tab, plus a note action on finish-drive |
| **C** | Trip preparation check | High | projections (done) | 2–3 | Sounding like a safety certificate | One screen: date and distance in, what falls due out |
| **D** | Receipt recognition | High | — | 5–8 + fixtures | Wrong figures saved quietly | Fuel receipts only, always a draft to confirm |
| **E** | Mechanic handover | Medium-high | B | 4–5 | Overlaps the reports that exist | Extend `ReportKind`, add selection and photos |
| **F** | Routes and commute trend | Medium (high to the person who asked) | drive draft (done) | 5–7 | Comparability; implying causation | Named route, median per direction, sample counts |
| **G** | Buyer's report, second pass | Medium | — | 2–3 | Implying the record verifies anything | Selection and attachments on the existing PDF |
| **H** | Twelve-month expenses | Medium | B, G | 5–6 | **Inventing numbers** | Known renewals only; estimates strictly opt-in |

---

## Flows

### Preparing for a trip

Enter a departure date and an estimated distance. The screen answers in three
groups, and the grouping is the honest part:

1. **Dated deadlines** — a registration or insurance that expires before the
   return date. These are recorded facts.
2. **Projections** — service items whose `dueOdometerKm` falls inside
   `current + trip distance`, or whose `dateFromDistance` lands before the
   return. These are forecasts from observed driving, and must be labelled as
   such; `ReminderProjection` already distinguishes a prediction from a
   deadline.
3. **The user's own checklist items** — free text, remembered per vehicle.

**What it must never do** is present the result as a roadworthiness check. It
lists what *the garage's own records* say falls due. The moment it adds "check
tyre pressure and lights" it implies an inspection nobody performed.

### Mechanic handover, and the visit afterwards

**Before:** pick the vehicle, tick which open observations and which upcoming
items to include, tick which photos. Produces a PDF alongside the existing
report kinds — same builder, same fonts, one more case.

**After:** open the same sheet and record the visit once. It creates a normal
`ServiceEntry` (which already has `cost`, `partsCost`, `laborCost`, `shop`,
`warrantyUntil`, `faultCodes` and `measurements`), attaches the invoice, and
ticks the observations the work addressed. Each ticked observation gets
`addressed_by`; whether it is *resolved* stays a separate question the owner
answers when they know.

### Recurring routes and commute time

The idea most likely to go wrong, so in full.

**Saving a route.** On the finish-drive sheet, "save this as a route" and name
it — *Home → Work*. A route is a **named pair with a direction**; the return
leg is a separate route, created with one tap from the first. **No addresses.**
A label is enough, and asking for a home address for a feature that does not
need one is a privacy cost with nothing bought.

**Recording.** Start drive → pick the route, last-used first → finish.
Departure and arrival come from the clock the draft already stamps. Duration is
derived and correctable.

**The chart.** Individual journeys as dots; a **median** line by month or
quarter; an interquartile band for spread. Median rather than mean, because one
journey stuck behind a crash should not move a trend. Always show *n* per
bucket, and grey any bucket under about five journeys instead of drawing a
confident line through three dots.

**Comparability, where the feature lives or dies:**

- Filter by **weekday group** and **departure window**. Comparing an 06:30 run
  with a 09:00 one is the commonest way to fool yourself.
- A **"not a normal run"** flag on the trip — the shopping detour, the school
  drop-off. Excluded from the trend by default, still drawn as a hollow dot so
  it is not hidden.
- **Route variants** (motorway versus the back road) are separate routes, not
  one route with noise in it. Comparing them is then a deliberate two-line
  chart rather than an accidental average.

**What the chart may claim, in words:** *"Recorded journeys on this route took
a median of 45 min this quarter, against 35 min two years ago (n=48 and
n=12)."* It must not say traffic got worse. It does not know that — the
departure time, the route or the car may have changed. This is the same rule
the rest of the app already follows: never print a number the data does not
support.

**A remembered figure** may be entered — *"recalled: about 35 min, 2024"* — and
must be drawn differently and never folded into the median. It is a reference
line, not an observation.

**In a shared garage, compare per driver by default.** Two people drive the
same road differently and merging them makes the trend meaningless. `driver` is
already on the trip (`supabase/migrations/0052_trip_driver.sql:13`), so this is
a group-by rather than a new field.

**Beyond commuting**, the same thing answers "is the school run getting worse",
"how long does the coast trip really take", and feeds the business logbook,
since a named recurring route is exactly what a *putni nalog* repeats.

---

## Phasing

**Phase 1 — make what exists trustworthy.** Confirm push server-side, then
build the offline queue (**A**). Nothing new is worth much while a fill-up
typed at a pump can vanish.

**Phase 2 — reduce typing.** Receipt recognition (**D**), odometer photos
second. Draft-and-confirm always.

**Phase 3 — the vehicle's story.** Observations (**B**), then the trip check
(**C**) and the handover (**E**). One arc, one model.

**Phase 4 — routes** (**F**). Deliberately after phase 3, so drive drafts have
accumulated real journeys. The feature is worthless against an empty history,
and shipping it early guarantees a bad first impression of it.

**Phase 5 — money, carefully.** Buyer's report (**G**), then the expense
calendar (**H**) if it still looks worth it.

---

## Privacy and data handling

Grounded in what the code does today, not what a policy says.

- **Recognition must run on the device.** ML Kit on Android is offline and
  cheap. If the web build cannot, the web build asks people to type — there
  must be **no cloud OCR fallback**. Sending a photographed receipt to a third
  party would contradict `PRIVACY.md` and the app's no-tracking claim outright.
- **Route labels are not locations.** "Home → Work" stores no coordinates, so
  as specified this feature adds **no new category of personal data**. The
  moment real addresses appear, `PRIVACY.md`, `web/privacy.html` and the Play
  data-safety answers all move. Keeping labels is the cheaper and better
  design, not a compromise.
- **The buyer's report is a disclosure surface.** Default it to excluding trips
  entirely: journey times and route names describe a person's routine. The
  owner picks what goes in, and the document should say what it is — the
  owner's own record, not an independent verification of mileage or condition.
- **A revocable read-only link is not worth it.** It means a public web
  surface, expiry rules, an abuse story and a new privacy section, to save
  somebody emailing a PDF. Revisit only if buyers actually ask for one.
- **Observations may want audio.** The attachment plumbing is vehicle-scoped
  with short-lived signed URLs and would carry it, but `Attachment.isImage`
  (`lib/domain/entities/attachment.dart:67`) handles only pictures, so playback
  is real work. Ship photos first; a recording of a rattle is charming and
  rarely diagnostic.
- **None of this needs background location.** That remains a non-goal
  (`roadmap.md:213`) and nothing proposed here approaches it.

---

## Recommendation

**Build first: the offline queue.** It was not among the eight ideas and it is
the most valuable thing on this page. Every idea here *adds* data entry; this
one makes the entry that already exists reliable at the one place the app's own
documentation admits it fails.

**Then receipt recognition** — the only idea that genuinely removes typing.

**Then observations**, which are small, cheap, and the keystone that turns
three proposed features into one.

**Defer the expense calendar.** It is the idea most likely to produce a
confident wrong number, and "guessing what a repair should cost" is already a
recorded non-goal (`roadmap.md:211`). Limited to known renewals on dates the
app holds, it is honest but thin; the moment it estimates, it is guessing.
Wait until observations and history give it a real basis.

**Leave out the standalone driving-event journal** — it is an observation with
a `trip_id` — **and the revocable share link**, which is a web application
wearing the costume of a button.

**One caution about the trip check**, the idea most tempting to over-build: keep
it to what the garage's own records say falls due, plus the owner's own items.
A checklist that grows toward "and check the lights" is one that implies a
safety inspection nobody carried out.
