-- What is this code?
--
-- Three kinds of eight-character code exist — a garage invite, a vehicle
-- transfer, a lending pass — and the person holding one has no way to tell
-- them apart. Three separate "enter your code" screens made that the user's
-- problem; this makes it the app's.
--
-- Says what the code *is* without spending it. Redeeming is still the
-- separate, deliberate act, and the app can now say what that act will do
-- before somebody agrees to it.
--
-- What it discloses, to somebody who already holds the code: the kind, the
-- nickname of the car or the name of the garage, and when it stops working.
-- No identifiers, no history, nothing about the owner. A wrong guess gets
-- null, and guessing is the same 36^8 as redeeming blind.
create function public.describe_code(candidate text)
returns jsonb
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  wanted text := upper(trim(candidate));
  found record;
begin
  if wanted is null or char_length(wanted) <> 8 then
    return null;
  end if;

  select 'lending' as kind, v.nickname as subject, p.expires_at as until,
         p.revoked_at is not null or now() >= p.expires_at
           or (p.redeemed_by is not null
               and p.redeemed_by <> (select auth.uid())) as spent
    into found
  from public.vehicle_guest_passes p
  join public.vehicles v on v.id = p.vehicle_id
  where p.code = wanted;

  if found is null then
    select 'transfer' as kind, v.nickname as subject, t.expires_at as until,
           t.redeemed_at is not null or now() >= t.expires_at as spent
      into found
    from public.vehicle_transfers t
    join public.vehicles v on v.id = t.vehicle_id
    where t.code = wanted;
  end if;

  if found is null then
    select 'invite' as kind, h.name as subject, i.expires_at as until,
           i.redeemed_at is not null or now() >= i.expires_at as spent
      into found
    from public.invites i
    join public.households h on h.id = i.household_id
    where i.code = wanted;
  end if;

  if found is null then
    return null;
  end if;

  return jsonb_build_object(
    'kind', found.kind,
    'subject', found.subject,
    'until', found.until,
    'spent', found.spent
  );
end;
$$;

revoke execute on function public.describe_code(text) from public;
grant execute on function public.describe_code(text) to authenticated;
