-- A garage must never be left without an admin.
--
-- The creator of a garage is its admin, and that was the only way to become
-- one. So when the admin left — or deleted their account, which removes their
-- membership — the garage survived with its cars and its whole history, and
-- nobody who could rename it, remove a member, or delete it. There was no
-- route out of that state: the remaining member could not promote themselves,
-- and the person who could promote them was gone.
--
-- The case is ordinary rather than exotic. Two people share a garage; one of
-- them created it; that one leaves. A couple, a household, a pair of
-- housemates. It is also the shape of every account deletion.
--
-- **The longest-standing remaining member is promoted.** Not the newest: the
-- person who has been in the garage longest is the one with the most history
-- in it, and on the common two-person garage there is only one candidate
-- anyway. `user_id` breaks a tie so the outcome is deterministic rather than
-- whatever the planner returned first.

create function public.ensure_household_has_admin(target_household uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nothing to do when an admin is still there, and nothing to do for a
  -- household that has just been emptied — `household_members_cleanup`
  -- removes those, and repopulating one mid-teardown would resurrect a row
  -- the trigger before this one deliberately deleted.
  if exists (
    select 1 from public.household_members
    where household_id = target_household and role = 'admin'
  ) or not exists (
    select 1 from public.household_members
    where household_id = target_household
  ) then
    return;
  end if;

  update public.household_members
  set role = 'admin'
  where (household_id, user_id) = (
    select household_id, user_id from public.household_members
    where household_id = target_household
    order by joined_at, user_id
    limit 1
  );
end;
$$;

revoke execute on function public.ensure_household_has_admin(uuid) from public;

-- Named to sort after `household_members_cleanup`: Postgres fires triggers on
-- the same event in name order, and the cleanup has to have its say about an
-- emptied household before this one looks at it.
create function public.promote_after_member_left()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_household_has_admin(old.household_id);
  return old;
end;
$$;

create trigger household_members_succession
after delete on public.household_members
for each row execute function public.promote_after_member_left();

-- The other way to leave a garage adminless: the only admin demoting
-- themselves. The grants allow a member row to be updated, so this is
-- reachable without any new UI.
create function public.promote_after_role_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_household_has_admin(new.household_id);
  return new;
end;
$$;

create trigger household_members_succession_on_demote
after update of role on public.household_members
for each row execute function public.promote_after_role_changed();

-- Existing garages that are already stranded. This is the whole reason the fix
-- cannot be code alone: the households that lost their admin before today
-- cannot recover on their own, and no future event will fire for them.
do $$
declare
  stranded uuid;
begin
  for stranded in
    select h.id from public.households h
    where exists (
      select 1 from public.household_members m where m.household_id = h.id
    )
    and not exists (
      select 1 from public.household_members m
      where m.household_id = h.id and m.role = 'admin'
    )
  loop
    perform public.ensure_household_has_admin(stranded);
  end loop;
end;
$$;
