-- Provenance hardening.
--
-- The UPDATE policies on vehicles / fuel_entries / service_entries can gate
-- *which rows* a member may change, but an RLS WITH CHECK cannot see the old
-- row, so it cannot stop a member from rewriting `created_by` to point at
-- another user. A BEFORE UPDATE trigger pins it: the attribution of a row never
-- changes after insert. This is a no-op for the app (its update paths never
-- send created_by) and blocks a crafted client from forging authorship.
create function public.pin_created_by()
returns trigger
language plpgsql
as $$
begin
  new.created_by := old.created_by;
  return new;
end;
$$;

create trigger vehicles_pin_created_by
  before update on public.vehicles
  for each row execute function public.pin_created_by();

create trigger fuel_entries_pin_created_by
  before update on public.fuel_entries
  for each row execute function public.pin_created_by();

create trigger service_entries_pin_created_by
  before update on public.service_entries
  for each row execute function public.pin_created_by();

-- The storage update policy relied on Postgres falling back to the USING
-- expression for its WITH CHECK. State it explicitly so "you cannot move an
-- object into another household" is guaranteed by the policy, not by a default.
drop policy if exists vehicle_photos_update on storage.objects;
create policy vehicle_photos_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'vehicle-photos'
    and ((storage.foldername(name))[1])::uuid in (select public.user_household_ids())
  )
  with check (
    bucket_id = 'vehicle-photos'
    and ((storage.foldername(name))[1])::uuid in (select public.user_household_ids())
  );
