import { assertEquals } from 'jsr:@std/assert@1'
import { calendarDay, humanise, line, oneLine } from './chat_text.ts'

Deno.test('keys become labels a person would write', () => {
  // A service type: the prefix says which table the key is from, which the
  // message's first line has already said.
  assertEquals(humanise('service_oil_change'), 'Oil change')
  assertEquals(humanise('service_brake_pads_front'), 'Brake pads front')
  // Cost and income categories carry no prefix, so none is looked for.
  assertEquals(humanise('insurance_comprehensive'), 'Insurance comprehensive')
  assertEquals(humanise('toll'), 'Toll')
  assertEquals(humanise('transport_app'), 'Transport app')
  assertEquals(humanise('vehicle_sale'), 'Vehicle sale')
  // Initialisms a plain capital letter would get wrong.
  assertEquals(humanise('service_dpf'), 'DPF')
  assertEquals(humanise('service_ac_service'), 'AC service')
  assertEquals(humanise('service_adblue'), 'AdBlue')
  // A household's own type is in no list, and needs none.
  assertEquals(humanise('service_detailing'), 'Detailing')
  // Not a key the app ships, but one a household could write: only
  // `service_` is a prefix, and this one is half of what the cost is.
  assertEquals(humanise('income_protection'), 'Income protection')
  // A prefix is only a prefix when something follows it.
  assertEquals(humanise('service'), 'Service')
})

Deno.test('a key that names something every object has is still just a word', () => {
  // `constructor` passes the column's own check, `^[a-z0-9_]+$`. Looked up in
  // a plain object it finds Object's constructor, and the message would read
  // "function Object() { [native code] }".
  assertEquals(humanise('constructor'), 'Constructor')
  assertEquals(humanise('service_constructor'), 'Constructor')
})

Deno.test('free text is folded onto one line and cut by character', () => {
  assertEquals(oneLine('  Tyres\nlook\r\n\tworn  ', 80), 'Tyres look worn')
  assertEquals(oneLine('abcde', 5), 'abcde')
  assertEquals(oneLine('abcdef', 5), 'abcde…')
  // The cut is not left hanging off a space.
  assertEquals(oneLine('abcd ef', 5), 'abcd…')
  // Half an emoji is a lone surrogate, and some receivers refuse a body that
  // carries one.
  assertEquals(oneLine('abcd🚗🚗', 5), 'abcd🚗…')
})

Deno.test('what is not text, or is only space, is no text at all', () => {
  assertEquals(oneLine(' \n\t ', 80), null)
  assertEquals(oneLine('', 80), null)
  assertEquals(oneLine(null, 80), null)
  assertEquals(oneLine(42, 80), null)
})

Deno.test('a line keeps the parts that are there, and only those', () => {
  assertEquals(
    line('Clio', null, 'by Ana', undefined, false, ''),
    'Clio · by Ana',
  )
  assertEquals(line(null, '', false), null, 'a line with nothing on it goes')
})

Deno.test('a calendar day is written the British way', () => {
  assertEquals(calendarDay('2026-11-04'), '4 Nov 2026')
  assertEquals(calendarDay('2027-03-15'), '15 Mar 2027')
})

Deno.test('or the way the reader writes one', () => {
  assertEquals(calendarDay('2026-11-04', 'hr-HR'), '4. stu 2026.')
  assertEquals(calendarDay('2026-11-04', 'it-IT'), '4 nov 2026')
})

// A stored day is midnight in UTC. Read in the clock of a server west of
// Greenwich, that is the evening before — and a reminder would name the wrong
// day. The edge runtime runs in UTC, so only a test that moves the clock
// shows it.
Deno.test('a calendar day is the day it names, wherever the server is', () => {
  const zone = Deno.env.get('TZ')
  Deno.env.set('TZ', 'America/New_York')
  try {
    assertEquals(calendarDay('2026-11-04'), '4 Nov 2026')
  } finally {
    if (zone === undefined) {
      Deno.env.delete('TZ')
    } else {
      Deno.env.set('TZ', zone)
    }
  }
})

// JavaScript reads 31 February as 3 March rather than refusing it. A message
// is better without a date than with one nobody set.
Deno.test('a day that is not a day is left out rather than invented', () => {
  assertEquals(calendarDay('2026-02-31'), null)
  assertEquals(calendarDay('someday'), null)
  assertEquals(calendarDay('2026-11-04T00:00:00Z'), null)
  assertEquals(calendarDay(null), null)
})
