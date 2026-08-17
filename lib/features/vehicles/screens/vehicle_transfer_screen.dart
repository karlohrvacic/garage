import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/confirm_delete.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../household/providers/household_providers.dart';
import '../providers/vehicle_providers.dart';

/// Moving a car to somebody else's garage, and taking one in.
///
/// A real move rather than a copy. Drivvo sends the buyer a copy of the
/// history, which leaves the seller holding a car they no longer own and two
/// records that drift apart the moment either is edited. Here the vehicle
/// changes hands: everything hanging off it goes, and it leaves the seller's
/// garage.
class VehicleTransferScreen extends ConsumerStatefulWidget {
  const VehicleTransferScreen({this.vehicleId, super.key});

  /// The vehicle being offered, when the screen was opened from one. Null when
  /// it was opened to redeem a code, where there is no vehicle yet.
  final String? vehicleId;

  @override
  ConsumerState<VehicleTransferScreen> createState() =>
      _VehicleTransferScreenState();
}

class _VehicleTransferScreenState extends ConsumerState<VehicleTransferScreen> {
  final _code = TextEditingController();

  String? _offeredCode;
  bool _busy = false;
  bool _redeemed = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _offer() async {
    final vehicleId = widget.vehicleId;
    if (vehicleId == null) {
      return;
    }
    // Confirmed first: a code in somebody's hands is most of the way to a car
    // leaving, and nothing on this side can call it back afterwards.
    if (!await confirmDelete(context) || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final code = await ref
          .read(vehicleRepositoryProvider)
          .offerTransfer(vehicleId);
      if (mounted) {
        setState(() {
          _offeredCode = code;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = AppFailure.from(error);
          _busy = false;
        });
      }
    }
  }

  Future<void> _redeem() async {
    // Awaited rather than read: nothing else on this screen watches the
    // household, so a plain read here is a cold start that returns null and
    // silently does nothing.
    final household = await ref.read(currentHouseholdProvider.future);
    if (household == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .redeemTransfer(
            code: _code.text.trim().toUpperCase(),
            householdId: household.id,
          );
      ref.invalidate(allVehiclesProvider);
      if (mounted) {
        setState(() {
          _redeemed = true;
          _busy = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = AppFailure.from(error);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return GaragePageScaffold(
      title: l10n.transferTitle,
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          if (widget.vehicleId != null) ...[
            Text(
              l10n.transferSell.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
            const SizedBox(height: GarageTokens.space2),
            Text(l10n.transferSellHint),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.transferPhotoNote,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.transferWarning,
              style: TextStyle(color: context.tokens.danger),
            ),
            const SizedBox(height: GarageTokens.space4),
            if (_offeredCode case final code?)
              Card(
                child: ListTile(
                  key: const Key('transfer-code'),
                  title: Text(
                    code,
                    style: GarageTheme.numeric(
                      Theme.of(context).textTheme.headlineSmall!,
                    ),
                  ),
                  subtitle: Text(l10n.transferCode),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.transferCopied)),
                        );
                      }
                    },
                  ),
                ),
              )
            else
              FilledButton.icon(
                key: const Key('offer-transfer'),
                onPressed: _busy ? null : _offer,
                icon: const Icon(Icons.outbox_outlined),
                label: Text(l10n.transferGenerate),
              ),
            const SizedBox(height: GarageTokens.space6),
          ],
          Text(
            l10n.transferBought.toUpperCase(),
            style: GarageTheme.eyebrow(context),
          ),
          const SizedBox(height: GarageTokens.space2),
          Text(l10n.transferBoughtHint),
          const SizedBox(height: GarageTokens.space3),
          if (_redeemed)
            Text(
              l10n.transferDone,
              style: TextStyle(color: context.tokens.success),
            )
          else ...[
            LabeledField(
              label: l10n.transferCode,
              child: TextField(
                key: const Key('redeem-code'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                style: GarageTheme.numericField(context),
              ),
            ),
            const SizedBox(height: GarageTokens.space3),
            FilledButton.icon(
              key: const Key('redeem-transfer'),
              onPressed: _busy ? null : _redeem,
              icon: const Icon(Icons.move_to_inbox_outlined),
              label: Text(l10n.transferRedeem),
            ),
          ],
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
