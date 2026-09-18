# Push notifications (FCM) — activation runbook

Everything in the repo is done. What is left is account work nobody can do from
here: creating the Firebase project and pasting four public values plus one
secret. Until you do, the app builds and runs exactly as before with push
inactive — `PushConfig.isConfigured` is false, `pushRegistrationProvider` hands
back `PushDisabled`, and nothing is registered or sent.

**Android only.** Web push additionally needs a service worker
(`firebase-messaging-sw.js`) that is not written, so the web build deliberately
gets no Firebase config and stays on local notifications.

> **No `google-services.json`.** The usual FlutterFire setup drops that file in
> `android/app/` and applies the `com.google.gms.google-services` Gradle plugin.
> That plugin **fails the build when the file is missing**, and the file is not
> in the repository — so CI's `flutter build apk`, and anyone cloning this,
> would break. The same four values are passed as dart-defines instead and
> handed to `Firebase.initializeApp(options:)`. See `lib/core/config/push_config.dart`.

## 1. Firebase console (~10 minutes)

1. <https://console.firebase.google.com> → **Add project** → pick the
   **existing Google Cloud project** already used for Google sign-in, so OAuth
   and messaging stay in one place.
2. **Add app → Android**, package name `cc.hrva.garage`. Skip the
   "download google-services.json" step; it is not used here.
3. **Project settings → General → Your apps → Android app.** Copy four values:

   | Console field | dart-define |
   |---|---|
   | Web API key (General tab, "Web API Key") | `FIREBASE_API_KEY` |
   | App ID (`1:…:android:…`) | `FIREBASE_APP_ID` |
   | Project number | `FIREBASE_MESSAGING_SENDER_ID` |
   | Project ID | `FIREBASE_PROJECT_ID` |

   None of these are secrets: they identify the project to the device and ship
   inside every copy of the app.

4. **Project settings → Service accounts → Generate new private key.** This
   downloads a JSON file. *This one is a secret* — it can send a push as you.
   Keep it out of git.

## 2. Where the values go

**Local development** — `env/local.json` (gitignored), alongside the Supabase
values already there:

```json
{
  "SUPABASE_URL": "…",
  "SUPABASE_ANON_KEY": "…",
  "FIREBASE_API_KEY": "…",
  "FIREBASE_APP_ID": "1:123456789:android:abc123",
  "FIREBASE_MESSAGING_SENDER_ID": "123456789",
  "FIREBASE_PROJECT_ID": "garage-xxxxx"
}
```

Then `flutter run --dart-define-from-file=env/local.json` as usual.

**Released builds** — GitHub → *Settings* → *Secrets and variables* → *Actions*
→ **New repository secret**, one per row:

| Secret | Value |
|---|---|
| `FIREBASE_API_KEY` | Web API key |
| `FIREBASE_APP_ID` | Android app ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Project number |
| `FIREBASE_PROJECT_ID` | Project ID |

`.github/workflows/deploy-play.yml` already reads them and passes them as
dart-defines. Missing secrets are empty strings, which simply leaves push off —
the build does not fail.

**The sending credential** — a Supabase secret, never a dart-define:

```bash
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat ~/Downloads/service-account.json)"
```

## 3. Deploy the sender, and switch its schedule on

Edge functions are not deployed by the migration integration.
`.github/workflows/deploy-functions.yml` deploys this one on a push to `main`
once the repository has its two Supabase secrets; until then, or from a laptop:

```bash
supabase functions deploy push-due-reminders
```

**The schedule already exists.** Migration
`supabase/migrations/0027_push_schedule.sql` creates the cron job
`push-due-reminders-daily`, at 06:00 UTC, which calls
`public.run_due_reminders_push()`. That function does nothing, quietly and by
design, until two Vault secrets name the endpoint and the credential. The
service-role key is the whole database, which is why it lives in Vault rather
than in git or in the job's own text, and why the app's own roles may not call
the function: `0027` withheld it from them by name and left it with PUBLIC,
which every role belongs to, until
`supabase/migrations/0076_push_schedule_timeout.sql` took that back too. Set
both once, in the SQL editor:

```sql
select vault.create_secret('https://<project-ref>.supabase.co/functions/v1/push-due-reminders', 'push_endpoint');
select vault.create_secret('<service-role-key>', 'push_service_role_key');
```

**Do not schedule it again by hand.** `cron.schedule` under the same name
replaces the migration's job with whatever it is given, and a command with the
key in it is kept as plain text in `cron.job`.

