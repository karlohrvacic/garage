-- The cost-entry sheet has always asked which country's vignette, and for how
-- long — but never saved either answer. Editing an existing vignette entry
-- restored everything except this, and the fields lived only in the sheet's
-- own widget state: closed the sheet, and "Slovenia, 7 days" was gone.
--
-- Language-neutral keys, matching every other stored choice in this schema:
-- `vignette_country` is the ISO 3166-1 alpha-2 code (VignetteCountry.code),
-- `vignette_validity` is VignetteValidity's own key (day1, days7, ...). Both
-- null for every entry that is not a vignette, and for the vignette entries
-- that already existed before this column did — there is no history to
-- backfill them from.
alter table public.cost_entries
  add column vignette_country text check (vignette_country ~ '^[A-Z]{2}$'),
  add column vignette_validity text check (vignette_validity ~ '^[a-z0-9]+$');
