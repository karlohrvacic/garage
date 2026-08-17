-- Fifteen more presets, and a correction.
--
-- The list shipped with brake *pads* front and rear and no discs at all, which
-- is the wrong half of the job: Consumer Reports' guidance is to replace pads
-- and discs together, and a household that logs a pad change has no way to
-- record the discs that went with it. Cars with rear drums — most small
-- European hatchbacks, which is what this app is for — could not record their
-- rear brakes at all.
--
-- The rest close gaps against the standard checklists (Consumer Reports,
-- Bridgestone) and against what a *European* fleet needs, which the American
-- lists do not cover:
--
--   * glow plugs, the diesel counterpart to spark plugs. Diesel is the common
--     case in Croatia and there was no way to log it.
--   * a clutch, on a continent where manual gearboxes are the default.
--   * a diesel particulate filter and AdBlue, which every modern EU diesel has
--     and no US checklist mentions.
--   * a fuel filter, oddly absent while air, cabin and oil filters were all
--     present.
--
-- Intervals stay deliberately conservative and generic, as the original set
-- does: they are a starting point the household overrides per vehicle, not a
-- claim about any model. Where an item is replaced on condition rather than on
-- a schedule — discs, drums, shocks, a clutch, an alternator, bulbs — both
-- intervals are null, so it is loggable without inventing a due date it has no
-- business projecting.
insert into public.service_types
  (household_id, key, default_interval_km, default_interval_months, is_statutory, country_code)
values
  -- Brakes, the part that was missing
  (null, 'service_brake_discs_front', null, null, false, null),
  (null, 'service_brake_discs_rear',  null, null, false, null),
  (null, 'service_brake_drums_rear',  null, null, false, null),

  -- Diesel, which the original list had no answer for at all
  (null, 'service_glow_plugs',        80000, null, false, null),
  (null, 'service_dpf',               null,  null, false, null),
  (null, 'service_adblue',            null,  null, false, null),

  -- Filters: air, cabin and oil were here; fuel was not
  (null, 'service_fuel_filter',       60000, 48,   false, null),

  -- Driveline
  (null, 'service_clutch',            null,  null, false, null),
  (null, 'service_differential_oil',  60000, 48,   false, null),

  -- Belt-driven accessories. Distinct from the timing belt: this one drives
  -- the alternator and the pump, and snapping it strands you without
  -- destroying the engine.
  (null, 'service_serpentine_belt',   90000, 72,   false, null),
  -- Usually replaced with the timing belt, which is why it earns its own row:
  -- a household wants to record that it was done at the same time.
  (null, 'service_water_pump',        120000, 72,  false, null),

  -- Suspension and steering
  (null, 'service_shock_absorbers',   null,  null, false, null),
  (null, 'service_wheel_alignment',   null,  24,   false, null),

  -- Comfort and consumables
  (null, 'service_ac_service',        null,  24,   false, null),
  (null, 'service_bulbs',             null,  null, false, null)
on conflict do nothing;
