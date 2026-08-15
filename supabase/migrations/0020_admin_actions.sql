-- Roles, finally used for something.
--
-- Every member remains equal for the day-to-day: logging fill-ups, services,
-- and costs, and editing what they logged. Two actions are not day-to-day —
-- removing a vehicle takes its whole history with it, and removing a member
-- cuts someone off from data they helped build — so those become the admin's.
--
-- The household's creator is already its admin (create_household), and a
-- household with one member is that member's, so nothing gets locked away
-- from a household that never thinks about roles.
create function public.is_household_admin(target_household uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.household_members
    where household_id = target_household
      and user_id = (select auth.uid())
      and role = 'admin'
  );
$$;

grant execute on function public.is_household_admin(uuid) to authenticated;

-- Deleting a vehicle deletes its fuel, service, cost, and attachment history
-- by cascade. Admins only.
drop policy vehicles_delete on public.vehicles;

create policy vehicles_delete on public.vehicles
  for delete to authenticated
  using (public.is_household_admin(household_id));

-- Leaving a household yourself is already allowed (members_delete_self, from
-- the first migration). Removing *someone else* is the admin's, and needs its
-- own policy: policies are permissive, so this widens delete for admins
-- without touching anyone's ability to leave.
create policy members_delete_by_admin on public.household_members
  for delete to authenticated
  using (public.is_household_admin(household_id));
