import {
  kindWords,
  languageOf,
  type Strings,
  strings,
} from '../_shared/chat_i18n.ts'
import { calendarDay, line, NAME_LIMIT, oneLine } from '../_shared/chat_text.ts'
import type { Builder, OutboxRow } from '../_shared/outbox.ts'
import {
  reminderBody,
  type ReminderDue,
  reminderMessage,
} from '../_shared/reminder_event.ts'
import { chatMessage, unitsFrom } from './chat_message.ts'
import {
  type ClosingSpan,
  closingSpan,
  fuelRowFrom,
  fuelRowsFrom,
  HISTORY_LIMIT,
} from './economy.ts'

// What each event says: one builder per event name, turning an outbox row
// into the generic body a receiver is signed and the lines a chat service
// shows. The drain (`_shared/outbox.ts`) calls the builder once per row, after
// it knows a hook is listening, and stores what comes back; a retry sends the
// same bytes. The lines are asked for by language — the hook's — and the
// words are `_shared/chat_i18n.ts`'s.
//
// The row is believed. Every row but one is written by a trigger or by the
// reminder run, as service role, from the table the change was made to
// (migration 0079). The one a member may insert is `test.ping`, whose
// builder reads nothing from it.
//
// What is sent says more than the row does. The row is canonical and terse —
// a vehicle id, litres, a category key — and the two things a receiver most
// wants are not on it at all: which car that is, and what the tank worked out
// to. Both are looked up here, with the service-role client, and neither may
// be the reason a notification does not arrive: a lookup that fails leaves its
// part of the message out. Only the car is required, because without it there
// is no name and no fuel to read the row by.

/// The entry tables, by the `kind` a receiver is told. A table missing here
/// reaches the outbox and is built into nothing, which is why adding an entry
/// kind means adding it in three places — the trigger, this map, and the
/// realtime publication.
export const entryKinds: Record<string, string> = {
  fuel_entries: 'fuel',
  service_entries: 'service',
  cost_entries: 'cost',
  odometer_entries: 'odometer',
  trip_entries: 'trip',
  income_entries: 'income',
}

// deno-lint-ignore no-explicit-any
type Admin = any
type Row = Record<string, unknown>

interface Vehicle {
  household_id: string
  nickname?: string | null
  fuel_type_key?: string | null
  secondary_fuel_type_key?: string | null
}

/// Everything looked up through this is decoration on a notification that
/// used to arrive without it, so none of it may be the reason one does not:
/// a lookup that fails or throws leaves its part of the message out.
async function optional<T>(lookup: () => PromiseLike<T>): Promise<T | null> {
  try {
    return await lookup()
  } catch {
    return null
  }
}

/// The car, or null when it is gone. Not [optional]: gone and unreadable are
/// different answers. Null is built into nothing and the row is marked
/// processed, which is right for a car that was deleted before the drain came
/// round; a read that failed throws instead, and the drain leaves the row for
/// the next pass rather than losing the event to a database that blinked.
async function vehicleNamed(
  admin: Admin,
  id: string,
): Promise<Vehicle | null> {
  const { data, error } = await admin
    .from('vehicles')
    .select('household_id, nickname, fuel_type_key, secondary_fuel_type_key')
    .eq('id', id)
    .maybeSingle()
  if (error) {
    throw new Error(`vehicles: ${error.message}`)
  }
  return (data as Vehicle | null) ?? null
}

/// A person's display name, or null when there is no profile — an account
/// deleted, or a row with nobody on it.
async function displayName(
  admin: Admin,
  userId: unknown,
): Promise<string | null> {
  if (typeof userId !== 'string') {
    return null
  }
  return await optional(async () => {
    const { data } = await admin
      .from('profiles')
      .select('display_name')
      .eq('user_id', userId)
      .maybeSingle()
    return (data?.display_name as string | undefined) ?? null
  })
}

/// The garage's units and currency, with the app's own fallbacks when the
/// garage cannot be read.
async function householdUnits(admin: Admin, householdId: string) {
  return unitsFrom(
    await optional(async () => {
      const { data } = await admin
        .from('households')
        .select('currency_code, distance_unit, volume_unit')
        .eq('id', householdId)
        .maybeSingle()
      return data as Row | null
    }),
  )
}

