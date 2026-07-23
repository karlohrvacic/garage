-- The app reads the member list as household_members with an embedded
-- profiles(display_name). PostgREST can only resolve that embed through a
-- foreign key, and household_members.user_id only referenced auth.users —
-- so the query has returned PGRST200 since day one. Every auth user gets a
-- profiles row on signup (handle_new_user), so the constraint is safe to add.
alter table public.household_members
  add constraint household_members_user_profile_fkey
  foreign key (user_id) references public.profiles (user_id)
  on delete cascade;
