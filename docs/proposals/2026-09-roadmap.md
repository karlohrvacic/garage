# A proposal: eight ideas, and what to do with them

**Date:** 2026-09-05
**Status:** Phases 1, 3, 4 and half of 5 are built (6 September 2026). Receipt
recognition and the expense calendar are not, and both are deliberate. See
*Phasing* below for what shipped and what was left.
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

### The roadmap is out of date about push — *corrected 6 September 2026*

[`roadmap.md:45`](../roadmap.md) used to say Firebase was not configured and
called it "the largest gap between what the app says and what it does". It now
says what this paragraph found. **The client half is wired.** `Firebase.initializeApp` is called from
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
| **Vehicle history for a buyer** | **~70%.** `ReportKind.sellers` (`lib/features/reports/report_builder.dart:266`) already renders vehicle facts, average economy, fill-up count, fuel total and the whole service table. | Choosing what goes in; attachments (no report embeds an image); wording that does not imply the record verifies anything. |
| **Mechanic handover** | **~40%.** `ReportKind.serviceSchedule` renders the rules and their projected due dates (`lib/features/reports/report_builder.dart:580`). | Symptoms, photos, selection, and the entire post-visit half. |

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
  roadmap items 6 (`roadmap.md:131`) and 2 (`roadmap.md:63`). Offline is
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
(`lib/features/trips/widgets/drive_card.dart:371`). That delivers the whole of
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
| **I** | Leasing contract on the car | Medium (high to a business) | a tester who leases | 4–6 in three stages | Building details nobody here can check | The record, its row and the end-date reminder |
| **J** | Company mode: a manager and drivers | Medium (high to a business) | a company that wants it; the RLS suite | 8–12 in three stages | A third tenancy path in RLS; employee data | Assignments with driver-scoped visibility; the manager sees everything |
| **K** | EU recall data beside the US registry | Medium | — | 3–4 | A second registry that fits no car perfectly; a new third party | Safety Gate by make and model, beside the NHTSA card, both labelled |
| **L** | Warranty with a date and a distance | Medium | rules (done) | 1–2 | Implying coverage the app cannot know | A document whose expiry is a rule with both dimensions |
| **M** | Fuel bought abroad | Medium | — | 3–4 | Rates, rounding; a new third party | Currency on the fill-up, converted at the day's HNB rate, original kept |
| **N** | Handover record when lending | Medium | guest passes (done) | 3–4 | Photos as evidence people argue over | Odometer, fuel level and photos at hand-over and return, both sides see it |
| **O** | Reminders as a calendar feed | Medium | API keys (done) | 1–2 | A key inside a calendar URL | ICS from the read-only API, one per key |
| **P** | Toll statement import | Low-medium (high to a commuter) | CSV mapper (done) | 1 | Statement formats change | An ENC preset for the mapper |
| **Q** | Last year's premium at renewal | Low-medium | — | 1 | Reading as a recommendation | The figure beside the insurance reminder, nothing more |
| **R** | Weekly garage digest | Medium | push switched on | 2–3 | Noise | One message a week, opt-in |
| **S** | "Did you forget to log?" nudge | Medium | — | 2–3 | Nagging | Local, per car, only past twice the usual gap, once a month at most |

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

### Leasing: a contract on the car — *added 14 September 2026*

Common in Croatia and never considered here. Operative leasing runs 36 to 60
months with an agreed kilometre allowance, a fee per kilometre over it, a
wear fee and an agreed residual; the car goes back to the lessor. Financial
leasing is a loan with a down payment and a small buyout; the car stays. Both
carry a monthly instalment with VAT and a deposit up front, and one lessor's
own advice is to ask for a bigger allowance mid-contract the moment you can
see yourself exceeding it — which is what an app that already measures the
driving rate (`lib/features/maintenance/providers/maintenance_providers.dart:164`)
can say months before the bill.

**One leasing record per car**, not a document type: type, lessor, start and
end, monthly instalment, deposit, kilometre allowance and the fee per
kilometre over, residual or buyout. It shows as a "Leasing" row under "This
car", puts the end date into the reminders the way a document's expiry goes
in, adds a line to Costs with the instalments paid so far, and for operative
leasing projects the allowance: "at this rate you reach it in March, seven
months early, about €680 over", with the app's usual caveat that it is a
projection from your own records. In cost of ownership the instalments stand
in for value lost (`lib/domain/costs/running_cost.dart:147`), because under
operative leasing the depreciation is the lessor's.

