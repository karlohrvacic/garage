# Garage public API

A read-only feed of one household's data, for that household's own automation:
a Home Assistant dashboard of fuel spend, a script that pages when something is
overdue, a spreadsheet that pulls the log once a week.

It is deliberately small. Nothing here writes, and a key only ever sees the
household that issued it.

## Getting a key

**More → Your data → API access → New key.** The key is shown once, at creation, and
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
| `/trips` | The 500 most recent trips, with their private/business purpose, who drove, the route they were on and whether they count as a normal run |
| `/income` | The 500 most recent income entries |
| `/documents` | The paperwork each vehicle holds, soonest expiry first |
| `/observations` | What the driver has noticed, newest first; `resolved_on` is null while it is still going on |
| `/due` | Active reminder rules, as stored |

Responses are JSON objects keyed by resource name, e.g. `{"fuel": [...]}`.
Values are canonical: kilometres, litres (kilowatt-hours for an electric
vehicle), and the household's currency. Dates are `YYYY-MM-DD`.

Errors are `{"error": "..."}` with a matching status: `401` for a missing,
unknown, or revoked key, `404` for an unknown resource, `500` for a database
error.

`/trips` carries `driver`, free text and often null: it is who was *driving*,
which in a shared garage is regularly not `created_by`, the member who typed
the row.

`/documents` carries `doc_type` (`registration`, `roadworthiness`,
`insurance_liability`, `insurance_comprehensive`, `green_card`, `other`),
`expires_on` and `issued_on`. A document with an expiry also raises a one-time
reminder, so the same fact appears in `/due` as a rule of the matching service
type — `/documents` is the paper, `/due` is the deadline it created. A document
with no `expires_on` is one somebody recorded without a date, not one that
never runs out.

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

`/vehicles` also carries `timing_drive` (`belt`, `chain`, `wet_belt`) and
`transmission` (`manual`, `automatic`, `dct_dry`, `dct_wet`, `cvt`), both null
until someone sets them on the vehicle. The app uses them to pick a default
timing-belt and gearbox-oil interval; a consumer projecting its own schedule
will want them for the same reason. Since September 2026 a vehicle also says
what it is: `kind` is `car`, `motorcycle` or `van` (never null; every older
row is a car), and a motorcycle may carry `final_drive` (`chain`, `belt`,
`shaft`, or null). The app uses the kind to decide which service items to
offer, and the final drive to know whether there is a chain to lubricate.

**What the market looked like that day.** A fill-up logged since August 2026
also carries four fields recording the cheapest station within 5 km of the one
it names, as the national price dataset had it when the entry was created:

| Field | Meaning |
|---|---|
| `cheapest_nearby_price` | Its price per litre |
| `cheapest_nearby_km` | How far it was from the station used; `0` when that *was* the cheapest |
| `cheapest_nearby_station` | Its name |
| `prices_seen_on` | The day the prices were read, `YYYY-MM-DD` |

All four are null together or set together — never some of each. They are null
on every fill-up logged before August 2026, on any station the Croatian dataset
does not carry (so on every fill-up outside Croatia), and when a chain name
matched forecourts too far apart to tell which was meant.

They are written **once, when the entry is created**, and are not updated when
it is edited: they describe the day of the fill-up, not today. `prices_seen_on`
is what makes them interpretable — the upstream feed carries no timestamp of its
own, so without it there is no telling a same-day snapshot from a stale one.

### Example: this month's fuel spend

```bash
curl -sH "Authorization: Bearer $GARAGE_KEY" \
  "$GARAGE_URL/functions/v1/public-api/fuel" \
  | jq '[.fuel[] | select(.entry_date >= "2026-08-01") | .total] | add'
```

## Webhooks

**More → Your data → API access → Add webhook.** Garage posts to the URL when
something happens to one of the household's vehicles. There are two events, and
every webhook hears both:

| Event | Sent when |
|---|---|
| `entry.created` | An entry is logged on the vehicle |
| `reminder.due` | Something on it falls due in 30 days, and again at 7 |

Each call names its event twice: in the body's `event`, and in the
`X-Garage-Event` header.

### `entry.created`

`kind` says which of the six kinds of entry was logged: `fuel`, `service`,
`cost`, `odometer`, `trip` or `income`.

