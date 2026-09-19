import 'package:garage/l10n/app_localizations.dart';

import '../../core/format/unit_format.dart';
import '../../domain/api/api_access.dart';

/// One line on how a hook is doing, in the order a reader needs it: a hook
/// the dispatcher switched off says so before anything else, one that was
/// never sent has no delivery to describe, and the rest say how the last one
/// went.
String webhookStatusLine(
  AppLocalizations l10n,
  UnitFormat format,
  Webhook webhook,
) {
  if (webhook.isPaused) {
    return l10n.apiWebhookPaused;
  }
  final at = webhook.lastDeliveryAt;
  if (at == null) {
    return l10n.apiWebhookNever;
  }
  if (webhook.isDelivering) {
    return l10n.apiWebhookDelivered(format.formatShortDate(at.toLocal()));
  }
  // Not delivering means a status, and one outside 2xx.
  return l10n.apiWebhookFailing(webhook.lastDeliveryStatus!);
}

/// Whether the line above is bad news, and so drawn in red.
bool webhookStatusIsBad(Webhook webhook) =>
    webhook.isPaused || !webhook.isDelivering;