**Deliberately not built:** VAT splits, the 70% deductibility rule for
passenger cars, driver assignment. A business that needs those needs an
accountant, not this app.

**Staged:** the record with its row and reminder; then the mileage
projection; then the money. **Wait for a tester who leases before stage one.**
Nobody on this project has held a leasing contract, so every detail above is
read from lessors' terms rather than lived, and the fee arithmetic is the
kind of thing that is confidently wrong until somebody with a contract in
hand reads it back.

### Company mode: a manager and drivers — *added 14 September 2026*

Asked for in one sentence: one manager assigns a car to a driver; the driver
is responsible for that car and cannot see the others; the manager sees
everything, exports spreadsheets, and can enter data on a driver's behalf.

**What already leans this way.** The rename from household to garage was
argued on exactly this: a garage with several cars, several drivers and a
cost split is what fleet management looks like from the outside. A guest pass
(decision 110) is already "one car, scoped, sees only what they logged": a
driver assignment is the long-lived, named, history-visible version of it. A
trip's driver is free text (`lib/domain/entities/trip_entry.dart:103`)
because the driver of a company van is often not in the garage at all.
Exports are garage-wide already.

**What it reverses.** Members are co-equal today; admin only gates deleting
and removing (`docs/architecture/06-security-and-tenancy.md`). A driver who
sees one car is a third kind of membership, and the database has to enforce
it, not the screen.

**Shape.** An assignment record, `vehicle → driver, from, to`, kept as a log
rather than a field, because "who had the car on 3 May" is the question a
fine or a scratch asks. A driver's visible set is the cars currently assigned
to them, resolved by a function of its own with additive policies, exactly as
`guest_vehicle_ids()` was added beside `user_vehicle_ids()` and never folded
into it. The manager is the admin and sees all. Logging on a driver's behalf
keeps `created_by` honest (the manager typed it) and takes the attribution
from the assignment on that date, which is also what makes the driver's own
entries theirs without a second field. Exports gain a per-driver cut. Shared
costs stay off for a fleet: drivers do not owe the company.

**Risks.** Every table a driver may reach needs its own policy and its own
case in the RLS suite, positive control included; the guest work showed how
a policy that denies everyone passes every "stranger sees nothing" test. A
manager reading what employees logged is employee data under the GDPR: the
app records typed places and never a position, and must stay that way, and
the privacy policy has to say what a manager sees. This is also the natural
paid feature, which decision 155 left room for.

**Staged:** assignments with driver-scoped visibility and the log; then
on-behalf logging with attribution and the per-driver export; then handover
between drivers and driver notifications. **Wait for a company that wants
it**, and pair it with the leasing item above: it is the same customer.

### Smaller ideas, and one nudge — *added 14 September 2026*

Each fits something the app already knows, and each is small enough to build
between larger items.

- **EU recall data (K).** The recall card queries the US NHTSA registry and
  says itself that a match may not apply to a European build. The EU Safety
  Gate publishes vehicle recalls as open data; searched by make and model it
  is the registry that covers a Croatian car. Both cards stay, each labelled
  with where it looked, and the policy gains a third party.
- **Warranty (L).** "Five years or 100,000 km" is a reminder rule with both
  dimensions, which the projection already handles, whichever comes first.
  A document type with a distance on it, nothing more; the app must never
  say whether something *is* covered.
- **Fuel abroad (M).** Slovenia and Bosnia are where a good share of Croatian
  fill-ups happen. A currency on the fill-up, converted at that day's rate
  from the national bank's public list, stored in the garage's currency with
  the original amount kept beside it, so economy and cost per kilometre stay
  comparable.
- **Handover record (N).** Odometer, fuel level and photos at hand-over and
  at return, written by whoever holds the car at the time and visible to both
  sides. It protects a friend lending a car and a small rental business
  alike; the guest pass already frames the loan. Photos are evidence, so the
  record must be plain about who took them and when.
