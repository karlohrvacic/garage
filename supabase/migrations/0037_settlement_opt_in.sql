-- Splitting the bill is a choice, not the default.
--
-- The settlement divides every logged expense equally between members and
-- reports who owes whom. That is right for people sharing a car and keeping
-- separate money, and wrong — faintly insulting, even — for a couple with
-- joint finances, who were told their partner owed them half of everything
-- purely because of who happened to log it.
--
-- Off by default, including for households that already exist: a feature that
-- makes a claim about somebody's money should be asked for.
alter table public.households
  add column if not exists settlement_enabled boolean not null default false;

comment on column public.households.settlement_enabled is
  'Whether the shared-costs settlement is shown. Off by default: it divides '
  'spend equally between members, which only some households want.';