```json
{
  "event": "entry.created",
  "kind": "fuel",
  "vehicle_id": "…",
  "entry": { "…": "the row as stored" },
  "at": "2026-08-15T09:12:03.000Z",
  "vehicle_name": "Clio",
  "currency": "EUR",
  "economy": {
    "l_per_100km": 6.096866096866097,
    "distance_km": 702,
    "volume_l": 42.8
  }
}
```

`entry` is the row as stored, in canonical units. The last three fields were
added in September 2026, after the five that were always there, so a receiver
written against those sees nothing move:

| Field | Meaning |
|---|---|
| `vehicle_name` | The vehicle's nickname, so a receiver need not call `/vehicles` to say which car |
| `currency` | The household's currency, ISO 4217 — what every amount in `entry` is in. Null only if it could not be read |
| `economy` | On `kind: "fuel"` only; other kinds do not carry the key. What the tank worked out to, or null |

**`economy` is the app's own figure**, by the same full-tank rule: it measures
from the previous full tank of the same fuel to this one, adding any partial
fills in between. It is null whenever that cannot be done honestly:

- this fill-up was not a full tank;
- there is no earlier full tank of the same fuel to measure from;
- a fill in the span, this one included, is marked as following a missed one;
- the odometer did not move since that earlier full tank;
- the span runs back further than the sixty fill-ups before this one, which is
  as far as the dispatcher reads — the app has a figure for such a span and
  the webhook does not;
- the earlier fill-ups could not be read at the moment the webhook was sent.

Null therefore means "no figure came with this message", not "this tank has
none".

Its three numbers are **canonical and unrounded**, whatever units the household
displays: `l_per_100km` is litres per 100 km, `distance_km` the kilometres the
span covered and `volume_l` the litres it burned. For an electric vehicle the
litres are kilowatt-hours, as they are in `entry`. The app prints the figure to
one decimal, and as mpg for a household on miles or gallons; a receiver that
wants either does the same.

It is worked out **once, when the fill-up is logged**, from the log as it stood.
Editing an entry, or entering an older fill-up afterwards, changes the figure
the app shows and sends nothing — `/fuel` is where the current log is.

### `reminder.due`

Sent since September 2026; every webhook was already subscribed to it, and
until then nothing sent it. It goes out for the reminders the app notifies
about, with the same two notices: 30 days before something falls due, and again
7 days before. Items due on the same vehicle on the same day arrive as one
call, the way they arrive as one notification.

```json
{
  "event": "reminder.due",
  "vehicle_id": "…",
  "vehicle_name": "Clio",
  "due": ["service_oil_change", "service_air_filter"],
  "due_date": "2026-11-04",
  "days_until_due": 7,
  "at": "2026-10-28T06:00:01.000Z"
}
```

| Field | Meaning |
|---|---|
| `vehicle_name` | The vehicle's nickname |
| `due` | What falls due, as service type keys — the `service_type_key` of the rules `/due` returns |
| `due_date` | The day it falls due, `YYYY-MM-DD` |
| `days_until_due` | `30` or `7`, as a number |
| `at` | When the call was made |
| `swap_direction` | Only when the call is about the seasonal tyre swap alone, in a country that fixes dates for it: `to_winter` or `to_summer`. Absent otherwise |

Keys rather than words, as everywhere else here: the names are the app's, in
the language each reader chose.

**It is only as regular as the daily job that sends it.** The event comes from
the same once-a-day run that sends the app's push notifications, so a project
where that run is not scheduled sends none, and a day it does not run is a
notice that never comes — nothing is queued or caught up. It does not need push
notifications to be set up.

**A date that comes from distance is an estimate.** Something due on a date —
registration, insurance, a vignette — is due on that date. Something due at an
odometer reading, whether it recurs like an oil change or comes once like a
timing belt good until a given reading, is dated from the furthest reading on
record: the highest, and of two at the same odometer the later. The odometer
given when the vehicle was added counts as a reading; one dated after the day
of the run does not. The distance still to go is assumed to take 30 km a day
from the day of that reading, which is rougher than the app's own projection.
Something with both a date and an odometer goes by whichever comes first.

The date holds still until a new reading is logged, and a new reading moves
it — which can bring a notice round again, or carry the date past one. A
receiver that must act only once should keep track of what it has already
acted on rather than count on one call per notice. Anything already past its
odometer, or past its estimated date, is not sent at all.

