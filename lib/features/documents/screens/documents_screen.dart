import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/clock.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/empty_state_art.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../domain/documents/document_expiry.dart';
import '../../../domain/entities/vehicle_document.dart';
import '../../settings/providers/unit_providers.dart';
import '../document_type_labels.dart';
import '../providers/document_providers.dart';
import '../widgets/document_sheet.dart';

/// The paperwork a vehicle carries, and when each piece runs out.
///
/// The app tracked money and work and knew nothing about paper, which is the
/// half that carries a fine rather than a repair bill. Each row is a date
/// somebody would otherwise find out about from a police officer or a refused
/// claim.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final documents = ref.watch(vehicleDocumentsProvider(vehicleId));
    final today = ref.watch(todayProvider);
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    Future<void> open([VehicleDocument? existing]) async {
      await showDocumentSheet(
        context,
        vehicleId: vehicleId,
        existing: existing,
        alreadyHeld: {
          for (final document in documents.value ?? const <VehicleDocument>[])
            document.type,
        },
      );
    }

    // The empty state carries its own button, so the floating one would be
    // the same offer twice on one screen — and this list is empty for every
    // household until somebody types their first expiry, which makes that the
    // *first* thing anyone sees here.
    final anyDocuments = (documents.value ?? const []).isNotEmpty;

    return GaragePageScaffold(
      title: l10n.documentsTitle,
      floatingActionButton: anyDocuments
          ? FloatingActionButton.extended(
              key: const Key('document-add'),
              onPressed: open,
              icon: const Icon(Icons.add),
              label: Text(l10n.documentAdd),
            )
          : null,
      body: AsyncValueView<List<VehicleDocument>>(
        value: documents,
        onRetry: () => ref.invalidate(vehicleDocumentsProvider(vehicleId)),
        // The shared empty state, with the button that resolves it: every
        // other list in this app offers the way out rather than describing
        // one, and this list is empty for every household until somebody
        // types the first expiry.
        //
        // Wrapped so it can scroll. This message is two sentences, and two
        // sentences at twice the text size on a 320-pixel phone are five
        // lines with a button under them — which overflowed the shortest
        // window this app supports by 240 pixels, on the *first* screen
        // anybody sees here. The minimum-height box keeps it centred when it
        // does fit; without it a scroll view takes the whole viewport and the
        // text sits at the top.
        //
        // Done here rather than inside `EmptyState` on purpose: the stations
        // screen puts that widget in a `SliverFillRemaining`, which measures
        // its child, and a `LayoutBuilder` cannot answer an intrinsic-height
        // question. See known-bugs for the rest of that story.
        empty: () => LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Center(
                child: EmptyState(
                  motif: EmptyStateMotif.document,
                  message: l10n.documentsEmpty,
                  action: FilledButton.icon(
                    onPressed: open,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.documentAdd),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Built lazily. Five of the six types are capped at one per vehicle,
        // but `other` is deliberately not — it is the escape hatch, and a
        // household that keeps every lease and border permit in it has a list
        // with no ceiling. The header is index zero rather than a fixed row
        // above the list, so it scrolls away like the rest of it.
        data: (list) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            GarageTokens.space4,
            GarageTokens.space4,
            GarageTokens.space4,
            // Clear of the button that adds the next one.
            GarageTokens.space8,
          ),
          itemCount: list.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: GarageTokens.space3),
                child: Text(
                  l10n.documentsSubtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.tokens.muted),
                ),
              );
            }
            final document = list[index - 1];
            return _DocumentCard(
              document: document,
              today: today,
              format: format,
              onTap: () => open(document),
            );
          },
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.today,
    required this.format,
    required this.onTap,
  });

  final VehicleDocument document;
  final DateTime today;
  final UnitFormat format;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final state = documentExpiryState(
      expiresOn: document.expiresOn,
      today: today,
    );
    final days = daysUntilExpiry(expiresOn: document.expiresOn, today: today);

    // Colour is state here, never decoration: the whole point of the row is
    // whether this piece of paper is still good.
    final (color, line) = switch (state) {
      DocumentExpiryState.undated => (tokens.muted, l10n.documentNoExpiry),
      DocumentExpiryState.expired => (
        tokens.danger,
        l10n.documentExpiredOn(format.formatDate(document.expiresOn!)),
      ),
      DocumentExpiryState.expiring => (
        tokens.warn,
        days == 0
            ? l10n.documentExpiresToday
            : l10n.documentExpiresInDays(days!),
      ),
      DocumentExpiryState.valid => (
        tokens.muted,
        l10n.documentValidUntil(format.formatDate(document.expiresOn!)),
      ),
    };

    return Card(
      child: ListTile(
        onTap: onTap,
        // The state, as an icon, in the state's own colour: a card is scanned
        // for whether it is still good before it is read for what it is.
        leading: Icon(switch (state) {
          DocumentExpiryState.expired => Icons.error_outline,
          DocumentExpiryState.expiring => Icons.schedule,
          DocumentExpiryState.valid => Icons.verified_outlined,
          DocumentExpiryState.undated => Icons.help_outline,
        }, color: color),
        title: Text(documentTitle(l10n, document)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line, style: TextStyle(color: color)),
            if (document.number != null)
              Text(
                document.number!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.muted),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
