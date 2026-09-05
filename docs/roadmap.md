# Roadmap

What Garage should become, and what it is missing today. Written September
2026, against the app as it stands: 30 screens, 21 tables, four edge
functions, Android and web, English and Croatian.

Revised 4 September 2026, after items 5, 9, 10 and 11 were built.

This is a working document, not a promise. The order reflects what would make
the app more useful to the people already using it, not what is most fun to
build. Each item says what it is, why it matters, and what it costs — because
an item with no cost written down always looks cheap.

Read it with [known-bugs-and-risks.md](operations/known-bugs-and-risks.md),
which lists what is broken rather than what is missing, and with
[decisions/decision-log.md](decisions/decision-log.md), which records what was
deliberately left out and why. **Check both before proposing something here:
several obvious ideas are already decided against on purpose.**

---

## The one-line summary

Garage is a good logbook and a competent planner, and since September 2026 it
also tracks the paperwork. It is weakest where it stops being a logbook: it
does not reliably reach a person who is not looking at it, and it does not
work without a signal. Both remain true, and the first cannot be fixed from
this repository.

---

## Now — finish what is half-built

These are not new features. Each is something the app already claims, or
nearly does, and does not deliver.

### 1. Turn push on
**Status: written, switched off.** Every piece exists — `device_tokens`, the
`push-due-reminders` cron, the FCM token exchange — and Firebase is not
configured, so reminders are per device. A garage is shared; a reminder
created by one member is heard by nobody else. That is the largest gap
between what the app says and what it does.

**Cost:** a Firebase project, the config files, one deploy of the edge
function, and a decision the app already has a switch for (device vs server
schedule). Note the all-or-nothing bit recorded in known-bugs: configuring
Firebase makes the app stand down its local scheduling, so this cannot be
half-done.

### 2. Work without a signal
Every write goes straight to Supabase. A fill-up is typed at a pump, which is
exactly where a phone has one bar of signal and a canopy overhead. Today a
failed write shows a message and keeps the sheet open; nothing queues.

**What it needs:** a local write queue with the client-generated ids the
sheets already mint (decision 79), replayed on reconnect, and a visible
"waiting to sync" state. The ids make this genuinely tractable — a replayed
insert is the same row, not a duplicate.

**Cost:** real. It touches every repository and needs its own test suite. It
is also the difference between an app people trust at a pump and one they
open afterwards, at home, if they remember.

### 3. Verify the confirmation and invite links against the live project
Recorded as High in known-bugs and still unproven: Supabase ignores
`emailRedirectTo` unless the URL is in the allow-list, and the invite deep
link needs `assetlinks.json` with the real Play fingerprint. A sign-up that
dead-ends on a blank page is the most expensive bug an app can have, because
nobody reports it — they leave.

### 4. Clear the critique backlog on Stations, Data and Features — *done*
**Closed by decision 91, which landed in the same change that wrote this
roadmap and was therefore described here as outstanding.** The duplicated
"national average" headings, the header that ate three quarters of a phone
screen, the twelve-tables-in-one-file CSV that omitted tyres, and "API access
— a read-only feed" sitting over the webhook screen are all fixed. Kept in the
list rather than deleted, because a roadmap that quietly loses an item is one
nobody can check.

---

## Next — the things people will ask for

### 5. Documents with expiry dates — *done*
**Built, September 2026 (decision 94).** `vehicle_documents` records the
paper: registration, roadworthiness, liability and comprehensive insurance,
green card, and an `other` for the rest — each with the number and issuer
written on it, the day it was issued, the day it runs out, and a photo through
a fourth `attachments.entry_kind`.

The reminder reuses the maintenance service types rather than inventing a
parallel system, so a registration turns up on the dashboard, in the planner,
in a notification and on `/due` without any of them learning what a document
is.

**Left out on purpose:** a driving licence. It belongs to a person, not a car,
and both the table and the attachments bucket are scoped by vehicle.

**Still open on top of it:** nothing reads the *photo* — see item 6 — and a
document of type `other` raises no reminder, because the app has no name for
whatever is being kept there.

### 6. Read the receipt
Attachments arrived; nothing reads them. A photographed fuel receipt carries
litres, price per litre, total, date and station — every field the sheet
asks for. Same for an odometer photo.

**Cost:** on-device text recognition is cheap and offline (ML Kit on Android;
the web build would fall back to typing). Getting the mapping right for the
handful of Croatian chains (INA, Petrol, Crodux, Tifon, Shell, MOL, Lukoil)
is a week of fixture work, not a research project. Start with "fill the
fields, let the person correct them" — never save a receipt read without
showing it.

