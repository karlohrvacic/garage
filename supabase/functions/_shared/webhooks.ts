import { deliveryFor, targetFor } from './chat_targets.ts'

// How a household's webhooks are called, whatever they are being told.
//
// Two functions send events: `dispatch-webhooks` when an entry is logged, and
// `push-due-reminders` when something falls due. A receiver cannot tell which
// one it heard from, and should not have to — the same signature over the
// same kind of body, the same headers, the same single attempt and the same
// record of how it went. Written once, here, so the two cannot drift.
//
// Directories under `functions/` whose name starts with `_` are not deployed
// as functions. Each function that imports this has it bundled in when it is
// deployed.

/// A `webhooks` row, as much of it as a delivery needs.
export interface Hook {
  id: string
  url: string
  secret: string
  events: string[]
  /// `auto` unless the household chose a shape the URL cannot imply.
  format?: string
}

/// The columns a [Hook] is read from.
export const HOOK_COLUMNS = 'id, url, secret, events, format'

/// How long a receiver has to answer before the call is abandoned.
const TIMEOUT_MS = 10_000

/// HMAC-SHA256 of [body] keyed with [secret], as lower-case hex: what
/// `hmac.new(secret, body, hashlib.sha256).hexdigest()` prints on the other
/// end.
export async function sign(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(body),
  )
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

export interface DeliveryDeps {
  /// The service-role client, to record each call on its hook.
  // deno-lint-ignore no-explicit-any
  admin: any
  fetch: typeof fetch
  now: () => Date
}

/// Posts [event] to every hook in [hooks], once each, and writes on each hook
/// when it was called and what came back. Resolves to how many answered with
/// a status in the 200s.
///
/// [body] is the generic JSON, and [message] the text a chat service shows
/// instead — see `chat_targets.ts`.
///
/// Best-effort on purpose: one attempt, no queue. A receiver that missed a
/// call can read the same data from the API, and retry storms are worse than
/// a missed ping. Every call is signed, so a receiver can tell a real one from
/// anything else that finds its URL.
///
/// The hooks are called side by side rather than in turn. The daily reminder
/// run calls every garage's hooks before it pushes, and in turn a few
/// receivers that are switched off would each hold everything behind them up
/// for the whole timeout. Each call still starts in the order given.
export async function deliver(
  deps: DeliveryDeps,
  event: string,
  hooks: Hook[],
  body: string,
  message: string,
): Promise<number> {
  const signatures = await Promise.all(
    hooks.map((hook) => sign(hook.secret, body)),
  )
  const answered = await Promise.all(
    hooks.map((hook, index) =>
      post(deps, event, hook, body, message, signatures[index])
    ),
  )
  return answered.filter((ok) => ok).length
}

async function post(
  deps: DeliveryDeps,
  event: string,
  hook: Hook,
  body: string,
  message: string,
  signature: string,
): Promise<boolean> {
  // Discord answers 400 to any body without `content`, and Slack and Telegram
  // have shapes of their own, so what goes over the wire depends on where it
  // is going. The signature is still sent and still covers the generic body:
  // a chat service ignores the header, and a receiver that checks it is by
  // definition a generic one.
  const outgoing = deliveryFor(
    targetFor(hook.url, hook.format ?? 'auto'),
    body,
    message,
  )
  let status = 0
  let ok = false
  try {
    const response = await deps.fetch(hook.url, {
      method: 'POST',
      headers: {
        'Content-Type': outgoing.contentType,
        'X-Garage-Event': event,
        'X-Garage-Signature': signature,
        ...outgoing.headers,
      },
      body: outgoing.body,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    })
    status = response.status
    ok = response.ok
  } catch {
    // A home server that is off, or a URL that no longer resolves. Recorded
    // below so the household can see the hook failing in the app.
    status = 0
  }
  await deps.admin
    .from('webhooks')
    .update({
      last_delivery_at: deps.now().toISOString(),
      last_delivery_status: status,
    })
    .eq('id', hook.id)
  return ok
}
