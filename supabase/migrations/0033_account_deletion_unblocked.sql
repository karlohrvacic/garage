-- Deleting an account failed for anyone who shared a household.
--
-- Every `created_by` (and the two `redeemed_by` columns) referenced auth.users
-- with the default `no action`, so Postgres refused to delete a user while any
-- row still pointed at them. It worked for a *solo* household only by accident:
-- household_members cascades, the cleanup trigger drops the now-empty
-- household, and that cascades through vehicles to every entry before these
-- references are ever checked. Share the household and none of that happens —
-- the delete-account function returned "Database error deleting user" and Play
-- requires in-app deletion to work.
--
-- Confirmed against a local Postgres before this was written: the first
-- constraint to refuse was invites_redeemed_by_fkey, and there were seventeen
-- more behind it.
--
-- `set null` rather than `cascade`, and this is the whole decision: the entries
-- belong to the *household*, not to the person who typed them. Cascading would
-- mean one member leaving takes half a shared household's fuel log with them,
-- which is data loss dressed up as tidiness. Attribution is what is lost, and
-- attribution is the part that stops being true anyway once the person is gone.
--
-- The columns therefore become nullable. Inserts are unaffected: every RLS
-- insert policy still requires `created_by = auth.uid()`, and a null fails that
-- check exactly as a wrong id would.
--
-- `pin_created_by` had to change with it, and this was the trap. That trigger
-- (migration 0008) reverts any UPDATE of `created_by` to the old value, to stop
-- a crafted client forging authorship. `on delete set null` *is* an update, so
-- the trigger reverted it: the delete then reported success and left a dangling
-- reference behind — silently, which is worse than the failure it replaced.
-- Verified on a local Postgres, both before and after.
--
-- The trigger now allows exactly one thing it did not: setting `created_by` to
-- null when the user it pointed at no longer exists. Postgres fires the
-- referential action after the parent row is gone, so that condition is true
-- for the FK and false for any client — which still cannot forge authorship,
-- and still cannot anonymise a row belonging to a user who is very much alive.

do $$
declare
  target record;
begin
  for target in
    select c.conrelid::regclass::text as tbl,
           a.attname as col,
           c.conname,
           a.attnotnull as not_null
    from pg_constraint c
    join unnest(c.conkey) with ordinality k(attnum, ord) on true
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = k.attnum
    where c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
      and c.connamespace = 'public'::regnamespace
      -- 'a' is no action: the ones that block a delete. The cascading
      -- references (profiles, household_members, device_tokens) are correct
      -- as they are and are left alone.
      and c.confdeltype = 'a'
  loop
    if target.not_null then
      execute format(
        'alter table %s alter column %I drop not null', target.tbl, target.col
      );
    end if;
    execute format(
      'alter table %s drop constraint %I', target.tbl, target.conname
    );
    execute format(
      'alter table %s add constraint %I foreign key (%I) '
      'references auth.users (id) on delete set null',
      target.tbl, target.conname, target.col
    );
  end loop;
end;
$$;

-- Let the referential action through, and nothing else.
--
-- `security definer` is load-bearing rather than convenience: the check reads
-- auth.users, and `authenticated` has no select on it, so without this every
-- ordinary edit of a fill-up fails with "permission denied for table users".
-- The function takes no arguments and reads exactly one row by primary key, so
-- there is nothing here for a caller to steer.
create or replace function public.pin_created_by()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if new.created_by is null
     and old.created_by is not null
     and not exists (select 1 from auth.users where id = old.created_by) then
    return new;
  end if;
  new.created_by := old.created_by;
  return new;
end;
$$;
