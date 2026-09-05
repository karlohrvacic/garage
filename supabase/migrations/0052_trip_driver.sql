-- Who was actually driving.
--
-- A mileage logbook is only worth keeping if it satisfies whoever asks for
-- it, and in Croatia a *putni nalog* names the driver. `created_by` cannot
-- stand in: it records who typed the row, and the whole point of a shared
-- garage is that one person often logs the journey another one made.
--
-- Free text rather than a reference to a household member. The driver of a
-- company van is frequently not a member of the garage at all — a colleague,
-- an employee, somebody covering a shift — and a foreign key would have made
-- the common case unrecordable in order to tidy the rare one.
alter table public.trip_entries
  add column driver text check (driver is null or char_length(driver) <= 80);
