import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/entry_sheet_body.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/pick_one.dart';
import '../../../core/widgets/text_prompt.dart';
import '../../../domain/api/api_access.dart';
import '../../household/providers/household_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../providers/api_access_providers.dart';
import '../webhook_format_labels.dart';
import '../widgets/webhook_switches.dart';

/// One webhook: what it is called, which cars and events it is sent, in which
/// language, and how its last deliveries went.
///
/// The address and the format are fixed here. Changing those is a different
/// hook, and deleting this one and adding the other says so.
class WebhookScreen extends ConsumerStatefulWidget {
  const WebhookScreen({super.key, required this.webhookId});

  final String webhookId;

  @override
  ConsumerState<WebhookScreen> createState() => _WebhookScreenState();
}

class _WebhookScreenState extends ConsumerState<WebhookScreen> {
  AppFailure? _failure;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _failure = null);
    try {
      await action();
      ref.invalidate(webhooksProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    }
  }

  Future<void> _update(WebhookChanges changes) {
    return _run(
      () => ref
          .read(apiAccessRepositoryProvider)
          .updateWebhook(widget.webhookId, changes),
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

  Future<void> _rename(Webhook webhook) async {
    final l10n = AppLocalizations.of(context)!;
    final name = await showTextPrompt(
      context,
      title: l10n.apiWebhookName,
      label: l10n.apiWebhookName,
      confirmLabel: l10n.commonSave,
      initialValue: webhook.name ?? '',
      maxLength: Webhook.nameLength,
    );
    if (name == null || !mounted) {
      return;
    }
    // An emptied field is "no name": the list falls back to the host.
    await _update(WebhookChanges(name: name.trim()));
  }

  Future<void> _chooseCars(Webhook webhook) async {
    final l10n = AppLocalizations.of(context)!;
    final vehicles = ref.read(allVehiclesProvider).value ?? const [];
    // Only cars still in the garage. A stored id of one since sold or
    // deleted would otherwise make a hook read as narrowed to no car, or as
    // covering every car, and be written back as the one or the other.
    final known = {for (final vehicle in vehicles) vehicle.id};
    final before = webhook.vehicleIds?.where(known.contains).toSet() ?? known;
    final cars = {...before};
    String? carsError;
    final chosen = await showAdaptiveEntrySheet<Set<String>>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: l10n.apiWebhookCars,
          fields: [
            DiscardGuard(
              controllers: const [],
              alsoDirty: () =>
                  cars.length != before.length || !cars.containsAll(before),
            ),
            WebhookCarSwitches(
              vehicles: vehicles,
              chosen: cars,
              heading: false,
              error: carsError,
              onChanged: (id, on) => setSheetState(() {
                on ? cars.add(id) : cars.remove(id);
                carsError = null;
              }),
            ),
          ],
          confirmLabel: l10n.commonSave,
          onConfirm: () {
            // Refused rather than stored: the dispatcher reads an empty
            // list as every car, the opposite of what was chosen.
            if (cars.isEmpty) {
              setSheetState(() => carsError = l10n.apiWebhookCarsNone);
              return;
            }
            Navigator.of(sheetContext).pop(cars);
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
          cancelLabel: l10n.commonCancel,
        ),
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    // Every car is no list at all, never the full list, so a car added
    // later is included.
    await _update(
      chosen.length == known.length
          ? const WebhookChanges(clearVehicleIds: true)
          : WebhookChanges(
              vehicleIds: [
                for (final vehicle in vehicles)
                  if (chosen.contains(vehicle.id)) vehicle.id,
              ],
            ),
    );
  }

  Future<void> _chooseLanguage(Webhook webhook) async {
    final l10n = AppLocalizations.of(context)!;
    final language = await showPickOne<WebhookLanguage>(
      context,
      title: l10n.apiWebhookLanguage,
      options: [
        for (final option in WebhookLanguage.values)
          PickOption(
            option,
            webhookLanguageLabel(option),
            key: Key('webhook-language-${option.name}'),
          ),
      ],
    );
    if (language == null || language == webhook.language || !mounted) {
      return;
    }
    await _update(WebhookChanges(language: language));
  }

  Future<void> _chooseEvents(Webhook webhook) async {
    final l10n = AppLocalizations.of(context)!;
    final before = WebhookEventGroup.of(webhook.events);
    final groups = {...before};
    String? groupsError;
    final chosen = await showAdaptiveEntrySheet<Set<WebhookEventGroup>>(
      context,
      (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => EntrySheetBody(
          title: l10n.apiWebhookEditEvents,
          fields: [
            DiscardGuard(
              controllers: const [],
              alsoDirty: () =>
                  groups.length != before.length || !groups.containsAll(before),
            ),
            WebhookEventSwitches(
              chosen: groups,
              error: groupsError,
              onChanged: (group, on) => setSheetState(() {
                on ? groups.add(group) : groups.remove(group);
                groupsError = null;
              }),
            ),
          ],
          confirmLabel: l10n.commonSave,
          onConfirm: () {
            if (groups.isEmpty) {
              setSheetState(() => groupsError = l10n.apiWebhookEventsNone);
              return;
            }
            Navigator.of(sheetContext).pop(groups);
          },
          onCancel: () => Navigator.of(sheetContext).pop(),
          cancelLabel: l10n.commonCancel,
        ),
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    await _update(WebhookChanges(events: WebhookEventGroup.toEvents(chosen)));
  }

  Future<void> _sendTest() async {
    final l10n = AppLocalizations.of(context)!;
    final household = ref.read(currentHouseholdProvider).value;
    if (household == null) {
      return;
    }
    await _run(
      () => ref
          .read(apiAccessRepositoryProvider)
          .sendTest(householdId: household.id),
    );
    if (mounted && _failure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.apiWebhookTestSent)));
    }
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    await _run(
      () =>
          ref.read(apiAccessRepositoryProvider).deleteWebhook(widget.webhookId),
    );
    if (mounted && _failure == null) {
      // Back to the list, which is beneath this screen when it was pushed
      // from there and nowhere when a link opened it directly.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/api');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final webhooks = ref.watch(webhooksProvider);
    final webhook = webhooks.value
        ?.where((hook) => hook.id == widget.webhookId)
        .firstOrNull;
    if (webhook == null) {
      // Loading, failed, or loaded without it: deleted on another device,
      // or a link to a hook that is not this garage's.
      return GaragePageScaffold(
        title: l10n.apiWebhooks,
        body: AsyncValueView<List<Webhook>>(
          value: webhooks,
          onRetry: () => ref.invalidate(webhooksProvider),
          data: (_) => EmptyState(message: l10n.apiWebhookGone),
        ),
      );
    }
    // Watched here so the cars sheet can read them when it opens: a derived
    // provider nobody has watched yet has no value to read.
    final vehicles = ref.watch(allVehiclesProvider).value ?? const [];
    final known = {for (final vehicle in vehicles) vehicle.id};
    // Counted over the garage's cars, not the stored list: a car since sold
    // is not one this hook is told about.
    final narrowedTo = webhook.vehicleIds?.where(known.contains).length;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final tokens = context.tokens;
    final groups = WebhookEventGroup.of(webhook.events);

    return GaragePageScaffold(
      title: webhook.name ?? webhook.url.host,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  webhook.url.toString(),
                  style: TextStyle(color: tokens.muted),
                ),
              ),
              IconButton(
                key: const Key('copy-webhook-url'),
                onPressed: () => _copyUrl(webhook),
                icon: const Icon(Icons.copy_outlined),
                tooltip: l10n.commonCopy,
              ),
            ],
          ),
          const SizedBox(height: GarageTokens.space3),
          if (webhook.isPaused)
            Card(
              child: ListTile(
                key: const Key('webhook-paused'),
                title: Text(
                  l10n.apiWebhookPaused,
                  style: TextStyle(color: tokens.danger),
                ),
                trailing: FilledButton(
                  key: const Key('webhook-resume'),
                  onPressed: () => _update(const WebhookChanges(active: true)),
                  child: Text(l10n.apiWebhookResume),
                ),
              ),
            ),
          _Field(
            fieldKey: const Key('webhook-field-name'),
            label: l10n.apiWebhookName,
            value: webhook.name ?? l10n.apiWebhookNameHint,
            onTap: () => _rename(webhook),
          ),
          // No cars, no choice: a garage with none has nothing to narrow
          // the hook to, as on the add sheet.
          if (vehicles.isNotEmpty)
            _Field(
              fieldKey: const Key('webhook-field-cars'),
              label: l10n.apiWebhookCars,
              value: switch (narrowedTo) {
                null => l10n.apiWebhookCarsAll,
                final count => l10n.apiWebhookCarsSome(count),
              },
              onTap: () => _chooseCars(webhook),
            ),
          _Field(
            fieldKey: const Key('webhook-field-language'),
            label: l10n.apiWebhookLanguage,
            value: webhookLanguageLabel(webhook.language),
            onTap: () => _chooseLanguage(webhook),
          ),
          _Field(
            fieldKey: const Key('webhook-field-events'),
            label: l10n.apiWebhookEvents,
            // Groups, in words. A hook written by hand with half a group
            // shows its keys instead, so what it receives is not hidden.
            value: groups.isEmpty
                ? [for (final event in webhook.events) event.key].join(', ')
                : [
                    for (final group in WebhookEventGroup.values)
                      if (groups.contains(group))
                        webhookGroupLabel(l10n, group),
                  ].join(' · '),
            onTap: () => _chooseEvents(webhook),
          ),
          const SizedBox(height: GarageTokens.space3),
          FilledButton.icon(
            key: const Key('webhook-send-test'),
            // The drain sends nothing to a paused hook, so a test would
            // only sit in the log as queued; Resume first.
            onPressed: webhook.isPaused ? null : _sendTest,
            icon: const Icon(Icons.send_outlined),
            label: Text(l10n.apiWebhookSendTest),
          ),
          if (_failure != null) ...[
            const SizedBox(height: GarageTokens.space3),
            Text(
              failureMessage(l10n, _failure!),
              style: TextStyle(color: tokens.danger),
            ),
          ],
          const SizedBox(height: GarageTokens.space6),
          Text(
            l10n.apiWebhookLog.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          const SizedBox(height: GarageTokens.space2),
          AsyncValueView<List<WebhookDelivery>>(
            value: ref.watch(webhookDeliveriesProvider(widget.webhookId)),
            onRetry: () =>
                ref.invalidate(webhookDeliveriesProvider(widget.webhookId)),
            empty: () => Text(
              l10n.apiWebhookLogEmpty,
              style: TextStyle(color: tokens.muted),
            ),
            data: (deliveries) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final delivery in deliveries)
                  _DeliveryRow(
                    delivery: delivery,
                    format: format,
                    locale: locale,
                  ),
              ],
            ),
          ),
          const SizedBox(height: GarageTokens.space6),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('webhook-delete'),
              onPressed: _delete,
              child: Text(
                l10n.commonDelete,
                style: TextStyle(color: tokens.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One setting of the hook: what it is called and what it is, tappable to
/// change through the app's own prompt for that kind of thing.
class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: fieldKey,
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// One delivery: the key a receiver matched on, when it was queued, and how
/// it went.
class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({
    required this.delivery,
    required this.format,
    required this.locale,
  });

  final WebhookDelivery delivery;
  final UnitFormat format;
  final String locale;

  /// The time alone when it is the day the row was queued, which is nearly
  /// always; a retry that crossed midnight names its day.
  String _when(DateTime at, DateTime queuedAt) {
    final time = DateFormat.Hm(locale).format(at);
    final sameDay =
        at.year == queuedAt.year &&
        at.month == queuedAt.month &&
        at.day == queuedAt.day;
    return sameDay ? time : '${format.formatShortDate(at)} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final queuedAt = delivery.createdAt.toLocal();
    final (outcome, bad) = switch (delivery) {
      WebhookDelivery(delivered: true, :final deliveredAt?) => (
        l10n.apiWebhookDelivered(_when(deliveredAt.toLocal(), queuedAt)),
        false,
      ),
      WebhookDelivery(givenUp: true) => (
        l10n.apiWebhookGivenUp(WebhookDelivery.mostAttempts),
        true,
      ),
      // Written by the drain and not yet posted: nothing has been tried, so
      // there is no attempt to count and nothing to be retried.
      WebhookDelivery(attempts: 0) => (l10n.apiWebhookQueued, false),
      _ => (
        [
          l10n.apiWebhookRetrying(
            delivery.attempts + 1,
            WebhookDelivery.mostAttempts,
          ),
          if (delivery.lastStatus case final status?) '($status)',
        ].join(' '),
        delivery.lastStatus != null,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: GarageTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(delivery.event)),
              const SizedBox(width: GarageTokens.space3),
              // Flexible rather than its natural width: at a large font on
              // a narrow phone the two halves share the line.
              Flexible(
                child: Text(
                  '${format.formatShortDate(queuedAt)} · '
                  '${DateFormat.Hm(locale).format(queuedAt)}',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: tokens.muted),
                ),
              ),
            ],
          ),
          Text(
            outcome,
            style: TextStyle(color: bad ? tokens.danger : tokens.muted),
          ),
        ],
      ),
    );
  }
}