- **Calendar feed (O).** An ICS address served by the read-only API, one per
  key, so what is due shows in the family's calendar without push. The key
  sits in a URL that calendar apps store; revoking the key kills the feed.
- **Toll statements (P).** Electronic toll comes as a monthly statement; a
  preset for the CSV mapper turns one into cost entries. Formats change, so
  a preset is a starting point for the mapping, never a parser.
- **Last year's premium (Q).** The cost history has it; showing it beside the
  insurance reminder prompts a comparison. No recommendation, no link.
- **Weekly digest (R).** One message a week, opt-in, once push is switched
  on: what was logged, what it cost, what is due. Silent when nothing
  happened.

**"Did you forget to log to Garage?" (S).** A nudge when a car has gone quiet
for longer than its own rhythm, computed on the device from the log itself:
the usual gap between fill-ups is the median of the gaps on record, and a
nudge is due only when the current gap has passed twice that, at most once a
month per car, and never for a car that is archived, out on loan, or on a
drive. The same rule works for odometer readings, which keep the projections
honest. It ships as a local notification through the existing per-device
plumbing in `lib/core/notifications/`, needs no server and no new data, and
is off with one switch under Settings › Reminders. The whole risk is nagging:
a nudge that fires while somebody is on holiday is one they turn off for
good, so the threshold errs long and the copy says what it saw ("no fill-up
since 2 August, you usually log one every ten days"), not what they should
have done.

## Phasing

**Phase 1 — make what exists trustworthy.** Confirm push server-side, then
build the offline queue (**A**). Nothing new is worth much while a fill-up
typed at a pump can vanish. — **Built**, except the server-side push check,
which needs a console this repository cannot reach
([TODO-manual-steps.md](../TODO-manual-steps.md)).

**Phase 2 — reduce typing.** Receipt recognition (**D**), odometer photos
second. Draft-and-confirm always. — **Not built.** Deliberately: there is no way
to tell whether extraction works on the receipts this app will actually meet
(INA, Petrol, Tifon, a Croatian service invoice) without holding some, and
shipping a recogniser that is wrong a third of the time costs more trust than
the typing it saves.

**Phase 3 — the vehicle's story.** Observations (**B**), then the trip check
(**C**) and the handover (**E**). One arc, one model. — **Built** (decisions
117–119). Per-item selection on the handover sheet was left out on purpose;
decision 119 says why.

**Phase 4 — routes** (**F**). Deliberately after phase 3, so drive drafts have
accumulated real journeys. The feature is worthless against an empty history,
and shipping it early guarantees a bad first impression of it. — **Built**
(decisions 120–122): `routes`, a picker when a drive is started, and a trend
that reports medians with their spread and refuses to explain them. The
"worthless against an empty history" risk is unaddressed by anything but time;
the screen says what it is waiting for rather than drawing an empty chart.

**Phase 5 — money, carefully.** Buyer's report (**G**), then the expense
calendar (**H**) if it still looks worth it. — **G is built** as a mileage
trail rather than as the selection-and-attachments pass this page proposed;
decision 128 says why. **H is not built, and is still deferred** for the reason
the recommendation below gives: it is the idea most likely to produce a
confident wrong number, and nothing has changed that.

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
  (`roadmap.md:291`) and nothing proposed here approaches it.

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
recorded non-goal (`roadmap.md:289`). Limited to known renewals on dates the
app holds, it is honest but thin; the moment it estimates, it is guessing.
Wait until observations and history give it a real basis.

**Company mode waits for a company.** It is the largest item here, a third
tenancy path through every policy, and the first paid feature; design it
with the customer who asked, not ahead of them.

**Leasing waits for a tester who leases.** The design is above and small
enough to build in stages once one person can check the details against a
real contract; before that it is guessing about money.

**Leave out the standalone driving-event journal** — it is an observation with
a `trip_id` — **and the revocable share link**, which is a web application
wearing the costume of a button.

**One caution about the trip check**, the idea most tempting to over-build: keep
it to what the garage's own records say falls due, plus the owner's own items.
A checklist that grows toward "and check the lights" is one that implies a
safety inspection nobody carried out.
