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

## 3. Deploy and schedule the sender

Edge functions are not deployed by the migration integration; they need this by
hand:

```bash
supabase functions deploy push-due-reminders
```

Then schedule it daily (Dashboard → SQL editor; `pg_cron` and `pg_net` are both
available). It pushes an item at exactly 14, 7, 1 and 0 days out, so running
once a day makes those single-shot without any bookkeeping table:

```sql
select cron.schedule(
  'push-due-reminders-daily',
  '0 6 * * *',
  $$
  select net.http_post(
    url := 'https://<project-ref>.supabase.co/functions/v1/push-due-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || '<service-role-key>'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

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

   With nothing due in exactly seven days it will correctly send nothing. Give
   a reminder a due date exactly 7 days out to test. Seven is
   `REMINDER_LEAD_DAYS` in the function and `notificationLeadTime` in the app,
   and a CI test fails if those two ever disagree.
4. Signing out deletes that device's row; check it disappears.

## 4a. What changes in the app the moment push is configured

Two things happen from the dart-defines alone, with no further switch:

- **The device stops scheduling its own reminders**
  (`lib/core/notifications/notification_providers.dart:39`). The server becomes
  the only thing that decides when a nudge fires. The two cannot be made to
  agree — the server projects a distance-based due date from a fallback rate
  while the app measures the real one — so running both would tell a household
  about one oil change twice, on two different days.
- **Settings say so.** The reminders section reads "Everyone in this garage is
  notified" instead of "Only this device is notified", which is the answer to
  the question a member with a phone that never buzzes will otherwise ask.

The consequence to hold on to: **if the cron is not scheduled, nobody gets
anything.** Configuring Firebase without finishing step 3 is worse than not
starting, because the local fallback has stood down. Do the whole runbook in
one sitting, and check step 4.

A push carries **keys, not sentences** — service type keys, the car, and the
due day. The device turns them into words in its own language
(`lib/core/notifications/push_reminder.dart:15`), which is why nothing here
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
