-- "Check engine light came on, shop said it was the coil pack."
--
-- A fault noted is not a scheduled item — it has no interval and never comes
-- due — but it belongs in the same history as the work done about it. Adding
-- it as a service type means it lands on the vehicle's timeline, carries the
-- date, odometer, cost, and notes every other entry does, and needs no new
-- table to hold it.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months,
   is_statutory, country_code)
values
  (null, 'service_issue', null, null, false, null),
  (null, 'service_diagnostics', null, null, false, null),
  (null, 'service_modification', null, null, false, null)
on conflict do nothing;
