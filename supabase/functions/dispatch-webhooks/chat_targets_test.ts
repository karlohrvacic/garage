import { assertEquals } from 'jsr:@std/assert@1'
import {
  chatSummary,
  chatTargetFor,
  deliveryFor,
  targetFor,
} from './chat_targets.ts'

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
    deliveryFor('discord', '{"generic":true}', 'hello').body,
    '{"content":"hello"}',
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

Deno.test('the summary names the kind and the car', () => {
  assertEquals(
    chatSummary('fuel', 'Golf', {}),
    '⛽ Fill-up logged for Golf',
  )
})

Deno.test('and the figures worth seeing in a chat window', () => {
  assertEquals(
    chatSummary('fuel', 'Golf', {
      odometer_km: 51000,
      total: 65.4,
      volume_l: 42,
    }),
    '⛽ Fill-up logged for Golf — 51,000 km · 65.40 · 42 L',
  )
})

Deno.test('a car with no name still reads as a sentence', () => {
  assertEquals(chatSummary('cost', null, {}), '🧾 Cost logged for a vehicle')
})

Deno.test('an unknown kind falls back to its own name', () => {
  assertEquals(chatSummary('mystery', 'Golf', {}), 'mystery logged for Golf')
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
