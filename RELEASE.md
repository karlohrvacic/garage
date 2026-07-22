# Releasing Garage

Two independent ways to ship, from the same codebase:

- **Web (PWA)** — fully automated. Push to `main` → GitHub Actions builds and
  publishes to GitHub Pages. Users install it from the browser. See §A.
- **Google Play** — a few manual steps, pre-filled below. See §B.

Both need a production Supabase project (§1) and the hosted privacy policy (§6).
They don't interfere; you can do web now and Play whenever.

---

## 1. Production Supabase (needed by both)

Project created in **Central EU (Frankfurt)** and connected via the **Supabase
GitHub integration**, so `supabase/migrations/` is applied automatically on push
to `main`. Two things to confirm the integration does *not* always cover:

- **Migrations applied?** Dashboard → Database → Migrations should list `0001`
  through `0008`, and the tables (`households`, `vehicles`, `fuel_entries`, …)
  should exist. If not, run `supabase link --project-ref <ref>` then
  `supabase db push` once.
- **Edge function deployed?** In-app account deletion needs it, and the GitHub
  integration usually does **not** deploy functions. Deploy it once:

  ```bash
  supabase functions deploy delete-account
  ```

  It needs no secrets — Supabase injects `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  and `SUPABASE_SERVICE_ROLE_KEY` automatically.

From **Project Settings → API**, note the **Project URL** and **anon/public key**.

---

## A. Web — Cloudflare (builds from Git)

Cloudflare builds straight from the GitHub repo on every push. Its build image
has no Flutter SDK, so `scripts/cf-build.sh` fetches a pinned Flutter and runs
`flutter build web`; `wrangler.jsonc` then serves `build/web` from the `garage`
Worker. One-time setup, in the **garage** Worker:

1. **Build → Connect to Git** → pick `karlohrvacic/garage`, branch `main`.
2. **Build settings:**
   - **Build command:** `bash scripts/cf-build.sh`
   - **Deploy command:** `npx wrangler deploy` (the default — it reads
     `wrangler.jsonc`)
   - Output/assets directory is defined by `wrangler.jsonc`; leave the preset as
     "None / no framework".
3. **Build → Variables and secrets** (the *build* ones, not runtime — runtime
   variables are correctly blocked for a static-assets Worker):
   - `SUPABASE_URL` = `https://<ref>.supabase.co`
   - `SUPABASE_ANON_KEY` = the anon/public key
4. Trigger a build (push, or "Retry"/"Create deployment"). First build is slower
   (it downloads Flutter, a few minutes); later builds reuse it.
5. **Custom domain** — the Worker → **Domains** → add `garage.hrva.cc`
   (auto-wired since the zone is on Cloudflare). Served at the root, so the
   `--base-href /` in the build is correct.

The web build is **email + password only** (Google sign-in is left off — add a
`GOOGLE_WEB_CLIENT_ID` dart-define in `scripts/cf-build.sh` later to enable it).

That's the whole web track. Every push auto-rebuilds and redeploys.

---

## B. Google Play

### 2. Env file (gitignored)

```bash
cat > env/prod.json <<'JSON'
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon public key>",
  "GOOGLE_WEB_CLIENT_ID": "<web-client-id>.apps.googleusercontent.com"
}
JSON
```

If you skip Google sign-in for v1, drop the `GOOGLE_WEB_CLIENT_ID` line — the
button then hides itself and the app is email-only.

### 3. Upload keystore (one-time, gitignored)

```bash
keytool -genkey -v -keystore ~/garage-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
# It prompts for a password and your name/org — any values are fine; remember the password.

cat > android/key.properties <<PROPS
storePassword=<the password you just set>
keyPassword=<same, unless you set a separate key password>
keyAlias=upload
storeFile=/Users/karlo/garage-upload.jks
PROPS
```

`android/app/build.gradle.kts` already reads this and signs the release build.
Enable **Play App Signing** when prompted in the Console (recommended) — Google
then manages the app key and you only keep this upload key.

### 4. Build the bundle

```bash
./scripts/build-android-release.sh
# → build/app/outputs/bundle/release/app-release.aab
```

### 5. Google sign-in (optional — can be added after launch)

In **Google Cloud Console**: OAuth consent screen, then two OAuth clients —
**Android** (package `cc.hrva.garage` + your debug SHA-1, and later the Play App
Signing SHA-1) and **Web** (copy its client id). In **Supabase → Auth →
Providers → Google**, enable it and paste the web client id into "Authorized
Client IDs". Debug SHA-1:

```bash
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android | grep SHA1
```

### 6. Host the privacy policy (both tracks)

Publish `PRIVACY.md` at **https://garage.hrva.cc/privacy** (Play requires a
reachable URL; the in-app Settings link points there). The contact email is
already set to `privacy@hrva.cc`.

### 7. Play Console

1. Create the app (name **Garage**, free, default language en; add hr).
2. **Testing → Internal testing → Create release → upload the AAB.** Add your
   own email as a tester. (Internal testing skips the long production review.)
3. **Main store listing** — copy from `docs/play-store-listing.md`
   (title/short/full, EN + HR). Upload:
   - App icon: `assets/store/play-icon-512.png`
   - Feature graphic: `assets/store/feature-graphic.png`
   - 2–8 phone screenshots (capture from the running app — the 6 in the listing).
4. **App content:**
   - **Privacy policy:** the URL from §6.
   - **Data safety:** the fill-in table in `docs/play-store-listing.md`.
   - **Content rating** (IARC questionnaire) — answer honestly; for this app:
     category *Utility/Productivity*; **no** violence, sexual content, profanity,
     drugs, gambling; **no** public user-to-user content or chat; users share
     vehicle data only within their own private household. Result: **Everyone /
     PEGI 3**.
   - **Target audience:** 18+ (or 13+); not designed for children.
   - **Ads:** No.
5. Roll out to Internal testing, install via the opt-in link on your phone, and
   walk the smoke test (sign up → household → vehicle → two fills → economy →
   two close intervals → bundle card → second device joins → sync).
6. When happy, promote the release to **Production** and submit for review.

---

## What's automated vs. manual

| | Web | Play |
|---|---|---|
| Build | ✅ CI on every push | `./scripts/build-android-release.sh` |
| Sign | n/a | upload keystore (one-time) |
| Deploy | ✅ automatic | manual upload to Console |
| Store review | none | first submission only |
| Backend | Supabase (§1) | Supabase (§1) |