`entry.created` is unchanged by any of this.

### Headers and delivery

Two headers come with every call:

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

### Chat services get a message instead

A webhook pointed at Discord, Slack, Google Chat, Telegram or ntfy.sh — or one
whose **Format** was set by hand, for a Gotify or an ntfy of your own — is not
sent the JSON above, which none of them would accept. It gets a few lines a
person can read, in the body shape that service takes:

```
⛽ Fill-up · Clio · by Ana
42.8 l at INA Zagreb · €60.21 (€1.407/l)
6.1 l/100km over 702 km · 49,680 km
"Motorway all the way"
```

For an entry, the first line is what was logged, on which vehicle, and by
whom. The rest is whatever the entry has: a service lists the work and the
shop, a cost or an income its category and amount, a trip its route, distance,
duration, purpose and driver, a reading the odometer. A line with nothing to
say is left out, and the note comes last, in quotes, cut at 200 characters.

A reminder is two lines — how soon and on which vehicle, then what falls due
and on which day:

```
🔔 Due in 7 days · Clio
Oil change, Air filter · 4 Nov 2026
```

Unlike the JSON, an entry's message is **in the household's units and
currency** — miles, gallons and mpg where that is what the household reads,
kilowatt-hours for an electric vehicle. Every message is in English, whatever
language the app is set to. `X-Garage-Signature` is still sent and still signs
the JSON body, which a chat service ignores.

## Limits and shape

- Read-only. There is no write API, by design.
- 500 rows per collection, newest first. A household with more history than
  that should use the spreadsheet export (More → Your data → Export as spreadsheets).
- No pagination yet. If it is ever needed, it will arrive as a `?before=` date
  parameter rather than opaque cursors.
- The key resolves to exactly one household. There is no cross-household or
  admin scope, and there will not be one.
- **Callable from a browser**, since August 2026. The function has always sent
  `Access-Control-Allow-Origin: *` — the key is the credential, so an origin is
  not a security boundary here — but it answered the preflight with a 204 that
  carried a body, which a `Response` may not do. Constructing it threw, so
  every `OPTIONS` request crashed the function and no browser could get past
  it. Scripts and home servers, which send no preflight, never noticed. Fixed,
  and pinned by a test.

  A reminder that follows from the above: **your key is in the page** if you
  call this from a browser. That is fine for a dashboard on your own machine
  and wrong for anything you publish.

## Deploying it

Both functions ship in this repo. A push to `main` that touches
`supabase/functions/**` deploys them from
`.github/workflows/deploy-functions.yml` — once the repository has
`SUPABASE_ACCESS_TOKEN` and `SUPABASE_PROJECT_REF` as Actions secrets. Without
both the job skips with a notice rather than failing, so a deploy that never
happened looks like a green run; until they are set, or to deploy from a
laptop, it is one command each:

```bash
supabase functions deploy public-api
supabase functions deploy dispatch-webhooks
```

`reminder.due` is sent by a third, `push-due-reminders`, which the same
workflow deploys and which does nothing until a daily cron calls it — the one
in [RUNBOOK-push.md](RUNBOOK-push.md). The webhook half of that run needs no
Firebase: without the `FCM_SERVICE_ACCOUNT` secret it still calls the hooks,
skips the pushes, and says so in its answer as `push_skipped`.

Either way, run them locally first — `supabase functions serve` answers all
four against the local stack. The Deno suite
(`cd supabase/functions && deno test --allow-env`) checks the logic but stubs
the client, so it cannot tell you whether the result still bundles.

`public-api` needs no configuration beyond the injected `SUPABASE_URL` and
`SUPABASE_SERVICE_ROLE_KEY`.

Webhook delivery is triggered from the database itself: migration `0024` adds an
`after insert` trigger on `fuel_entries`, `service_entries` and `cost_entries`,
and `0032` on `odometer_entries`, `trip_entries` and `income_entries`. Each posts
the row to `dispatch-webhooks` through `pg_net`. The payload is the same shape
Supabase's own Database Webhooks send, so either wiring works.

**Adding an entry kind means three edits, and forgetting one is silent.** The
trigger, the `entryKinds` map in `dispatch-webhooks/handler.ts`, and the realtime
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
