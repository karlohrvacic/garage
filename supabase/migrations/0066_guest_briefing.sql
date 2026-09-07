-- What somebody holding your car can see without being told anything else.
--
-- Reported: a borrower saw the vehicle's *baseline* odometer, because they
-- cannot read `odometer_entries` or `fuel_entries` and the app fell back to
-- the stored figure. A stale reading presented as the current one is worse
-- than none: it is the number they will write down at a pump.
--
-- The same argument as `guest_service_history` in 0064 — Postgres has no
-- column masking, so this cannot be a narrower row grant. Everything a
-- borrower always sees comes back from one function, which decides field by
-- field, and no new rows are granted anywhere.
--
-- The set is deliberate: how far it has gone, the papers that matter if they
-- are stopped or in a crash, what is known to be wrong with it, and what it
-- is standing on. No money, no numbers, no notes, no history.
create function public.guest_vehicle_briefing(target_vehicle uuid)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  allowed boolean;
  reading int;
  papers jsonb;
  problems jsonb;
  tyres jsonb;
begin
  select
    target_vehicle in (select public.user_vehicle_ids())
    or target_vehicle in (select public.guest_vehicle_ids('vehicle'))
  into allowed;

  if not allowed then
    -- Not an error: a pass that expired mid-session asks this question once
    -- more on its way out, and an exception there reads as a broken app
    -- rather than as an ended loan.
    return null;
  end if;

  -- The furthest reading anybody has logged, whichever table it came from.
  -- A borrower's own fill-up counts: it is the most recent thing that
  -- happened to the car and they are the one it happened to.
  select max(km) into reading from (
    select max(odometer_km) as km from public.odometer_entries
      where vehicle_id = target_vehicle
    union all
    select max(odometer_km) from public.fuel_entries
      where vehicle_id = target_vehicle
    union all
    select max(odometer_km) from public.service_entries
      where vehicle_id = target_vehicle
    union all
    select max(end_odometer_km) from public.trip_entries
      where vehicle_id = target_vehicle
  ) readings;

  -- Type and expiry only. A green card's number and issuer are the owner's
  -- business; that it runs out on the third of March is the borrower's.
  select coalesce(
    jsonb_agg(
      jsonb_build_object('type', doc_type, 'expires_on', expires_on)
      order by expires_on
    ),
    '[]'::jsonb
  )
  into papers
  from public.vehicle_documents
  where vehicle_id = target_vehicle
    and expires_on is not null
    and doc_type in (
      'insurance_liability', 'insurance_comprehensive',
      'green_card', 'roadworthiness'
    );

  -- What is known to be wrong with it, still open. The rattle you are about
  -- to hear is not a surprise anybody benefits from.
  select coalesce(
    jsonb_agg(
      jsonb_build_object('note', note, 'noticed_on', noticed_on)
      order by noticed_on
    ),
    '[]'::jsonb
  )
  into problems
  from public.observations
  where vehicle_id = target_vehicle and resolved_on is null;

  select coalesce(
    jsonb_agg(jsonb_build_object('season', season, 'fitted_on', fitted_at)),
    '[]'::jsonb
  )
  into tyres
  from public.tyre_sets
  where vehicle_id = target_vehicle and fitted is true;

  return jsonb_build_object(
    'odometer_km', reading,
    'documents', papers,
    'problems', problems,
    'tyres', tyres
  );
end;
$$;

revoke execute on function public.guest_vehicle_briefing(uuid) from public;
grant execute on function public.guest_vehicle_briefing(uuid) to authenticated;
