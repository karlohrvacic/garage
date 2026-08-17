-- A garage could not be renamed, by anybody. Not a permission problem — there
-- was no field for it anywhere in the app, while the write that would carry it
-- (`households_update`) has existed since `0001` and already carries currency,
-- units, bundling windows and tracking level.
--
-- Renaming is not the same kind of thing as those. Units are a preference and
-- any member may set them; the name is the garage's identity, shown to every
-- member and on every invite, and one member renaming the shared garage out
-- from under the others is a different act.
--
-- So: admins only, enforced here. A check in the app would be decoration —
-- the policy is the boundary, and `households_update` deliberately stays open
-- to members so they keep the settings that are genuinely theirs. Column-level
-- privileges cannot express "this column, only for admins *of this row*",
-- which is why this is a trigger rather than a grant.
create function public.enforce_household_rename_is_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.name is distinct from old.name
     and not public.is_household_admin(old.id) then
    raise exception 'only an admin may rename a garage'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

-- `42501` is insufficient_privilege, which the app already maps to its
-- "you do not have access to that" message (`AppFailure.from`), so a member
-- who somehow reaches this gets a sentence rather than a raw backend error.
create trigger households_rename_is_admin
before update on public.households
for each row execute function public.enforce_household_rename_is_admin();
