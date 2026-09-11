-- An invite link opened by somebody already in the garage it is for.
--
-- join_household_with_code accepts that join and changes nothing — deliberately,
-- so the invite is not consumed (0010) — and the app then said "You are in"
-- for a second time. The screen now asks first. This adds `member` to what
-- describe_code says about an invite: whether the caller is already in that
-- garage. It says nothing about anybody else's membership, and nothing at all
-- for the other two kinds of code.
--
-- Same signature as 0067, so this replaces rather than overloads (see decision
-- 113 for the trap).
create or replace function public.describe_code(candidate text)
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
               and p.redeemed_by <> (select auth.uid())) as spent,
         false as member
    into found
  from public.vehicle_guest_passes p
  join public.vehicles v on v.id = p.vehicle_id
  where p.code = wanted;

  if found is null then
    select 'transfer' as kind, v.nickname as subject, t.expires_at as until,
           t.redeemed_at is not null or now() >= t.expires_at as spent,
           false as member
      into found
    from public.vehicle_transfers t
    join public.vehicles v on v.id = t.vehicle_id
    where t.code = wanted;
  end if;

  if found is null then
    select 'invite' as kind, h.name as subject, i.expires_at as until,
           i.redeemed_at is not null or now() >= i.expires_at as spent,
           exists (
             select 1 from public.household_members m
             where m.household_id = i.household_id
               and m.user_id = (select auth.uid())
           ) as member
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
    'spent', found.spent,
    'member', found.member
  );
end;
$$;
