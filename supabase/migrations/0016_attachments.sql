-- Receipts and documents attached to an entry: the pump receipt for a fill-up,
-- the shop invoice for a service, the policy PDF for an insurance cost.
--
-- The file lives in Storage; this table is the household-scoped index of what
-- belongs to which entry. Scoping by vehicle (rather than by entry alone) is
-- what lets one RLS policy cover all three entry kinds: an attachment is
-- visible exactly to the people who can see the vehicle it hangs off.
create table public.attachments (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles (id) on delete cascade,
  entry_kind text not null check (entry_kind in ('fuel', 'service', 'cost')),
  entry_id uuid not null,
  storage_path text not null unique,
  file_name text not null,
  content_type text,
  size_bytes int check (size_bytes >= 0),
  created_by uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create index attachments_entry_idx
  on public.attachments (entry_kind, entry_id);

create index attachments_vehicle_idx
  on public.attachments (vehicle_id, created_at desc);

alter table public.attachments enable row level security;

create policy attachments_select on public.attachments
  for select to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

create policy attachments_insert on public.attachments
  for insert to authenticated
  with check (
    vehicle_id in (select public.user_vehicle_ids())
    and created_by = (select auth.uid())
  );

create policy attachments_delete on public.attachments
  for delete to authenticated
  using (vehicle_id in (select public.user_vehicle_ids()));

grant select, insert, delete on public.attachments to authenticated;

alter publication supabase_realtime add table public.attachments;

-- The bucket itself. Private: every read goes through a signed URL, so a file
-- is only reachable by someone who currently passes the policies below.
insert into storage.buckets (id, name, public, file_size_limit)
values ('attachments', 'attachments', false, 10485760)
on conflict (id) do nothing;

-- Objects are keyed <vehicle_id>/<uuid>-<file name>, so the first path segment
-- is what the policies check against the caller's vehicles.
create policy attachments_object_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    -- Compared as text: casting a user-supplied path segment to uuid raises
    -- rather than denying, and a policy should fail closed, not error.
    and (storage.foldername(name))[1] in (
      select vehicle_id::text from public.user_vehicle_ids() as vehicle_id
    )
  );

create policy attachments_object_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    -- Compared as text: casting a user-supplied path segment to uuid raises
    -- rather than denying, and a policy should fail closed, not error.
    and (storage.foldername(name))[1] in (
      select vehicle_id::text from public.user_vehicle_ids() as vehicle_id
    )
  );

create policy attachments_object_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    -- Compared as text: casting a user-supplied path segment to uuid raises
    -- rather than denying, and a policy should fail closed, not error.
    and (storage.foldername(name))[1] in (
      select vehicle_id::text from public.user_vehicle_ids() as vehicle_id
    )
  );
