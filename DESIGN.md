---
name: Garage
description: A dark-first instrument cluster for a household's vehicles — amber readouts on asphalt, every number in tabular mono.
colors:
  bg: "#0F1114"
  surface: "#1A1D21"
  fg: "#F2F3F0"
  muted: "#8A9098"
  border: "#262B31"
  accent: "#FFB020"
  accent-on: "#1A1400"
  success: "#35C46B"
  warn: "#FFC94D"
  danger: "#FF4D3D"
typography:
  headline:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 600
    lineHeight: "32px"
    letterSpacing: "-0.5px"
  title:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: "28px"
    letterSpacing: "-0.5px"
  body:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: "24px"
  readout:
    fontFamily: "JetBrains Mono, ui-monospace, monospace"
    fontSize: "24px"
    fontWeight: 400
    lineHeight: "32px"
    fontFeature: "tnum"
  eyebrow:
    fontFamily: "JetBrains Mono, ui-monospace, monospace"
    fontSize: "11px"
    fontWeight: 500
    lineHeight: "16px"
    letterSpacing: "1.5px"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "9999px"
spacing:
  space1: "4px"
  space2: "8px"
  space3: "12px"
  space4: "16px"
  space5: "20px"
  space6: "24px"
  space8: "32px"
  space12: "48px"
  space20: "80px"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-on}"
    rounded: "{rounded.sm}"
    height: "48px"
    padding: "0 24px"
  button-outlined:
    backgroundColor: "transparent"
    textColor: "{colors.fg}"
    rounded: "{rounded.sm}"
    height: "48px"
    padding: "0 24px"
  button-text:
    backgroundColor: "transparent"
    textColor: "{colors.accent}"
    rounded: "{rounded.sm}"
    padding: "0 12px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.fg}"
    rounded: "{rounded.md}"
    padding: "16px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.fg}"
    rounded: "{rounded.sm}"
    padding: "14px"
  input-focus:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.fg}"
    rounded: "{rounded.sm}"
    padding: "14px"
  chip-state:
    textColor: "{colors.warn}"
    rounded: "{rounded.pill}"
    padding: "4px 8px"
  fab:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-on}"
    rounded: "{rounded.lg}"
    size: "56px"
---

# Design System: Garage

## Overview

**Creative North Star: "The Instrument Cluster"**

Garage is the panel behind the wheel, not an app about cars. Asphalt darks, a
single dash-amber accent, and every figure the user might compare rendered as an
illuminated monospace readout. The light theme is the same cockpit in daylight —
the same structure at adjusted values, never a separate design that happens to
share a palette.

The discipline is that only one thing is loud. Numbers are the identity: they are
monospace, tabular, and in the dark theme the important ones light up amber.
Everything around them — surfaces, borders, labels, chrome — stays matte and gets
out of the way. An interface that shouted in three places would have no cluster
left, only decoration.

The confirmed anti-reference is **the generic Material template**: light-only
default M3, floating labels drifting up out of text fields, unbranded auth
screens, and a palette with no point of view. That is what this system was built
to leave behind, and reverting any part of it towards stock Material is a
regression rather than a simplification.

**Key Characteristics:**

- Dark-first, with a genuine light theme rather than an inverted afterthought.
- Exactly one accent, spent sparingly, on actions and lit readouts.
- Every compared number is monospace with tabular figures — no exceptions.
- Flat throughout: no shadow anywhere, depth comes from a tonal step and a 1px border.
- Colour outside the accent is semantic — state, never decoration.

## Colors

Two very dark neutrals, one amber, and three semantic signals. The palette is
small on purpose: a cluster reads because almost nothing in it is coloured.

`GarageTokens` (`lib/core/theme/garage_tokens.dart`) is the only file in the app
permitted to hold a raw hex literal. The frontmatter above carries the dark
theme, which is the flagship; the light theme is the same roles at daylight
values, defined as `GarageTokens.light` in that same file.

### Primary

- **Dash Amber** (dark): the one accent. Primary buttons, the floating action
  button, focused field borders, text links, and lit readouts on the dashboard
  and vehicle cards. In the light theme it darkens to **Daylight Amber**, which
  is not a stylistic choice: the bright amber fails AA as text on white, and the
  darker value passes at 5.0:1 — which in turn flips its button text from near-
  black to white.

### Neutral

- **Asphalt** — the window behind everything. Never holds content directly.
- **Panel** — every card, sheet, dialog, date picker and field fill. The step
  between it and Asphalt is one of only two ways depth is expressed.
