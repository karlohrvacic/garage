import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../domain/entities/guest_pass.dart';
import '../providers/guest_pass_providers.dart';

/// Changing what a pass allows, on the code its holder already has.
///
/// The alternative was to withdraw the code and mint another, which loses the
/// link between the loan and everything logged under it — and means telling
/// somebody a new code because you changed your mind about one switch.
Future<void> showEditPassSheet(BuildContext context, GuestPass pass) {
  return showAdaptiveEntrySheet<void>(context, (_) => _EditPassForm(pass));
}

class _EditPassForm extends ConsumerStatefulWidget {
  const _EditPassForm(this.pass);

  final GuestPass pass;

  @override
  ConsumerState<_EditPassForm> createState() => _EditPassFormState();
}

class _EditPassFormState extends ConsumerState<_EditPassForm> {
  late bool _fuel = widget.pass.canLogFuel;
  late bool _trips = widget.pass.canLogTrips;
  late bool _costs = widget.pass.canLogCosts;
  late bool _history = widget.pass.canViewHistory;
  late bool _prices = widget.pass.canViewPrices;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.passEdit, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.passEditNote,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space4),
            SwitchListTile(
              key: const Key('edit-pass-fuel'),
              contentPadding: EdgeInsets.zero,
              value: _fuel,
              onChanged: (value) => setState(() => _fuel = value),
              title: Text(l10n.guestLendAllowFuel),
            ),
            SwitchListTile(
              key: const Key('edit-pass-trips'),
              contentPadding: EdgeInsets.zero,
              value: _trips,
              onChanged: (value) => setState(() => _trips = value),
              title: Text(l10n.guestLendAllowTrips),
            ),
            SwitchListTile(
              key: const Key('edit-pass-costs'),
              contentPadding: EdgeInsets.zero,
              value: _costs,
              onChanged: (value) => setState(() => _costs = value),
              title: Text(l10n.guestLendAllowCosts),
            ),
            SwitchListTile(
              key: const Key('edit-pass-history'),
              contentPadding: EdgeInsets.zero,
              value: _history,
              onChanged: (value) => setState(() {
                _history = value;
                if (!value) {
                  _prices = false;
                }
              }),
              title: Text(l10n.guestLendAllowHistory),
              subtitle: Text(l10n.guestLendAllowHistoryHint),
            ),
            if (_history)
              SwitchListTile(
                key: const Key('edit-pass-prices'),
                contentPadding: const EdgeInsets.only(
                  left: GarageTokens.space4,
                ),
                value: _prices,
                onChanged: (value) => setState(() => _prices = value),
                title: Text(l10n.guestLendAllowPrices),
                subtitle: Text(l10n.guestLendAllowPricesHint),
              ),
            const SizedBox(height: GarageTokens.space5),
            FilledButton(
              key: const Key('edit-pass-save'),
              onPressed: _busy ? null : _save,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final saved = await ref
        .read(guestPassControllerProvider.notifier)
        .changePermissions(
          GuestPass(
            id: widget.pass.id,
            vehicleId: widget.pass.vehicleId,
            code: widget.pass.code,
            createdBy: widget.pass.createdBy,
            createdAt: widget.pass.createdAt,
            expiresAt: widget.pass.expiresAt,
            label: widget.pass.label,
            startsAt: widget.pass.startsAt,
            revokedAt: widget.pass.revokedAt,
            redeemedBy: widget.pass.redeemedBy,
            redeemedAt: widget.pass.redeemedAt,
            canLogFuel: _fuel,
            canLogTrips: _trips,
            canLogCosts: _costs,
            canViewHistory: _history,
            canViewPrices: _prices,
          ),
        );
    if (!mounted) {
      return;
    }
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _busy = false);
    }
  }
}
