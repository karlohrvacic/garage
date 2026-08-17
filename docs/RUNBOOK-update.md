# Shipping an update

`RELEASE.md` covers the **first** release — creating the Supabase project, the
keystore, the Play listing. This is the shorter loop you run every time after
that: ship a new version to an existing listing, keep the backend ahead of the
app, and keep the privacy disclosures true.

Order matters. The backend goes first, because an old app must keep working
against the new database, but a new app must never meet an old one.

---

## 1. Before you build

**The version is not yours to type anywhere.** The tag is the version:

```bash
git tag v1.3.1 && git push origin v1.3.1
```

That is the whole act of versioning. The workflow takes the marketing version
from the tag and the build number from the commit count, and passes both into
the build, so a release cannot call itself something its tag does not say. The
build number always increases and can never repeat one Play has accepted, which
is the failure that otherwise ends a release.

`pubspec.yaml` and `lib/core/app_info.dart` still carry a version, but only as
the fallback a local build shows, since a local build has no tag to read. They
do not need bumping in order to release. An earlier design required bumping both
by hand, and that is exactly what once stopped a release: the tag said 1.3.1
while pubspec still said 1.3.0.

Pushing the tag builds, runs analyze and the full suite, signs with the upload
key, uploads to the **alpha** track, and opens a GitHub release carrying the
same notes that went to Play.

**The tag also chooses the track**, as a suffix:

| Tag | Lands on |
|---|---|
| `v1.3.1` | **alpha**, the closed test |
| `v1.3.1-internal` | internal, your own devices |
| `v1.3.1-beta` | open testing |
| `v1.3.1-production` | production, once access is granted |

A bare tag means alpha because the closed test is the only track that counts
toward the 12-testers-for-14-days requirement standing between this app and
production access. A build sent to `internal` advances nothing, however
convenient it is. The version is the tag with the suffix stripped, so
`v1.3.1-beta` still ships as 1.3.1.

An unrecognised suffix fails the job rather than guessing, because guessing
means shipping to the wrong audience. Running the workflow by hand from the
Actions tab still works and picks the track from a dropdown; a manual run has no
tag, so its version falls back to pubspec.

**If a tag was pushed before the code was ready**, move the tag onto the right
commit rather than inventing a new version: remove it locally and on the remote,
then create it again on the commit you want.

**Release notes live in `distribution/whatsnew/`**, one file per language
(`whatsnew-en-GB`, `whatsnew-hr`). They are reviewed alongside the code they
describe, and `test/ci/deploy_workflow_test.dart` fails if either is missing or
runs past the 500 characters Play accepts.

**Deploy the backend first.**

Migrations apply themselves: the Supabase GitHub integration runs everything in
`supabase/migrations/` on push to `main`. **Edge functions do not** — the
integration does not deploy them, so every function that changed needs a manual
push:

```bash
supabase link --project-ref <ref>        # once per machine
supabase functions deploy public-api
supabase functions deploy dispatch-webhooks
supabase functions deploy delete-account
supabase functions deploy push-due-reminders
```

Then confirm in the dashboard (Database → Migrations) that `0001`–`0025` are
all listed. If the integration missed them, `supabase db push` applies the
backlog.

Migrations `0015`–`0025` (tank capacity, attachments, public API, tracking
depth, household country, admin actions, issue log, fault codes, tyre sets,
webhook dispatch) are new since the last shipped build. Two things the SQL
cannot do for itself: `0016`'s private `attachments` bucket must exist under
Storage, and `0024`'s webhook triggers stay dormant until the project's
endpoint is inserted into `webhook_dispatch_config`. Both are in `RELEASE.md`
§1.

**Verify against the real project**, not just locally:

```bash
flutter analyze && flutter test                # 850 tests
SUPABASE_URL=… SUPABASE_ANON_KEY=… dart test test_rls/rls_test.dart   # 35 tests
```

The RLS suite is the one that matters most here: it is the only thing that
proves migration `0016`/`0017`/`0023` did not open one household's data to
another. Run it against a **staging** project or a local `supabase start`,
never production — it creates users and rows.

---

## 2. Google Play

### Build and upload

Both are the workflow's job now:

```bash
git tag v1.3.1 && git push origin v1.3.1                    # alpha
git tag v1.3.1-internal && git push origin v1.3.1-internal  # your devices
```

Or Actions → **Deploy to Play** → *Run workflow* → pick a track. Before it builds
anything it checks the signing secrets are actually set, so a missing secret
costs ten seconds rather than a full build. Then it runs `flutter analyze` and
the whole suite, because a release nobody checked is not a release. After
building it reads the bundle's own certificate and stops if it is debug-signed,
rather than letting Play be the thing that tells you.

To build one by hand anyway:

```bash
./scripts/build-android-release.sh
```

### Release notes

