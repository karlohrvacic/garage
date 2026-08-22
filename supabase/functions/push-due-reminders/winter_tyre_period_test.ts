import { assertEquals } from 'jsr:@std/assert@1'
import {
  nextSeasonalSwap,
  swapsSeasonally,
  winterTyrePeriodFor,
} from './winter_tyre_period.ts'

const day = (y: number, m: number, d: number) => new Date(Date.UTC(y, m - 1, d))

Deno.test('Croatia is dated and ignores the weather', () => {
  assertEquals(winterTyrePeriodFor('HR').rule, 'dated')
  assertEquals(winterTyrePeriodFor('HR').start, [11, 15])
})

Deno.test('an unverified country claims nothing', () => {
  for (const code of ['GB', 'US', 'IT', 'ZZ', '']) {
    assertEquals(winterTyrePeriodFor(code).rule, 'none')
  }
})

Deno.test('autumn points at the winter date', () => {
  const swap = nextSeasonalSwap('HR', day(2026, 10, 1))!
  assertEquals(swap.date.getTime(), day(2026, 11, 15).getTime())
  assertEquals(swap.direction, 'to_winter')
})

Deno.test('the first day of the window is the swap, not a missed one', () => {
  const swap = nextSeasonalSwap('HR', day(2026, 11, 15))!
  assertEquals(swap.date.getTime(), day(2026, 11, 15).getTime())
})

Deno.test('the day after points at the spring swap', () => {
  const swap = nextSeasonalSwap('HR', day(2026, 11, 16))!
  assertEquals(swap.date.getTime(), day(2027, 4, 15).getTime())
  assertEquals(swap.direction, 'to_summer')
})

Deno.test('midwinter crosses the year end', () => {
  const swap = nextSeasonalSwap('HR', day(2026, 12, 31))!
  assertEquals(swap.date.getTime(), day(2027, 4, 15).getTime())
})

Deno.test('Slovenia comes out of winter a month before Croatia', () => {
  const swap = nextSeasonalSwap('SI', day(2026, 12, 1))!
  assertEquals(swap.date.getTime(), day(2027, 3, 15).getTime())
})

Deno.test('a country with no window has no swap to point at', () => {
  for (const code of ['DE', 'GB', 'US', 'IT']) {
    assertEquals(nextSeasonalSwap(code, day(2026, 10, 1)), null)
  }
})

Deno.test('all-season tyres mean no seasonal swap', () => {
  assertEquals(
    swapsSeasonally([{ season: 'all_season', retired_at: null }]),
    false,
  )
})

Deno.test('a winter set means there is a swap', () => {
  assertEquals(swapsSeasonally([{ season: 'winter', retired_at: null }]), true)
})

Deno.test('no tyres recorded is not evidence of all-season', () => {
  assertEquals(swapsSeasonally([]), true)
})

Deno.test('a retired seasonal set does not keep the swap alive', () => {
  assertEquals(
    swapsSeasonally([
      { season: 'winter', retired_at: '2025-01-01' },
      { season: 'all_season', retired_at: null },
    ]),
    false,
  )
})
