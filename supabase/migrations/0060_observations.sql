-- Things a driver noticed and has not settled: a rattle at the front when the
-- engine is cold, a vibration since a pothole, a warning light that came on
-- once.
--
-- The app recorded money and work and had nowhere to put a *symptom*. A
-- service entry has notes, but a note on a service is a record of a visit that
-- happened; the interesting thing is the one nobody has been to the garage
-- about yet, because that is what you are trying to remember at the counter.
--
-- **One table, not three.** A driving event ("hit a pothole, now it vibrates"),
-- a symptom and a note for the mechanic are the same thing described three
-- ways: something a person noticed, at a date, at a mileage. The only real
-- difference is whether it is still open, so a second "events" table would
-- have been the same columns under another name and two lists to fill in.
--
-- `trip_id` is what makes an event an event: an observation that happened on a
-- journey points at it, and one noticed in a car park does not. `set null`
-- rather than cascade — deleting the trip should not delete the fact that
-- something started rattling on it.
create table public.observations (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  trip_id uuid references public.trip_entries (id) on delete set null,
  noticed_on date not null,
  odometer_km int check (odometer_km is null or odometer_km >= 0),
  note text not null check (char_length(note) between 1 and 2000),

  -- **Two fields, and the split is the whole point.**
  --
  -- `addressed_by` records that a mechanic did work about this. `resolved_on`
  -- records that the noise actually stopped. A repair that did not fix it
  -- leaves the first set and the second null, which is exactly the row worth
  -- putting at the top of the next handover sheet — and the distinction a
  -- single "done" flag would have thrown away.
  addressed_by uuid references public.service_entries (id) on delete set null,
  resolved_on date,

  -- Nullable and `set null`, for the reason 0033 gives and 0059 had to give
  -- again: a `not null` reference with the default `no action` refuses to let
  -- the user be deleted, and in-app account deletion is a Play requirement.
  -- The observation belongs to the vehicle, not to whoever typed it.
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),

  -- Noticing something after it was fixed is a typo.
  constraint observation_resolved_after_noticed
    check (resolved_on is null or resolved_on >= noticed_on)
);

create index observations_vehicle_idx
  on public.observations (vehicle_id, noticed_on desc);

-- The list the vehicle page and the handover sheet both want first.
create index observations_open_idx
  on public.observations (vehicle_id, noticed_on desc)
  where resolved_on is null;

alter table public.observations enable row level security;

create policy observations_select on public.observations
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy observations_insert on public.observations
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy observations_update on public.observations
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy observations_delete on public.observations
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

-- Deliberately no guest policy. A borrower noticing a rattle is genuinely
-- useful and it is a *permission* question — which the guest pass would need a
-- new column for — so it is left out rather than guessed at. Members only.

grant select, insert, update, delete on public.observations to authenticated;

-- Authorship cannot be rewritten by an update, and `pin_created_by` already
-- allows the one exception 0033 identified: the null that arrives when the
-- user it pointed at has been deleted.
create trigger observations_pin_created_by
  before update on public.observations
  for each row execute function public.pin_created_by();

-- A photo of what is wrong, or of the warning light. Audio is deliberately not
-- enabled yet: the plumbing would carry it, but `Attachment.isImage` handles
-- only pictures, so playback is real work for a recording of a rattle that is
-- charming and rarely diagnostic.
alter table public.attachments
  drop constraint attachments_entry_kind_check;
alter table public.attachments
  add constraint attachments_entry_kind_check
  check (entry_kind in ('fuel', 'service', 'cost', 'document', 'observation'));
