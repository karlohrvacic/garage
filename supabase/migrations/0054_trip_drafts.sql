-- A drive you start now and finish later.
--
-- Logging a journey after the fact means remembering when it began and what
-- the odometer said, which is exactly what nobody remembers. So a drive can be
-- opened at the moment it starts — the clock is read for you, the odometer is
-- one number you can see from the driver's seat — and completed when you park.
--
-- **A draft is a trip whose distance is not known yet**, and that is the whole
-- state machine: `distance_km is null` means in progress, and filling it in is
-- what finishes the drive. No status column, no second table, and no backfill —
-- every existing row already has a distance, so nothing already logged becomes
-- a draft.
--
-- This is deliberately not GPS. Background location detection is an explicit
-- non-goal (docs/roadmap.md): it drains a battery and needs a permission people
-- reasonably refuse, and two taps around a journey get most of the value.

alter table public.trip_entries
  alter column distance_km drop not null;

-- When the drive began. Set by the app from the device clock at the moment the
-- draft is opened, and kept after the trip is finished: "left at 07:12" is part
-- of the record a logbook is asked for, not scaffolding for the draft.
alter table public.trip_entries
  add column started_at timestamptz;

-- The only row allowed to have no distance is one that is still under way, and
-- a drive under way must know when it began. Together these make the draft
-- state impossible to enter by accident: a plain insert that forgets the
-- distance is rejected rather than quietly becoming an open drive.
alter table public.trip_entries
  add constraint trip_draft_is_started check (
    distance_km is not null or started_at is not null
  );

-- One open drive per car. A vehicle cannot be on two journeys at once, and
-- without this a second tap on "Start drive" — or two members starting one on
-- the same car — leaves two drafts, of which finishing either looks like the
-- app lost the other.
create unique index trip_entries_one_open_draft_per_vehicle
  on public.trip_entries (vehicle_id)
  where distance_km is null;

-- Finding a car's open drive is a lookup the trip screen does on every visit.
create index trip_entries_open_drafts_idx
  on public.trip_entries (vehicle_id, started_at desc)
  where distance_km is null;
