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
  | 'teams'
  | 'text'
  | 'pushover'
  | 'pushbullet'
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
  // Teams webhooks are Power Automate flows now that the Office connectors
  // are retired; both hosts are Microsoft's and neither is ever a home
  // server.
  if (
    host.endsWith('.logic.azure.com') || host.endsWith('.webhook.office.com')
  ) {
    return 'teams'
  }
  if (host === 'api.pushover.net') {
    return 'pushover'
  }
  if (host === 'api.pushbullet.com') {
    return 'pushbullet'
  }
  return 'generic'
}

/// What goes over the wire for one delivery, and how to say what it is.
///
/// Not just a body: ntfy takes the message as a plain-text body with the title
/// in a header, so the content type and the headers vary by target too.
export interface Outgoing {
  body: string
  contentType: string
  headers: Record<string, string>
  /// Where to post when that is not the URL the household pasted. Pushover
  /// and Pushbullet set it: their tokens ride in the pasted URL's query, are
  /// lifted into the body or a header, and the call goes to the URL without
  /// them. Every other target leaves it unset and is posted to as pasted.
  url?: string
}

/// [generic] is the signed JSON every non-chat receiver gets, passed in rather
/// than rebuilt so the signature stays over exactly what is sent. [message] is
/// the text a person reads — an entry's or a reminder's — which may run to
/// several lines; every target here takes a line break as a line break,
/// except Teams, which is given two.
///
/// The message carries what people typed — a note, a station, a shop — and
/// not only members type: a guest with a pass to one car can log a fill-up
/// with a note on it. Where a service reads its own markup out of message
/// text, that text is somebody else's way into the household's channel.
///
/// [url] is the one the household pasted. Most targets never look at it; the
/// ones whose tokens ride in its query read them out and post to the rest.
export function deliveryFor(
  target: ChatTarget,
  generic: string,
  message: string,
  url: string,
): Outgoing {
  const json = (body: unknown): Outgoing => ({
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
    // Teams wants an Adaptive Card; a bare `text` is refused by a Workflows
    // webhook. One text block, wrapped, is the whole card. A TextBlock
    // breaks a line on `\n` only inside a list; anywhere else it takes
    // `\n\n` (Microsoft's "Newlines for Adaptive Cards"), so every line
    // break is doubled, after the Markdown in the text has been defused.
    case 'teams':
      return json({
        type: 'message',
        attachments: [{
          contentType: 'application/vnd.microsoft.card.adaptive',
          content: {
            type: 'AdaptiveCard',
            version: '1.4',
            body: [{
              type: 'TextBlock',
              text: teamsDefused(message).replaceAll('\n', '\n\n'),
              wrap: true,
            }],
          },
        }],
      })
    // Rocket.Chat, Matrix through hookshot, and anything else that reads a
    // `text` key and decodes no entities. Slack's escaping would show up
    // here as a literal "&amp;", which is why this is its own target. What
    // Rocket.Chat and Mattermost do read out of it is a group mention and a
    // Markdown link, so the message is defused of both.
    case 'text':
      return json({ text: textDefused(message) })
    // Pushover takes the application token and the user key in the body,
    // and a household has nowhere to type them but the URL. They are lifted
    // out of its query and the URL is called without them. Whatever else was
    // pasted — `priority`, `device`, `sound`, `title` — is a body field too
    // and goes along. "Garage" is only the default title, so a pasted one
    // replaces it; the message is written last, so nothing pasted replaces
    // that.
    case 'pushover': {
      const { bare, query } = split(url)
      const token = query.get('token') ?? ''
      const user = query.get('user') ?? ''
      query.delete('token')
      query.delete('user')
      return {
        ...json({
          title: 'Garage',
          ...Object.fromEntries(query),
          token,
          user,
          message,
        }),
        url: bare,
      }
    }
    // Pushbullet takes its token in a header, the same way.
    case 'pushbullet': {
      const { bare, query } = split(url)
      return {
        ...json({ type: 'note', title: 'Garage', body: message }),
        headers: { 'Access-Token': query.get('token') ?? '' },
        url: bare,
      }
    }
    case 'generic':
      return {
        body: generic,
        contentType: 'application/json',
        headers: {},
      }
  }
}

/// A URL without its query, and the query on its own.
///
/// The query is copied before the URL is stripped of it: `searchParams` is a
/// live view of the URL, and clearing `search` empties it too.
function split(url: string): { bare: string; query: URLSearchParams } {
  try {
    const parsed = new URL(url)
    const query = new URLSearchParams(parsed.search)
    parsed.search = ''
    return { bare: parsed.toString(), query }
  } catch {
    return { bare: url, query: new URLSearchParams() }
  }
}

/// Slack reads `&`, `<` and `>` as control characters — `<!channel>` notifies
/// everyone, `<https://…|words>` is a link wearing other words — and asks for
/// exactly these three as entities, which it turns back for display. Nothing
/// else decodes them, so nothing else is given them.
///
/// Mattermost speaks this format too, and reads out of it what Slack does
/// not: a plain `@channel` pages the channel, which Slack wants spelled
/// `<!channel>`, and `[words](url)` is a Markdown link, which Slack spells
/// `<url|words>`. So the text is defused the way it is for `text` before
/// the entities go on; Slack loses nothing by it.
function slackEscaped(text: string): string {
  return textDefused(text)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}

/// Mattermost and Rocket.Chat page everyone in the channel on `@channel`,
/// `@all` or `@here` in webhook text, and render Markdown, so a note's
/// `[words](url)` is a link wearing other words. The mentions are broken by
/// [mentionsDefused] and the link the way it is for Teams: a space after
/// the closing bracket.
function textDefused(text: string): string {
  return mentionsDefused(text).replaceAll('](', '] (')
}

/// `@channel`, `@all` and `@here` as words of their own, in any case: not
/// `@allison`, not `x@here`, and not `name@example.com`, whose `@` is
/// followed by no such word.
const GROUP_MENTION = /(?<!\w)@(channel|all|here)(?!\w)/gi

/// A zero-width space after the `@` leaves the word readable, and a service
/// looking for the mention finds none. Invisible, which is the point here:
/// the word is what the person wrote and should still read as it.
function mentionsDefused(text: string): string {
  // U+200B, spelled out because it cannot be seen at all.
  return text.replaceAll(GROUP_MENTION, '@​$1')
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

/// A Teams TextBlock renders Markdown: bold, italic, lists and links. The
/// link is the one that matters — `[the invoice](https://evil.example)` in
/// a note arrives as a link wearing other words, the same threat Slack and
/// Google Chat are defused of above — and Adaptive Cards document no escape
/// for it either. So the syntax is broken instead: a space after the closing
/// bracket, and `[words] (url)` is two things a person can read rather than
/// one link. Bold and italic from a note are harmless and are left alone.
function teamsDefused(text: string): string {
  return text.replaceAll('](', '] (')
}
