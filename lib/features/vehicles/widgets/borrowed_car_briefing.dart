import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/cluster_readout.dart';
import '../../../domain/entities/tyre_set.dart';
import '../../../domain/entities/vehicle_document.dart';
import '../../documents/document_type_labels.dart';
import '../../settings/providers/unit_providers.dart';
import '../../tyres/screens/tyres_screen.dart' show tyreSeasonLabel;
import '../providers/guest_pass_providers.dart';

/// What a borrower sees instead of the owner's dashboard.
///
/// The car's own screens are built for somebody who can read its history, and
/// for a borrower they are mostly empty — an odometer that was really the
/// stored baseline, a fuel log with one entry in it, tabs that answer nothing.
/// This answers the four questions they actually have.
class BorrowedCarBriefing extends ConsumerWidget {
  const BorrowedCarBriefing({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = context.tokens;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final briefing = ref.watch(vehicleBriefingProvider(vehicleId)).value;
    if (briefing == null) {
      return const SizedBox.shrink();
    }
    if (briefing.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Text(
          l10n.briefingNothing,
          style: TextStyle(color: tokens.muted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(GarageTokens.space4),
      children: [
        if (briefing.odometerKm case final km?)
          Center(
            child: ClusterReadout(
              label: l10n.briefingOdometer,
              // The real reading, from whichever table it was logged in. The
              // stored baseline was what a borrower used to be shown, and a
              // stale number presented as current is the one they copy at a
              // pump.
              value: format.formatDistance(km.toDouble(), decimals: 0),
            ),
          ),
        if (briefing.problems.isNotEmpty) ...[
          const SizedBox(height: GarageTokens.space5),
          Text(
            l10n.briefingProblems.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          for (final problem in briefing.problems)
            Padding(
              padding: const EdgeInsets.only(top: GarageTokens.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined, color: tokens.warn),
                  const SizedBox(width: GarageTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(problem.note),
                        Text(
                          l10n.briefingNoticedOn(
                            format.formatDate(problem.noticedOn),
                          ),
                          style: TextStyle(color: tokens.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (briefing.documents.isNotEmpty) ...[
          const SizedBox(height: GarageTokens.space5),
          Text(
            l10n.briefingPapers.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          // A type and a date. The number and the issuer stay with the owner;
          // what a borrower needs is whether it runs out while they have it.
          for (final paper in briefing.documents)
            Padding(
              padding: const EdgeInsets.only(top: GarageTokens.space2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      documentTypeLabel(l10n, DocumentType.fromKey(paper.type)),
                    ),
                  ),
                  Text(
                    format.formatDate(paper.expiresOn),
                    style: TextStyle(color: tokens.muted),
                  ),
                ],
              ),
            ),
        ],
        if (briefing.tyres.isNotEmpty) ...[
          const SizedBox(height: GarageTokens.space5),
          Text(
            l10n.briefingTyres.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          for (final set in briefing.tyres)
            Padding(
              padding: const EdgeInsets.only(top: GarageTokens.space2),
              child: Text(
                set.fittedOn == null
                    ? tyreSeasonLabel(l10n, TyreSeason.fromKey(set.season))
                    : '${tyreSeasonLabel(l10n, TyreSeason.fromKey(set.season))} · '
                          '${l10n.briefingTyresFitted(format.formatDate(set.fittedOn!))}',
              ),
            ),
        ],
      ],
    );
  }
}
