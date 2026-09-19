-- 0079: an outbox for webhooks.
--
-- Until now each entry table's trigger posted the row to the dispatch-webhooks
-- function through pg_net, once, and the function believed nothing it was
-- handed: it read the row back. That cannot announce a delete — the row is
-- gone — and it allows one attempt. From here a trigger writes one row per
-- event into webhook_outbox and pokes the function with an empty body; the
-- function, as service role, reads the outbox, writes one webhook_deliveries
-- row per subscribed hook, and posts them with backoff. Nothing from outside
-- carries data, so nothing from outside is believed. See decision 183.

create table public.webhook_outbox (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  event text not null,
  payload jsonb not null default '{}'::jsonb,
  -- Not now(): a sale writes handed_over and returned in one transaction,
  -- and the receiver should get them in the order they happened.
  created_at timestamptz not null default clock_timestamp(),
  processed_at timestamptz
);

create index webhook_outbox_pending_idx
  on public.webhook_outbox (created_at)
  where processed_at is null;

create table public.webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  outbox_id uuid not null references public.webhook_outbox (id) on delete cascade,
  webhook_id uuid not null references public.webhooks (id) on delete cascade,
  household_id uuid not null references public.households (id) on delete cascade,
  event text not null,
  -- The exact signed JSON, so a retry sends the same bytes under the same
  -- signature, and the chat text in the hook's language.
  body text not null,
  message text not null,
  attempts int not null default 0,
  next_attempt_at timestamptz not null default now(),
  last_status int,
  delivered_at timestamptz,
  given_up_at timestamptz,
  -- Not now(), for the same reason as the outbox: the dispatcher writes a
  -- sale's deliveries in one request, and the hook's log must keep their order.
  created_at timestamptz not null default clock_timestamp()
);

create index webhook_deliveries_due_idx
  on public.webhook_deliveries (next_attempt_at)
  where delivered_at is null and given_up_at is null;

create index webhook_deliveries_hook_idx
  on public.webhook_deliveries (webhook_id, created_at desc);

-- A poke and the five-minute cron can drain the same outbox row at once; the
-- drain inserts with ignoreDuplicates on this pair, so an event reaches a
-- hook once.
create unique index webhook_deliveries_once_idx
  on public.webhook_deliveries (outbox_id, webhook_id);

alter table public.webhooks
  add column name text check (name is null or char_length(name) <= 80),
  add column vehicle_ids uuid[],
  add column language text not null default 'en'
    check (language in ('en', 'hr', 'it')),
  add column paused_reason text;

comment on column public.webhooks.vehicle_ids is
  'Null: every car in the garage. Otherwise only these.';
comment on column public.webhooks.paused_reason is
  'Set by the dispatcher when it switched the hook off: ''failing'' after 20 '
  'consecutive failed deliveries. Cleared when a member resumes it.';

-- 0044's list of body shapes, widened by the four this release adds: Teams,
-- plain text, Pushover and Pushbullet.
alter table public.webhooks
  drop constraint webhooks_format_check,
  add constraint webhooks_format_check check (
    format in (
      'auto',
      'generic',
      'discord',
      'slack',
      'googlechat',
      'telegram',
      'ntfy',
      'gotify',
      'teams',
      'text',
      'pushover',
      'pushbullet'
    )
  );

-- The log is the household's to read and nobody's to write through the API,
-- except for one thing: the app may ask for a test by inserting a ping.
alter table public.webhook_outbox enable row level security;

create policy webhook_outbox_select on public.webhook_outbox
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

create policy webhook_outbox_insert_ping on public.webhook_outbox
  for insert to authenticated
  with check (
    event = 'test.ping'
    and household_id in (select public.user_household_ids())
  );

-- The schema's default privileges hand anon and authenticated everything on
-- a new table, so the grants are spelled out. A column grant is what keeps a
-- ping to two columns: the policy constrains values, not which columns a
-- member may set, and a payload of any size or a created_at from years ago
-- would head every drain of the garage's queue.
revoke all on public.webhook_outbox from anon, authenticated;
grant select on public.webhook_outbox to authenticated;
grant insert (household_id, event) on public.webhook_outbox to authenticated;

alter table public.webhook_deliveries enable row level security;

create policy webhook_deliveries_select on public.webhook_deliveries
  for select to authenticated
  using (household_id in (select public.user_household_ids()));

revoke all on public.webhook_deliveries from anon, authenticated;
grant select on public.webhook_deliveries to authenticated;

