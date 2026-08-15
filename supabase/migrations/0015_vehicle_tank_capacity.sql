-- Tank size lives on the vehicle, not on the household: a fleet mixes a 45 l
-- hatchback with an 80 l van, and the figure is only ever used to sanity-check
-- a fill-up against the car it went into. Optional — a vehicle whose capacity
-- nobody entered simply gets no volume warning.
alter table public.vehicles
  add column tank_capacity_l numeric check (tank_capacity_l > 0);
