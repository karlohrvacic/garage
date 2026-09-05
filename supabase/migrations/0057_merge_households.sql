-- Two garages becoming one.
--
-- People marry, move in together, or simply started with a garage each before
-- realising they wanted one. Until now the only route was manual: invite the
-- other person, transfer each car with a code, then leave the old garage and
-- let it delete itself. That works, and it loses every vehicle photo (a
-- transfer nulls `photo_path` because the file sits under the old garage's
-- storage prefix), leaves the old garage's custom service types behind, and
-- takes one code per car.
--
-- **A merge is an absorption, not a marriage of equals.** One garage survives
-- with its own settings and the other is emptied into it and deleted. There is
-- no third garage, because a new one would leave both originals to be cleaned
-- up and doubles the number of things that can half-happen.
--
-- Irreversible by nature: once the vehicles have moved and the old garage is
-- gone, nothing records which car came from where.

create function public.merge_households(
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

  select count(*) into keys_revoked from public.api_keys
  where household_id = absorbed_household;

  -- Everything still pointing at the absorbed garage goes with it, by cascade:
  -- its membership rows (already copied), its outstanding invites and vehicle
  -- transfer offers (which would otherwise admit somebody to, or offer a car
  -- from, a garage that no longer exists), its remaining duplicate service
  -- types, and its API keys and webhooks.
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
