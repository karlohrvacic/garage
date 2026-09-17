import {
  calendarDay,
  humanise,
  line,
  NAME_LIMIT,
  oneLine,
  present,
  WORK_LIMIT,
} from '../_shared/chat_text.ts'
import type { SwapDirection } from './winter_tyre_period.ts'

// What a webhook is told when something falls due: the `reminder.due` event.
//
// Every webhook has been subscribed to it since the table was created
// (`supabase/migrations/0017_public_api.sql`), and for a long time nothing
// sent it. This run is what knows something is due, so it is what tells the
// hooks — the same visits the phones hear about, on the same days.
//
// The generic body is the push's payload in JSON's own types: keys rather
// than sentences, a number for the days, a list for the work. A chat service
// gets two lines in English, written with the same pieces as an entry's.

export const REMINDER_EVENT = 'reminder.due'

/// One visit, as the hooks are told about it.
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

function dueIn(days: number): string {
  if (days === 0) {
    return 'Due today'
  }
  return `Due in ${days} ${days === 1 ? 'day' : 'days'}`
}

/// What a chat service shows: how soon and on which car, then the work and
/// the day.
///
///     🔔 Due in 7 days · Clio
///     Oil change, Air filter · 4 Nov 2026
export function reminderMessage(due: ReminderDue): string {
  const work = due.keys.map(humanise).join(', ')
  return present([
    line(`🔔 ${dueIn(due.daysUntilDue)}`, oneLine(due.vehicleName, NAME_LIMIT)),
    line(oneLine(work, WORK_LIMIT), calendarDay(due.dueDate)),
  ]).join('\n')
}
