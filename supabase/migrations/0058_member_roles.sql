-- A garage can have more than one admin.
--
-- Creating a garage made you its admin and there was no UPDATE policy on
-- `household_members` at all, so the role could never change afterwards. A
-- couple who share a garage had one of them permanently in charge of it and
-- the other permanently not, with no way to even things up — and because
-- PostgREST reports a row that RLS filtered out as *zero rows updated* rather
-- than as an error, an app that tried would have looked like it worked and
-- silently changed nothing.
--
-- The shape people actually want is two parents as admins and a teenager as a
-- member who can log fuel but cannot delete the garage.

-- Admins may change roles in their own garage. Both clauses name the same
-- garage, so a row cannot be updated out of the household it belongs to, and
-- the `check` constraint on the column still limits the value to admin/member.
create policy members_update_by_admin on public.household_members
  for update to authenticated
  using (public.is_household_admin(household_id))
  with check (public.is_household_admin(household_id));

-- Stepping down has to actually step down.
--
-- The succession rule from 0056 promotes the longest-standing member, and the
-- admin who has just demoted themselves is usually exactly that — they created
-- the garage. So the trigger fired on their own demotion and handed the role
-- straight back, making "step down" a no-op with no error.
--
-- Whoever gave the role up is now excluded from inheriting it, unless there is
-- nobody else at all, in which case they keep it: a garage with one member
-- cannot be adminless, and refusing the update instead would leave a solitary
-- owner unable to do anything about it.
create or replace function public.ensure_household_has_admin(
  target_household uuid,
  stepping_down uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
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
      and (stepping_down is null or user_id <> stepping_down)
    order by joined_at, user_id
    limit 1
  );

  -- Nobody but the person stepping down: they keep it rather than the garage
  -- losing its last admin.
  if not found and stepping_down is not null then
    update public.household_members
    set role = 'admin'
    where household_id = target_household and user_id = stepping_down;
  end if;
end;
$$;

revoke execute on function public.ensure_household_has_admin(uuid, uuid)
  from public;

-- `create or replace` on a function with a new parameter creates an overload
-- rather than replacing anything, and plpgsql then cannot choose between them:
-- every existing caller passing one argument fails with "is not unique". The
-- single-argument version has to go.
create or replace function public.promote_after_member_left()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Nobody is stepping down here: the row is gone, so it cannot inherit.
  perform public.ensure_household_has_admin(old.household_id, null);
  return old;
end;
$$;

drop function if exists public.ensure_household_has_admin(uuid);

create or replace function public.promote_after_role_changed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.ensure_household_has_admin(
    new.household_id,
    -- Only when this update is the one that gave the role up.
    case when old.role = 'admin' and new.role <> 'admin'
      then new.user_id
    end
  );
  return new;
end;
$$;
