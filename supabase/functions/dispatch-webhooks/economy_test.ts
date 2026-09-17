import { assert, assertAlmostEquals, assertEquals } from 'jsr:@std/assert@1'
import {
  closingSpan,
  type FuelRow,
  fuelRowFrom,
  fuelRowsFrom,
} from './economy.ts'
// Imported rather than read: a static import needs no `--allow-read`, so the
// suite still runs as `deno test --allow-env`, and the path is resolved from
// this file rather than from wherever the command happened to be typed.
import fixture from '../../../test/fixtures/economy_spans.json' with {
  type: 'json',
}

// The other half of `test/domain/fuel/economy_fixture_test.dart`. The rule is
// written twice, in two languages that cannot import each other, and the
// fixture is the only thing both of them answer to. Its values were worked out
// by hand; see the note at the top of the file itself.

interface Span {
  name: string
  working: string
  primary_fuel_key: string | null
  entries: FuelRow[]
  closing_id: string
  expected:
    | { l_per_100km: number; distance_km: number; volume_l: number }
    | null
}

const spans = fixture.spans as Span[]

Deno.test('the fixture holds both outcomes', () => {
  // Guards the guard: an import that resolved to an empty list would make the
  // loop below pass without running.
  assert(spans.some((span) => span.expected !== null))
  assert(spans.some((span) => span.expected === null))
})

for (const span of spans) {
  Deno.test(`fixture: ${span.name}`, () => {
    const closing = span.entries.find((row) => row.id === span.closing_id)
    assert(closing, 'the case closes at an entry it does not contain')
    // Everything else in the case is handed over as "earlier", later fills
    // included. That is more than the handler's query ever returns, which is
    // the point: the function is shown not to lean on the query being right.
    const others = span.entries.filter((row) => row.id !== span.closing_id)

    const result = closingSpan(closing, others, span.primary_fuel_key)

    if (span.expected === null) {
      assertEquals(result, null, span.working)
      return
    }
    assert(result, span.working)
    assertAlmostEquals(
      result.litresPer100Km,
      span.expected.l_per_100km,
      1e-9,
      span.working,
    )
    assertAlmostEquals(result.distanceKm, span.expected.distance_km, 1e-9)
    assertAlmostEquals(result.volumeL, span.expected.volume_l, 1e-9)
  })
}

const row = (values: Partial<FuelRow> & { id: string }): FuelRow => ({
  entry_date: '2026-01-01',
  odometer_km: 0,
  volume_l: 40,
  full_tank: true,
  missed_fill: false,
  fuel_type_key: null,
  ...values,
})

Deno.test('the new row is not its own history', () => {
  // The trigger fires after the insert, so a query that forgot to leave the
  // new row out hands it back. Counted twice it would open its own span at
  // zero distance and every fill-up would lose its figure.
  const closing = row({ id: 'b', odometer_km: 1500, volume_l: 35 })

  const result = closingSpan(
    closing,
    [row({ id: 'a', odometer_km: 1000 }), { ...closing }],
    null,
  )

  assertEquals(result?.distanceKm, 500)
  assertEquals(result?.volumeL, 35)
})

Deno.test('the volume is added in the order the app adds it', () => {
  // 0.1 + 0.2 + 0.3 and 0.3 + 0.2 + 0.1 differ in the last bit. The app sums
  // oldest first, so this does too, and the two can agree exactly.
  const result = closingSpan(
    row({ id: 'd', odometer_km: 1300, volume_l: 0.3 }),
    [
      row({ id: 'a', odometer_km: 1000 }),
      row({ id: 'b', odometer_km: 1100, volume_l: 0.1, full_tank: false }),
      row({ id: 'c', odometer_km: 1200, volume_l: 0.2, full_tank: false }),
    ],
    null,
  )

  assertEquals(result?.volumeL, 0.1 + 0.2 + 0.3)
})

Deno.test('a stored row becomes a fuel row', () => {
  assertEquals(
    fuelRowFrom({
      id: 'f1',
      vehicle_id: 'v1',
      entry_date: '2026-02-14',
      odometer_km: 49680,
      volume_l: 42.8,
      full_tank: true,
      missed_fill: false,
      fuel_type_key: null,
      station: 'INA',
    }),
    {
      id: 'f1',
      entry_date: '2026-02-14',
      odometer_km: 49680,
      volume_l: 42.8,
      full_tank: true,
      missed_fill: false,
      fuel_type_key: null,
    },
  )
})

Deno.test('numerics that arrive as text are still numbers', () => {
  // Postgres `numeric` is a JSON number from `to_jsonb` and from PostgREST
  // today. A driver or a setting that turns it into "42.800" must not turn
  // the sum into string concatenation.
  const parsed = fuelRowFrom({
    id: 'f1',
    entry_date: '2026-02-14',
    odometer_km: '49680',
    volume_l: '42.800',
    full_tank: true,
    missed_fill: false,
  })

  assertEquals(parsed?.odometer_km, 49680)
  assertEquals(parsed?.volume_l, 42.8)
  assertEquals(parsed?.fuel_type_key, null)
})

Deno.test('a row missing what the rule needs is no row at all', () => {
  assertEquals(fuelRowFrom({ vehicle_id: 'v1', volume_l: 40 }), null)
  assertEquals(
    fuelRowFrom({ id: 'f1', entry_date: '2026-02-14', odometer_km: 1 }),
    null,
  )
  // Without the flags there is no telling whether the span is whole.
  assertEquals(
    fuelRowFrom({
      id: 'f1',
      entry_date: '2026-02-14',
      odometer_km: 1500,
      volume_l: 35,
    }),
    null,
  )
})

Deno.test('one unreadable row in the history means no figure at all', () => {
  // Dropping the row instead would quietly leave a partial fill out of the
  // sum and report a better figure than the car earned. Nothing is the honest
  // answer when the history cannot be read.
  assertEquals(
    fuelRowsFrom([
      {
        id: 'a',
        entry_date: '2026-01-03',
        odometer_km: 1000,
        volume_l: 40,
        full_tank: true,
        missed_fill: false,
        fuel_type_key: null,
      },
      { id: 'b', entry_date: '2026-01-10', odometer_km: 1200 },
    ]),
    null,
  )
  assertEquals(fuelRowsFrom([])?.length, 0)
})