### 7. Fuel-price alerts and cheapest-on-route
The station data is already there, updated daily, with a price trend and a
detour calculation. The missing half is being told. "Tell me when diesel near
me drops below €1.45" is one push and one predicate. "Cheapest station on my
way to Split" is a route match against a dataset already loaded.

This is the app's most distinctive asset. Nobody else has the ministry's feed
with a household's own consumption figures on top of it.

### 8. Electric and plug-in hybrid, properly
The plumbing knows kWh. What is missing is everything a driver of one
actually wants: charging sessions with a tariff (home night rate versus a
public charger), cost per 100 km against the petrol car they replaced,
battery state of health over time, and range at this temperature. Croatia's
EV share is small and growing fast, and a fuel-first app that treats
electricity as "fuel with a different unit" will feel wrong the moment
somebody logs a home charge at €0.09/kWh next to a Hrvatski Telekom charger
at €0.55.

### 9. Anomaly and duplicate detection — *done*
The app has enough history to know when an entry is wrong, and the moment of
entry is the only moment a person can still fix it cheaply.

**Done:** a fill-up whose odometer and litres cannot describe a journey
(decision 93); a cost repeating one already logged that day, a service
repeating one at the same odometer, and a trip whose distance and time imply a
speed no road allows (decision 95). All four are warnings rather than
refusals — the household is the one who knows which is real.

**What would come next, if anything:** an odometer that jumps implausibly far
between two readings, which is the one remaining shape of the same mistake and
the only one that needs history rather than the two fields in front of you.

---

## Later — bets worth taking

### 10. A business logbook that satisfies a Croatian tax inspection — *mostly done*
**Built, September 2026 (decision 100).** A trip now records **who drove it**
— not who typed it — and `ReportKind.tripLog` prints a period's journeys with
the route, the purpose, the driver, the business and private totals, and a
line to sign.

**What is deliberately still missing:** a real *putni nalog* is issued
*before* a journey and carries an advance, a per-diem and an approval. This
prints what was driven, after the fact. Closing that gap means modelling an
order rather than a record, which is a different feature and probably a
different app.

### 11. What the car is worth, and what it has cost — *done*
**Built, September 2026 (decision 96), the hand-entered way.** A vehicle
carries what the household reckons it is worth and the day they reckoned it,
and the vehicle page now prints what the car costs to *own* beside what it
costs to run.

Scraping Njuškalo was rejected on more than cost: a scraped listing price
would be a number the app invented, sitting on the same card as numbers the
household typed, carrying an authority it has not earned.

**Still open on top of it:** the figure is measured over the distance covered
*since the household added the car*, which is the only span the app has
readings for. A car bought years before it was logged reads high, and nothing
on screen says so.

### 12. Consumables the car actually takes
Oil viscosity and spec, filter part numbers, bulb types, wiper lengths, tyre
sizes, battery type. A DIY owner searches for these before every job, and
gets them wrong. The app knows the make, model, year and engine.

**Cost:** data. There is no free authoritative source; this is a scraping and
curation project, and it is the single biggest lever on making the app
indispensable to the person who does their own oil changes. Start with what
the household types in once, per car, and let the app remember it.

### 13. Shared reliability signal
Every household is recording what broke, at what mileage, on what model. In
aggregate that is worth more than any of the individual logs. It is also the
one feature that could not be built without a strict, opt-in, anonymised
design and an explicit change to the privacy policy, which currently promises
the data goes nowhere. Do it right or not at all.

### 14. iOS
Android and web only. The web build is installable and covers an iPhone
badly. This is not a feature, it is a market decision with a cost attached:
a Mac, a developer account, and the Flutter code already exists.

---

## Explicit non-goals

Recorded so nobody proposes them twice.

- **Ads, or selling any of this data.** The privacy policy says so and the
  app is free without them.
- **A social feed.** Nobody wants a like button on their brake fluid change.
- **Booking a garage appointment.** A marketplace is a different company.
- **Guessing what a repair should cost.** The app would be believed, and it
  cannot know.
- **Automatic trip detection by GPS in the background.** It drains a battery,
  it needs a permission Croatians reasonably refuse, and a manual trip entry
  takes fifteen seconds. Revisit only for the business logbook, where the
  compliance value is real.

---

## What would make the biggest difference tomorrow

If only one thing gets done: **turn push on**. A shared garage where only one
person hears the reminder is not shared, and everything else on this list is
worth less until that is true. It is also the one item on this page that
cannot be done from the repository at all — it is a Firebase project, five
values and one cron row, and [RUNBOOK-push.md](RUNBOOK-push.md) is the whole
list.

If two: push, then **work offline**, because the pump is where the app is
used and the pump is where it fails. That one is real engineering — it touches
every repository and needs its own suite — and it is the largest thing left on
this page that is entirely within the code.
