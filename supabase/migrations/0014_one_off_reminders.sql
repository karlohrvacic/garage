-- One-off reminders: "registration due 12 March" alongside the recurring
-- interval rules. A one-time rule carries a fixed due date and/or odometer
-- and deactivates once a matching service is logged.
alter table public.reminder_rules
  add column one_time boolean not null default false,
  add column due_date date,
  add column due_odometer_km int check (due_odometer_km > 0);

alter table public.reminder_rules
  drop constraint reminder_rules_needs_an_interval;

alter table public.reminder_rules
  add constraint reminder_rules_needs_a_target check (
    interval_km is not null
    or interval_months is not null
    or due_date is not null
    or due_odometer_km is not null
  );

-- Recurring rules stay unique per vehicle and type; several one-off items of
-- the same type (two dated tyre swaps, say) may coexist.
alter table public.reminder_rules
  drop constraint reminder_rules_vehicle_id_service_type_key_key;

create unique index reminder_rules_recurring_unique_idx
  on public.reminder_rules (vehicle_id, service_type_key)
  where not one_time;