Edit `distribution/whatsnew/whatsnew-en-GB` and `whatsnew-hr`; the workflow
uploads them with the bundle and copies the English one into the GitHub release.
Nothing is pasted into the Console. Keep each under 500 characters — the test
suite enforces it, so you find out before the upload rather than during it.

### Staged rollout

Start production at **20%**, watch for two days, then go to 100%. The Play
Console's *Android vitals* crash rate is the signal; a household app has few
enough users that one crash loop is visible immediately.

If something is wrong, *Halt rollout* stops new installs but **does not** roll
anyone back — the fix is a new build number, which is why step 1 insists on
keeping them monotonic.

### What forces a Data safety re-review

The form at Play → *App content* → *Data safety* is already correct for this
release (`docs/play-store-listing.md` has the exact answers). Re-open it only
when one of these changes:

| Change | Data safety consequence |
|---|---|
| Adding push notifications | **Declare "Device or other IDs"** — an FCM token is a device identifier stored server-side |
| Adding any analytics or crash reporting | Declare the type **and** switch "Shared" to Yes for the vendor |
| Storing location (not just linking to a map) | Declare Location; currently the app only opens an external map URL |
| A new attachment kind (video, audio) | Extend the Photos/Files rows |

An update that only adds features over data types you already declare needs no
form change and no extra review time.

---

## 3. Firebase / push notifications

**Current state:** reminders are **local** notifications scheduled on the
device (`flutter_local_notifications`). They fire without a server and without
Firebase. The server half of push is already in the repo — migration
`0013_device_tokens.sql` and the `push-due-reminders` edge function — but the
**client is deliberately not wired**, because adding the Firebase SDK changes
the Android build and cannot be done without a real Firebase project.

**When to add it:** when a reminder needs to reach a household member whose
phone did not create it — that is the case local notifications structurally
cannot cover.

`docs/RUNBOOK-push.md` has the step-by-step (Firebase project → Android app →
`google-services.json` → `firebase_core` + `firebase_messaging` → token
registrar → cron schedule). Three things that runbook assumes you know and that
bite on the way:

1. **Use the Google Cloud project you already have** for Google sign-in. A
   second project means a second OAuth consent screen and two sets of SHA-1s.
2. **`POST_NOTIFICATIONS` is already in the manifest**, so Android 13+ will
   prompt — but only when you call `requestPermission()`. Ask at a moment the
   user understands (after they set their first reminder), not at launch.
3. **Adding push changes the Data safety form** (see the table above). Do that
   in the same release, not after — a mismatch between behaviour and the
   declaration is the kind of thing that gets an app suspended rather than
   asked about.

Cost: FCM is free at any volume this app will see. The Supabase cron job is one
HTTP call a day.

---

## 4. Privacy updates

`PRIVACY.md` is the source of truth. `web/privacy.html` is what Play links to
and what the app opens from Settings → Privacy policy. Two tests
(`test/legal/privacy_policy_test.dart`) fail if they drift apart or carry
different dates — that check exists because the hosted page was once materially
older than the policy, missing whole data categories.

**Every time you change what the app does with data:**

1. Edit `PRIVACY.md` — the section, and the `_Last updated: YYYY-MM-DD_` line.
2. Mirror the change into `web/privacy.html`, including the date.
3. `flutter test test/legal/` — this is what proves the two agree.
4. Deploy the web build (GitHub Actions on push to `main`), so the hosted page
   updates before the app that references it reaches users.

**What counts as a change worth disclosing:** a new data type stored (the
attachments in this release), a new third party the data reaches (the NHTSA VIN
lookup — a transfer to the US), a new retention period, or a new user-directed
transfer (webhooks). Adding a screen that shows data you already store is not a
privacy change.

**Material changes need more than a new date.** Adding analytics, sharing with
a new processor, or changing the legal basis means telling existing users
in-app before it takes effect — under GDPR a quiet edit to a policy page is not
consent. Nothing in this release is material in that sense: attachments and
tyre data are the user's own records, held the same way and under the same
basis as everything else.

> Not legal advice. For a real EU public launch, have a lawyer read
> `PRIVACY.md` and the Data safety answers together — they must say the same
> thing, and the Play form is the one Google enforces.

---

## Quick checklist

- [ ] Version decided, which means only choosing the tag (nothing to edit)
- [ ] Migrations `0001`–`0023` listed in the dashboard; all four functions deployed
- [ ] `flutter analyze`, `flutter test`, `dart test test_rls/` all green
- [ ] Tag pushed (`git tag v1.3.0 && git push origin v1.3.0`) — the workflow builds, signs and uploads
- [ ] `distribution/whatsnew/` updated in **both** en-GB and hr
- [ ] Data safety re-checked only if the table in §2 says so
- [ ] `PRIVACY.md` and `web/privacy.html` agree, and the hosted page is live
- [ ] Rollout started at 20%
