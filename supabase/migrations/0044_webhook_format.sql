-- Which shape a webhook's body should take, when the URL cannot say.
--
-- Detection by host works for the services that have one: Discord, Slack,
-- Google Chat, Telegram, ntfy.sh. It cannot work for the ones a household runs
-- itself — a self-hosted ntfy, Gotify, Mattermost or Home Assistant answers on
-- a domain of the owner's choosing, and no list of hostnames will ever contain
-- it.
--
-- So the URL decides by default and the household can override it. `auto` is
-- the default precisely because it is right for every hosted service and for
-- every generic receiver; the override exists for the case where the app has
-- no way to know.
alter table public.webhooks
  add column if not exists format text not null default 'auto'
  check (
    format in (
      'auto',
      'generic',
      'discord',
      'slack',
      'googlechat',
      'telegram',
      'ntfy',
      'gotify'
    )
  );

comment on column public.webhooks.format is
  'Body shape to send. `auto` reads it from the URL host, which is right for '
  'every hosted service; the rest are for receivers a household runs itself.';
