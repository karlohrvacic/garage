import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

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
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/api_access_providers.dart';
import '../webhook_format_labels.dart';
import '../webhook_status.dart';
import '../widgets/webhook_switches.dart';

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
  final _webhookName = TextEditingController();
  final _webhookUrl = TextEditingController();

  @override
  void dispose() {
    _webhookName.dispose();
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
    final name = _webhookName..clear();
    final controller = _webhookUrl..clear();
    // Outside the builder: a value declared inside it resets on every rebuild,
    // so the message would vanish the moment it was set.
    String? error;
    // Auto reads the shape from the URL's host, which is right for Discord,
    // Slack, Google Chat, Telegram, ntfy.sh and every generic receiver. The
    // choice exists for the ones a household runs itself, whose domain no host
    // list can contain.
    var format = WebhookFormat.auto;
    // Every car and every group by default, as every hook was sent before
    // there was a choice. Watched by the screen rather than read here: a
    // derived provider nobody has watched yet has no value to read.
    final vehicles = ref.read(allVehiclesProvider).value ?? const [];
    final cars = {for (final vehicle in vehicles) vehicle.id};
    final groups = WebhookEventGroup.values.toSet();
    // The app's own language: the chat text should read as the app does,
    // and the signed JSON is the same in every one.
    final appLanguage = WebhookLanguage.fromKey(
      Localizations.localeOf(context).languageCode,
    );
    var language = appLanguage;
    String? carsError;
    String? groupsError;
    final url = await showAdaptiveEntrySheet<String>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: l10n.apiWebhookAdd,
          fields: [
            DiscardGuard(
              controllers: [name, controller],
              alsoDirty: () =>
                  format != WebhookFormat.auto ||
                  language != appLanguage ||
                  cars.length != vehicles.length ||
                  groups.length != WebhookEventGroup.values.length,
            ),
            LabeledField(
              label: l10n.apiWebhookName,
              child: TextField(
                key: const Key('webhook-name'),
                controller: name,
                autofocus: true,
                maxLength: Webhook.nameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: l10n.apiWebhookNameHint),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            LabeledField(
              label: l10n.apiWebhookUrl,
              child: TextField(
                key: const Key('webhook-url'),
                controller: controller,
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
            // No cars, no choice: a garage with none yet has nothing to
            // narrow the hook to, and the hook covers whatever gets added.
            if (vehicles.isNotEmpty) ...[
              const SizedBox(height: GarageTokens.space3),
              WebhookCarSwitches(
                vehicles: vehicles,
                chosen: cars,
                error: carsError,
                onChanged: (id, on) => setSheetState(() {
                  on ? cars.add(id) : cars.remove(id);
                  carsError = null;
                }),
              ),
            ],
            const SizedBox(height: GarageTokens.space3),
            LabeledField(
              label: l10n.apiWebhookLanguage,
              child: DropdownButtonFormField<WebhookLanguage>(
                key: const Key('webhook-language'),
                initialValue: language,
                isExpanded: true,
                decoration: InputDecoration(
                  helperText: l10n.apiWebhookLanguageHint,
                ),
                items: [
                  for (final option in WebhookLanguage.values)
                    DropdownMenuItem(
                      value: option,
                      child: Text(webhookLanguageLabel(option)),
                    ),
                ],
                onChanged: (value) =>
                    setSheetState(() => language = value ?? language),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            WebhookEventSwitches(
              chosen: groups,
              error: groupsError,
              onChanged: (group, on) => setSheetState(() {
                on ? groups.add(group) : groups.remove(group);
                groupsError = null;
              }),
            ),
          ],
          confirmLabel: l10n.apiWebhookAddAction,
          onConfirm: () {
            final value = controller.text.trim();
            // https only: a webhook carries household data, and the secret
            // that signs it, over the open internet.
            final uri = Uri.tryParse(value);
            if (uri == null || !value.startsWith('https://')) {
              setSheetState(() => error = l10n.apiWebhookInvalid);
              return;
            }
            // A push service's credentials ride in the address; without them
            // every delivery would be refused, and the log would say so only
            // after the first event.
            if (missingWebhookCredentials(uri, format)) {
              setSheetState(() => error = l10n.apiWebhookNeedsToken);
              return;
            }
            // Refused rather than stored: the dispatcher reads an empty
            // list as every car, the opposite of what was chosen.
            if (vehicles.isNotEmpty && cars.isEmpty) {
              setSheetState(() => carsError = l10n.apiWebhookCarsNone);
              return;
            }
            if (groups.isEmpty) {
              setSheetState(() => groupsError = l10n.apiWebhookEventsNone);
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

    final chosenName = name.text.trim();
    await _run(
      () => ref
          .read(apiAccessRepositoryProvider)
          .addWebhook(
            householdId: household.id,
            url: Uri.parse(url),
            events: WebhookEventGroup.toEvents(groups),
            format: format,
            name: chosenName.isEmpty ? null : chosenName,
            // Every car is no list at all, never the full list, so a car
            // added later is included.
            vehicleIds: cars.length == vehicles.length
                ? null
                : [
                    for (final vehicle in vehicles)
                      if (cars.contains(vehicle.id)) vehicle.id,
                  ],
            language: language,
          ),
    );
  }

  Future<void> _copyUrl(Webhook webhook) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: webhook.url.toString()));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.apiWebhookCopied)));
    }
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
    // Resolved here so the add sheet can read the cars when it opens.
    ref.watch(allVehiclesProvider);
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
                key: Key('webhook-${webhook.id}'),
                title: Text(webhook.name ?? webhook.url.host),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      webhook.url.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.tokens.muted),
                    ),
                    Text(
                      webhookStatusLine(l10n, format, webhook),
                      style: TextStyle(
                        color: webhookStatusIsBad(webhook)
                            ? context.tokens.danger
                            : context.tokens.muted,
                      ),
                    ),
                  ],
                ),
                onTap: () => context.push('/api/webhooks/${webhook.id}'),
                trailing: IconButton(
                  key: Key('copy-webhook-${webhook.id}'),
                  onPressed: () => _copyUrl(webhook),
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: l10n.commonCopy,
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
