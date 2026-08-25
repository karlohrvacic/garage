import 'package:garage/l10n/app_localizations.dart';

import '../../domain/api/api_access.dart';

/// The service names are proper nouns and stay as they are in every language;
/// only the two that describe a behaviour get translated.
String webhookFormatLabel(AppLocalizations l10n, WebhookFormat format) {
  return switch (format) {
    WebhookFormat.auto => l10n.apiWebhookFormatAuto,
    WebhookFormat.generic => l10n.apiWebhookFormatGeneric,
    WebhookFormat.discord => 'Discord',
    WebhookFormat.slack => 'Slack / Mattermost',
    WebhookFormat.googlechat => 'Google Chat',
    WebhookFormat.telegram => 'Telegram',
    WebhookFormat.ntfy => 'ntfy',
    WebhookFormat.gotify => 'Gotify',
  };
}