It sends at exactly 30 and 7 days out, so running once a day is what makes
each notice go once, without any bookkeeping table. A reminder due by
distance, recurring or one-off, is dated from the day of the car's furthest
reading, so it holds still between runs too; a new reading can move it — see
the sharp edges in
[08](architecture/08-reminders-and-notifications.md#sharp-edges).

**The schedule is not only for push.** The same run sends the `reminder.due`
webhook event to the garages whose cars have something due, and that half
needs no Firebase: without the `FCM_SERVICE_ACCOUNT` secret the run still calls
the hooks, skips the pushes, and says so in its answer. A project that wants
webhooks and not push needs the two Vault secrets and nothing from sections 1
and 2.

**The call that starts the run has to wait up to a minute.** It is the
`net.http_post` inside `run_due_reminders_push()`, and it needs
`timeout_milliseconds := 60000`, because the run now waits up to ten seconds on
the garages' webhooks before it starts pushing, and pg_net stops waiting after
five seconds unless told otherwise:

```sql
perform net.http_post(
  url := endpoint,
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer ' || auth_token
  ),
  body := '{}'::jsonb,
  timeout_milliseconds := 60000
);
```

`supabase/migrations/0076_push_schedule_timeout.sql` gives it that timeout.
Before it, a run that outlasted pg_net's wait was recorded in
`net._http_response` as `timed_out`, with no answer to read.

## 4. Check it works

1. Install a build carrying the config, sign in, allow notifications.
2. The token should appear:

   ```sql
   select platform, updated_at from device_tokens where user_id = auth.uid();
   ```

   No row means registration failed. It is deliberately not fatal to sign-in, so
   look for the reason in `adb logcat -s garage.failure`.
3. Force a send without waiting for 06:00:

   ```bash
   curl -X POST 'https://<project-ref>.supabase.co/functions/v1/push-due-reminders' \
     -H "Authorization: Bearer <service-role-key>" -H 'Content-Type: application/json' -d '{}'
   ```

   With nothing due in exactly 30 or 7 days it will correctly send nothing and
   answer `{"pushed": 0}`. Give a reminder a due date exactly 7 days out to
   test. The two days are `REMINDER_LEAD_DAYS` in the function and
   `notificationLeadDays` in the app, and a CI test fails if they ever
   disagree.

   An answer with `push_skipped` in it means step 2's secret is not set:
   webhooks went, pushes did not. `delivered` appears only when a webhook was
   called, and counts the ones that answered in the 200s.

   To try the path the schedule takes instead, run
   `select public.run_due_reminders_push();` and read the newest row of
   `net._http_response` once the run has had time to finish.
4. Signing out deletes that device's row; check it disappears.

## 4a. What changes in the app the moment push is configured

Two things happen from the dart-defines alone, with no further switch:

- **The device stops scheduling its own reminders**
  (`lib/core/notifications/notification_providers.dart:31`). The server becomes
  the only thing that decides when a nudge fires. The two cannot be made to
  agree — the server projects a distance-based due date from a fallback rate
  while the app measures the real one — so running both would tell a household
  about one oil change twice, on two different days.
- **Settings say so.** The reminders section reads "Everyone in this garage is
  notified" instead of "Only this device is notified", which is the answer to
  the question a member with a phone that never buzzes will otherwise ask.

The consequence to hold on to: **if the schedule is not switched on, nobody
gets anything** — no push, and no `reminder.due` webhook either. Configuring
Firebase without finishing step 3 is worse than not starting, because the local
fallback has stood down. Do the whole runbook in one sitting, and check step 4.

A push carries **keys, not sentences** — service type keys, the car, and the
due day. The device turns them into words in its own language
(`lib/core/notifications/push_reminder.dart:16`), which is why nothing here
stores anyone's language.

## 5. Before you ship it — the disclosure is not optional

Push creates a device identifier that leaves the phone, which location never
did. Already written down, but the Play form is filled in by hand:

- `PRIVACY.md` and `web/privacy.html` describe the registration token and name
  Google as a processor. `test/legal/privacy_policy_test.dart` keeps the two in
  step.
- Play → **Data safety** must now declare **Device or other IDs**. The row and
  the reasoning are in [play-store-listing.md](play-store-listing.md).

Declaring it is the part people forget, and a Data safety form that disagrees
with the app's behaviour is a common rejection.
