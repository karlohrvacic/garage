# 13. Company mode: the layer above the car

A garage on the company plan gets what a household never needed: who is
responsible for each car, who may see it, what the administrator does on
somebody's behalf, what the whole fleet needs this month, and what leaves for
the accountant. Siblings: [06](06-security-and-tenancy.md#drivers-the-third-tenancy-path)
for how a driver is kept to their cars, [08](08-reminders-and-notifications.md)
for who a reminder reaches, [02](02-domain-model.md) for the tables. The
product reasoning is item 15 of [the roadmap](../roadmap.md); the trade-offs
are decision 184.

> Jump to [Sharp edges](#sharp-edges): a second handover on the same day is
> refused, a driver's "today" is UTC's, an incident logged with no signal is
> lost rather than queued, and a departed driver's name cannot be read back.

## The garage is the company

There is no company above garages. `households.plan` is `free` or `company`,
with `plan_until` for when it ends
(`supabase/migrations/0080_company.sql:32`); `company_enabled(household)`
(`supabase/migrations/0080_company.sql:106`) is true while the plan is current,
and every gate reads it. **Nothing on the plan gates reading, exporting or
deleting** (decision 155): a lapsed garage keeps every row and every screen,
and only three things wait for the plan — adding a car above the free cap,
making a driver, and handing a car to one. The app reads the same two facts
off the household entity: `isOnCompanyPlan` is what the company surfaces key
on, lapsed or not, and `companyEnabledAt(now)` is what the gates ask
(`lib/domain/entities/household.dart:67`). The console says which of the two
it is in a banner (`lib/features/company/widgets/company_plan_banner.dart:13`).

**The free cap is five active cars**, `free_vehicle_limit()`
(`supabase/migrations/0080_company.sql:91`), and it gates every way a car
becomes active, not only the insert: `can_add_vehicle`
(`supabase/migrations/0080_company.sql:127`) is asked by the `vehicles` insert
policy, by a `before update of archived` trigger when a car comes back from
the archive (`supabase/migrations/0080_company.sql:161`), by a redeemed
transfer before the car moves (`supabase/migrations/0080_company.sql:276`) and
by a merge whose survivor would end up over the cap
(`supabase/migrations/0080_company.sql:410`). Archived cars do not count: a
family that sold two cars and archived them has three in the garage. The three
functions refuse with their own code, `P0008`, which the app renders as its
"free plan's five cars" sentence (`lib/core/errors/app_failure.dart:142`); a
policy cannot raise, so the insert is a bare `42501`. That is why the vehicles
screen asks first: `canAddVehicleProvider`
(`lib/features/company/providers/company_providers.dart:53`) mirrors the rule
through `Household.canAddVehicleAt` (`lib/domain/entities/household.dart:88`),
and the Add button shows the cap sentence, or the "plan ended on" sentence for
a lapsed company garage, instead of a form the database would refuse
(`lib/features/vehicles/screens/vehicles_screen.dart:41`).

**Nobody puts their own garage on the plan.** `authenticated` holds `update`
on every household column but `plan` and `plan_until`
(`supabase/migrations/0080_company.sql:54`): a column privilege rather than a
trigger, so that the service role — which is what billing will use — keeps its
table-level update. Until billing ships (Stage 3 of the roadmap) the operator
sets it by SQL as the service role. The app never writes the plan:
`Household.copyWith` carries it through unchanged
(`lib/domain/entities/household.dart:99`), and `householdSettingsToRow` writes
the three letterhead columns and nothing else.

**The letterhead is the admin's**, the way the garage's name is: the rename
guard of 0036 now compares the three columns as well
(`supabase/migrations/0080_company.sql:66`), and a member's change of any of
them is refused with `42501`. The settings row every member saves carries
the letterhead unchanged, so a unit preference still lands; a member whose
copy of the garage is stale — the admin changed the name or the letterhead
since their phone last read it — has that save refused, which is the edge
the name guard always had.

## Drivers

`household_members.role` gained `driver`
(`supabase/migrations/0080_company.sql:26`). A driver is a member of the
garage whose role names the cars they may reach: the ones the assignment log
says are theirs today, and nothing else — not the other cars, not the garage's
costs, not the people's spending. How that is enforced is
[06](06-security-and-tenancy.md#drivers-the-third-tenancy-path); what it looks
like is below.

**The role travels with the startup fetch.** The bootstrap's fourth request is
the caller's own `household_members` rows
(`lib/features/household/data/supabase_garage_bootstrap_repository.dart:99`),
kept in `GarageBootstrap.rolesByHousehold` and in the on-device cache, so a
driver's phone opens on the right presentation from the copy it kept
(`lib/features/household/data/garage_bootstrap.dart:48`). A role that could not
be read, or a cache from before roles were kept, reads as `member`, which is
what every garage was. `myRoleProvider` and `isDriverProvider`
(`lib/features/company/providers/company_providers.dart:67`) are what every
screen asks about the garage on screen. The car page asks about the car's
own garage instead, `roleForVehicleProvider` and `isDriverForVehicleProvider`
(`lib/features/company/providers/company_providers.dart:83`), because a car
opened by URL or from a push can be another garage's: a driver whose own
private garage was the current one used to be handed the owner's menu on the
company's van.

**Making a driver** is on the members screen, for an admin, while the plan is
current — the update policy refuses the role otherwise
(`supabase/migrations/0080_company.sql:569`) — and never on your own row
(`lib/features/household/screens/household_screen.dart:630`). A driver's row
says which cars they have today, or that they have none. When the viewer is
a driver, only their own row says so
(`lib/features/household/screens/household_screen.dart:529`): the policy
shows a driver their own windows and nothing else, so the log they hold
cannot say another driver has no car. The role stays on a lapsed garage: its
drivers keep their cars, and only a new driver waits for the plan.

**Succession never crowns a driver.** `ensure_household_has_admin` skips
`role = 'driver'` when the last admin steps down or leaves
(`supabase/migrations/0080_company.sql:583`), and `successorOf` in the app
does the same (`lib/features/household/admin_succession.dart:12`), so the
sentence naming who inherits is right before the trigger decides. When only
drivers would remain, an admin's own leave is refused with `P0007`
(`supabase/migrations/0080_company.sql:634`) and the members screen shows
"a garage of drivers needs an admin" (`lib/core/errors/app_failure.dart:140`).
Only a leave, and only an admin's: a driver leaving an adminless garage is
never refused, and an account deletion cascades through with no `auth.uid()`
to compare and proceeds, because erasure has to be real (decision 101). That
last case leaves a garage of drivers with no admin; it is recorded in
[known-bugs](../operations/known-bugs-and-risks.md#a-garage-of-drivers-can-be-left-without-an-admin-by-an-account-deletion)
rather than refused.

**"My cars"** is the vehicles screen wearing a driver's presentation
(`lib/features/vehicles/screens/vehicles_screen.dart:77`): the title, no Add
button, no archived section, an empty state that names the administrator as
the one who hands a car over, and two cards above the grid. The dashboard
says the same to a driver with no car yet
(`lib/features/dashboard/screens/dashboard_screen.dart:213`) in place of the
"add your first vehicle" card, whose every way in is refused for a driver,
and its quick-add sheet and "What next" card offer no reminder and no income
(`lib/features/dashboard/screens/dashboard_screen.dart:719`). The first is a
one-time notice saying what the administrator sees — every entry on a company
car, and which car was theirs on which day — with the sentence that the app
records the places you type and never where the phone is
(`lib/features/company/widgets/driver_notice_card.dart:10`). It is owed per
device, under the SharedPreferences key `company.driver_notice.seen`
(`lib/features/company/providers/driver_notice.dart:14`): a phone that was
reset owes it again, and a store that cannot answer shows it and logs why. The
second lists the handovers the driver has not signed off, one button each
(`lib/features/company/widgets/pending_handovers_card.dart:21`), scoped to the
garage on screen: a driver's windows come back from every garage they still
drive for — the policy pairs their own row with a current driver membership
in the car's garage (`supabase/migrations/0080_company.sql:742`), so a
removed driver reads none of their old windows, notes and readings included
— and a window whose car is not on this garage's list is skipped. A refused
sign-off keeps the card and says why.

**The driver's car page** keeps the four tabs and the everyday buttons, and
loses the owner's once-in-a-while acts, every one of which the policies
refuse: a driver gets a menu of their own with *Report an incident* and
*Create report* (`lib/features/vehicles/screens/vehicle_detail_screen.dart:508`),
no add-reminder row (`lib/features/vehicles/screens/vehicle_detail_screen.dart:2334`)
and no *Add income* (`lib/features/vehicles/screens/vehicle_detail_screen.dart:1633`).
The menu is theirs only for a car handed to them: a driver holding somebody
else's car on a pass gets the borrower's page like anyone. The report reads
what they can read and asks no "which driver" of them
(`lib/features/vehicles/screens/vehicle_detail_screen.dart:197`): the log a
driver holds is their own windows, so any other pick would file an empty
logbook. A report whose read fails says so in a snackbar rather than ending
the tap in silence. The tyres,
documents and parts screens still offer a driver their add buttons; the
database refuses the write and the sheet says so (the parts sheet learned to
in this work, `lib/features/parts/widgets/vehicle_part_sheet.dart:171`), which
is a button that cannot work rather than one that fails silently, and is
recorded rather than fixed.

## The assignment log

`vehicle_assignments` is a log, not a field
(`supabase/migrations/0080_company.sql:666`): "who had the car on 3 May" is
what a fine, a scratch or a speeding ticket asks, and a field only ever knows
who has it now. One driver per car at a time is an exclusion constraint over
`daterange(from_date, to_date, '[]')`
(`supabase/migrations/0080_company.sql:688`), any number of cars per driver.
The window carries the readings at both ends, a note, and the driver's
sign-off — what the paper *putni blok* had.

**A handover is one call.** `hand_over_vehicle()`
(`supabase/migrations/0080_company.sql:807`) closes the open window on the day
before, writes the reading as an odometer entry and opens the next, in one
transaction, so the odometer series and the log cannot drift; with no
recipient the car comes back to nobody, which is allowed on a lapsed plan
while handing it on is not. A second handover on the same day is refused
(`P0006`, both for an open window that started that day and for a closed one
that covers it), and the app's sentence tells the admin to remove the wrong
handover first (`lib/core/errors/app_failure.dart:137`). The console's row
menu removes the newest window still open — usually today's, but a handover
arranged on Friday for Monday is open too, is not today's, and is the
likelier mistake (`lib/features/company/widgets/drivers_and_cars_tab.dart:166`).
A sale closes the seller's driver out: every window that still reaches today
is cut on the day before the sale and one that opens today or later is
deleted (`supabase/migrations/0080_company.sql:300`).

**A sign-off is the driver's and nobody else's.** `confirm_vehicle_assignment()`
(`supabase/migrations/0080_company.sql:897`) is the only thing a driver may
change on the log, and a `before insert or update` trigger pins the two
columns to it (`supabase/migrations/0080_company.sql:932`): a window is created
unsigned whoever creates it, the one change let through afterwards is the
row's own driver signing it once, a signed window keeps its driver, and an
admin's write of either column is refused. An admin owns the log and may
delete a window and create it again, so a sign-off can be lost; it cannot be
forged or edited. The confirm dialog for removing a signed window says the
sign-off goes with it.

**Attribution is resolved, not stored.** `created_by` stays whoever typed the
entry; the driver is whoever the log says had the car that day. The rule
exists twice, `driver_on()` in SQL (`supabase/migrations/0080_company.sql:781`)
and `AssignmentResolution.driverOn` in Dart
(`lib/domain/company/assignment_resolution.dart:18`), both ends inclusive,
first window wins as the SQL's `limit 1` does, and both held to
`test/fixtures/assignment_resolution.json` from both suites — the arrangement
decision 163 chose for the economy rule. A day with no window belongs to
nobody, and every reader says so rather than guessing at who typed it. In the
app the resolution is `driverOnProvider` and `driverNameOnProvider`
(`lib/features/company/providers/company_providers.dart:156`), null off the
plan and while the log is unknown; bulk readers — an export, the pack, the
report — go through `AssignmentResolution.driverOf`
(`lib/domain/company/assignment_resolution.dart:40`) with a names map.

Every entry sheet on the plan says so under its date
(`lib/features/company/widgets/driver_on_date.dart:21`): "Driver on this
date: Ana", or that nobody was assigned, and nothing at all while the log has
not arrived or its fetch failed with nothing cached — the first sheet after
launch must not claim nobody had the car. For a driver a day the log gives
to nobody is also nothing (`lib/features/company/widgets/driver_on_date.dart:50`),
since the policy shows them their own windows only: under the previous
driver's fine the line would say nobody had the car, and be wrong. Driver
in the car's garage, as the car page asks it, since a car opened by URL can
be another garage's than the one on screen. The trip sheet goes one further
and prefills its free-text driver from the log while creating
(`lib/features/trips/widgets/trip_entry_sheet.dart:151`): re-resolved per
date, cleared when the new date has nobody, and left alone from the moment
somebody types, because a name the sheet put there is the sheet's claim and a
typed one is the person's. A box the person emptied is refilled by the next
date change, by design.

**A window can outlive the membership behind it**, so the log can name a user
the member list no longer has. That reads as "a former member" on the sheets
and the incidents tab and "Former member" on a reimbursement line, on the
Drivers and cars row and in the pack's ledger — never a bare colon — through
one helper, `memberNameOf` (`lib/features/company/member_name.dart:13`), and
only once the member list is known: while it is loading or its read failed,
nobody is a former member yet, and the tab says so in a sentence instead.
It reads that way because `profiles_select`
(`supabase/migrations/0001_households.sql:172`) shows a profile only while its
owner shares a garage with the caller, and the name cannot be read back. A
snapshot of the name on the window is Stage 2 material. A window whose account
was deleted keeps its dates and loses its driver (`user_id` set null), like an
entry keeps its place when its author goes, and resolves to nobody.

## The console

`/company` (`lib/features/company/screens/company_screen.dart:24`) is an
admin's, on the rail's secondary links and under More on a phone, leading the
list while there is one (`lib/core/widgets/secondary_destinations.dart:36`).
It refuses, in words, a garage off the plan and a member who is not its admin,
and shows progress rather than either refusal while the household is still
unknown on a cold start typed in by URL
(`lib/features/company/screens/company_screen.dart:36`). Tabs, on a
`GarageTabBar` that scrolls rather than cuts a label:

| Tab | Widget | What it holds |
|---|---|---|
| Drivers and cars | `lib/features/company/widgets/drivers_and_cars_tab.dart:30` | A card per car: who has it today, since when, signed or not, a Hand over button, the earlier windows, and a menu that strikes the newest open window from the log |
| Deadlines | `lib/features/company/widgets/deadlines_tab.dart:30` | This month, or everything ahead, grouped by month; a row opens the car |
| Incidents | `lib/features/company/widgets/incidents_tab.dart:19` | Open, or all, across the fleet, archived cars included; a row opens the sheet |
| Reimbursements | `lib/features/company/widgets/reimbursements_tab.dart:26` | Who is owed what, per month, with Mark as paid |
| Accountant pack | `lib/features/company/widgets/accountant_pack_tab.dart:35` | The month's missing receipts with Remind driver, the month picker, and Build the pack with its progress line |
| Settings | `lib/features/company/widgets/company_settings_tab.dart:19` | The letterhead: name, OIB (eleven digits, digits only), address. The plan is read-only and named in the banner |

The rows are cards in the app's own idiom rather than data tables: they read
the same on the phone an admin happens to have in hand as on the desk the
console is built for. The handover sheet defaults its date to today, prefills
the reading from the car's current odometer once that resolves and never over
a typed value (`lib/features/company/widgets/handover_sheet.dart:77`), offers
"Nobody: the car comes back" as a recipient, and says "invite somebody and
make them a driver" when there is nobody to hand to.

**A failed read says so.** The console, the handover sheet, the driver's
member row, the pending-handovers card and the incidents and observations
cards on the car page render `failureMessage` when a read failed with nothing
cached, and progress while loading, rather than "Nobody" on every car with
nothing to report (`lib/features/company/widgets/drivers_and_cars_tab.dart:48`)
or a header over nothing (`lib/features/incidents/widgets/incidents_card.dart:63`).
The cache serves last-good rows on a network failure only, so a refusal or a
server error on a first load has nothing to fall back on, and the cause
reaches `failure_log` once per build. Every tab offers the fleet's Retry: the
Drivers and cars tab under its sentence
(`lib/features/company/widgets/drivers_and_cars_tab.dart:79`), since the log
and the members are kept alive and would otherwise wait for a resume or a
realtime event; the Reimbursements tab folds a failed names read into its
own state (`lib/features/company/widgets/reimbursements_tab.dart:43`) rather
than printing "Former member" on every line; and the Deadlines tab names the
five entry families the odometer series is built from
(`lib/features/company/widgets/deadlines_tab.dart:87`), which no bootstrap
refresh reaches and which, with retry off (decision 185), otherwise held a
first-load timeout for the session. The one exception is the missing-receipts
card on the Costs tab, which renders nothing when its read failed
(`lib/features/company/widgets/missing_receipts_card.dart:42`): it reads the
car's own lists, and the Costs list directly beneath it says the sentence,
so a second one would repeat it.

## Fleet deadlines

`FleetDeadlines.of` (`lib/domain/company/fleet_deadlines.dart:57`) folds the
household's projections and every active car's papers into one list, soonest
first. The admin's month is about what must happen, so the statutory items —
registration, the technical and the periodic inspection, the tachograph, the
tyre window (`lib/domain/company/fleet_deadlines.dart:49`) — always appear,
and an ordinary service only when it falls no later than the car's next
inspection; the rest is the car page's business until then. A registration
written both as a paper and as a rule is one date, the earlier, because that
is the one that binds. A paper reaches the fold through the one seam that
makes it a reminder, `DocumentType.serviceTypeKey`, gated by the statutory
kinds: an insurance paper's expiry still arrives, as the one-off rule the
document sheet syncs at that date, filed among the services. Row keys carry
the due date, because a one-off and a recurring rule of one type are two
rows. `thisMonth` (`lib/domain/company/fleet_deadlines.dart:146`) is the
calendar month plus everything overdue, which heads the list. The provider
reads the papers of active cars only, concurrently
(`lib/features/company/providers/deadline_providers.dart:11`); its Retry
invalidates the leaves — rules, services and papers — not just the aggregate,
which would re-await whichever leaf still caches the error.

Two service types came with the migration: the six-monthly periodic
inspection, statutory in Croatia for older and heavier vehicles, and the
tachograph calibration, which is not statutory for a car and is added where a
van carries one (`supabase/migrations/0080_company.sql:1566`).

## Money

`paid_with` on the three money tables — `company_card`, `company_cash`,
`own_money`, or null, the household default a private garage always has
(`supabase/migrations/0080_company.sql:1047`) — with `reimbursed_at` beside it.
The sheets ask through `PaidWithField`
(`lib/features/company/widgets/paid_with_field.dart:33`), which renders
nothing off the plan; `PaymentMethod` (`lib/domain/company/payment_method.dart:4`)
reads an unknown key as null rather than guessing, the rule every stored-key
enum follows. The backup carries `paid_with` and deliberately not
`reimbursed_at` (`lib/domain/export/garage_backup.dart:324`): the stamp is the
company's bookkeeping, and a restore writes through `add`.

**The stamp is the console's.** `guard_reimbursed_at`
(`supabase/migrations/0080_company.sql:1067`) refuses any change of
`reimbursed_at` by anybody but an admin of the car's garage, so the three row
mappers never send it (`lib/features/fuel/data/supabase_fuel_repository.dart:107`):
a driver's edit of their own entry would otherwise carry a stale stamp and
have the whole edit refused.

`MoneyEntries.of` (`lib/domain/company/money_entry.dart:53`) reduces the
three tables to one shape — when, which car, how much, how paid — leaving out
a fill-up with no total and a service with no cost, since there is nothing to
pay back and nothing a receipt could be for. `Reimbursements.outstanding`
(`lib/domain/company/reimbursements.dart:30`) sums own-money entries not yet
paid back, per driver per month, the driver resolved from the log on each
entry's date; a day with nobody is its own line, named as such and never
folded into somebody's total. The provider reads every car including the
archived ones (`lib/features/company/providers/reimbursement_providers.dart:14`):
an own-money fill-up on a car since sold is still owed to whoever paid it.
"Mark as paid" stamps one update per table
(`lib/features/company/providers/company_providers.dart:237`) and refreshes the
cars on the line whether or not every table took it, so a refusal part-way
leaves the line showing what is still owed rather than the full total.

**The household settlement is switched off for a fleet.** The settlement card
and its setting are hidden on the plan
(`lib/features/household/screens/household_screen.dart:661`,
`lib/features/settings/screens/settings_screen.dart:425`): drivers do not owe
the company; the company owes whoever paid out of their own pocket, which is
what the reimbursements are.

## Incidents

`incidents` (`supabase/migrations/0080_company.sql:982`): damage, a fault, a
fine or an accident, on a day, with a description, an optional reading and
amount, a status (`open`, `at_insurer`, `repaired`, `paid`, `closed`) and a
`resolved_on`. Photos go through `attachments` as the sixth kind,
`entry_kind = 'incident'` (`supabase/migrations/0080_company.sql:1036`), with
the same sweep on delete every other entry's receipts get (decision 129).
`lib/features/incidents/` mirrors the observations feature: a repository over
the read cache, a card on the Car tab
(`lib/features/incidents/widgets/incidents_card.dart:22`) with the driver line
under each row, a sheet (`lib/features/incidents/widgets/incident_sheet.dart:30`),
a menu per row for close, reopen, edit and delete. A driver reports on an
assigned car through their own menu; admins manage all. Realtime carries the
table (`lib/core/sync/realtime_sync.dart:62`): a dent reported from the
driver's phone is what the admin's console is looking at.

**Settling has one owner.** Two statuses are open — `open` and `at_insurer`,
somebody is still waiting — and three are the ways a report stops being
anybody's problem (`lib/domain/entities/incident.dart:38`); `isOpen` is read
off the status, and `resolvedOn` says since when. The sheet moves a report
between the open statuses and never writes `resolvedOn`; settling is the
card's act, `IncidentController.close(incident, status:)`, which writes the
word and the day together, and `reopen` clears both
(`lib/features/incidents/providers/incident_providers.dart:70`). So choosing
"With the insurer" leaves the incident open, a settled report shows its
status as text rather than offering to change it, and a settled report never
carries an open status nor an open one a day.

`Incidents.forDisplay` puts the open ones first, newest first — the one
reported yesterday is the one the admin is asked about — then the settled by
when they settled; `Incidents.forMechanic`
(`lib/domain/entities/incident.dart:150`) is what the handover sheet prints
beside the observations: open damage, faults and accidents, oldest first,
because the thing the car has lived with longest is the thing to mention at
the counter. A fine is the accountant's and is not printed
(`lib/features/reports/report_builder.dart:428`).

## Receipts and the pack

`MissingReceipts.inMonth` (`lib/domain/company/missing_receipts.dart:8`) lists
the month's money entries with nothing attached, oldest first — an entry for
nothing still wants its receipt. The car page's Costs tab leads with the
car's own list (`lib/features/company/widgets/missing_receipts_card.dart:28`),
read from the car's own three tables
(`lib/features/company/providers/receipt_providers.dart:30`) rather than the
fleet's, which on a thirty-car fleet was ninety requests for one tab, each row with
"Photo now", which opens the entry's own sheet — where the paperclip is —
rather than a second way to attach; the card renders nothing off the plan and
nothing in a clean month, and an entry deleted since the card was drawn opens
nothing rather than throwing. The row leaves the card once the photo is
attached: an upload or a delete in `EntryAttachments` invalidates the
attachments index beside the entry's own list, and viewing a file does not
(`lib/features/attachments/widgets/entry_attachments.dart:92`). The console's
Accountant pack tab (`lib/features/company/widgets/accountant_pack_tab.dart:35`)
shows the fleet's list for the chosen month, every car including the archived
ones, with the driver line under each row and "Remind driver" for an entry
whose day the log gives to a current member; a day with nobody, or a former
member, gets the sentence and no button
(`lib/features/company/widgets/accountant_pack_tab.dart:144`), because
`request_receipt_reminder()` refuses a non-member and a button that always
fails is worse than a row that says why. The two lists share one row widget
(`lib/features/company/widgets/missing_receipt_row.dart:11`), and the console
tabs share one Retry, `fleetRetry`
(`lib/features/company/widgets/fleet_retry.dart:13`), which invalidates the
bootstrap and the leaves named rather than the aggregate alone.

`CompanyController.remindDriver`
(`lib/features/company/providers/company_providers.dart:268`) calls
`request_receipt_reminder()` (`supabase/migrations/0080_company.sql:1169`),
which writes a `receipt_reminders` row and pokes the daily push function with
`{"only": "receipts"}`; that run sends one data-only push per row to the
driver's own phones and nothing else — see
[08](08-reminders-and-notifications.md#the-same-run-tells-the-webhooks). A row
per request rather than a push from the app, because the app holds nothing
that may send a push, and must not; a second request pushes again, and
nothing dedupes. The console says "reminder sent" once the request is
recorded, whether or not push is configured.

**The accountant pack** is one zip for a month, assembled by
`AccountantPackAssembly` (`lib/features/company/providers/pack_assembly.dart:37`)
and written by `buildAccountantPack`
(`lib/features/reports/accountant_pack.dart:45`). The assembly reads every
car's month, archived cars included — a car sold on the tenth has that
month's entries and the accountant wants them beside the rest, while an
archived car with nothing in the month gets no folder, since one empty folder
per car ever owned would be noise
(`lib/features/company/providers/pack_assembly.dart:55`) — keeps only the
money entries in the period, asks the attachment repository for the receipts
of the entries the index says have one, lists every receipt before
downloading any so the count is known, and downloads them one by one while
the tab shows "Fetching receipts, n of m" with the button disabled. Nothing is
saved until every byte is in hand: a download that fails is said and no
half-built pack reaches the accountant, and a pack finished after the tab was
left is let go rather than saved
(`lib/features/company/widgets/accountant_pack_tab.dart:256`). The zip holds
a folder per car — named by plate, falling back to the nickname, folded by
`vehicleSlug` and made unique by `uniqueName`
(`lib/domain/export/export_file_name.dart:65`), the helpers the data screen's
export shares — with the ledger PDF and every placeable receipt appended
after it in the ledger's order, the receipts as the files they were uploaded
as, named `<date>-<kind>-<amount>.<ext>` so a folder sorts by date and says
what each is, and the month's three spreadsheets with the same driver column
as the data screen's. Everything matches per car, because the tax office
samples per car, and an accountant wants each entry next to its receipt. The
ledger is `ReportKind.accountantPack`
(`lib/features/reports/report_builder.dart:772`): one row per money entry with
the driver of the day (`driverOf`, printing "Former member" for a driver the
list no longer names), how it was paid and whether a receipt exists, a total,
a footer, and the company's name and OIB from the console's Settings tab as
the letterhead. A receipt the PDF library cannot place — a PDF, a HEIC, an
undecodable file — travels in the archive and is left out of the ledger:
`_placeable` asks the library itself rather than the content type
(`lib/features/reports/report_builder.dart:920`). The month is picked from
this one and the five before it, and the file is named for the month inside,
`garage-accountant-pack-YYYY-MM.zip` (`ExportKind.pack` carries `byMonth`,
`lib/domain/export/export_file_name.dart:31`), which is what the accountant
files it under. The bytes come through `AttachmentRepository.download`
(`lib/features/attachments/data/attachment_repository.dart:36`), added for
this: a signed URL is a link, not bytes.

## Exports

Every entry spreadsheet ends in a `driver` column — `assigned_driver` on
trips, whose `driver` column is the typed name and stays where it is — and
the fuel, service and cost sheets carry `paid_with` after `notes`
(`lib/core/export/csv_export.dart:19`). The name is resolved by the caller
from the log and handed in as a `DriverOn` callback, so the file stays a
writer of rows; nothing passed means a blank column, which keeps the export's
shape the same on and off the plan, and the importer ignores a column it does
not know. On the plan the data screen resolves through `driverOf` with the
"Former member" word, so a day somebody the list no longer names had the car
does not read as a day nobody did
(`lib/features/settings/screens/data_screen.dart:113`), and offers a driver
chooser directly above the export row
(`lib/features/settings/screens/data_screen.dart:533`): the per-driver export
keeps only the entries whose day resolves to that person, on every entry
sheet, while tyres, documents and `vehicles.csv` are never filtered because
nothing on them happened on a day. The chooser is a device setting that
outlives switching garages, so the export applies it only when this garage's
member list contains the id and the chooser shows Everyone otherwise
(`lib/features/settings/screens/data_screen.dart:100`); the members are read
on the plan, not once the log has a window, so a company before its first
handover exports what its chooser says. A driver is not offered the chooser
and a stale choice is ignored for them: their rows are their own, and the
log they hold is their own windows, so any other pick would be empty
tables. A departed driver is not choosable:
their rows are reached by exporting everyone and filtering the `driver`
column on "Former member". The mileage logbook asks which driver after the
period, on the plan and never of a driver
(`lib/features/vehicles/screens/vehicle_detail_screen.dart:197`), through the
resolution rather than the typed name: the log says whose car it was, the
free text says who was at the wheel that day.

## Who is told

The daily reminder run tells every member of the garage but its drivers, plus
whoever `driver_on()` names for the due day, and only while that person is
still a member (`supabase/functions/push-due-reminders/handler.ts:928`). A
driver is a member whose role names their cars, so the member list alone would
tell every driver about every van. The same run carries the receipt
reminders. Both are in [08](08-reminders-and-notifications.md#the-same-run-tells-the-webhooks);
the device turns a receipt payload into words in its own language
(`lib/core/notifications/push_receipt_reminder.dart:10`).

## Testing this

The live suite's group `company: roles, assignments and drivers`
(`test_rls/rls_test.dart:6209`) is the test plan for every driver policy: a
positive and a negative case as the driver, the admin and a stranger, per
table, with every refusal asserting the code the database answered with; the
free cap on the insert, the unarchive, a redeemed transfer and a merge;
succession; the log, the handover, the sign-off guard in both directions, and
the sale; one case per storage policy; and every new table in the
account-deletion setup (decision 101). The resolution's fixture is read by the
same group and by `test/domain/company/assignment_resolution_test.dart`. A
screen test asks for a driver by name — `pumpScreen(role: 'driver')`, and
`household:` for a garage on the plan (`test/support/pump_screen.dart:152`) —
because every existing screen test was written as the garage's owner.
`test/support/driver_log.dart` builds the log and the names the sheets
resolve against.

## Sharp edges

- **A second handover on the same day is refused** (`P0006`). Under one
  driver per day there is no room for it; the admin strikes the wrong window
  from the log and hands over again.
- **A driver's "today" is UTC's.** `driver_vehicle_ids()` reads
  `current_date` (`supabase/migrations/0080_company.sql:711`), so a handover
  dated today reaches the phone once it is today in UTC — two hours late in
  Zagreb's summer.
- **Incidents are not queued offline.** Unlike an observation, a report made
  with no signal fails rather than waits
  (`lib/features/incidents/providers/incident_providers.dart:18`); a
  `PendingWriteKind` and a sender are the cost of changing that.
- **A departed driver's name cannot be read back.** The profiles policy hides
  a profile once its owner is no longer a co-member, so every reader prints a
  former member as such, through `memberNameOf`.
- **"A former member" flashes while the names load.** `driverNameOnProvider`
  answers `''` until the member list arrives
  (`lib/features/company/providers/company_providers.dart:171`), so a sheet
  or the incidents card reads "a former member" for the frames before it
  lands. The Reimbursements tab waits for the list instead.
- **The role flips from member to driver when the first bootstrap fetch
  lands.** `myRoleProvider` answers `member` until then, so on a cold open the
  title reads "Vehicles" before "My cars", the Company entry can show at the
  top of More, and the add-reminder and income rows can show on a car page
  for a moment.
- **A borrower on a pass sees "Report an incident"** on the car's Car tab
  (`lib/features/incidents/widgets/incidents_card.dart:52`); there is no
  guest policy on `incidents`, so the database refuses it with the permission
  sentence. Ruling 15's shape: recorded, not built.
- **The failure sentence repeats on every driver row of the members screen**
  when the log could not be read; once would do.
- **The tyres, documents and parts screens still offer a driver their add
  buttons.** The policy refuses and the sheet says so; the buttons are wrong,
  not silent.
- **A driver's edit of an entry they did not write is refused, not
  silent.** Their update and delete policies are per author while their
  select policy is per car (`supabase/migrations/0080_company.sql:1253`), and
  PostgREST answers a write RLS filters away with 204 and zero rows rather
  than `42501`. So every entry write a driver can reach — fuel, service,
  cost, odometer, trip (a drive finished or abandoned included), observation
  and incident, and with them a receipt's delete and the garage's settings
  row — ends in `.select('id')` and hands the answer to
  `refusedIfNone` (`lib/core/supabase/refused_if_none.dart:20`), which
  throws the permission failure on an empty list; the sheet then stays open
  and says so. Inserts are left alone: a refused insert is a real `42501`.
  Decision 186; the cost is in
  [known-bugs](../operations/known-bugs-and-risks.md#an-empty-answer-to-a-filtered-entry-write-reads-as-a-refusal):
  a row deleted from another phone a moment earlier reads the same way.
- **A driver's service entry leaves its one-off reminder open.** The
  tables with no driver write policy — papers, tyres, parts, routes,
  intervals — answer an update or a delete with zero rows and 204 exactly as
  the per-author policy does, only an insert being a real `42501`, so every
  write a driver's screens offer on them reads its row back as the entries
  do. The one exception is on purpose: `completeOneTimeRules` runs after the
  service entry has landed, and a refusal there would report a failure over
  an entry that was saved, so the rule stays open until an admin logs or
  completes it. A driver update policy on `reminder_rules` is the fix; in
  [known-bugs](../operations/known-bugs-and-risks.md#a-drivers-service-entry-leaves-its-one-off-reminder-open).
- **The plan is set by SQL until billing ships** (Stage 3). `update
  households set plan = 'company' where id = …` as the service role.
- **A receipt reminder needs push configured.** Without the Vault secrets the
  poke returns quietly (`supabase/migrations/0080_company.sql:1150`) and the
  row waits for the first run that has them.
- **`paid_with` is not in the public API.** The read-only API selects its
  columns by name (`supabase/functions/public-api/handler.ts:138`) and was not
  taught the new one.
- **The bottom tab under "My cars" still says "Vehicles".** Both navigation
  widgets take one-word labels by test, and "My cars" is two in every
  language; an open question for the owner.
