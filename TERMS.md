# Garage — Terms of Use

> **Status: a draft for legal review, written 2026-09-17. These terms are not
> in force and are not published at garage.hrva.cc.** The questions a lawyer
> needs to answer, and the steps that publish this, are in
> `docs/TODO-manual-steps.md` §7. Delete this box when it goes live; until then
> nothing should link here.

_Last updated: 2026-09-17_

These terms are the agreement between you and the people who run Garage. They
cover the hosted service: the Android app, the web app at **garage.hrva.cc**,
and the read-only API. They are written to match how the app actually works,
and the [Privacy Policy](PRIVACY.md) explains what happens to your data.

By creating an account you accept them. If you use Garage for a business, you
accept them for that business as well.

## Who runs Garage

Garage is run by **Karlo Hrvačić** ("we", "us"), **[postal address, to be filled
in before publication]**. You can reach us at **garage@hrva.cc**.

## Your account

- You need to be **at least 16 years old** to have an account.
- Give a real email address and keep your password to yourself. An account is
  for one person. To share cars with somebody, share a garage rather than a
  login.
- You are responsible for what is done through your account. If you think
  somebody else has got into it, tell us.

## Garages, members and guests

Garage is built for sharing, so it matters who can see what.

- **What you log in a garage belongs to that garage.** Every member can see it.
  If you leave, or delete your account while other members remain, your entries
  stay with the garage, without your name on them. If you are the last member,
  the garage and everything in it is deleted with you.
- **Admins** can remove members and vehicles, and can delete the garage, which
  deletes it for everyone in it. If the only admin leaves, the longest-standing
  member becomes admin.
- **Lending a car** gives somebody a code for one vehicle, for the dates you
  choose. Whoever holds it always sees that car's own details, its current
  odometer reading, when its insurance, green card and roadworthiness run out,
  the problems still open on it, and the tyres it is on. Beyond that they see
  and log only what you allowed. What they log stays in that vehicle's history after their access
  ends.
- **Transferring a vehicle** to another garage moves it and its whole history
  out of yours. **Merging** two garages moves the vehicles, their history and
  the members into one and deletes the other, along with what belonged only to
  it, such as its API keys and webhooks. **Neither can be undone**, by you or
  by us.
- You decide whom to invite, lend to or hand a vehicle to. Anybody you let in
  can see what that access shows them, and we cannot take back what they have
  already seen.

## What you put into Garage

Your records are yours. You give us permission to store them, back them up,
process them and show them to you and to the people you share with, because
that is what running the service means. We do not sell them and we do not use
them for advertising.

You are responsible for what you enter. That includes having the right to enter
it: a driver's name, a photo of a document with somebody's details on it, or
anything else about another person.

## Using Garage fairly

Please do not:

- reach for garages, vehicles or accounts you have not been given access to, or
  try to get round the controls that keep garages apart;
- probe, scan or load-test the service, or send it traffic that makes it worse
  for everybody else. **The API has no fixed rate limit today. Use it the way a
  household would**: reading your own data every few minutes is fine, hammering
  it is not. We may slow down or revoke a key that puts the service at risk;
- upload anything unlawful or harmful, or use attachments as general file
  storage. They are for receipts, invoices, vehicle documents and photos, up to
  10 MB each;
- point a webhook at a system that is not yours or that has not agreed to
  receive your data;
- create accounts by script, or pretend to be somebody else.

If you believe something stored in Garage is illegal, write to
**garage@hrva.cc** and say what it is and where. We will look at it, and we may
remove it or restrict the account it came from.

## What the numbers are, and what they are not

Garage is a logbook that does arithmetic. **Everything it shows is worked out
from what you and your garage typed in**, so a wrong entry gives a wrong answer,
and nothing in it has been checked against the vehicle itself.

- **Due dates are estimates.** A maintenance date is projected from how the car
  has lately been driven, which is why the app calls a projected date
  "Expected". It does not replace the manufacturer's service schedule, a
  mechanic's judgement or a legal deadline. **Registration, roadworthiness
  tests, insurance, vignettes and the like remain your responsibility, whether
  or not a reminder reached you.**
- **Reminders can fail to arrive.** Notifications depend on your phone's
  settings, its battery saving, your connection and services we do not run.
- **Tyre figures are an aid, not an inspection.** Age, wear estimates and the
  legal-minimum warning come from the readings you entered.
- **The check before a long drive** lists what your own records say falls due
  over the journey. It is not a roadworthiness check and says nothing about the
  tyres, lights or brakes.
