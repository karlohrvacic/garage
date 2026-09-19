import 'package:garage/l10n/app_localizations.dart';

import '../../domain/api/api_access.dart';

/// The service names are proper nouns and stay as they are in every language;
/// only the ones that describe a behaviour get translated.
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
    WebhookFormat.teams => l10n.apiWebhookFormatTeams,
    WebhookFormat.text => l10n.apiWebhookFormatText,
    WebhookFormat.pushover => l10n.apiWebhookFormatPushover,
    WebhookFormat.pushbullet => l10n.apiWebhookFormatPushbullet,
  };
}

/// What a group of events sends, in words: a household chooses these by what
/// they are, not by the keys a receiver matches on.
String webhookGroupLabel(AppLocalizations l10n, WebhookEventGroup group) {
  return switch (group) {
    WebhookEventGroup.entries => l10n.apiWebhookEventEntries,
    WebhookEventGroup.changes => l10n.apiWebhookEventChanges,
    WebhookEventGroup.cars => l10n.apiWebhookEventCars,
    WebhookEventGroup.members => l10n.apiWebhookEventMembers,
    WebhookEventGroup.reminders => l10n.apiWebhookEventReminders,
  };
}

/// Each language named in itself, as a language picker does, so a reader who
/// does not speak the app's language still finds their own.
String webhookLanguageLabel(WebhookLanguage language) {
  return switch (language) {
    WebhookLanguage.en => 'English',
    WebhookLanguage.hr => 'Hrvatski',
    WebhookLanguage.it => 'Italiano',
  };
}