- **Instrument White** — body text and unlit readouts.
- **Dimmed** — labels, eyebrows, units, secondary lines, and any figure that is
  present but not the point.
- **Seam** — the 1px rule around cards and fields, and every divider. The other
  way depth is expressed.

### Semantic

- **Running** (success), **Due** (warn), **Overdue** (danger): reserved for
  state. `StateChip` renders them at 12% alpha behind full-strength text, and
  `GaugeArc` swaps to danger when an interval is nearly spent.

### Named Rules

**The One Lit Thing Rule.** Amber marks the action or the reading, never the
furniture. If two things on a screen are amber, one of them is wrong.

**The Semantic Colour Rule.** Green, yellow and red mean *state* — running, due,
overdue. They never carry emphasis, category, or brand. A chart series is the one
exception, and it derives from these tokens rather than introducing new hex.

## Typography

**Display Font:** Inter Display (with system-ui, sans-serif)
**Body Font:** Inter Display, same family
**Label/Mono Font:** JetBrains Mono (with ui-monospace, monospace)

**Character:** Inter carries the prose without drawing attention; JetBrains Mono
carries the identity. The pairing is a dashboard's: a plain legible label above a
figure that is unmistakably an instrument reading.

Sizes are Material 3's own scale, unmodified except where noted — the system
changes weight, tracking and *face*, not the ramp.

### Hierarchy

- **Headline** (600, 24/32, −0.5 tracking): page titles, and the `PageHeader`
  that replaces the app bar on desktop windows.
- **Title** (600, 22/28, −0.5 tracking): card headings and section titles.
- **Body** (400, 16/24): prose, list rows, field contents.
- **Readout** (mono, tabular, headline size; `titleMedium` when dense): every
  metric. `GarageTheme.numeric()` is the single entry point and must stay so.
- **Eyebrow** (mono, 11px, +1.5 tracking, Dimmed, uppercased by the caller):
  card headers and section labels — `FUEL · JULY`, `ŠKODA OCTAVIA`.

### Named Rules

**The Tabular Figures Rule.** Any number a person might compare down a column is
monospace with tabular figures, routed through `GarageTheme.numeric()`. This
includes what they type: numeric fields use the same face, so the entry lines up
with the table it joins.

**The No Floating Label Rule.** `floatingLabelBehavior: never`. Labels sit above
their field and stay there. A label that animates into a border is the stock
Material tell this system was built to escape.

**The Croatian Fits Rule.** Every string ships in English and Croatian, and
Croatian is longer. Labels shrink (`FittedBox`) rather than collide, and layouts
must survive a 2.0 text scale at 320 logical pixels.

## Layout

A single spacing scale of 4-px steps (4, 8, 12, 16, 20, 24, 32, 48, 80) governs
everything; 16 is the default page and card padding.

Three window classes, chosen by width **and shortest side** — a landscape phone
is still a phone, and treating a 988-px Galaxy as a tablet gave it a sidebar its
owner did not expect:

- **Phone** (under 900, or any window whose shortest side is under 600): bottom
  navigation, edge-to-edge lists, entry forms as bottom sheets.
- **Compact** (900–1200): an icon rail replaces the bottom bar.
- **Desktop** (1200+): a labelled sidebar, `PageHeader` inside the content
  instead of an app bar, entry forms as centred dialogs, and two-column sections.

Content is capped rather than stretched, and a screen must *ask* for width:
reading 840, single-column form 560, dashboard-style 1440, dialog 480. The
default is reading width, so nothing sprawls because somebody added a wrapper.

Lists on a screen with a floating button reserve 88px at the end, or the last row
sits under the button and cannot be tapped.

### Named Rules

**The Ask For Width Rule.** `AdaptiveContent` defaults to reading width. A
dashboard or a grid passes `ContentWidth.wide` deliberately; nothing gets a
monitor's full width by accident.

## Elevation & Depth

**There are no shadows in this system.** Cards, the app bar, dialogs, buttons and
the floating action button all sit at elevation 0, and Material's surface tint is
switched off. Depth is expressed two ways and only two: the tonal step from
Asphalt to Panel, and a 1px Seam border.

This is an invariant, not a default that nobody revisited. A dark instrument
panel does not cast shadows on itself, and a raised card in this palette reads as
a rendering artefact rather than as height.

### Named Rules

**The Flat Rule.** No `box-shadow`, no `elevation`, no surface tint. If something
needs to separate from its background, it gets a border or a tonal step.