/// When the event happened: when the row was written, not when it was built.
/// A poke that is lost has the cron build the row five minutes later, and
/// the fill-up did not move.
///
/// The one row a member may insert is a ping, and the policy leaves them the
/// timestamp: a year JavaScript cannot hold would make this throw, and a
/// builder that throws leaves its row at the front of every drain's batch.
/// So a time that cannot be read is now.
function writtenAt(row: OutboxRow): Date {
  const written = new Date(row.created_at)
  return Number.isNaN(written.getTime()) ? new Date() : written
}

const at = (row: OutboxRow): string => writtenAt(row).toISOString()

const FUEL_COLUMNS =
  'id, entry_date, odometer_km, volume_l, full_tank, missed_fill, ' +
  'fuel_type_key'

/// The span the new fill-up closed, by the app's own full-tank rule — see
/// `economy.ts` for the rule and for what keeps it honest.
async function spanClosedBy(
  admin: Admin,
  vehicleId: string,
  vehicle: Vehicle,
  entry: Row,
): Promise<ClosingSpan | null> {
  const closing = fuelRowFrom(entry)
  // A partial fill closes nothing, and neither does one that admits to a gap
  // before it. Most of what is asked below is asked to find that out, so it
  // is not asked.
  if (!closing || !closing.full_tank || closing.missed_fill) {
    return null
  }

  // Nearest first, and cut off: a span is a handful of rows and a log is
  // years of them. The order is the chain's own, reversed — including a
  // partial fill before a full one at the same reading on the same day — so
  // what the limit drops is always the farthest row. It can cost a very long
  // span its opening tank, which reads as no figure; it cannot drop a fill
  // from inside a span and leave a flattering one.
  const { data } = await admin
    .from('fuel_entries')
    .select(FUEL_COLUMNS)
    .eq('vehicle_id', vehicleId)
    // The trigger fires after the insert, so the new row is already there.
    .neq('id', closing.id)
    // Nothing past the new reading can be part of a span that ends at it.
    .lte('odometer_km', closing.odometer_km)
    .order('odometer_km', { ascending: false })
    .order('entry_date', { ascending: false })
    .order('full_tank', { ascending: true })
    .limit(HISTORY_LIMIT)
  // No rows is a history; no answer is not, and neither is one that cannot
  // be read.
  const earlier = data && fuelRowsFrom(data)
  if (!earlier) {
    return null
  }

  // The app names a main fuel only for a car that takes two
  // (`economyPointsProvider`), and an unnamed fill joins a chain or stands
  // apart depending on it. Handing over anything else here would split the
  // same log differently and the two figures would part ways.
  const primaryFuelKey = vehicle.secondary_fuel_type_key != null
    ? vehicle.fuel_type_key ?? null
    : null
  return closingSpan(closing, earlier, primaryFuelKey)
}

