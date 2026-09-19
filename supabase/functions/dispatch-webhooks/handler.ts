import { createClient } from 'jsr:@supabase/supabase-js@2'
import { drain } from '../_shared/outbox.ts'
import { builders } from './events.ts'

// Drains the webhook outbox: every poke — from a trigger, from the cron, from
// anybody holding the anon key — runs one bounded pass over what is due.
//
// Nothing in the request is read, so nothing in it is believed. The triggers
// used to post the changed row here and the handler read it back from its
// table rather than trust it; now the row goes into `webhook_outbox`, written
// by the trigger as service role, and the request is only the hint that there
// is work (migration 0079, decision 183). A poke storm from somebody holding
// the anon key costs a bounded amount of work that was due anyway, and the
// five-minute cron makes the same call, so a poke that is lost costs a
// receiver five minutes, not the event. See `_shared/outbox.ts` for what a
// pass does and `events.ts` for what each event says.
//
// The logic lives here rather than in `index.ts` so it can be imported without
// starting a server.

// deno-lint-ignore no-explicit-any
export type ClientFactory = (url: string, key: string, options?: any) => any

export interface Deps {
  createClient: ClientFactory
  fetch: typeof fetch
  /// Injected so a test can stand at a fixed time.
  now: () => Date
}

export function makeHandler(deps: Deps) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 })
    }
    const admin = deps.createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )
    const report = await drain(
      admin,
      { admin, fetch: deps.fetch, now: deps.now },
      builders,
    )
    return new Response(JSON.stringify(report), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  }
}

export const handler = makeHandler({
  createClient,
  fetch: globalThis.fetch,
  now: () => new Date(),
})