- **Reports are your records, printed.** The seller's report, the sheet for the
  mechanic, the maintenance history, the mileage logbook and the rest are
  compiled from what the garage logged. They are not an official mileage
  statement, not an inspection, and they verify nothing. If you hand one to a
  buyer, a mechanic or an authority, you are the one standing behind what it
  says.
- **The mileage logbook is not tax advice.** Whether it is enough for your tax
  authority is a question for you or your accountant.
- **Fuel prices** come from the Croatian Ministry of Economy's public dataset.
  They can be out of date or wrong, and a station can charge something else.
- **Recalls and VIN lookups** come from the US NHTSA registry. They may miss a
  European vehicle or not apply to one. Confirm with a dealer.
- **Route trends** report how long your journeys took, not why.
- **"Who owes whom"** is arithmetic over what was logged. It is not an account
  and it creates no debt.
- **What a car costs to own** rests on your own estimate of what it is worth.

**Do not use the app while driving.** Start and finish a drive while parked, and
write down a rattle once you have stopped, or let a passenger do it.

## What it costs

Garage is free today and has no ads, and it will never have ads. It is free for
a small garage. If paid plans for larger garages are ever introduced, you will
be told in advance, nothing will be charged without your explicit agreement,
and **what you have already logged will stay readable, exportable and deletable
without paying**.

## Availability, changes, and the end of the service

Garage is run on a best-effort basis. There is no guaranteed uptime: it can be
slow, unavailable or interrupted for maintenance, and features can change or be
withdrawn. Fill-ups, readings, journeys, costs, services, problems and their
photos entered without a connection are kept on your device and retried until
they can be sent; anything else needs a connection. That is a convenience and
not a guarantee.

**Keep your own copy of anything you cannot afford to lose.** More → Your data
exports everything as spreadsheets and backs the whole garage up to a file.

If we ever shut the hosted service down, we will say so by email to the address
on your account, and at garage.hrva.cc, at least **30 days** beforehand, so
that you can export. The
source code stays available for anybody who wants to run their own copy.

## Ending it

You can delete your account at any time from More → Settings → Delete account.
What that deletes is described in the Privacy Policy.

We may suspend or close an account that breaks these terms or puts the service
or other people at risk. Where we reasonably can, we will warn you first and
leave you time to export. For something serious we may act at once.

## Our responsibility to you

Garage is provided free of charge, as it is and as available. To the extent the
law allows, we make no promise that it is accurate, uninterrupted or fit for a
particular purpose, and we are not liable for:

- decisions made by relying on a figure, a projection or a reminder, including
  a missed deadline, a fine, a breakdown or a repair;
- loss caused by the service being unavailable, or by data being lost. Keep
  backups;
- what people you gave access to did with it;
- services run by others, listed below.

**Nothing in these terms limits liability that cannot be limited by law**,
including liability for intent or gross negligence and for death or personal
injury, **or takes away rights you have as a consumer** under the law of the
country you live in. If you use Garage for a business, our total liability to
that business is limited to the larger of what it paid us in the previous
twelve months and EUR 50.

## Services run by others

Some parts of Garage depend on other people's services, under their terms:
Google, if you sign in with Google or allow notifications; the Croatian Ministry
of Economy's fuel-price dataset; the US NHTSA registry, when you ask for a VIN
lookup or a recall check; and any server you point a webhook at. Supabase hosts
the data, in the EU, and Cloudflare serves the web app and these pages, both on
our behalf. We do not control the others and are not responsible for them.

## The software is open source

Garage's source code is published under the **GNU AGPL-3.0** at
<https://github.com/karlohrvacic/garage>. That licence governs the code. These
terms govern the service we host. If you run your own copy, you are its
operator: the AGPL applies to you, and these terms and our Privacy Policy do not
apply to it.

## Changes to these terms

The current version is always at **garage.hrva.cc/terms**, with the date it was
last changed. If a change takes away a right you have or adds an obligation, we
will tell you by email at least **30 days** before it applies. If you do not
agree, you can export your data and delete your account before then.

## Law and disputes

These terms are governed by the law of the Republic of Croatia. If you are a
consumer living elsewhere in the EU, you keep the protection of the mandatory
consumer law of your own country, and you may bring a dispute before the courts
there. Otherwise, disputes go to the competent court in Croatia.

If something has gone wrong, write to **garage@hrva.cc** first. We answer
complaints in writing within 15 days.

## Contact

**garage@hrva.cc**
