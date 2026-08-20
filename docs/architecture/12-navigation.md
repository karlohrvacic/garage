# Navigation and information architecture

Twenty-seven routes, five bottom tabs, and one window that may be a phone or a
desktop browser. This is how they fit together, and what went wrong the last
time they did not.

## The five tabs

`lib/core/widgets/garage_bottom_nav.dart` owns the destinations. Material allows
a maximum of five in a `NavigationBar`, and all five are spent:

| Tab | Route | What it answers |
|---|---|---|
| Dashboard | `/` | What needs attention now |
| Garage | `/vehicles` | Which cars, and one car in detail |
| Timeline | `/timeline` | What happened, searchable |
| Planner | `/planner` | What is coming, and what to group into one visit |
| More | `/more` | Everything the other four could not hold |

On a wide window the same list becomes a `GarageNavigationRail`; a pushed screen
keeps the rail rather than swapping it for a back button, because a browser
window that loses its navigation on every push leaves the back button as the only
way out (`lib/core/widgets/page_scaffold.dart:47`).

## The fifth tab is "More", not "Settings"

Four features are not tabs and never can be: Statistics, the trip log, fuel
stations, the calculator. The garage's own screen — members, invites, renaming —
is a fifth. They have to live somewhere, and for most of the app's life that
somewhere was called *Settings*.

Nobody looks under Settings for the people they share a car with. For an app
whose premise is shared upkeep, that was its most consequential misplacement, and
it was not the only cost: Settings had grown to 21 rows of which several were not
settings at all (API access, CSV import, backups, About, Diagnostics).

So the tab is **More**, Settings is one row inside it, and the imports, exports
and backups moved to their own screen at `/data`
(`lib/features/settings/screens/more_screen.dart`,
`lib/features/settings/screens/data_screen.dart`). The tab did not change what it
holds so much as stop lying about it. See decision 43.

`secondaryDestinations()` in `lib/core/widgets/secondary_destinations.dart` is the
single list of non-tab destinations, feeding both the desktop rail and the More
screen. It is one list because the two had already drifted: the rail's own
comment said "on a phone these live under Settings", and only the garage did.

## A feature you can only reach after using it is not reachable

The failure that motivated the restructure is worth stating plainly, because it
is easy to reintroduce. On a phone, Statistics, stations and the calculator were
reachable only through unlabelled icons in the dashboard app bar. The trip log
was worse: its only entry point was a timeline row for a trip already logged.

Two guards exist against a repeat:

- `test/features/settings/more_screen_test.dart` asserts every non-tab
  destination has a labelled entry point, by key and by word.
- The same file asserts the trip log opens before any trip exists.

## Toolbars are fixed-width rows

An app bar lays its title and actions out in a row that cannot wrap. A text
control in `actions` therefore competes with the title for a width neither can
give up, and the loser is an overflow — not a wrap, not an ellipsis, an
exception. Statistics overflowed by 46 pixels at twice the default text size,
because the toolbar carried a title, a vehicle-name dropdown and an icon button.

The rule this leaves: **app-bar actions are icons; anything with a variable-width
label belongs in the body.** Statistics now puts its vehicle picker beside the
period bar (`lib/features/stats/screens/stats_screen.dart:104`), which is also
where someone would look for a filter.
`test/features/stats/stats_screen_test.dart` pumps the screen at
`TextScaler.linear(2)` and asserts both that nothing throws *and* that the filter
is still on screen — surviving by hiding the control would pass the first
assertion and lose the feature for exactly the people who need the layout to
hold.

When adding such a test, wrap the screen with
`MediaQuery.of(context).copyWith(textScaler: …)`, never a bare `MediaQueryData`:
a fresh one has a zero size, every adaptive layout in the app asks MediaQuery how
wide the window is, and the test then silently exercises the phone path.

## A fixed footer takes height the list is for