/// The three entry events share one builder: the same lookups and the same
/// lines, under a different first word. `entry.created` alone carries the
/// economy figure — an edit changes the figure the app shows and the app is
/// where the current figure is, and a delete has no tank to close.
function entryEvent(
  event: 'entry.created' | 'entry.updated' | 'entry.deleted',
): Builder {
  return async (admin, row) => {
    const kind = entryKinds[String(row.payload.table)]
    const entry = row.payload.record as Row | undefined
    const vehicleId = row.payload.vehicle_id
    if (!kind || !entry || typeof vehicleId !== 'string') {
      return null
    }
    const vehicle = await vehicleNamed(admin, vehicleId)
    if (!vehicle) {
      return null
    }
    const closesSpan = event === 'entry.created' && kind === 'fuel'
    const [units, author, economy] = await Promise.all([
      // The garage the row was written in, which the outbox row names: a car
      // sold between the trigger and the drain is announced to the seller's
      // hooks, in the seller's currency.
      householdUnits(admin, row.household_id),
      // Who typed the row, which is what `created_by` records. A trip's
      // driver is somebody else and is on the row already.
      displayName(admin, entry.created_by),
      closesSpan
        ? optional(() => spanClosedBy(admin, vehicleId, vehicle, entry))
        : Promise.resolve(null),
    ])
    const body = JSON.stringify({
      event,
      kind,
      vehicle_id: vehicleId,
      entry,
      ...(event === 'entry.updated' && {
        previous: row.payload.old_record ?? null,
      }),
      at: at(row),
      // Everything from here down was added later, and added after: a
      // receiver written against the five keys above must not notice.
      vehicle_name: vehicle.nickname ?? null,
      currency: units.currency,
      // Canonical like the row beside it, whatever the household reads:
      // litres per 100 km — kilowatt-hours for an electric car — over
      // kilometres. Only a new fill-up has the key at all.
      ...(closesSpan && {
        economy: economy && {
          l_per_100km: economy.litresPer100Km,
          distance_km: economy.distanceKm,
          volume_l: economy.volumeL,
        },
      }),
    })
    return {
      body,
      message: (hookLanguage) => {
        const language = languageOf(hookLanguage)
        const text = chatMessage(kind, entry, {
          vehicleName: vehicle.nickname ?? null,
          author,
          units,
          // The fuel that went in, not the car's main one: a plug-in charge
          // on a car that also takes petrol is still kilowatt-hours.
          electric: (entry.fuel_type_key ?? vehicle.fuel_type_key) ===
            'fuel_electric',
          economy,
          language,
        })
        if (event === 'entry.created') {
          return text
        }
        // The same lines under a first line of its own: "⛽ Fill-up · Clio ·
        // by Ana" becomes "✏️ Fill-up edited · Clio · logged by Ana". The row
        // knows who logged it and nothing about who changed it, and "by" on
        // an edit would read as the editor.
        const [, ...rest] = text.split('\n')
        const icon = event === 'entry.updated' ? '✏️' : '🗑️'
        const change = event === 'entry.updated' ? 'edited' : 'deleted'
        const who = oneLine(author, NAME_LIMIT)
        const head = line(
          `${icon} ${
            kindWords(language, kind)?.[change] ?? `${kind} ${change}`
          }`,
          oneLine(vehicle.nickname, NAME_LIMIT),
          who && strings(language).loggedBy(who),
        )
        return [head, ...rest].join('\n')
      },
    }
  }
}

/// Added, archived or restored: the car, by name. The row carries the name;
/// the table is asked only when it does not.
const vehicleEvent = (
  event: string,
  label: (text: Strings) => string,
): Builder => {
  return async (admin, row) => {
    const vehicleId = row.payload.vehicle_id
    if (typeof vehicleId !== 'string') {
      return null
    }
    const record = (row.payload.record as Row | undefined) ?? {}
    const nickname = typeof record.nickname === 'string'
      ? record.nickname
      : (await vehicleNamed(admin, vehicleId))?.nickname ?? null
    const body = JSON.stringify({
      event,
      vehicle_id: vehicleId,
      vehicle_name: nickname,
      // A new car is described. Not its plate or VIN: those stay in the API,
      // where a key is needed to read them.
      ...(event === 'vehicle.added' && {
        vehicle: {
          id: vehicleId,
          nickname,
          make: record.make ?? null,
          model: record.model ?? null,
          year: record.year ?? null,
          fuel_type_key: record.fuel_type_key ?? null,
          secondary_fuel_type_key: record.secondary_fuel_type_key ?? null,
        },
      }),
      at: at(row),
    })
    return {
      body,
      message: (language) =>
        line(
          label(strings(languageOf(language))),
          oneLine(nickname, NAME_LIMIT),
        )!,
    }
  }
}

/// A sale, announced to the garage the car is leaving. Where it went is the
/// buyer's business.
const handedOver: Builder = (_admin, row) => {
  const vehicleId = row.payload.vehicle_id
  if (typeof vehicleId !== 'string') {
    return Promise.resolve(null)
  }
  const record = (row.payload.record as Row | undefined) ?? {}
  const nickname = typeof record.nickname === 'string' ? record.nickname : null
  return Promise.resolve({
    body: JSON.stringify({
      event: 'vehicle.handed_over',
      vehicle_id: vehicleId,
      vehicle_name: nickname,
      at: at(row),
    }),
    message: (language) =>
      line(
        `🤝 ${strings(languageOf(language)).handedOver}`,
        oneLine(nickname, NAME_LIMIT),
      )!,
  })
}

/// The switches on a pass (migration 0055 and 0064), as the row has them.
const PASS_PERMISSIONS = [
  'can_log_fuel',
  'can_log_trips',
  'can_log_costs',
  'can_view_history',
  'can_view_prices',
]

