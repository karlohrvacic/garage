import { assertEquals } from 'jsr:@std/assert@1'
import { chatTargetFor, deliveryFor, targetFor } from './chat_targets.ts'

// The URL the household pasted. Only Pushover and Pushbullet read anything
// out of it; every other target is handed it and leaves it alone, so one
// will do for all of them.
const hookUrl = 'https://home.example/hook'

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
    JSON.parse(
      deliveryFor('discord', '{"generic":true}', 'hello', hookUrl).body,
    )
      .content,
    'hello',
  )
  assertEquals(
    deliveryFor('slack', '{"generic":true}', 'hello', hookUrl).body,
    '{"text":"hello"}',
  )
  assertEquals(
    deliveryFor('telegram', '{"generic":true}', 'hello', hookUrl).body,
    '{"text":"hello"}',
  )
})

Deno.test('Google Chat is recognised and takes text', () => {
  assertEquals(
    chatTargetFor('https://chat.googleapis.com/v1/spaces/A/messages?key=k'),
    'googlechat',
  )
  assertEquals(
    deliveryFor('googlechat', '{"generic":true}', 'hello', hookUrl).body,
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
  const delivery = deliveryFor('ntfy', '{"generic":true}', 'hello', hookUrl)

  assertEquals(delivery.body, 'hello')
  assertEquals(delivery.contentType, 'text/plain; charset=utf-8')
  assertEquals(delivery.headers.Title, 'Garage')
})

Deno.test('a generic receiver gets exactly what was signed', () => {
  const delivery = deliveryFor('generic', '{"generic":true}', 'hello', hookUrl)

  assertEquals(delivery.body, '{"generic":true}')
  assertEquals(delivery.contentType, 'application/json')
})

// The message now carries what people typed — a note, a station, a shop — and
// a guest with a pass to one car can type there too. `@everyone` in a note
// would otherwise ping the household's whole server from a fill-up.
Deno.test('Discord is told to ping nobody', () => {
  const sent = JSON.parse(
    deliveryFor('discord', '{"generic":true}', '"@everyone look"', hookUrl)
      .body,
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
      deliveryFor('slack', '{}', '"<!channel> tyres < 3 mm & worn"', hookUrl)
        .body,
    ).text,
    '"&lt;!channel&gt; tyres &lt; 3 mm &amp; worn"',
  )
  // Nobody else decodes entities, so nobody else gets them.
  assertEquals(
    JSON.parse(deliveryFor('telegram', '{}', 'a < b & c', hookUrl).body).text,
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
        hookUrl,
      ).body,
    ).text,
    '"‹users/all› see ‹https://evil.example|the invoice›, tyres ‹ 3 mm"',
  )
  // Its own business, and nobody else's.
  assertEquals(
    JSON.parse(deliveryFor('telegram', '{}', '<users/all>', hookUrl).body).text,
    '<users/all>',
  )
})

