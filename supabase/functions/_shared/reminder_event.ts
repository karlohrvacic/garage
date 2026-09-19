import { type Language, nameOf, strings } from './chat_i18n.ts'
import {
  calendarDay,
  line,
  NAME_LIMIT,
  oneLine,
  present,
  WORK_LIMIT,
} from './chat_text.ts'
import type { SwapDirection } from '../push-due-reminders/winter_tyre_period.ts'

// What a webhook is told when something falls due: the `reminder.due` event.
//
// Every webhook has been subscribed to it since the table was created
// (`supabase/migrations/0017_public_api.sql`), and for a long time nothing
// sent it. The daily run is what knows something is due, so it is what writes
// the event — one `webhook_outbox` row per garage, carrying a [ReminderDue] —
// and the dispatcher's builder (`dispatch-webhooks/events.ts`) is what turns
// the row into a body and a message. Shared because both sides read it: the
// run writes the shape, the builder reads it back.
//
// The generic body is the push's payload in JSON's own types: keys rather
// than sentences, a number for the days, a list for the work. A chat service
// gets two lines in the hook's language, written with the same pieces as an
// entry's.

export const REMINDER_EVENT = 'reminder.due'

/// One visit, as the hooks are told about it. What the run puts in the outbox
/// row's payload, and what the builder reads out of it.
export interface ReminderDue {
  vehicleId: string
  /// The vehicle's nickname.
  vehicleName: string | null
  /// Service type keys, as the rules store them.
  keys: string[]
  /// `YYYY-MM-DD`.
  dueDate: string
  daysUntilDue: number
  swapDirection?: SwapDirection
}

/// The generic body: what is signed, and what a generic receiver is sent.
///
/// The order of the keys is the order they were published in. JSON promises
/// none, and people parse it as if it did.
export function reminderBody(due: ReminderDue, at: Date): string {
  return JSON.stringify({
    event: REMINDER_EVENT,
    vehicle_id: due.vehicleId,
    vehicle_name: due.vehicleName,
    due: due.keys,
    due_date: due.dueDate,
    days_until_due: due.daysUntilDue,
    at: at.toISOString(),
    // Only on a visit that is the swap alone, as on the push.
    ...(due.swapDirection && { swap_direction: due.swapDirection }),
  })
}

/// What a chat service shows: how soon and on which car, then the work and
/// the day, in the hook's language.
///
///     🔔 Due in 7 days · Clio
///     Oil change, Air filter · 4 Nov 2026
export function reminderMessage(
  due: ReminderDue,
  language: Language = 'en',
): string {
  const text = strings(language)
  const days = due.daysUntilDue
  const soon = days === 0 ? text.dueToday : text.dueIn(days)
  const work = due.keys.map((key) => nameOf(language, key)).join(', ')
  return present([
    line(`🔔 ${soon}`, oneLine(due.vehicleName, NAME_LIMIT)),
    line(oneLine(work, WORK_LIMIT), calendarDay(due.dueDate, text.locale)),
  ]).join('\n')
}
