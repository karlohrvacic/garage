import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/clock.dart';
import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../domain/company/reimbursements.dart';
import '../../costs/providers/cost_providers.dart';
import '../../fuel/providers/fuel_providers.dart';
import '../../household/providers/member_providers.dart';
import '../../maintenance/providers/service_entry_providers.dart';
import '../../settings/providers/unit_providers.dart';
import '../member_name.dart';
import '../providers/company_providers.dart';
import '../providers/reimbursement_providers.dart';
import 'fleet_retry.dart';

/// Who is owed what for paying out of their own pocket, and the one button
/// that settles a month.
class ReimbursementsTab extends ConsumerWidget {
  const ReimbursementsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final format = UnitFormat(
      locale: locale,
      preferences: ref.watch(unitPreferencesProvider),
    );
    final lines = ref.watch(reimbursementsProvider);
    final names = ref.watch(memberNamesProvider);
    // The names are half of every line. A names read that failed with
    // nothing cached is the tab's failure, said with the Retry, rather than
    // "Former member" on every line with the cause unlogged; and until the
    // list is known the tab waits rather than naming anybody.
    final AsyncValue<List<ReimbursementLine>> value;
    if (names.hasValue) {
      value = lines;
    } else if (names case AsyncError(:final error, :final stackTrace)) {
      value = AsyncValue.error(error, stackTrace);
    } else {
      value = const AsyncValue.loading();
    }
    final known = names.value ?? const <String, String>{};

    return AsyncValueView<List<ReimbursementLine>>(
      value: value,
      onRetry: fleetRetry(ref, [
        rawFuelEntriesProvider,
        serviceEntriesProvider,
        costEntriesProvider,
        fleetAssignmentsProvider,
        fleetMoneyEntriesProvider,
        membersProvider,
      ]),
      empty: () => EmptyState(message: l10n.companyReimbursementsEmpty),
      data: (lines) {
        return ListView(
          padding: const EdgeInsets.all(GarageTokens.space4),
          children: [
            for (final line in lines)
              _LineCard(
                line: line,
                name: _nameOf(l10n, known, line),
                format: format,
                locale: locale,
                onMarkPaid: line.driverId == null
                    ? null
                    : () => _markPaid(context, ref, line, format, known),
              ),
          ],
        );
      },
    );
  }

  /// Who the line is for, as the card and the question both say it: nobody
  /// for a day with no window, and a member who has since left by that
  /// fact rather than by a blank, since what they are owed does not leave
  /// with them.
  static String _nameOf(
    AppLocalizations l10n,
    Map<String, String> names,
    ReimbursementLine line,
  ) {
    return switch (line.driverId) {
      null => l10n.companyReimbursementUnassigned,
      final id => memberNameOf(l10n, names, id),
    };
  }

  Future<void> _markPaid(
    BuildContext context,
    WidgetRef ref,
    ReimbursementLine line,
    UnitFormat format,
    Map<String, String> names,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.companyMarkPaidTitle(
        format.formatMoney(line.total),
        _nameOf(l10n, names, line),
      ),
      body: l10n.companyMarkPaidBody,
      confirmLabel: l10n.companyMarkPaid,
      // The same words as the button that opened it, so a test tells the
      // two apart by key.
      confirmKey: const Key('mark-paid-confirm'),
    );
    if (!confirmed) {
      return;
    }
    final ok = await ref
        .read(companyControllerProvider.notifier)
        .markReimbursed(line, at: ref.read(clockProvider)().toUtc());
    if (ok) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.companyMarkedPaid)));
    } else if (context.mounted) {
      // The line stays with whatever is still owed (a refusal part-way
      // through leaves the tables before it stamped, and the controller
      // refreshes either way) and the sentence says why: a driver's
      // account cannot do this, the trigger refuses it.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failureMessage(
              l10n,
              failureOf(ref.read(companyControllerProvider)),
            ),
          ),
        ),
      );
    }
  }
}

/// One driver, one month: the name and the sum on one row, the month and
/// the count under them, and the button on a row of its own. A trailing
/// button beside a Croatian label at a large font was wider than a narrow
/// phone, so nothing here sits beside anything that grows with the font.
class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.name,
    required this.format,
    required this.locale,
    required this.onMarkPaid,
  });

  final ReimbursementLine line;
  final String name;
  final UnitFormat format;
  final String locale;

  /// Null when nobody had the car those days: the line is there to be
  /// seen, and fixed by assigning the car for those days.
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final who =
        '${line.driverId ?? 'nobody'}-${line.month.year}-'
        '${line.month.month}';
    return Card(
      key: Key('reimbursement-$who'),
      child: Padding(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(name, style: textTheme.titleMedium)),
                const SizedBox(width: GarageTokens.space3),
                Text(
                  format.formatMoney(line.total),
                  style: GarageTheme.numeric(textTheme.titleMedium!),
                ),
              ],
            ),
            const SizedBox(height: GarageTokens.space1),
            Text(
              '${DateFormat.yMMMM(locale).format(line.month)} · '
              '${l10n.companyEntriesCount(line.entries.length)}',
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space3),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                style: GarageTheme.inlineButton,
                key: Key('mark-paid-$who'),
                onPressed: onMarkPaid,
                child: Text(l10n.companyMarkPaid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
