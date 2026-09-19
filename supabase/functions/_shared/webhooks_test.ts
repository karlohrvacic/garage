import { assertEquals } from 'jsr:@std/assert@1'
import { fakeClient } from '../_test/fake_supabase.ts'
import { type Delivery, type Hook, postDelivery, sign } from './webhooks.ts'

// What one post looks like on the wire. How posts are queued, retried, given
// up on and recorded is the drain's business and is tested in
// `outbox_test.ts`. Deliveries are posted in turn there, not side by side:
// each is bounded by the ten-second timeout, and a receiver that is off is
// paused after twenty failures rather than waited on forever.

const AT = new Date('2026-08-17T10:00:00.000Z')

const BODY = '{"event":"test.event","vehicle_id":"v1"}'
const MESSAGE = '🔔 Something · Clio'

const delivery: Delivery = {
  id: 'd1',
  webhook_id: 'w1',
  event: 'test.event',
  body: BODY,
  message: MESSAGE,
  attempts: 0,
}

const generic: Hook = {
  id: 'w1',
  url: 'https://home.example/hook',
  secret: 's3cret',
  events: ['test.event'],
}

const discord: Hook = {
  id: 'w2',
  url: 'https://discord.com/api/webhooks/1/a',
  secret: 'another',
  events: ['test.event'],
  format: 'auto',
}

interface Call {
  url: string
  init: RequestInit
  headers: Record<string, string>
}

/// Delivery wired to a recording fetch and the shared fake, so what went over
/// the wire and what was written back can both be looked at.
function deliveryWith(
  respond: (url: string) => Response | Promise<Response> = () =>
    new Response('', { status: 200 }),
) {
  const admin = fakeClient()
  const calls: Call[] = []
  const deps = {
    admin,
    now: () => AT,
    fetch: ((url: string, init: RequestInit) => {
      calls.push({
        url,
        init,
        headers: init.headers as Record<string, string>,
      })
      return Promise.resolve(respond(url))
    }) as unknown as typeof fetch,
  }
  return { deps, admin, calls }
}

// RFC 4231, test case 2, which is also what the snippet in the public docs
// prints: `hmac.new(b"Jefe", body, hashlib.sha256).hexdigest()`. A receiver
// verifies with its own library, so the only signature worth sending is the
// one every library agrees on.
Deno.test('the signature is the HMAC-SHA256 a receiver computes, in hex', async () => {
  assertEquals(
    await sign('Jefe', 'what do ya want for nothing?'),
    '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
  )
})

Deno.test('a delivery is posted with its event, signature and id', async () => {
  const { deps, admin, calls } = deliveryWith()

  const status = await postDelivery(deps, delivery, generic)

  assertEquals(status, 200)
  assertEquals(calls.length, 1)
  assertEquals(calls[0].url, generic.url)
  assertEquals(calls[0].init.method, 'POST')
  assertEquals(calls[0].init.body, BODY)
  assertEquals(calls[0].headers['Content-Type'], 'application/json')
  assertEquals(calls[0].headers['X-Garage-Event'], 'test.event')
  assertEquals(calls[0].headers['X-Garage-Delivery'], 'd1')
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign('s3cret', BODY),
  )
  assertEquals(calls[0].init.signal instanceof AbortSignal, true)
  assertEquals(admin.queries, [], 'the drain records the outcome, not this')
})

// A chat service ignores the header, and a receiver that checks it is by
// definition a generic one — so what is signed is always the generic body,
// whatever this particular hook was sent.
Deno.test('a chat service gets its own shape, under the generic signature', async () => {
  const { deps, calls } = deliveryWith()

  await postDelivery(deps, delivery, discord)

  assertEquals(JSON.parse(calls[0].init.body as string), {
    content: MESSAGE,
    allowed_mentions: { parse: [] },
    flags: 4,
  })
  assertEquals(
    calls[0].headers['X-Garage-Signature'],
    await sign('another', BODY),
  )
})

// The one place the pasted URL is both read and rewritten: the tokens come
// out of its query and into the body or a header, and the post goes to the
// URL without them.
Deno.test('a Pushover hook is posted to its bare URL, tokens in the body', async () => {
  const { deps, calls } = deliveryWith()
  const pushover: Hook = {
    id: 'w3',
    url: 'https://api.pushover.net/1/messages.json?token=t&user=u',
    secret: 's',
    events: ['test.event'],
    format: 'auto',
  }

  await postDelivery(deps, delivery, pushover)

  assertEquals(calls[0].url, 'https://api.pushover.net/1/messages.json')
  assertEquals(JSON.parse(calls[0].init.body as string), {
    token: 't',
    user: 'u',
    title: 'Garage',
    message: MESSAGE,
  })
})

Deno.test('a Pushbullet hook is posted to its bare URL, token in a header', async () => {
  const { deps, calls } = deliveryWith()
  // No format stored at all, as an older row would have: reads as auto.
  const pushbullet: Hook = {
    id: 'w4',
    url: 'https://api.pushbullet.com/v2/pushes?token=o.abc',
    secret: 's',
    events: ['test.event'],
  }

  await postDelivery(deps, delivery, pushbullet)

  assertEquals(calls[0].url, 'https://api.pushbullet.com/v2/pushes')
  assertEquals(calls[0].headers['Access-Token'], 'o.abc')
  assertEquals(
    calls[0].headers['X-Garage-Delivery'],
    'd1',
    "the app's own headers still ride along",
  )
})

Deno.test('the answer is the status, whatever it was', async () => {
  // A 204 may not carry a body, not even an empty one.
  const { deps } = deliveryWith(() => new Response(null, { status: 204 }))
  assertEquals(await postDelivery(deps, delivery, generic), 204)

  const refused = deliveryWith(() => new Response('', { status: 500 }))
  assertEquals(await postDelivery(refused.deps, delivery, generic), 500)
})

// Status 0 is what the app shows as "the last call did not get through".
Deno.test('a receiver that cannot be reached answers 0', async () => {
  const { deps, calls } = deliveryWith(() => {
    throw new TypeError('connection refused')
  })

  assertEquals(await postDelivery(deps, delivery, generic), 0)
  assertEquals(calls.length, 1, "one attempt; the retry is the drain's")
})
