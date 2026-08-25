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
// Detection is by host, never by asking the household to pick: the URL already
// says which service it is, and a dropdown that could disagree with the URL is
// a way to get it wrong.

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

/// A line a person can read in a chat window.
///
/// Deliberately plain and English. The edge function has no access to the
/// household's locale or to the app's ARB files, and a half-translated
/// notification would be worse than a consistent one — the app's own screens
/// remain the localized surface.
export function chatSummary(
  kind: string,
  vehicleName: string | null,
  entry: Record<string, unknown>,
): string {
  const car = vehicleName ?? 'a vehicle'
  const parts: string[] = []

  const odometer = entry.odometer_km
  if (typeof odometer === 'number') {
    parts.push(`${odometer.toLocaleString('en-GB')} km`)
  }
  const amount = entry.total ?? entry.amount ?? entry.cost
  if (typeof amount === 'number') {
    parts.push(amount.toFixed(2))
  }
  const volume = entry.volume_l
  if (typeof volume === 'number') {
    parts.push(`${volume} L`)
  }
  const distance = entry.distance_km
  if (typeof distance === 'number') {
    parts.push(`${distance} km driven`)
  }

  const detail = parts.length > 0 ? ` — ${parts.join(' · ')}` : ''
  return `${labels[kind] ?? kind} logged for ${car}${detail}`
}

const labels: Record<string, string> = {
  fuel: '⛽ Fill-up',
  service: '🔧 Service',
  cost: '🧾 Cost',
  odometer: '🛣️ Odometer reading',
  trip: '🚗 Trip',
  income: '💶 Income',
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
/// than rebuilt so the signature stays over exactly what is sent.
export function deliveryFor(
  target: ChatTarget,
  generic: string,
  summary: string,
): Delivery {
  const json = (body: unknown): Delivery => ({
    body: JSON.stringify(body),
    contentType: 'application/json',
    headers: {},
  })

  switch (target) {
    case 'discord':
      return json({ content: summary })
    // Slack and Google Chat happen to agree on the key. Kept as separate
    // cases rather than folded together: they are separate services and one of
    // them changing its mind should not silently move the other.
    case 'slack':
      return json({ text: summary })
    case 'googlechat':
      return json({ text: summary })
    // Telegram takes `chat_id` from the query string the household pasted —
    // `…/bot<token>/sendMessage?chat_id=<id>` — so only the text is ours to
    // supply. Without a chat_id Telegram answers 400, which is the honest
    // outcome for a URL that names no chat.
    case 'telegram':
      return json({ text: summary })
    // The topic is the URL's own path, so the message is the whole body and
    // nothing needs rewriting. The alternative — JSON with a `topic` field —
    // has to be POSTed to the root instead, which would mean editing the URL
    // the household pasted.
    case 'ntfy':
      return {
        body: summary,
        contentType: 'text/plain; charset=utf-8',
        headers: { Title: 'Garage' },
      }
    // Gotify takes a title and a message as JSON, with the application token
    // in the URL the household pasted.
    case 'gotify':
      return json({ title: 'Garage', message: summary })
    case 'generic':
      return {
        body: generic,
        contentType: 'application/json',
        headers: {},
      }
  }
}
