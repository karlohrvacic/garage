-- Diagnostic trouble codes read during a visit: "P0301, P0171".
--
-- Free text rather than a code table: the codes a household reads come from
-- whatever tool they own, manufacturer-specific ones included, and refusing an
-- unrecognised code would lose the very thing worth writing down. Structured
-- enough to search for, which is what "was this the same fault as last time?"
-- actually needs.
alter table public.service_entries
  add column fault_codes text;

comment on column public.service_entries.fault_codes is
  'Diagnostic trouble codes read at this visit, as the user typed them.';
