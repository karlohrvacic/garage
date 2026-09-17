-- A merge carries the absorbed garage's named routes.
--
-- Routes are scoped to a garage and cascade with it (0061). `merge_households`
-- was written before they existed (0057): it moved the vehicles, the members
-- and the custom service types, then deleted the absorbed garage, and the
-- routes went with the delete. The trips survived with `route_id` set to null,
-- so a commute's whole trend started again from nothing, in an operation the
-- screen says cannot be undone.
--
-- `test/ci/merge_covers_garage_tables_test.dart` now reads the migrations for
-- every table with a foreign key to `households` and fails unless this
-- function mentions it or the test lists why it is left to the cascade, which
-- is what would have caught this the day routes were added.
--
-- Rows a merge has already destroyed cannot be brought back by a migration.
--
-- The function is otherwise 0057's, word for word.

create or replace function public.merge_households(
  absorbed_household uuid,
  surviving_household uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  caller uuid := (select auth.uid());
  absorbed public.households;
  surviving public.households;
  vehicles_moved int;
  members_moved int;
  keys_revoked int;
begin
  if caller is null then
    raise exception 'authentication required';
  end if;

  if absorbed_household = surviving_household then
    raise exception 'a garage cannot be merged into itself';
  end if;

  -- Admin of both. The strictest rule that still lets the case happen, and the
  -- easiest to explain: a merge is irreversible and takes every vehicle and
  -- every entry with it, so being merely a member of the garage being
  -- dissolved is not enough.
  if not public.is_household_admin(absorbed_household)
    or not public.is_household_admin(surviving_household) then
    raise exception 'you must be an admin of both garages';
  end if;

  select * into absorbed from public.households
  where id = absorbed_household for update;
  select * into surviving from public.households
  where id = surviving_household for update;

  if absorbed.id is null or surviving.id is null then
    raise exception 'no such garage';
  end if;

  -- Money is stored as a bare number; the currency lives on the garage. Merging
  -- across currencies would silently reinterpret every amount in the absorbed
  -- garage's history — a 12,000 HRK repair reading as €12,000. Distances and
  -- volumes are safe, because those are stored canonical.
  --
  -- Refused rather than converted: one rate applied across years of history is
  -- wrong in a quieter way than refusing is.
  if absorbed.currency_code <> surviving.currency_code then
    raise exception 'the two garages keep their money in different currencies (% and %)',
      absorbed.currency_code, surviving.currency_code;
  end if;

  -- Vehicles first, and everything keyed to a vehicle comes with them: fuel,
  -- services, costs, income, trips, odometer readings, tyre sets, documents,
  -- reminder rules, attachments and any guest pass already handed out.
  update public.vehicles
  set household_id = surviving_household
  where household_id = absorbed_household;
  get diagnostics vehicles_moved = row_count;

  -- The people, keeping the role they had. Without this their names stop
  -- resolving on entries they wrote — a profile is only visible to fellow
  -- members — so the history would survive with its authorship unreadable.
  insert into public.household_members (household_id, user_id, role, joined_at)
  select surviving_household, m.user_id, m.role, m.joined_at
  from public.household_members m
  where m.household_id = absorbed_household
  on conflict (household_id, user_id) do nothing;
  get diagnostics members_moved = row_count;

  -- Custom service types, minus any the surviving garage already defines under
  -- the same key. Both garages having their own `service_cambelt` is ordinary.
  update public.service_types s
  set household_id = surviving_household
  where s.household_id = absorbed_household
    and not exists (
      select 1 from public.service_types existing
      where existing.household_id = surviving_household
        and existing.key = s.key
    );

  -- Named routes belong to the garage, not to a car, so moving the vehicles
  -- does not move them. Where the surviving garage already has a route of the
  -- same name the absorbed one folds into it: `routes_unique_name` allows one
  -- per garage whatever the case, and two garages that both named "Home to
  -- work" meant the same drive. Its journeys are repointed first, because the
  -- folded route is about to be deleted with its garage and `route_id` is
  -- `on delete set null`.
  update public.trip_entries t
  set route_id = kept.id
  from public.routes folded
  join public.routes kept
    on kept.household_id = surviving_household
   and lower(kept.name) = lower(folded.name)
  where folded.household_id = absorbed_household
    and t.route_id = folded.id;

  update public.routes r
  set household_id = surviving_household
  where r.household_id = absorbed_household
    and not exists (
      select 1 from public.routes existing
      where existing.household_id = surviving_household
        and lower(existing.name) = lower(r.name)
    );

  select count(*) into keys_revoked from public.api_keys
  where household_id = absorbed_household;

  -- Everything still pointing at the absorbed garage goes with it, by cascade:
  -- its membership rows (already copied), its outstanding invites and vehicle
  -- transfer offers (which would otherwise admit somebody to, or offer a car
  -- from, a garage that no longer exists), its remaining duplicate service
  -- types and routes, and its API keys and webhooks.
  --
  -- Keys are revoked rather than moved on purpose. A key minted to read one
  -- garage would, after the merge, read every car in the combined one — a
  -- widening of a live credential that nobody asked for. Breaking a script
  -- loudly beats broadening it quietly.
  delete from public.households where id = absorbed_household;

  return jsonb_build_object(
    'vehicles_moved', vehicles_moved,
    'members_moved', members_moved,
    'keys_revoked', keys_revoked
  );
end;
$$;

revoke execute on function public.merge_households(uuid, uuid) from public;
grant execute on function public.merge_households(uuid, uuid) to authenticated;
