# Garage public API

A read-only feed of one household's data, for that household's own automation:
a Home Assistant dashboard of fuel spend, a script that pages when something is
overdue, a spreadsheet that pulls the log once a week.

It is deliberately small. Nothing here writes, and a key only ever sees the
household that issued it.

## Getting a key

**Settings → API access → New key.** The key is shown once, at creation, and
never again — the server stores only a SHA-256 hash of it. Lose it and issue a
new one; revoke the old one from the same screen.

Keys look like `grg_` followed by 32 characters. Treat one like a password: it
is the whole credential.

## Calling it

```bash
curl -H "Authorization: Bearer grg_your_key_here" \
  https://<project-ref>.supabase.co/functions/v1/public-api/fuel
```

| Path | Returns |
|---|---|
| `/` | The household id and the list of resources |
| `/vehicles` | Every vehicle, archived ones included |
| `/fuel` | The 500 most recent fill-ups across the fleet |
| `/services` | The 500 most recent service entries |
| `/costs` | The 500 most recent costs |
| `/readings` | The 500 most recent standalone odometer readings |
| `/trips` | The 500 most recent trips, with their private/business purpose |
| `/income` | The 500 most recent income entries |
| `/due` | Active reminder rules, as stored |

Responses are JSON objects keyed by resource name, e.g. `{"fuel": [...]}`.
Values are canonical: kilometres, litres (kilowatt-hours for an electric
vehicle), and the household's currency. Dates are `YYYY-MM-DD`.

Errors are `{"error": "..."}` with a matching status: `401` for a missing,
unknown, or revoked key, `404` for an unknown resource, `500` for a database
error.

`/due` returns the rules rather than projected dates. Projection needs the
driving rate the app computes, and a consumer of this API is usually better
served by the raw schedule plus the logs.

**Distance comes from more than `/fuel`.** A vehicle's odometer is recorded by
fill-ups, services, costs that carry a reading, standalone readings, and the end
of a trip. Anything reconstructing how far a car has gone has to merge all of
them, the way the app does — reading `/fuel` alone under-reports a household
that pays cash at the pump.

`/fuel` rows carry `fuel_type_key` for a car that runs on two fuels, and
`/vehicles` carries `secondary_fuel_type_key` to say which cars those are. Both
are null for the ordinary single-fuel car.

### Example: this month's fuel spend

```bash
curl -sH "Authorization: Bearer $GARAGE_KEY" \
  "$GARAGE_URL/functions/v1/public-api/fuel" \
  | jq '[.fuel[] | select(.entry_date >= "2026-08-01") | .total] | add'
```

## Webhooks

**Settings → API access → Add webhook.** Garage posts to the URL whenever a
fill-up, service, or cost is logged on any of the household's vehicles.

```json
{
  "event": "entry.created",
  "kind": "fuel",
  "vehicle_id": "…",
  "entry": { "…": "the row as stored" },
  "at": "2026-08-15T09:12:03.000Z"
}
```

Two headers come with it:

- `X-Garage-Event` — the event name.
- `X-Garage-Signature` — HMAC-SHA256 of the exact request body, keyed with the
  webhook's secret, hex-encoded. Verify it before trusting the payload:

  ```python
  expected = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
  hmac.compare_digest(expected, request.headers["X-Garage-Signature"])
  ```

Delivery is one attempt with a ten-second timeout, and the URL must be
`https://`. A hook whose last call failed shows its status in the app, so a
home server that was off is visible rather than silent. Nothing is queued for
retry: the same data is always available from the API above.

## Limits and shape

- Read-only. There is no write API, by design.
- 500 rows per collection, newest first. A household with more history than
  that should use the CSV export (Settings → Export as CSV).
- No pagination yet. If it is ever needed, it will arrive as a `?before=` date
  parameter rather than opaque cursors.
- The key resolves to exactly one household. There is no cross-household or
  admin scope, and there will not be one.

## Deploying it

Both functions ship in this repo and need one deploy each:

```bash
supabase functions deploy public-api
supabase functions deploy dispatch-webhooks
```

`public-api` needs no configuration beyond the injected `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`.

Webhook delivery is triggered from the database itself: migration `0024` adds an
`after insert` trigger on `fuel_entries`, `service_entries` and `cost_entries`,
and `0032` on `odometer_entries`, `trip_entries` and `income_entries`. Each posts
the row to `dispatch-webhooks` through `pg_net`. The payload is the same shape
Supabase's own Database Webhooks send, so either wiring works.

**Adding an entry kind means three edits, and forgetting one is silent.** The
trigger, the `entryKinds` map in `dispatch-webhooks/index.ts`, and the realtime
publication. A table missing from the map is ignored by the dispatcher without
an error, so a receiver subscribed to "new entries" simply stops hearing about
some of them — which is exactly what happened between `0028` and `0032`.

The trigger is a **no-op until the project's endpoint is on record** — deliberate,
so local development and CI never call out. Configure it with one row:

```sql
insert into public.webhook_dispatch_config (endpoint, auth_token)
values (
  'https://<ref>.supabase.co/functions/v1/dispatch-webhooks',
  '<anon key>'
)
on conflict (id) do update
  set endpoint = excluded.endpoint,
      auth_token = excluded.auth_token,
      updated_at = now();
```

That table has RLS on and no policy, so no signed-in user can read the token —
it is operator configuration, not household data.

Delivery cannot break a write: `pg_net` queues the request and returns, and the
trigger swallows anything it still manages to raise. A household logging fuel
never fails because a home-automation box is unreachable.