/// The UTC day a timestamp falls on, as a person writes it, or null.
function dayOf(timestamp: unknown, locale: string): string | null {
  if (typeof timestamp !== 'string') {
    return null
  }
  const date = new Date(timestamp)
  return Number.isNaN(date.getTime())
    ? null
    : calendarDay(date.toISOString().slice(0, 10), locale)
}

/// A pass redeemed is the car lent; a live pass given back by the borrower
/// or withdrawn by the owner is the car returned. The row says which of the
/// two ended it (`returned_at`, `revoked_at`); the event says only that the
/// loan is over and whose it was. The pass's code is the key to the car and
/// is not sent.
const loanEvent = (event: 'vehicle.lent' | 'vehicle.returned'): Builder => {
  return async (admin, row) => {
    const vehicleId = row.payload.vehicle_id
    const record = row.payload.record as Row | undefined
    if (typeof vehicleId !== 'string' || !record) {
      return null
    }
    const [vehicle, borrower] = await Promise.all([
      vehicleNamed(admin, vehicleId),
      displayName(admin, record.redeemed_by),
    ])
    const nickname = vehicle?.nickname ?? null
    const body = JSON.stringify({
      event,
      vehicle_id: vehicleId,
      vehicle_name: nickname,
      borrower,
      ...(event === 'vehicle.lent' && {
        until: record.expires_at ?? null,
        permissions: Object.fromEntries(
          PASS_PERMISSIONS.map((key) => [key, record[key] === true]),
        ),
      }),
      at: at(row),
    })
    const who = oneLine(borrower, NAME_LIMIT)
    return {
      body,
      message: (language) => {
        const text = strings(languageOf(language))
        const car = oneLine(nickname, NAME_LIMIT)
        return event === 'vehicle.lent'
          ? line(
            `🔑 ${text.lentOut}`,
            car,
            text.lentTo(who, dayOf(record.expires_at, text.locale)),
          )!
          : line(`🔑 ${text.returned}`, car, who && text.returnedBy(who))!
      },
    }
  }
}

/// Joined or left, by display name. An account that was deleted took its
/// profile with it, and the garage still hears that somebody left.
const memberEvent = (event: 'member.joined' | 'member.left'): Builder => {
  return async (admin, row) => {
    const member = await displayName(admin, row.payload.user_id)
    const body = JSON.stringify({
      event,
      member,
      role: row.payload.role ?? null,
      at: at(row),
    })
    const who = oneLine(member, NAME_LIMIT)
    return {
      body,
      message: (language) => {
        const text = strings(languageOf(language))
        const name = who ?? text.somebody
        return `👋 ${
          event === 'member.joined' ? text.joined(name) : text.left(name)
        }`
      },
    }
  }
}

/// The reminder run wrote a [ReminderDue] into the row, having looked up
/// everything it needed; this reads it back and asks for nothing more.
const reminderDue: Builder = (_admin, row) => {
  const due = row.payload as unknown as ReminderDue
  return Promise.resolve({
    body: reminderBody(due, writtenAt(row)),
    message: (language) => reminderMessage(due, languageOf(language)),
  })
}

/// The app's test button. The policy lets a member insert this row with any
/// payload they like, so the payload is not read: nothing a member typed
/// reaches the wire through a ping.
const ping: Builder = (_admin, row) =>
  Promise.resolve({
    body: JSON.stringify({ event: 'test.ping', at: at(row) }),
    message: (language) => `🔔 ${strings(languageOf(language)).test}`,
  })

/// Every event name migration 0079 writes, and the reminder run's.
export const builders: Record<string, Builder> = {
  'entry.created': entryEvent('entry.created'),
  'entry.updated': entryEvent('entry.updated'),
  'entry.deleted': entryEvent('entry.deleted'),
  'vehicle.added': vehicleEvent(
    'vehicle.added',
    (text) => `🚙 ${text.carAdded}`,
  ),
  'vehicle.archived': vehicleEvent(
    'vehicle.archived',
    (text) => `📦 ${text.carArchived}`,
  ),
  'vehicle.restored': vehicleEvent(
    'vehicle.restored',
    (text) => `📦 ${text.carRestored}`,
  ),
  'vehicle.handed_over': handedOver,
  'vehicle.lent': loanEvent('vehicle.lent'),
  'vehicle.returned': loanEvent('vehicle.returned'),
  'member.joined': memberEvent('member.joined'),
  'member.left': memberEvent('member.left'),
  'reminder.due': reminderDue,
  'test.ping': ping,
}
