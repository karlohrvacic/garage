import { assertEquals } from 'jsr:@std/assert@1'
import { chatTargetFor, deliveryFor, targetFor } from './chat_targets.ts'

Deno.test('a Discord webhook is recognised', () => {
  assertEquals(
    chatTargetFor('https://discord.com/api/webhooks/123/abc'),
    'discord',
  )
  // The old host is still handed out by older integrations.
  assertEquals(
    chatTargetFor('https://discordapp.com/api/webhooks/123/abc'),
    'discord',
  )
})

Deno.test('so are Slack and Telegram', () => {
  assertEquals(chatTargetFor('https://hooks.slack.com/services/A/B/C'), 'slack')
  assertEquals(
    chatTargetFor('https://api.telegram.org/bot123:abc/sendMessage?chat_id=1'),
    'telegram',
  )
})

Deno.test('anything else keeps the generic contract', () => {
  assertEquals(chatTargetFor('https://home.example/hook'), 'generic')
  assertEquals(chatTargetFor('https://discord.com.evil.test/x'), 'generic')
  assertEquals(chatTargetFor('not a url'), 'generic')
})

Deno.test('Discord gets content, Slack and Telegram get text', () => {
  assertEquals(
    JSON.parse(deliveryFor('discord', '{"generic":true}', 'hello').body)
      .content,
    'hello',
  )
  assertEquals(
    deliveryFor('slack', '{"generic":true}', 'hello').body,
    '{"text":"hello"}',
  )
  assertEquals(
    deliveryFor('telegram', '{"generic":true}', 'hello').body,
    '{"text":"hello"}',
  )
})

Deno.test('Google Chat is recognised and takes text', () => {
  assertEquals(
    chatTargetFor('https://chat.googleapis.com/v1/spaces/A/messages?key=k'),
    'googlechat',
  )
  assertEquals(
    deliveryFor('googlechat', '{"generic":true}', 'hello').body,
    '{"text":"hello"}',
  )
})

Deno.test('ntfy.sh is recognised, but only the hosted instance', () => {
  assertEquals(chatTargetFor('https://ntfy.sh/my-garage'), 'ntfy')
  // Self-hosted: no host check can know which software answers there.
  assertEquals(chatTargetFor('https://ntfy.example.org/my-garage'), 'generic')
})

// The message is the body, not a JSON field, and the title rides in a header.
// Posting JSON to a topic URL would publish the literal braces as the text.
Deno.test('ntfy takes the message as plain text', () => {
  const delivery = deliveryFor('ntfy', '{"generic":true}', 'hello')

  assertEquals(delivery.body, 'hello')
  assertEquals(delivery.contentType, 'text/plain; charset=utf-8')
  assertEquals(delivery.headers.Title, 'Garage')
})

Deno.test('a generic receiver gets exactly what was signed', () => {
  const delivery = deliveryFor('generic', '{"generic":true}', 'hello')

  assertEquals(delivery.body, '{"generic":true}')
  assertEquals(delivery.contentType, 'application/json')
})

// The message now carries what people typed — a note, a station, a shop — and
// a guest with a pass to one car can type there too. `@everyone` in a note
// would otherwise ping the household's whole server from a fill-up.
Deno.test('Discord is told to ping nobody', () => {
  const sent = JSON.parse(
    deliveryFor('discord', '{"generic":true}', '"@everyone look"').body,
  )

  assertEquals(sent, {
    content: '"@everyone look"',
    allowed_mentions: { parse: [] },
    // SUPPRESS_EMBEDS. A link in a note stays a link; it does not also unfurl
    // into a preview card of somebody else's choosing under a fill-up.
    flags: 4,
  })
})

// Slack reads `&`, `<` and `>` as control characters: `<!channel>` notifies
// everyone and `<https://…|text>` is a link wearing other words. Its own rule
// is that these three become entities, which it turns back for display.
Deno.test('Slack gets its three control characters as entities', () => {
  assertEquals(
    JSON.parse(
      deliveryFor('slack', '{}', '"<!channel> tyres < 3 mm & worn"').body,
    ).text,
    '"&lt;!channel&gt; tyres &lt; 3 mm &amp; worn"',
  )
  // Nobody else decodes entities, so nobody else gets them.
  assertEquals(
    JSON.parse(deliveryFor('telegram', '{}', 'a < b & c').body).text,
    'a < b & c',
  )
})

// Google Chat reads `<users/all>` as a mention of the whole space and
// `<https://…|words>` as a link wearing other words, and documents no way to
// escape either. What is left is to make sure the token is not there.
Deno.test('Google Chat is given no angle bracket to read markup out of', () => {
  assertEquals(
    JSON.parse(
      deliveryFor(
        'googlechat',
        '{}',
        '"<users/all> see <https://evil.example|the invoice>, tyres < 3 mm"',
      ).body,
    ).text,
    '"‹users/all› see ‹https://evil.example|the invoice›, tyres ‹ 3 mm"',
  )
  // Its own business, and nobody else's.
  assertEquals(
    JSON.parse(deliveryFor('telegram', '{}', '<users/all>').body).text,
    '<users/all>',
  )
})

Deno.test('a message of several lines reaches every target whole', () => {
  const message = 'first\nsecond'

  for (
    const target of ['discord', 'slack', 'googlechat', 'telegram'] as const
  ) {
    const sent = JSON.parse(deliveryFor(target, '{}', message).body)
    assertEquals(sent.content ?? sent.text, message, target)
  }
  assertEquals(deliveryFor('ntfy', '{}', message).body, message)
  assertEquals(
    JSON.parse(deliveryFor('gotify', '{}', message).body).message,
    message,
  )
})

// The gap host detection cannot close: a self-hosted ntfy, Gotify or
// Mattermost answers on a domain of the owner's choosing, and no list of
// hostnames will ever contain it.
Deno.test('an explicit format beats the URL', () => {
  assertEquals(targetFor('https://push.example.org/my-garage', 'ntfy'), 'ntfy')
  assertEquals(targetFor('https://chat.example.org/hooks/x', 'slack'), 'slack')
})

Deno.test('auto falls back to reading the host', () => {
  assertEquals(
    targetFor('https://discord.com/api/webhooks/1/a', 'auto'),
    'discord',
  )
  assertEquals(targetFor('https://home.example/hook', 'auto'), 'generic')
  // An older row with no format stored at all reads as auto.
  assertEquals(targetFor('https://ntfy.sh/topic', ''), 'ntfy')
})

Deno.test('Gotify takes a title and a message', () => {
  const delivery = deliveryFor('gotify', '{"generic":true}', 'hello')

  assertEquals(JSON.parse(delivery.body), { title: 'Garage', message: 'hello' })
})

// Home Assistant needs nothing: its webhook trigger accepts any JSON and
// exposes it to automations as `trigger.json`, so the generic signed payload
// is already the right thing to send.
Deno.test('Home Assistant is a generic receiver, not a special case', () => {
  assertEquals(
    targetFor('https://ha.example.org/api/webhook/abc', 'auto'),
    'generic',
  )
})