Deno.test('a message of several lines reaches every target whole', () => {
  const message = 'first\nsecond'

  for (
    const target of ['discord', 'slack', 'googlechat', 'telegram'] as const
  ) {
    const sent = JSON.parse(deliveryFor(target, '{}', message, hookUrl).body)
    assertEquals(sent.content ?? sent.text, message, target)
  }
  assertEquals(deliveryFor('ntfy', '{}', message, hookUrl).body, message)
  assertEquals(
    JSON.parse(deliveryFor('gotify', '{}', message, hookUrl).body).message,
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
  const delivery = deliveryFor('gotify', '{"generic":true}', 'hello', hookUrl)

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

Deno.test('Teams is recognised from either of its webhook hosts', () => {
  assertEquals(
    chatTargetFor(
      'https://prod-12.westeurope.logic.azure.com:443/workflows/abc',
    ),
    'teams',
  )
  assertEquals(
    chatTargetFor('https://contoso.webhook.office.com/webhookb2/abc'),
    'teams',
  )
  // A look-alike: the suffix has to end the host, not merely appear in it.
  assertEquals(
    chatTargetFor('https://contoso.webhook.office.com.evil.example/x'),
    'generic',
  )
  assertEquals(
    chatTargetFor('https://prod-1.logic.azure.com.evil.example/x'),
    'generic',
  )
})

Deno.test('Teams gets an adaptive card with the message wrapped', () => {
  const delivery = deliveryFor(
    'teams',
    '{}',
    'line one\nline two',
    'https://x.webhook.office.com/a',
  )
  const body = JSON.parse(delivery.body)
  assertEquals(body.type, 'message')
  assertEquals(
    body.attachments[0].contentType,
    'application/vnd.microsoft.card.adaptive',
  )
  // A TextBlock breaks a line on `\n` only inside a list; anywhere else it
  // takes `\n\n`, so every line break is sent twice.
  assertEquals(
    body.attachments[0].content.body[0].text,
    'line one\n\nline two',
  )
  assertEquals(body.attachments[0].content.body[0].wrap, true)
})

// A TextBlock renders Markdown, so `[words](url)` in a note would arrive as
// a link wearing other words: the threat Slack and Google Chat are defused
// of above. Adaptive Cards document no escape either, so the syntax is
// broken instead.
Deno.test('Teams is given no Markdown link to render', () => {
  const text = (message: string): string =>
    JSON.parse(deliveryFor('teams', '{}', message, hookUrl).body)
      .attachments[0].content.body[0].text

  assertEquals(
    text('see [the invoice](https://evil.example) today'),
    'see [the invoice] (https://evil.example) today',
  )
  // Nothing else is touched: no entities, no guillemets, and a line break
  // is only doubled.
  assertEquals(
    text('tyres < 3 mm & worn\n**next**'),
    'tyres < 3 mm & worn\n\n**next**',
  )
})

// Mattermost and Rocket.Chat page the whole channel on `@channel`, `@all`
// or `@here` in webhook text and render Markdown links, and both are
// reached through `text` or, Mattermost, through the Slack format.
Deno.test('text and Slack are given no group mention and no link', () => {
  const note = 'hey @channel, see [x](https://evil.example) and @ALL @here'
  const text = (target: 'text' | 'slack'): string =>
    JSON.parse(deliveryFor(target, '{}', note, hookUrl).body).text

  for (const target of ['text', 'slack'] as const) {
    const sent = text(target)
    assertEquals(sent.includes('@channel'), false, target)
    assertEquals(sent.includes('@ALL'), false, target)
    assertEquals(sent.includes('@here'), false, target)
    assertEquals(sent.includes(']('), false, target)
  }
  // Exactly what is sent: a zero-width space (U+200B) after each `@`, which
  // a reader never sees, and a space in the link. Slack's entities come on
  // top of it.
  assertEquals(
    text('text'),
    'hey @​channel, see [x] (https://evil.example) and @​ALL @​here',
  )
  assertEquals(
    text('slack'),
    'hey @​channel, see [x] (https://evil.example) and @​ALL @​here',
  )
})

Deno.test('an address is not a mention, nor is a longer word', () => {
  for (const target of ['text', 'slack'] as const) {
    assertEquals(
      JSON.parse(
        deliveryFor(target, '{}', 'mail name@example.com', hookUrl).body,
      )
        .text,
      'mail name@example.com',
      target,
    )
  }
  assertEquals(
    JSON.parse(
      deliveryFor('text', '{}', '@allison @channels x@here', hookUrl).body,
    )
      .text,
    '@allison @channels x@here',
  )
})

Deno.test('text is never detected and takes the message as it is', () => {
  assertEquals(chatTargetFor('https://chat.example/hooks/abc'), 'generic')
  assertEquals(targetFor('https://chat.example/hooks/abc', 'text'), 'text')
  assertEquals(
    JSON.parse(
      deliveryFor('text', '{}', 'a & b <c>', 'https://chat.example/hooks/abc')
        .body,
    ),
    { text: 'a & b <c>' },
  )
})

Deno.test('Pushover takes its token and user key out of the pasted URL', () => {
  const url =
    'https://api.pushover.net/1/messages.json?token=app123&user=usr456'
  assertEquals(chatTargetFor(url), 'pushover')
  const delivery = deliveryFor('pushover', '{}', 'hello', url)
  assertEquals(delivery.url, 'https://api.pushover.net/1/messages.json')
  assertEquals(JSON.parse(delivery.body), {
    token: 'app123',
    user: 'usr456',
    title: 'Garage',
    message: 'hello',
  })
})

// Pushover reads `priority`, `device`, `sound` and the rest as body fields,
// and the URL is the only place a household can put them.
Deno.test('Pushover is handed whatever else was pasted after the token', () => {
  const url =
    'https://api.pushover.net/1/messages.json?token=app123&user=usr456&priority=1&sound=magic'
  const delivery = deliveryFor('pushover', '{}', 'hello', url)
  assertEquals(delivery.url, 'https://api.pushover.net/1/messages.json')
  assertEquals(JSON.parse(delivery.body), {
    priority: '1',
    sound: 'magic',
    token: 'app123',
    user: 'usr456',
    title: 'Garage',
    message: 'hello',
  })
})

// "Garage" is only the default: a household that typed a title meant it.
Deno.test('a pasted title wins over the default one', () => {
  const delivery = deliveryFor(
    'pushover',
    '{}',
    'hello',
    'https://api.pushover.net/1/messages.json?token=a&user=b&title=Mine',
  )
  assertEquals(JSON.parse(delivery.body).title, 'Mine')
})

Deno.test('Pushbullet takes its token into the header', () => {
  const url = 'https://api.pushbullet.com/v2/pushes?token=o.abc'
  assertEquals(chatTargetFor(url), 'pushbullet')
  const delivery = deliveryFor('pushbullet', '{}', 'hello', url)
  assertEquals(delivery.url, 'https://api.pushbullet.com/v2/pushes')
  assertEquals(delivery.headers['Access-Token'], 'o.abc')
  assertEquals(JSON.parse(delivery.body), {
    type: 'note',
    title: 'Garage',
    body: 'hello',
  })
})

Deno.test('a token that was never pasted is sent as nothing, not as "undefined"', () => {
  const delivery = deliveryFor(
    'pushover',
    '{}',
    'hello',
    'https://api.pushover.net/1/messages.json',
  )
  assertEquals(JSON.parse(delivery.body).token, '')
})