-- The app watches a hook's log while a test is out.
alter publication supabase_realtime add table public.webhook_deliveries;
alter table public.webhook_deliveries replica identity full;

-- A hint that there is work. The cron every five minutes is the guarantee;
-- this is what makes a fill-up reach Discord in a second rather than in five
-- minutes. Silent when the operator has not configured an endpoint.
create or replace function public.poke_webhook_dispatch()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  config public.webhook_dispatch_config;
begin
  select * into config from public.webhook_dispatch_config limit 1;
  if not found then
    return;
  end if;
  perform net.http_post(
    url := config.endpoint,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || coalesce(config.auth_token, '')
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000
  );
end;
$$;

revoke execute on function public.poke_webhook_dispatch()
  from public, anon, authenticated;

-- Nothing about delivery may endanger the write that caused it: a household
-- logging fuel in a tunnel must not fail because the outbox could not be
-- written to. The household may already be gone by the time a member's
-- after-delete trigger runs (household_members_cleanup fires after this one,
-- but a cascade from the household itself fires first), which is one of the
-- things swallowed here.
create or replace function public.enqueue_webhook_event(
  target_household uuid,
  event_name text,
  event_payload jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target_household is null then
    return;
  end if;
  begin
    insert into public.webhook_outbox (household_id, event, payload)
    values (target_household, event_name, coalesce(event_payload, '{}'::jsonb));
    -- The poke has a block of its own. In the insert's block, a poke that
    -- raises (pg_net not installed, its queue refusing) would roll the row
    -- back with it, and the event would be lost rather than left for the
    -- five-minute drain, which is the whole point of the row.
    begin
      perform public.poke_webhook_dispatch();
    exception
      when others then
        null;
    end;
  exception
    when others then
      null;
  end;
end;
$$;

revoke execute on function public.enqueue_webhook_event(uuid, text, jsonb)
  from public, anon, authenticated;

-- Entries: insert, update and delete. The vehicle is looked up because the
-- row does not carry the household; when the vehicle itself is being deleted
-- the cascade has already removed it, so nothing is announced for the entries
-- that go with it — a car deleted is not five hundred entries deleted.
create or replace function public.dispatch_entry_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  target uuid;
begin
  -- Attribution alone is not an event. Deleting an account nulls created_by
  -- on every row the person authored (0033), which is an update of each of
  -- them, and five hundred "edited" events for one deleted account is noise.
  if tg_op = 'UPDATE'
      and to_jsonb(new) - 'created_by' = to_jsonb(old) - 'created_by' then
    return new;
  end if;
  select household_id into target
  from public.vehicles
  where id = (current->>'vehicle_id')::uuid;
  if target is null then
    return coalesce(new, old);
  end if;
  perform public.enqueue_webhook_event(
    target,
    case tg_op
      when 'INSERT' then 'entry.created'
      when 'UPDATE' then 'entry.updated'
      else 'entry.deleted'
    end,
    jsonb_build_object(
      'table', tg_table_name,
      'op', tg_op,
      'vehicle_id', current->>'vehicle_id',
      'record', current,
      'old_record', case when tg_op = 'UPDATE' then to_jsonb(old) else null end
    )
  );
  return coalesce(new, old);
end;
$$;

comment on function public.dispatch_entry_webhook() is
  'Writes an entry change to webhook_outbox and pokes the dispatcher.';

revoke execute on function public.dispatch_entry_webhook()
  from public, anon, authenticated;

drop trigger if exists dispatch_webhook_on_insert on public.fuel_entries;
drop trigger if exists dispatch_webhook_on_insert on public.service_entries;
drop trigger if exists dispatch_webhook_on_insert on public.cost_entries;
drop trigger if exists dispatch_webhook_on_insert on public.odometer_entries;
drop trigger if exists dispatch_webhook_on_insert on public.trip_entries;
drop trigger if exists dispatch_webhook_on_insert on public.income_entries;

create trigger dispatch_webhook_on_change
  after insert or update or delete on public.fuel_entries
  for each row execute function public.dispatch_entry_webhook();
create trigger dispatch_webhook_on_change
  after insert or update or delete on public.service_entries
  for each row execute function public.dispatch_entry_webhook();
create trigger dispatch_webhook_on_change
  after insert or update or delete on public.cost_entries
  for each row execute function public.dispatch_entry_webhook();
create trigger dispatch_webhook_on_change
  after insert or update or delete on public.odometer_entries
  for each row execute function public.dispatch_entry_webhook();
create trigger dispatch_webhook_on_change
  after insert or update or delete on public.trip_entries
  for each row execute function public.dispatch_entry_webhook();
create trigger dispatch_webhook_on_change
  after insert or update or delete on public.income_entries
  for each row execute function public.dispatch_entry_webhook();

-- Vehicles: added, archived, restored. A change of household is not
-- announced here — a merge moves the same column and must not read as a
-- sale; the transfer function says so itself, below.
create or replace function public.dispatch_vehicle_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.enqueue_webhook_event(
      new.household_id,
      'vehicle.added',
      jsonb_build_object('vehicle_id', new.id, 'record', to_jsonb(new))
    );
  elsif old.household_id is distinct from new.household_id then
    -- A move is not a restore. A transfer announces itself from the function
    -- that performs it, and a merge announces nothing; the sale also clears
    -- `archived`, which would otherwise reach the buyer as vehicle.restored.
    return new;
  elsif old.archived is distinct from new.archived then
    perform public.enqueue_webhook_event(
      new.household_id,
      case when new.archived then 'vehicle.archived' else 'vehicle.restored' end,
      jsonb_build_object('vehicle_id', new.id, 'record', to_jsonb(new))
    );
  end if;
  return new;
end;
$$;

revoke execute on function public.dispatch_vehicle_webhook()
  from public, anon, authenticated;

create trigger dispatch_webhook_on_change
  after insert or update on public.vehicles
  for each row execute function public.dispatch_vehicle_webhook();

-- Loans: a pass redeemed is the car lent; a redeemed pass withdrawn by the
-- owner, or given back by the borrower (0068), is the car returned. A pass
-- withdrawn before anybody typed it in was never a loan, and expiry changes
-- no row, so it announces nothing (a known gap).
create or replace function public.dispatch_guest_pass_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  select household_id into target from public.vehicles where id = new.vehicle_id;
  if old.redeemed_at is null and new.redeemed_at is not null then
    perform public.enqueue_webhook_event(
      target,
      'vehicle.lent',
      jsonb_build_object('vehicle_id', new.vehicle_id, 'record', to_jsonb(new))
    );
  -- Only a pass that was live is returned. A car the borrower gave back and
  -- the owner later withdrew anyway ended once, not twice.
  elsif new.redeemed_at is not null
      and old.revoked_at is null and old.returned_at is null
      and (new.revoked_at is not null or new.returned_at is not null) then
    perform public.enqueue_webhook_event(
      target,
      'vehicle.returned',
      jsonb_build_object('vehicle_id', new.vehicle_id, 'record', to_jsonb(new))
    );
  end if;
  return new;
end;
$$;

revoke execute on function public.dispatch_guest_pass_webhook()
  from public, anon, authenticated;

create trigger dispatch_webhook_on_change
  after update on public.vehicle_guest_passes
  for each row execute function public.dispatch_guest_pass_webhook();

-- Members. Named to sort before household_members_cleanup, so an emptied
-- garage's last "left" is written and then cascaded away with the garage
-- rather than refused.
create or replace function public.dispatch_member_webhook()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    perform public.enqueue_webhook_event(
      new.household_id,
      'member.joined',
      jsonb_build_object('user_id', new.user_id, 'role', new.role)
    );
    return new;
  end if;
  perform public.enqueue_webhook_event(
    old.household_id,
    'member.left',
    jsonb_build_object('user_id', old.user_id, 'role', old.role)
  );
  return old;
end;
$$;

revoke execute on function public.dispatch_member_webhook()
  from public, anon, authenticated;

create trigger dispatch_webhook_on_change
  after insert or delete on public.household_members
  for each row execute function public.dispatch_member_webhook();

-- The app's test button is an insert of a ping, straight into the outbox
-- through the policy above and through none of the functions here, so
-- nothing else would poke the dispatcher for it. Swallowed for the same
-- reason enqueue_webhook_event swallows: a poke that fails must not refuse
-- the row it was meant to announce.
create or replace function public.poke_on_ping()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    perform public.poke_webhook_dispatch();
  exception
    when others then
      null;
  end;
  return new;
end;
$$;

revoke execute on function public.poke_on_ping()
  from public, anon, authenticated;

create trigger poke_on_ping
  after insert on public.webhook_outbox
  for each row
  when (new.event = 'test.ping')
  execute function public.poke_on_ping();

-- A sale, written by the one function that performs one. The body is 0070's,
-- reordered so the loans end before the car moves, with one call added before
-- the move, so the seller's hooks — the only ones that knew the car — hear it.
create or replace function public.redeem_vehicle_transfer(
  transfer_code text,
  target_household uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  transfer public.vehicle_transfers;
  caller uuid := (select auth.uid());
  car public.vehicles;
begin
  if caller is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if target_household not in (select public.user_household_ids()) then
    raise exception 'not a member of this household' using errcode = '42501';
  end if;

  select * into transfer
  from public.vehicle_transfers
  where code = upper(trim(transfer_code))
  for update;

  if transfer.id is null then
    raise exception 'unknown transfer code' using errcode = 'P0002';
  end if;

  if transfer.redeemed_at is not null then
    raise exception 'transfer code already used' using errcode = 'P0004';
  end if;

  if transfer.expires_at <= now() then
    raise exception 'transfer code expired' using errcode = 'P0003';
  end if;

  -- The car is locked here rather than by the update that moves it, because
  -- the passes are now withdrawn before the move. 0074's guarantee is that a
  -- mint under way holds a share lock on the car and the sale waits for it,
  -- so that the withdrawal sees the pass; with the withdrawal first, a lock
  -- taken only by the move would let a pass minted during the sale outlive
  -- it again. No key update, the lock an update takes, so an entry's
  -- foreign-key check on the car does not queue behind a sale.
  select * into car
  from public.vehicles
  where id = transfer.vehicle_id
    and household_id = transfer.from_household_id
  for no key update;
  if car.id is null then
    raise exception 'transfer code is no longer valid' using errcode = 'P0002';
  end if;

  if target_household = transfer.from_household_id then
    raise exception 'the vehicle is already in this household' using errcode = 'P0005';
  end if;

  -- The seller's loans end with the seller's ownership. Passes already over
  -- are left as they are, so the record still says how each one ended.
  -- Withdrawn before the car moves: the pass trigger announces each one as
  -- vehicle.returned to the garage the car is in at that moment, and that
  -- has to be the seller's, whose hooks knew the loan.
  update public.vehicle_guest_passes
  set revoked_at = now()
  where vehicle_id = transfer.vehicle_id
    and revoked_at is null
    and returned_at is null
    and expires_at > now();

  -- Announced after the loans end and before the car moves, so the seller's
  -- receiver reads the sale in the order it happened: returned, then handed
  -- over. `car` is the row as it was before the move, which is the car the
  -- seller's hooks knew.
  perform public.enqueue_webhook_event(
    transfer.from_household_id,
    'vehicle.handed_over',
    jsonb_build_object(
      'vehicle_id', car.id,
      'record', to_jsonb(car),
      'to_household_id', target_household
    )
  );

  update public.vehicles
  set household_id = target_household,
      -- The photo lives under the old household's storage prefix and cannot
      -- follow. Left behind rather than pointing at a file the new owner
      -- cannot read.
      photo_path = null,
      archived = false
  where id = transfer.vehicle_id;

  update public.vehicle_transfers
  set redeemed_at = now(), redeemed_by = caller
  where id = transfer.id;

  -- Any other outstanding offer for this vehicle is now meaningless.
  delete from public.vehicle_transfers
  where vehicle_id = transfer.vehicle_id
    and id <> transfer.id
    and redeemed_at is null;

  return transfer.vehicle_id;
end;
$$;

revoke execute on function public.redeem_vehicle_transfer(text, uuid) from public, anon;
grant execute on function public.redeem_vehicle_transfer(text, uuid) to authenticated;

-- The guarantee behind the poke, and the sweep that keeps the log short.
create or replace function public.run_webhook_drain()
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.poke_webhook_dispatch();
end;
$$;

revoke execute on function public.run_webhook_drain()
  from public, anon, authenticated;

create or replace function public.prune_webhook_history()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.webhook_deliveries
  where created_at < now() - interval '30 days';
  -- Processed or not. A garage whose operator never configured a dispatch
  -- endpoint must not grow a queue forever, and a month-old event is not
  -- worth delivering once it finally could be.
  delete from public.webhook_outbox
  where created_at < now() - interval '30 days';
end;
$$;

revoke execute on function public.prune_webhook_history()
  from public, anon, authenticated;

select cron.unschedule('drain-webhooks')
where exists (select 1 from cron.job where jobname = 'drain-webhooks');
select cron.schedule(
  'drain-webhooks',
  '*/5 * * * *',
  $$select public.run_webhook_drain()$$
);

select cron.unschedule('prune-webhook-history')
where exists (select 1 from cron.job where jobname = 'prune-webhook-history');
select cron.schedule(
  'prune-webhook-history',
  '15 3 * * *',
  $$select public.prune_webhook_history()$$
);
