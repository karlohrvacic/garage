-- Two obligations that already had a place to be *spent* but nowhere to come
-- due.
--
-- Comprehensive cover has had its own cost category since 0018, because it is
-- bought separately from the mandatory policy and usually from a different
-- insurer on a different date. It had no service type, so paying it scheduled
-- nothing and the renewal people actually forget was the one the app said
-- nothing about. Not statutory and not Croatian: optional cover exists in
-- every market, so it carries no country code.
--
-- A vignette is road use bought for a period, the way Slovenia, Austria,
-- Switzerland and Czechia sell it. What matters is the date it stops being
-- valid, which is a one-off reminder rather than a recurring interval, so it
-- is seeded with no default interval: the cost entry supplies the expiry from
-- the period the driver bought. Deliberately not country-scoped — a Croatian
-- household needs it precisely when it leaves Croatia, and Croatia itself
-- charges at the barrier instead.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months, is_statutory, country_code)
values
  (null, 'service_insurance_comprehensive', null, 12,   false, null),
  (null, 'service_vignette',                null, null, false, null)
on conflict do nothing;
