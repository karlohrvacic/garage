# 10. Localization and units

Two things that look like formatting and are really correctness: what language the
app speaks, and what a number means. Siblings:
[05-data-access-and-sync.md](05-data-access-and-sync.md) for where conversion
sits in the stack, [09-errors-and-diagnostics.md](09-errors-and-diagnostics.md)
for the error sentences.

> Jump to [Sharp edges](#sharp-edges): Croatian plurals are a correctness rule
> with a test behind it, generated files are committed, and one email template
> serves both languages.

## Why this exists, and why it is built this way

The app is used by Croatian households, and Croatian is not a nice-to-have
translation layered onto an English product. It is the language half the intended
users think in, so it is treated as a first-class locale with its own review pass
rather than as string substitution.

Units are the same kind of problem wearing different clothes. A household that
prefers miles is expressing a display preference, not changing what its history
means. Conflating the two corrupts data permanently.

## Localization

| Piece | Where |
|---|---|
| Source strings | `lib/l10n/app_en.arb`, `lib/l10n/app_hr.arb` |
| Config | `l10n.yaml:1` |
| Generated | `lib/l10n/app_localizations*.dart`, committed |
| Guard | `test/l10n/arb_consistency_test.dart` |

Regenerate with `flutter gen-l10n` after editing an ARB. The generated files are
**committed**, and `.github/workflows/ci.yml:36` fails the build when they are
stale, because a build that silently ships yesterday's strings is worse than one
that will not compile.

`test/l10n/arb_consistency_test.dart` enforces four things: every English message
has a Croatian one (`:36`), Croatian carries no orphans (`:40`), a translation
never drops a placeholder (`:44`), and no message is empty (`:58`).

### The Croatian plural rule

The fifth check (`test/l10n/arb_consistency_test.dart:66`) is the one that catches
real bugs. Croatian inflects a counted noun three ways: one, two to four, and five
or more. A message that interpolates a count without ICU plural forms reads wrong
for two of those three cases.

```
"notificationBundleTitle": "{count, plural, one{{count} stavka dospijeva}
                            few{{count} stavke dospijevaju zajedno}
                            other{{count} stavki dospijeva zajedno}}"
```

Any Croatian message with a `count` or `days` placeholder must carry
`plural,`, or the test fails naming the key. English needs only two forms, so this
is a mistake that only shows in one of the two files and only to readers of that
language.

### Writing Croatian here

Translated-sounding Croatian was a real defect in this app, corrected in a pass
across the ARB. The standard is what a Croatian speaker would actually say, not a
word-for-word mapping of the English. Where a term is genuinely used in English by
mechanics, keeping it is better than inventing a translation nobody says.

## Units

Canonical storage, conversion at the edge. The rule is stated at
`lib/core/format/unit_format.dart:19` and enforced by nothing but discipline, so
it is worth restating: **kilometres, litres, and the household's currency go into
the database.**

| Preference | Options | Notes |
|---|---|---|
| Distance | `km`, `mi` | 1.609344 km per mile (`unit_format.dart:9`) |
| Volume | `liter`, `usGallon`, `ukGallon` | Two different gallons, 3.785 and 4.546 litres |
| Currency | ISO code | 23 offered, regional ones first |

Economy conversion uses two constants that are easy to mix up
(`lib/core/format/unit_format.dart:14`): divide l/100km into 235.214583 for US
mpg, or 282.480936 for imperial. Using one for the other is a silent 20 percent
error in a headline number.

Currency is a **label, not a conversion**. Changing it relabels the household's
figures; it does not convert them, and nothing in the app does foreign exchange.

**A figure that is per-distance carries its own unit.**
`UnitFormat.formatCostPerDistance` (`unit_format.dart:177`) prints "0,09 €/km"
or "$0.15/mi" rather than a bare amount under a label naming a unit. Assembling
the unit into the label instead — the fuel header did, as
`'${l10n.fuelPricePerUnit} / km'` — puts the km in a place no preference
reaches, so an imperial household read a per-kilometre figure under a heading
that said km and a value that said nothing.

**Every numeric field says its unit inside the box.** `UnitFormat` exposes the
unit alone — `distanceSuffix`, `volumeSuffix`, `energySuffix`,
`currencySymbol`, `pricePerUnitSuffix`, `economySuffix` — and every entry
sheet puts the right one in the field's `suffixText`: "km" beside an odometer,
"l" (or "kWh") beside a volume, "€/l" beside a price per unit, "€" beside a
total, "min" beside a duration. The fill-up sheet was the report that prompted
it: "Količina" under "Kilometraža" with a bare box was read as "litres,
probably". The label names the quantity; the suffix names the unit, in the
household's own preference, from one place rather than a ternary per screen.

## Amounts are read, not just parsed

A money field takes a sum as well as a number. `evaluateAmount`
(`lib/domain/format/amount_expression.dart:24`) reads `2*1.50` as three euros —
the motivating case being a parking ticket extended by an hour, where the
alternative is doing the arithmetic at the meter. It is deliberately small:
`+ - * /` with the usual precedence, no parentheses, and division by zero is a
refusal rather than an infinity reaching the amount column.

**The comma stays a decimal mark and never becomes a separator.** Croatian
writes 12,50, and that reading has to survive multiplication, so `2*1,50` is
three euros rather than a list of three numbers. This is the one place where
being a bilingual app changes the grammar of an input rather than the wording of
a label.

The operators are unreachable from the keypad the fields ask for —
`TextInputType.numberWithOptions(decimal: true)` gives digits and a separator
and nothing else — so `AmountCalculatorDock`
(`lib/core/widgets/amount_calculator_dock.dart`) puts one `+ − × ÷` row above
Save, serving whichever amount field has focus (and the last one typed into
once focus moves on), and echoes the running total beside it. It sat under
each field until decision 80: appearing on focus it pushed Save below the
fold, and holding its height left blank bands. The alternative, a plain text
keyboard, would have taxed every ordinary amount to serve the rare one.

## Sharp edges

- **A taller field can push a control off the test viewport.** Adding the
  operator row under the cost amount moved the vignette dropdowns below 600 px
  and four sheet tests started failing on a hit test, not on behaviour. The fix
  is `tester.ensureVisible` before the tap, which is what the rest of that file
  already did.
- **Croatian plurals will fail your build, correctly.** Adding a counted message
  in English and translating it plainly is the most common way to break the suite.
- **Generated localizations drift silently in a local build.** `flutter test` will
  not tell you, only CI will. Run `flutter gen-l10n` after touching an ARB.
- **Supabase auth emails have no per-user language.** One template goes to
  everyone, so `supabase/templates/confirmation.html` and `recovery.html` are
  written bilingually, English then Croatian. That is a workaround for a platform
  limit, not a style choice.
- **The store listing is a third place strings live**
  ([play-store-listing.md](../play-store-listing.md)) and release notes a fourth
  (`distribution/whatsnew/`). Neither is covered by the ARB tests. A feature rename
  has to be carried to both by hand.
- **`ZZ` is the "elsewhere" country code** (`lib/features/settings/screens/settings_screen.dart:62`),
  chosen from the ISO user-assigned range so it can never collide with a real
  country the app later ships rules for.