A tab that ends in a fixed block gives that block its height first and hands the
scrolling content whatever is left. The vehicle Service tab did exactly that —
the recalls card plus a row of three buttons, capped at 60% of the tab — so on a
phone the schedule the tab exists to show was squeezed into the strip above it.
Capping the footer stopped it overflowing at large text sizes; it did not stop
it taking.

The shape that works, and what the Service tab does now
(`lib/features/vehicles/screens/vehicle_detail_screen.dart:411`):

- **Anything that is content scrolls with the content.** The recalls card is a
  `footer` on `MaintenanceProjectionList`, inside its `ListView`
  (`lib/features/maintenance/screens/maintenance_screen.dart:343`), so it is
  reached by scrolling past the schedule rather than by taking room from it. It
  is passed to the empty state too: a car with nothing due is not a car with
  nothing to offer.
- **The everyday action is a FAB**, on a `Scaffold` belonging to the tab rather
  than to the screen. The vehicle screen holds four tabs and one app bar, and
  hanging a tab-specific action off it would mean threading the tab index
  through a widget with no other reason to know it.
- **The once-in-a-while actions go in the menu.** The calendar and tyre sets
  moved into the vehicle's `PopupMenuButton` beside edit, transfer and report.

## Acting where you are told something

A screen that describes work and then sends you elsewhere to do it spends the
trip it exists to save. Three places carry the same prefill seam
(`showServiceEntrySheet(..., initialServiceTypeKeys: {…})`): the dashboard bundle
card, the maintenance screen, and — since the restructure — the planner
(`lib/features/planner/screens/planner_screen.dart`). All three refuse to offer
it when a bundle spans two cars, because a service entry belongs to one vehicle
and guessing which would be worse than not offering.

**The same gesture has to be the same control on every surface that offers it.**
Trimming an item out of a suggestion is an icon with a tooltip on both the
dashboard card and the planner, and both follow it with the same note once
something has been trimmed. It was a word on the planner for a while — the
dashboard had already replaced it, for reasons its own comment spells out, and
the planner kept rendering `bundleExclude` as a visible button, which Croatian
reads as "Preskoči": *Skip*, beside a brake fluid change. A string safe as a
tooltip is not automatically safe as a label.

## Links from outside: what Android will and will not open

Two kinds of URL open this app directly, and they work for the same reason and
fail for the same one. `web/.well-known/assetlinks.json` delegates
`handle_all_urls` for `garage.hrva.cc`, and the manifest's `autoVerify` filter
claims two prefixes: `/join` for invites and `/auth/confirm` for emailed
confirmation and password-reset links.

**Android matches an app link against the URL the person taps, not against
where it ends up.** Supabase's default `{{ .ConfirmationURL }}` points at the
project's own `/auth/v1/verify`, which 302s here afterwards. That is a host no
app claims, so the browser takes the tap and keeps it; the redirect arriving in
an already-open tab is not offered to the app. No manifest entry can fix that,
because the app was never asked.

So the templates in `supabase/templates/` build the link against this host and
carry the token hash instead:

```
{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&amp;type=email
```

`ConfirmEmailScreen` spends the hash through `verifyOTP`
(`lib/features/auth/data/supabase_auth_repository.dart:62`), which signs the
user in and — for `type=recovery` — raises `passwordRecovery`, the event
`main.dart` answers with the new-password prompt. The same URL still loads the
web build for anyone without the app, which is the common case: people register
on a phone and read mail on a laptop. That path also no longer needs a PKCE
verifier from the original device, which the old flow did.

`confirmEmailRoute` sits outside both gates in `garageRedirect` for the same
reason `/join` does: whoever follows the link is not signed in yet, and the
sign-in gate would bounce them to a form, spending nothing and losing the
single-use token.

Four files have to agree — template, manifest, assetlinks, and the parser the
screen uses — and nothing else relates them, so
`test/ci/invite_links_test.dart` does: it fails if a template reverts to
`ConfirmationURL`, if the path prefix stops matching the route, if the two
templates swap `type=email` and `type=recovery`, or if the ampersand is left
bare in what is, after all, an HTML attribute.
