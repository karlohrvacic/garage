-- Redeeming a code while already a member used to burn it: the membership
-- insert no-opped but the invite was still marked redeemed, wasting a code the
-- household meant for someone else. Only a join that actually added a row
-- consumes the invite.
create or replace function public.join_household_with_code(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  invite public.invites;
  caller uuid := (select auth.uid());
  joined boolean;
begin
  if caller is null then
    raise exception 'authentication required';
  end if;

  select * into invite
  from public.invites
  where code = upper(trim(invite_code))
  for update;

  if invite is null then
    raise exception 'invalid invite code' using errcode = 'P0002';
  end if;
  if invite.expires_at < now() then
    raise exception 'invite code has expired' using errcode = 'P0003';
  end if;
  if invite.redeemed_at is not null then
    raise exception 'invite code has already been used' using errcode = 'P0004';
  end if;

  insert into public.household_members (household_id, user_id, role)
  values (invite.household_id, caller, 'member')
  on conflict (household_id, user_id) do nothing;
  joined := found;

  if joined then
    update public.invites
    set redeemed_at = now(), redeemed_by = caller
    where id = invite.id;
  end if;

  return invite.household_id;
end;
$$;
