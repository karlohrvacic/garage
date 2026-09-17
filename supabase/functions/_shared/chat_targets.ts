// Where a webhook is pointed decides what it will accept.
//
// The generic contract — a signed JSON body a household's own service can
// verify — is what this app's webhooks were built for, and it is what a home
// dashboard or a script wants. Chat services are not generic receivers: Discord
// replies 400 to anything without `content`, `embeds` or `file`, whatever else
// the body holds, and Slack and Telegram have their own shapes. A household
// that pastes a Discord URL is not doing anything unreasonable, and telling
// them the app cannot talk to it would be a poor answer when the difference is
// one JSON key.
//
// Detection is by host first: the URL already says which service it is, and a
// household that pastes a Discord address should not also have to say so. It
// stopped being the only way when self-hosted receivers turned up — an ntfy or
// a Gotify on a domain of the owner's own, which no list of hosts can contain
// — so the webhook carries a `format` as well, `auto` unless the household
// chose one, and `targetFor` lets that choice win.

export type ChatTarget =
  | 'discord'
  | 'slack'
  | 'googlechat'
  | 'telegram'
  | 'ntfy'
  | 'gotify'
  | 'generic'

/// The target for a hook, honouring an explicit choice over the URL.
///
/// `auto` — the default — reads the host, which is right for every hosted
/// service and for every generic receiver. A household running its own ntfy,
/// Gotify or Mattermost has a domain no host list can contain, and says so
/// here instead.
export function targetFor(url: string, format: string): ChatTarget {
  if (format !== 'auto' && format !== '') {
    return format as ChatTarget
  }
  return chatTargetFor(url)
}

export function chatTargetFor(url: string): ChatTarget {
  let host: string
  try {
    host = new URL(url).host.toLowerCase()
  } catch {
    // Not a URL we can read. The generic body is the safe answer: it is what
    // every non-chat receiver expects, and delivery will fail on the fetch
    // rather than on the shape.
    return 'generic'
  }
  if (host === 'discord.com' || host === 'discordapp.com') {
    return 'discord'
  }
  if (host === 'hooks.slack.com') {
    return 'slack'
  }
  if (host === 'chat.googleapis.com') {
    return 'googlechat'
  }
  if (host === 'api.telegram.org') {
    return 'telegram'
  }
  // Only the hosted instance. ntfy is commonly self-hosted on a domain of the
  // household's own, which no host check can recognise — those keep the
  // generic contract until there is a way to say so explicitly.
  if (host === 'ntfy.sh') {
    return 'ntfy'
  }
  return 'generic'
}

/// What to send, and how to say what it is.
///
/// Not just a body: ntfy takes the message as a plain-text body with the title
/// in a header, so the content type and the headers vary by target too.
export interface Delivery {
  body: string
  contentType: string
  headers: Record<string, string>
}

/// [generic] is the signed JSON every non-chat receiver gets, passed in rather
/// than rebuilt so the signature stays over exactly what is sent. [message] is
/// the text a person reads — an entry's or a reminder's — which may run to
/// several lines; every target here takes a line break as a line break.
///
/// The message carries what people typed — a note, a station, a shop — and
/// not only members type: a guest with a pass to one car can log a fill-up
/// with a note on it. Where a service reads its own markup out of message
/// text, that text is somebody else's way into the household's channel.
export function deliveryFor(
  target: ChatTarget,
  generic: string,
  message: string,
): Delivery {
  const json = (body: unknown): Delivery => ({
    body: JSON.stringify(body),
    contentType: 'application/json',
    headers: {},
  })

  switch (target) {
    // An empty `parse` list is Discord's own way of saying that nothing in
    // the text is a mention. Without it `@everyone` in a note pings the whole
    // server from a fill-up. And 4 is SUPPRESS_EMBEDS, one of the few flags a
    // webhook may set: a link in a note stays a link, without also unfurling
    // into a preview card of its author's choosing.
    case 'discord':
      return json({
        content: message,
        allowed_mentions: { parse: [] },
        flags: 4,
      })
    // Slack and Google Chat happen to agree on the key. Kept as separate
    // cases rather than folded together: they are separate services and one of
    // them changing its mind should not silently move the other.
    case 'slack':
      return json({ text: slackEscaped(message) })
    case 'googlechat':
      return json({ text: googleChatDefused(message) })
    // Telegram takes `chat_id` from the query string the household pasted —
    // `…/bot<token>/sendMessage?chat_id=<id>` — so only the text is ours to
    // supply. Without a chat_id Telegram answers 400, which is the honest
    // outcome for a URL that names no chat.
    case 'telegram':
      return json({ text: message })
    // The topic is the URL's own path, so the message is the whole body and
    // nothing needs rewriting. The alternative — JSON with a `topic` field —
    // has to be POSTed to the root instead, which would mean editing the URL
    // the household pasted.
    case 'ntfy':
      return {
        body: message,
        contentType: 'text/plain; charset=utf-8',
        headers: { Title: 'Garage' },
      }
    // Gotify takes a title and a message as JSON, with the application token
    // in the URL the household pasted.
    case 'gotify':
      return json({ title: 'Garage', message })
    case 'generic':
      return {
        body: generic,
        contentType: 'application/json',
        headers: {},
      }
  }
}

/// Slack reads `&`, `<` and `>` as control characters — `<!channel>` notifies
/// everyone, `<https://…|words>` is a link wearing other words — and asks for
/// exactly these three as entities, which it turns back for display. Nothing
/// else decodes them, so nothing else is given them.
function slackEscaped(text: string): string {
  return text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

/// Google Chat reads `<users/all>` as a mention of the whole space and
/// `<https://…|words>` as a link wearing other words, and documents no way of
/// writing either literally: no escape, and nothing about decoding entities,
/// so Slack's answer cannot be assumed and would likely arrive as a visible
/// `&lt;`. What can be done without knowing is to leave it no token to find.
/// Every angle bracket becomes the single guillemet that looks most like it,
/// which costs "tyres < 3 mm" a slightly odd character and costs markup
/// everything. Nothing the message says for itself has a bracket in it.
function googleChatDefused(text: string): string {
  // U+2039 and U+203A, spelled out because in most editors they are hard
  // to tell from the characters they replace.
  return text.replaceAll('<', '\u2039').replaceAll('>', '\u203a')
}
