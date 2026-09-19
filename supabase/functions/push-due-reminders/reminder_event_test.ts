import { assertEquals } from 'jsr:@std/assert@1'
import {
  REMINDER_EVENT,
  reminderBody,
  type ReminderDue,
  reminderMessage,
} from '../_shared/reminder_event.ts'

const AT = new Date('2026-10-28T06:00:00.000Z')

const clio: ReminderDue = {
  vehicleId: 'v1',
  vehicleName: 'Clio',
  keys: ['service_oil_change', 'service_air_filter'],
  dueDate: '2026-11-04',
  daysUntilDue: 7,
}

Deno.test('the event is the one every hook has always subscribed to', () => {
  // `WebhookEvent.reminderDue` in the app, and the table's default.
  assertEquals(REMINDER_EVENT, 'reminder.due')
})

Deno.test('the event carries keys, not sentences', () => {
  assertEquals(
    JSON.parse(reminderBody(clio, AT)),
    {
      event: 'reminder.due',
      vehicle_id: 'v1',
      vehicle_name: 'Clio',
      due: ['service_oil_change', 'service_air_filter'],
      due_date: '2026-11-04',
      days_until_due: 7,
      at: '2026-10-28T06:00:00.000Z',
    },
  )
})

// JSON does not promise an order, and people parse it as if it did. This is
// the order the event was published with.
Deno.test('the keys come in the order they were published in', () => {
  assertEquals(Object.keys(JSON.parse(reminderBody(clio, AT))), [
    'event',
    'vehicle_id',
    'vehicle_name',
    'due',
    'due_date',
    'days_until_due',
    'at',
  ])
})

Deno.test('a swap says which way it goes, after everything else', () => {
  const swap = JSON.parse(reminderBody(
    {
      ...clio,
      keys: ['service_tire_swap_seasonal'],
      dueDate: '2026-11-15',
      swapDirection: 'to_winter',
    },
    AT,
  ))

  assertEquals(Object.keys(swap).at(-1), 'swap_direction')
  assertEquals(swap.swap_direction, 'to_winter')
})

Deno.test('a car with no name is still named as not having one', () => {
  assertEquals(
    JSON.parse(reminderBody({ ...clio, vehicleName: null }, AT)).vehicle_name,
    null,
  )
})

Deno.test('a chat target is told how soon, which car, what and when', () => {
  assertEquals(
    reminderMessage(clio),
    [
      '🔔 Due in 7 days · Clio',
      'Oil change, Air filter · 4 Nov 2026',
    ].join('\n'),
  )
})

// The same visit to a Croatian and to an Italian hook: the days are counted
// in the language, the work is named as the app names it, and the date is
// written as the reader writes one.
Deno.test('a Croatian hook is told in Croatian', () => {
  assertEquals(
    reminderMessage(clio, 'hr'),
    [
      '🔔 Dospijeva za 7 dana · Clio',
      'Zamjena ulja, Filtar zraka · 4. stu 2026.',
    ].join('\n'),
  )
  assertEquals(
    reminderMessage({ ...clio, daysUntilDue: 1 }, 'hr').split('\n')[0],
    '🔔 Dospijeva za 1 dan · Clio',
  )
  assertEquals(
    reminderMessage({ ...clio, daysUntilDue: 0 }, 'hr').split('\n')[0],
    '🔔 Dospijeva danas · Clio',
  )
})

Deno.test('an Italian hook is told in Italian', () => {
  assertEquals(
    reminderMessage(clio, 'it'),
    [
      '🔔 Scade tra 7 giorni · Clio',
      "Cambio dell'olio, Filtro dell'aria · 4 nov 2026",
    ].join('\n'),
  )
  assertEquals(
    reminderMessage({ ...clio, daysUntilDue: 0 }, 'it').split('\n')[0],
    '🔔 Scade oggi · Clio',
  )
})

Deno.test('a month out says so', () => {
  assertEquals(
    reminderMessage({ ...clio, daysUntilDue: 30, dueDate: '2026-11-27' }),
    [
      '🔔 Due in 30 days · Clio',
      'Oil change, Air filter · 27 Nov 2026',
    ].join('\n'),
  )
})

// Neither is a lead day today. The list is the app's as well as this
// function's, and a sentence that went wrong the day it changed would be
// found by a household rather than by a test.
Deno.test('one day is a day, and none is today', () => {
  assertEquals(
    reminderMessage({ ...clio, daysUntilDue: 1 }).split('\n')[0],
    '🔔 Due in 1 day · Clio',
  )
  assertEquals(
    reminderMessage({ ...clio, daysUntilDue: 0 }).split('\n')[0],
    '🔔 Due today · Clio',
  )
})

Deno.test('what is missing is left out rather than left blank', () => {
  assertEquals(
    reminderMessage({ ...clio, vehicleName: null, dueDate: 'not a day' }),
    '🔔 Due in 7 days\nOil change, Air filter',
  )
})

// A nickname is typed by a person, and a household's own service type is a
// key as long as whoever wrote it liked. Discord refuses content past 2,000
// characters, and a refusal is a notification that never arrives.
Deno.test('nothing typed can break the message or run it too long', () => {
  const long = 'x'.repeat(5000)
  const message = reminderMessage({
    ...clio,
    vehicleName: `Cl\nio ${long}`,
    keys: Array.from({ length: 300 }, (_, i) => `service_${long}${i}`),
  })

  assertEquals(message.split('\n').length, 2)
  assertEquals(message.startsWith('🔔 Due in 7 days · Cl io xxx'), true)
  assertEquals(message.length < 2000, true, `${message.length}`)
})