## Shapes

Four radii: 8 for controls (buttons, fields), 12 for cards, sheets and dialogs,
16 for the floating action button, and a full pill for status chips and skeleton
lines. Nothing is square, and nothing is a circle except a gauge and an avatar.

The recurring silhouette is a bordered panel with 16px of padding — card, sheet,
dialog and date picker are all the same object at different sizes.

## Components

Buttons, cards and fields are **machined and legible**: precise, unfussy, sized
for a gloved thumb, and stating their state plainly rather than decoratively.

### Buttons

- **Shape:** gently rounded (8px), full-width by default, minimum height 48px.
- **Primary (filled):** Dash Amber fill with near-black text, elevation 0.
- **Outlined:** transparent with a 1px Seam border and Instrument White text,
  same 48px floor.
- **Text:** Dash Amber label, no fill, used for tertiary and inline actions.
- **Hover / Focus:** Material's own state layer over the token colours; no
  translation, no shadow, no scale.

### Cards / Containers

- **Corner:** 12px. **Background:** Panel. **Border:** 1px Seam.
- **Shadow:** none — see Elevation & Depth.
- **Padding:** 16px.

### Inputs / Fields

- **Style:** filled with Panel, 1px Seam border, 8px radius, 14px padding.
- **Label:** above the field, always; never floating.
- **Focus:** the border becomes 2px Dash Amber. No glow, no fill change.
- **Error:** the border becomes Overdue, 2px when focused.
- **Numeric fields** use the mono tabular face, so what is typed matches what the
  tables render.

### Chips

- **StateChip:** a pill carrying its semantic colour at 12% alpha behind
  full-strength 600-weight text. Overdue, Due and Upcoming only — this is a state
  readout, not a tag.

### Navigation

- **Phone:** Material `NavigationBar`, five destinations, the fifth being "More"
  rather than "Settings" — nobody looks under Settings for the people they share
  a car with.
- **Compact:** icon-only rail, still carrying "More".
- **Desktop:** labelled sidebar where "More" is not a destination at all; what it
  held is listed below the primaries, because a sidebar with room has nothing to
  fold.
- **Transitions:** tabs cross-fade as peers. Pushed pages use the platform's push
  below the wide breakpoint and a cross-fade above it, because the sidebar is
  drawn inside each page and a sliding page would drag a second one with it.

### ClusterReadout (signature)

An eyebrow over a large mono value with an optional small unit. Lit amber only
when it is both emphasized *and* in the dark theme; everywhere else it is
Instrument White. Used on the dashboard and vehicle cards only — elsewhere
numbers stay mono but unlit. Its label shrinks to fit rather than colliding with
its neighbour.

### GaugeArc (signature)

A 270° arc for interval consumption, with the percentage in mono at its centre
and an eyebrow beneath. Deliberately static — there is no sweep-in animation, so
reduced motion needs no special case. It turns Overdue in the last 15% of the
interval, at the *full* end: the arc shows how much of an interval is used, so a
nearly full arc is an item nearly due.

### Skeleton (signature)

Placeholders drawn from the Seam colour, pulsing between two points on the way
towards Instrument White — never towards Panel, which makes them vanish at one
end of the pulse. Used to draw a screen's real shape before its data arrives, so
nothing moves on arrival. Holds still under reduced motion, and is hidden from
screen readers.

## Do's and Don'ts

### Do:

- **Do** route every compared number through `GarageTheme.numeric()`, including
  numeric text fields.
- **Do** put new raw colour values in `GarageTokens` and nowhere else — chart
  palettes and placeholder tints derive from the tokens.
- **Do** give a new surface a border or a tonal step when it needs to separate.
- **Do** check a new layout at 2.0 text scale on a 320-pixel-wide window, in
  Croatian.
- **Do** let a screen ask for the width it needs, and default to reading width.
- **Do** respect `MediaQuery.disableAnimationsOf` in anything that moves.

### Don't:

- **Don't** add a shadow, an elevation, or a Material surface tint.
- **Don't** use a second accent, or spend the amber on anything but the action or
  the reading.
- **Don't** use green, amber or red for emphasis or category — they mean state.
- **Don't** re-enable floating labels, or let a stock M3 component ship with its
  default styling where a token exists.
- **Don't** animate a gauge or a readout on arrival; the numbers are the point
  and motion makes them harder to read.
- **Don't** introduce a font. Two families carry the whole system.
