-- Giving a car back.
--
-- A pass could be withdrawn by the owner and could expire on its own, and the
-- person actually holding the car had no way to end it: the loan sat in their
-- garage until the clock ran out, and a car returned on Sunday stayed
-- borrowable until Wednesday. Handing the keys back is the borrower's act, and
-- it was the only one of the three the app could not express.
--
-- Distinct from `revoked_at` on purpose, the same way that is distinct from
-- expiry: three different things happened, and "who ended this and when" is
-- worth more than one nullable timestamp that means whichever.
alter table public.vehicle_guest_passes
  add column returned_at timestamptz;

-- Access ends the moment it is stamped, on the same clock as everything else.
create or replace function public.guest_vehicle_ids(permission text)
returns setof uuid
language sql
security definer
stable
set search_path = public
as $$
  select vehicle_id from public.vehicle_guest_passes
  where redeemed_by = (select auth.uid())
    and revoked_at is null
    and returned_at is null
    and now() < expires_at
    and (starts_at is null or now() >= starts_at)
    and case permission
      when 'fuel' then can_log_fuel
      when 'trips' then can_log_trips
      when 'costs' then can_log_costs
      when 'history' then can_view_history and can_view_prices
      when 'history_masked' then can_view_history and not can_view_prices
      when 'vehicle' then true
      else false
    end
$$;

-- The holder's own act, so it cannot go through the table's update policy —
-- that one belongs to the garage. A definer function, keyed on being the
-- person who redeemed it.
create function public.return_guest_pass(pass_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.vehicle_guest_passes
  set returned_at = now()
  where id = pass_id
    and redeemed_by = (select auth.uid())
    and returned_at is null;

  if not found then
    raise exception 'no pass of yours to give back';
  end if;
end;
$$;

revoke execute on function public.return_guest_pass(uuid) from public;
grant execute on function public.return_guest_pass(uuid) to authenticated;
