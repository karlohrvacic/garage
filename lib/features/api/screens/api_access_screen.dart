import '../../../core/widgets/dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/api/api_access.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/api_access_providers.dart';

/// Keys and webhooks for the household's own automation.
///
/// Everything here is read-only access to data the household already owns —
/// the app's answer to "let me put my fuel costs on my home dashboard" without
/// handing anyone a password.
class ApiAccessScreen extends ConsumerStatefulWidget {
  const ApiAccessScreen({super.key});

  @override
  ConsumerState<ApiAccessScreen> createState() => _ApiAccessScreenState();
}

class _ApiAccessScreenState extends ConsumerState<ApiAccessScreen> {
  /// The key just created, shown once. Never read back from the server.
  String? _freshKey;
  AppFailure? _failure;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _failure = null);
    try {
      await action();
      ref
        ..invalidate(apiKeysProvider)
        ..invalidate(webhooksProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    }
  }

  Future<void> _createKey() async {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        actionsOverflowDirection: garageActionsOverflowDirection,
        actionsOverflowAlignment: garageActionsOverflowAlignment,
        title: Text(l10n.apiNewKey),
        content: LabeledField(
          label: l10n.apiKeyName,
          child: TextField(controller: controller, autofocus: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.apiKeyCreate),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }

    await _run(() async {
      final key = await ref
          .read(apiAccessRepositoryProvider)
          .createKey(householdId: household.id, name: name);
      if (mounted) {
        setState(() => _freshKey = key);
      }
    });
  }

  Future<void> _revokeKey(ApiKeyRecord key) async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    await _run(() => ref.read(apiAccessRepositoryProvider).revokeKey(key.id));
  }

  Future<void> _addWebhook() async {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }
    final controller = TextEditingController();
    // Outside the builder: a value declared inside it resets on every rebuild,
    // so the message would vanish the moment it was set.
    String? error;
    final url = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            actionsOverflowDirection: garageActionsOverflowDirection,
            actionsOverflowAlignment: garageActionsOverflowAlignment,
            title: Text(l10n.apiWebhookAdd),
            content: LabeledField(
              label: l10n.apiWebhookUrl,
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(errorText: error),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  // https only: a webhook carries household data, and the
                  // secret that signs it, over the open internet.
                  if (!value.startsWith('https://')) {
                    setDialogState(() => error = l10n.apiWebhookInvalid);
                    return;
                  }
                  Navigator.of(context).pop(value);
                },
                child: Text(l10n.apiWebhookAddAction),
              ),
            ],
          );
        },
      ),
    );
    if (url == null) {
      return;
    }

    await _run(
      () => ref
          .read(apiAccessRepositoryProvider)
          .addWebhook(
            householdId: household.id,
            url: Uri.parse(url),
            events: WebhookEvent.values.toSet(),
          ),
    );
  }

  Future<void> _deleteWebhook(Webhook webhook) async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    await _run(
      () => ref.read(apiAccessRepositoryProvider).deleteWebhook(webhook.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final keys = ref.watch(apiKeysProvider).value ?? const <ApiKeyRecord>[];
    final webhooks = ref.watch(webhooksProvider).value ?? const <Webhook>[];
    final hasHousehold = ref.watch(currentHouseholdProvider).value != null;

    return GaragePageScaffold(
      title: l10n.apiTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text(l10n.apiHint, style: TextStyle(color: context.tokens.muted)),
          const SizedBox(height: GarageTokens.space4),
          if (_freshKey != null) _FreshKeyCard(apiKey: _freshKey!),
          for (final key in keys)
            Card(
              child: ListTile(
                title: Text(key.name),
                subtitle: Text(
                  [
                    key.preview,
                    if (key.isRevoked)
                      l10n.apiKeyRevoked
                    else if (key.lastUsedAt == null)
                      l10n.apiKeyNeverUsed
                    else
                      l10n.apiKeyLastUsed(format.formatDate(key.lastUsedAt!)),
                  ].join(' · '),
                ),
                trailing: key.isRevoked
                    ? null
                    : TextButton(
                        onPressed: () => _revokeKey(key),
                        child: Text(
                          l10n.apiKeyRevoke,
                          style: TextStyle(color: context.tokens.danger),
                        ),
                      ),
              ),
            ),
          const SizedBox(height: GarageTokens.space3),
          FilledButton.icon(
            // Null rather than a handler that returns: a tap doing nothing
            // is indistinguishable from a broken app.
            onPressed: hasHousehold ? _createKey : null,
            icon: const Icon(Icons.key),
            label: Text(l10n.apiNewKey),
          ),
          const SizedBox(height: GarageTokens.space6),
          Text(
            l10n.apiWebhooks.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          const SizedBox(height: GarageTokens.space1),
          Text(
            l10n.apiWebhooksHint,
            style: TextStyle(color: context.tokens.muted),
          ),
          const SizedBox(height: GarageTokens.space2),
          for (final webhook in webhooks)
            Card(
              child: ListTile(
                title: Text(webhook.url.toString()),
                subtitle: webhook.isDelivering
                    ? Text(webhook.events.map((event) => event.key).join(', '))
                    : Text(
                        l10n.apiWebhookFailing(webhook.lastDeliveryStatus!),
                        style: TextStyle(color: context.tokens.danger),
                      ),
                trailing: IconButton(
                  onPressed: () => _deleteWebhook(webhook),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.commonDelete,
                ),
              ),
            ),
          const SizedBox(height: GarageTokens.space3),
          OutlinedButton.icon(
            onPressed: hasHousehold ? _addWebhook : null,
            icon: const Icon(Icons.add_link),
            label: Text(l10n.apiWebhookAdd),
          ),
          if (_failure != null) ...[
            const SizedBox(height: GarageTokens.space4),
            Text(
              failureMessage(l10n, _failure!),
              style: TextStyle(color: context.tokens.danger),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one moment a key is visible. It is not stored anywhere the app can read
/// it back, so this card is the household's only chance to copy it.
class _FreshKeyCard extends StatelessWidget {
  const _FreshKeyCard({required this.apiKey});

  final String apiKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: context.tokens.surface,
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.apiKeyOnce,
              style: TextStyle(color: context.tokens.accent),
            ),
            const SizedBox(height: GarageTokens.space2),
            SelectableText(
              apiKey,
              style: GarageTheme.numeric(
                Theme.of(context).textTheme.bodyMedium!,
              ),
            ),
            const SizedBox(height: GarageTokens.space2),
            TextButton.icon(
              onPressed: () => Clipboard.setData(ClipboardData(text: apiKey)),
              icon: const Icon(Icons.copy),
              label: Text(l10n.householdCopyCode),
            ),
          ],
        ),
      ),
    );
  }
}
