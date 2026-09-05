-- `created_by` on a document is attribution and must survive an edit, for the
-- reason 0008 and 0041 give: an RLS `with check` cannot see the old row, so
-- nothing else stops one household member rewriting who filed a document.
--
-- It is also what makes editing work at all. The app saves a document with an
-- **upsert** — one code path for "add" and "correct", and the only shape that
-- survives a save which timed out and was tried again, since the retry lands
-- on the same client-minted id. Postgres checks an `insert ... on conflict do
-- update` against the *insert* policy as well as the update one, and that
-- policy demands `created_by = auth.uid()`. So the row has to carry the
-- caller's own id on the way in, and this trigger puts the original creator
-- back on the way through.
--
-- Without it, the second member of a household could not correct a document
-- the first one filed: the write was refused as "new row violates row-level
-- security policy", on a screen that gave no reason. The RLS suite covers
-- exactly that case, because a plain `update` test passes either way.
create trigger vehicle_documents_pin_created_by
  before update on public.vehicle_documents
  for each row execute function public.pin_created_by();
