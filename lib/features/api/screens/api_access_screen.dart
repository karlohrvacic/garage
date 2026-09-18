import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/api/api_access.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/api_access_providers.dart';
import '../webhook_format_labels.dart';

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

  /// Owned by the screen, not by the dialogs that show them.
  ///
  /// Created beside `showDialog` these were never disposed, so every open
  /// leaked a `ChangeNotifier`. Disposing them when the dialog's future
  /// completes is not the fix either: that future lands while the route is
  /// still animating out and the field still depends on the controller, which
  /// trips the framework's own assertion. Held here they are allocated once,
  /// cleared before each open, and disposed exactly when the screen is.
  final _webhookUrl = TextEditingController();

  @override
  void dispose() {
    _webhookUrl.dispose();
    super.dispose();
  }

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
    // One field, asked for the way every other name is: your own, the
    // garage's, another garage's and a join code all use the shared prompt.
    final name = (await showTextPrompt(
      context,
      title: l10n.apiNewKey,
      label: l10n.apiKeyName,
      confirmLabel: l10n.apiKeyCreate,
    ))?.trim();
    if (name == null || name.isEmpty || !mounted) {
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
    final controller = _webhookUrl..clear();
    // Outside the builder: a value declared inside it resets on every rebuild,
    // so the message would vanish the moment it was set.
    String? error;
    // Auto reads the shape from the URL's host, which is right for Discord,
    // Slack, Google Chat, Telegram, ntfy.sh and every generic receiver. The
    // choice exists for the ones a household runs itself, whose domain no host
    // list can contain.
    var format = WebhookFormat.auto;
    // Both by default, as every hook was sent before there was a choice.
    final events = WebhookEvent.values.toSet();
    String? eventsError;
    final url = await showAdaptiveEntrySheet<String>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: l10n.apiWebhookAdd,
          fields: [
            DiscardGuard(
              controllers: [controller],
              alsoDirty: () =>
                  format != WebhookFormat.auto ||
                  events.length != WebhookEvent.values.length,
            ),
            LabeledField(
              label: l10n.apiWebhookUrl,
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(errorText: error),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            LabeledField(
              label: l10n.apiWebhookFormat,
              child: DropdownButtonFormField<WebhookFormat>(
                key: const Key('webhook-format'),
                initialValue: format,
                isExpanded: true,
                decoration: InputDecoration(
                  helperText: l10n.apiWebhookFormatHint,
                ),
                items: [
                  for (final option in WebhookFormat.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(webhookFormatLabel(l10n, option)),
                    ),
                ],
                onChanged: (value) =>
                    setSheetState(() => format = value ?? format),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            _EventSwitches(
              chosen: events,
              error: eventsError,
              onChanged: (event, on) => setSheetState(() {
                on ? events.add(event) : events.remove(event);
                eventsError = null;
              }),
            ),
          ],
          confirmLabel: l10n.apiWebhookAddAction,
          onConfirm: () {
            final value = controller.text.trim();
            // https only: a webhook carries household data, and the secret
            // that signs it, over the open internet.
            if (!value.startsWith('https://')) {
              setSheetState(() => error = l10n.apiWebhookInvalid);
              return;
            }
            if (events.isEmpty) {
              setSheetState(() => eventsError = l10n.apiWebhookEventsNone);
              return;
            }
            Navigator.of(sheetContext).pop(value);
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
          cancelLabel: l10n.commonCancel,
        ),
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
            events: events,
            format: format,
          ),
    );
  }

  /// What [webhook] is sent, chosen again. The hook's address and format stay:
  /// changing those is a different hook, and deleting it and adding the other
  /// says so.
  Future<void> _editWebhookEvents(Webhook webhook) async {
    final l10n = AppLocalizations.of(context)!;
    final events = {...webhook.events};
    String? eventsError;
    final chosen = await showAdaptiveEntrySheet<Set<WebhookEvent>>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: l10n.apiWebhookEditEvents,
          fields: [
            DiscardGuard(
              controllers: const [],
              alsoDirty: () =>
                  events.length != webhook.events.length ||
                  !events.containsAll(webhook.events),
            ),
            Text(
              webhook.url.toString(),
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space3),
            _EventSwitches(
              chosen: events,
              error: eventsError,
              onChanged: (event, on) => setSheetState(() {
                on ? events.add(event) : events.remove(event);
                eventsError = null;
              }),
            ),
          ],
          confirmLabel: l10n.commonSave,
          onConfirm: () {
            if (events.isEmpty) {
              setSheetState(() => eventsError = l10n.apiWebhookEventsNone);
              return;
            }
            Navigator.of(sheetContext).pop(events);
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
          cancelLabel: l10n.commonCancel,
        ),
      ),
    );
    if (chosen == null) {
      return;
    }
    await _run(
      () => ref
          .read(apiAccessRepositoryProvider)
          .setWebhookEvents(webhook.id, chosen),
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
          // A key with no documentation is a credential nobody can spend: the
          // repository is private, so this page is the only place the endpoint
          // names exist.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => ref.read(urlOpenerProvider)(GarageLinks.apiDocs),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.apiDocs),
            ),
          ),
          const SizedBox(height: GarageTokens.space3),
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
                onTap: () => _editWebhookEvents(webhook),
                subtitle: webhook.isDelivering
                    ? Text(
                        [
                          for (final event in WebhookEvent.values)
                            if (webhook.events.contains(event))
                              webhookEventLabel(l10n, event),
                        ].join(' · '),
                      )
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

/// The events a webhook can be sent, one switch each, and at least one on.
class _EventSwitches extends StatelessWidget {
  const _EventSwitches({
    required this.chosen,
    required this.onChanged,
    this.error,
  });

  final Set<WebhookEvent> chosen;
  final void Function(WebhookEvent event, bool on) onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.apiWebhookEvents,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final event in WebhookEvent.values)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(webhookEventLabel(l10n, event)),
            value: chosen.contains(event),
            onChanged: (on) => onChanged(event, on),
          ),
        if (error != null)
          Text(error!, style: TextStyle(color: context.tokens.danger)),
      ],
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
