# Getting production access: the 12-tester closed test

Google locks production for personal developer accounts created on or after
13 November 2023 until a **closed test** has run with **at least 12 testers
opted in continuously for 14 days**. The Play Console dashboard tracks it as
three checkboxes; ours currently reads `0 testers currently opted in`.

Two things that cost people weeks:

- **Internal testing does not count.** Only a *closed* track accrues toward the
  requirement. An internal release is still useful for testing on your own
  phone, and ticks nothing.
- **The clock starts at the 12th opt-in**, not at the first. Eleven testers for
  ten days counts as zero. It also measures the *last* 14 days continuously —
  drop to 11 and the window rebuilds from when you are back at 12.

Organization accounts (registered with a D-U-N-S number) are exempt entirely.
If converting is ever on the table, it removes this requirement for every
future app, not just this one — but verification takes weeks, so it is not a
shortcut for a launch in progress.

---

## 1. Publish the closed release first

The 14 days cannot begin until the release is **approved**, and review takes
about a day (up to three for a new account). So this goes first, before any
recruiting.

Play Console → **Testing → Closed testing** → use the default *Alpha* track →
upload the same `app-release.aab` that went to internal testing → release notes
in **en-GB and hr** (drafted in `RUNBOOK-update.md` §2) → submit.

**Country availability is the trap.** A tester in a country the track does not
include gets a 404 on the opt-in link and cannot install, while your count sits
stubbornly at 11. Include Croatia and every country a tester actually lives in.

## 2. Collect Gmail addresses, then send the link

Closed testing only admits addresses on your list — the opt-in link is not a
public invitation. So the order is: collect addresses → add them under the
**Testers** tab → send each person the opt-in link.

Recruit **15–18**, not 12. A single drop-out below the floor breaks continuity,
and rebuilding costs more days than over-recruiting costs effort.

Where they realistically come from, best fit first:

1. **Colleagues** — a dev office is a dozen Android phones in one room, and
   they will actually open the app.
2. **People who own cars.** This app is for households with vehicles: Croatian
   car groups on Facebook, forum.hr's auto section, the local car club. Real
   users produce real feedback, and the production-access questionnaire is
   scored against what you did with that feedback.
3. **Tester-exchange communities** — free, but budget 2–4 weeks to accumulate
   enough credits.
4. **Paid tester services** (~$15–20). Google's own questionnaire lists paid
   testing as a recruitment channel; disclose it honestly and it is fine.

## 3. The invite

### English

> **Looking for Android testers (2 weeks)**
>
> I've built **Garage** — an app for keeping track of the cars in a household:
> fuel fill-ups and consumption, servicing, running costs, and what falls due
> next (registration, roadworthiness test). It's free, with no ads and no
> subscription, and everything you log can be exported as CSV whenever you like.
>
> To publish it on Google Play I need 12 people to test it for 14 days. If you
> have an Android phone and a car, it should genuinely be useful to you rather
> than a favour.
>
> What it takes:
>
> 1. Send me the **Gmail address you use on your phone**
> 2. Open the link I send back and tap **"Become a tester"**
> 3. Install Garage from the Play Store (it won't show up in search — the link
>    is the only way in)
> 4. Use it now and then over the next two weeks, and stay opted in
>
> That's it. If something breaks or annoys you, tell me — that's the point.

### Hrvatski

> **Tražim testere za Android aplikaciju (2 tjedna)**
>
> Napravio sam **Garage** — aplikaciju za vođenje evidencije o autima u
> kućanstvu: točenja goriva i potrošnju, servise, troškove i što sljedeće
> dolazi na red (registracija, tehnički). Besplatna je, bez oglasa i pretplate,
> a sve što upišeš možeš u svakom trenutku izvesti u CSV.
>
> Da bih je objavio na Google Playu, treba mi 12 ljudi koji će je testirati 14
> dana. Ako imaš Android i auto, vjerujem da će ti stvarno koristiti, a ne da mi
> samo činiš uslugu.
>
> Što treba napraviti:
>
> 1. Pošalji mi **Gmail adresu koju koristiš na telefonu**
> 2. Otvori link koji ti pošaljem i klikni **"Postani tester"**
> 3. Instaliraj Garage s Play Storea (nećeš je naći pretragom — jedini put je
>    preko linka)
> 4. Koristi je s vremena na vrijeme sljedeća dva tjedna i ostani prijavljen
>
> To je sve. Ako nešto ne radi ili ti smeta, slobodno javi — upravo to i tražim.

### What testers get wrong

Four failure modes account for nearly every "I joined but I'm not counted":

- They opt in with one Google account and their phone is signed in to another.
  The address you added must be the one **active on the phone**.
- They tap the link but never tap **"Become a tester"** — the opt-in is that
  button, not the click-through.
- They opt in but never install. Opting in and installing are separate steps.
- They search the Play Store for "Garage" and don't find it. Closed tests are
  not discoverable; the link is the only route.

## 4. During the 14 days

- **Check the Console count daily.** It is the only count that matters — not
  what people told you on WhatsApp. It can lag opt-ins by up to 24 hours.
- **Replace flat-liners early.** Testers who installed and never opened the app
  keep your headcount but produce the flat engagement that gets production
  access rejected with "continue testing with real testers".
- **Keep notes as you go**: what testers reported, what you changed, what you
  decided not to change and why. The questionnaire asks exactly this, and
  reviewers read the answers against your engagement data — vague answers from
  a real test still get bounced.
- Ship fixes to the closed track as you go. Updating the build does not reset
  the window; the opt-ins are what the clock follows.

## 5. After the 14 days

Publishing overview → **Production → Apply for production access** → the
questionnaire (~10 questions on recruitment, feedback, and changes made) →
3–7 business days for review.

Then the staged rollout from `RUNBOOK-update.md` §2: 20% first, two days of
Android vitals, then 100%.

> Numbers here are current as of August 2026 — the requirement was 20 testers
> until Google reduced it to 12 in 2025, so older guides disagree. Your own Play
> Console dashboard is the authority for what applies to this account.
