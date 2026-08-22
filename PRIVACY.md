# Garage — Privacy Policy

_Last updated: 2026-08-17_

Garage ("the app") is a free shared vehicle-upkeep app: fuel logging, a
maintenance calendar, and smart maintenance bundling, shared across the members
of a garage. This policy explains what data the app processes, why, and the
choices you have. It is written to be accurate to how the app actually works.

> **Not legal advice.** This is a good-faith draft. Before a public EU launch,
> have a lawyer review it against the GDPR and ePrivacy Directive, and confirm a
> Data Processing Agreement (DPA) is in place with Supabase.

## Who is responsible

The data controller is the operator of **garage.hrva.cc**. For any privacy
request, contact **garage@hrva.cc**.

## What the app collects

The app only stores what you enter or what is needed to run your account:

- **Account:** your email address and a display name.
- **Vehicles:** nickname, and any optional details you add — make, model, year,
  trim, licence plate, VIN, and a photo.
- **Fuel entries:** date, odometer, volume, price, total, station, and notes.
- **Service and maintenance:** dates, odometer, service types, cost, shop, notes,
  and the reminder intervals you set.
- **Garage:** which garage you belong to and your role in it.
- **Cost entries:** date, category, amount, odometer, and notes.
- **Income entries:** date, kind, amount, odometer, and notes — including what a
  vehicle sold for, if you record it.
- **Odometer readings:** date and reading, when you log one on its own.
- **Trips:** date, distance, how long it took, whether it was private or
  business, and the **place names you type** for where a journey started and
  ended. Those are text you write, not a position the device measured — the app
  never records where you have been.
- **Attachments:** any receipt, invoice, or document you choose to attach to an
  entry, along with its file name and size. Files are stored in a private
  bucket and are only reachable through short-lived links issued to members of
  your garage.
- **API keys and webhooks:** if you create them (Settings → API access), we
  store a name, a hash of the key — never the key itself — when it was last
  used, and any webhook URL you register with the secret used to sign calls to
  it.

### VIN lookups (only when you ask for one)

The vehicle form has a **Look up** button next to the VIN field. Pressing it
sends that VIN — and nothing else — to the United States NHTSA vPIC registry
(`vpic.nhtsa.dot.gov`), a free government service, to fill in make, model, and
year. This is a transfer outside the EU, it happens only when you press the
button, and no account data accompanies it. Leave the button alone and no VIN
ever leaves your device.

The vehicle's Service tab has a **Check for recalls** button. Pressing it sends
the make, model, and year — and nothing else — to the same registry
(`api.nhtsa.gov`) to look for open safety recalls. This is also a transfer
outside the EU, it also happens only when you press the button, and it is asked
for once per visit rather than remembered. The registry is American, so a
European vehicle may have recalls that never appear there and a match may not
apply to a European build; the app says so beside the button.

### Webhooks (only if you register one)

If you register a webhook, entries logged in your garage are posted to the
URL **you** chose, signed with that webhook's secret. You are choosing where
that data goes; we deliver it to that address and record only the status of the
last attempt.

### Location (fuel stations, and filling in a fill-up)

If you grant the location permission, your device position is used **on the
device only**, for two things: sorting nearby fuel stations by distance, and —
when you are recording a fill-up at a station — filling in that station's name
and its currently posted price for your fuel. The station list and its prices
are already on your phone; matching your position against them happens there.

Your location is never sent to our servers and never stored. If you decline the
permission, both features simply do nothing and the rest of the app works
unchanged. The permission is requested only from the Fuel stations screen or
from the control in Settings that explains it, never in the background.

### Push notifications (only if you enable them)

If you allow notifications, Firebase Cloud Messaging issues your device a
**registration token**. We store that token, and which account it belongs to, so
a reminder that becomes due can be sent to the right devices. It is a device
identifier: it identifies the installation, not you personally, and it changes
if you reinstall the app or clear its data.

Google acts as a processor for delivery (see below). The message itself carries
only what the reminder says — a vehicle's name and what is due. Signing out
deletes the token for that device, and deleting your account deletes all of
them.

## What the app does **not** collect

- No location data stored or transmitted to our servers (see the location note
  above for on-device use).
- No advertising identifiers, and no ads.
- No third-party analytics or trackers.
- No cross-app or cross-site tracking of any kind.

## Who processes your data

- **Supabase** acts as our data processor and hosts the database, authentication,
  and file storage in the **EU (Stockholm)** region. Your data stays in the EU.
- **Google** is involved in two optional places. If you choose "Continue with
  Google" to sign in, Google authenticates you and returns a token; sign in with
  email and password and it is not involved. If you allow notifications, Google
  operates Firebase Cloud Messaging, which delivers the push to your device and
  therefore processes the device's registration token and the message contents.
  Decline notifications and no token is ever created.
- **mzoe-gor.hr** (Croatian Ministry of Economy) provides the public fuel-price
  dataset shown on the Fuel stations screen. When that screen loads, your device
  requests the dataset directly from their server, which — like any web
  request — exposes your IP address to them. No account data is included in the
  request.
- **NHTSA (US Department of Transportation)** decodes a VIN when you press
  **Look up** on the vehicle form, and looks for open safety recalls when you
  press **Check for recalls** on the Service tab. Both only on a press. See the
  VIN section above.
- **Anywhere you point a webhook.** A webhook you register sends your own
  garage's entries to a server of your choosing; that server is outside our
  control and governed by whatever policy applies to it.

Your data is transmitted over encrypted connections (HTTPS/TLS).

## How your data is shared

Your vehicle, fuel, and maintenance data is visible to the other members of your
garage — that is the whole point of sharing one. It is never visible to any
other garage, or to anyone outside yours. Access is enforced at the
database level by row-level security, not only in the app.

## Retention and deletion

- Your data is kept until you delete it.
- **Attachments** are deleted with the entry they belong to, with the vehicle,
  and with the garage — the file is removed from storage, not just its
  record.
- **Deleting your account** (Settings → Delete account) removes your account
  immediately. If you are the last member of a garage, that garage's
  vehicles and all their history are deleted along with it.
- **Leaving a garage** removes your membership; a garage with no members
  left is deleted automatically.

## Your rights (GDPR)

- **Access and portability:** export all your vehicle, fuel, and service data as
  CSV from Settings → Export as CSV, at any time, without needing this app.
  Settings → Back up everything writes the whole garage — every kind of entry —
  as a JSON file you keep, and which the app can read back. A read-only API
  (Settings → API access) gives the same data as JSON on demand, so your records
  stay usable outside this app by design.
- **Erasure:** delete your account in-app, as described above.
- **Other requests** (rectification, restriction, objection, or a copy in another
  form): contact **garage@hrva.cc**.

## Children

The app is not directed at children and does not knowingly collect data from
them.

## Changes to this policy

If this policy changes, the updated version will be posted at
**garage.hrva.cc/privacy** with a new "last updated" date.
