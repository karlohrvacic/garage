-- The paperwork a car needs to be on the road, and the dates it stops being
-- valid.
--
-- The app tracked money and work and knew nothing about paper. A registration
-- certificate, a roadworthiness certificate, a liability policy and a green
-- card each have an expiry, and missing one costs a fine or a refused claim —
-- which is a larger and more certain loss than any of the maintenance the app
-- was already careful about.
--
-- Reminders and cost entries covered part of this by accident: paying for a
-- registration raised a one-off rule dated a year on. That is the *payment*,
-- not the document, and it says nothing about a policy bought mid-year, a
-- certificate whose date does not match the payment, or a green card nobody
-- pays for separately at all. A document carries its own expiry and raises
-- its own reminder from it.
--
-- One row per vehicle per type, enforced below. A car has one current
-- registration certificate; renewing it is a new expiry on the same row, not
-- a second row. The history of what was paid, and when, stays in
-- `cost_entries`, which is where it always was.
--
-- Not modelled here: a driving licence. It belongs to a person rather than to
-- a car, and both this table and the attachments bucket are scoped by
-- vehicle — filing one household member's licence against whichever car they
-- happen to drive would be a wrong answer that looks like a right one.
create table public.vehicle_documents (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  -- Language-neutral, localized client-side, like every other key in this
  -- schema.
  doc_type text not null check (doc_type in (
    'registration',
    'roadworthiness',
    'insurance_liability',
    'insurance_comprehensive',
    'green_card',
    'other'
  )),
  -- What is written on the paper. All optional: a household that records only
  -- "the registration runs out on 3 June" has recorded the thing that matters.
  label text check (label is null or char_length(label) between 1 and 60),
  number text check (number is null or char_length(number) <= 60),
  issuer text check (issuer is null or char_length(issuer) <= 80),
  issued_on date,
  expires_on date,
  notes text,
  -- Nullable, `set null`, for the reason `0033` spells out at length: a
  -- `not null` reference with the default `no action` refuses to let the user
  -- it points at be deleted, and `delete-account` relies entirely on the
  -- cascade. `0033` was a one-shot pass over the constraints that existed
  -- then, so a table added afterwards has to get this right on its own or it
  -- breaks in-app account deletion again — silently, and only for a *shared*
  -- garage, which is the case a solo test never reaches.
  --
  -- Attribution is what is lost when a member leaves, and attribution is the
  -- part that stops being true anyway. The document belongs to the household.
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  -- A document that expired before it was issued is a typo, and the two dates
  -- are the whole point of the row.
  constraint vehicle_documents_dates_ordered
    check (issued_on is null or expires_on is null or expires_on >= issued_on)
);

create index vehicle_documents_vehicle_idx
  on public.vehicle_documents (vehicle_id, expires_on);

-- One of each kind per car. `other` is exempt: it is the escape hatch for
-- everything this list does not name, and capping it at one would make it
-- useless the second time somebody needed it.
create unique index vehicle_documents_one_per_type
  on public.vehicle_documents (vehicle_id, doc_type)
  where doc_type <> 'other';

alter table public.vehicle_documents enable row level security;

create policy vehicle_documents_select on public.vehicle_documents
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy vehicle_documents_insert on public.vehicle_documents
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy vehicle_documents_update on public.vehicle_documents
  for update to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()))
  with check (vehicle_id in (select public.user_vehicle_ids()));

create policy vehicle_documents_delete on public.vehicle_documents
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

grant select, insert, update, delete on public.vehicle_documents
  to authenticated;

alter publication supabase_realtime add table public.vehicle_documents;

-- FULL, for the reason 0042 spells out: a DELETE's old tuple otherwise
-- carries only the primary key, and the client cannot read `vehicle_id` to
-- know which list to refresh — so a document deleted on a phone stays on
-- screen on the laptop, silently.
alter table public.vehicle_documents replica identity full;

-- A photo of the paper is the other half of this feature: the point of
-- recording a green card is being able to show it at a border.
alter table public.attachments
  drop constraint attachments_entry_kind_check;
alter table public.attachments
  add constraint attachments_entry_kind_check
  check (entry_kind in ('fuel', 'service', 'cost', 'document'));

-- A green card has no service type to come due as, so it gets one. Not
-- statutory in the catalogue sense — it is a certificate of cover rather than
-- a national obligation — and not country-scoped, since it exists precisely
-- for driving outside the country that issued the policy.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months,
   is_statutory, country_code)
values
  (null, 'service_green_card', null, 12, false, null)
on conflict do nothing;
