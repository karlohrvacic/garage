import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/labeled_field.dart';
import '../providers/guest_pass_providers.dart';

/// Minting a pass: how long, for whom, and what it allows.
Future<void> showLendCarSheet(
  BuildContext context,
  WidgetRef ref,
  String vehicleId,
) {
  return showAdaptiveEntrySheet<void>(context, (sheetContext) {
    return _LendCarForm(vehicleId: vehicleId);
  });
}

class _LendCarForm extends ConsumerStatefulWidget {
  const _LendCarForm({required this.vehicleId});

  final String vehicleId;

  @override
  ConsumerState<_LendCarForm> createState() => _LendCarFormState();
}

class _LendCarFormState extends ConsumerState<_LendCarForm> {
  final _label = TextEditingController();
  int _days = 7;
  bool _fuel = true;
  bool _trips = true;
  bool _costs = true;
  bool _history = false;

  /// Set once the pass exists. The form becomes the handover: a code nobody
  /// read is a pass nobody can use.
  String? _code;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_code case final code?) {
      return _Handover(code: code);
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GarageTokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.guestLendTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: GarageTokens.space2),
            Text(
              l10n.guestLendIntro,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space5),
            LabeledField(
              label: l10n.guestLendDays,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 7, label: Text('7')),
                  ButtonSegment(value: 30, label: Text('30')),
                ],
                selected: {_days},
                onSelectionChanged: (value) =>
                    setState(() => _days = value.first),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            LabeledField(
              label: l10n.guestLendLabel,
              child: TextField(
                key: const Key('lend-label'),
                controller: _label,
                decoration: InputDecoration(hintText: l10n.guestLendLabelHint),
              ),
            ),
            const SizedBox(height: GarageTokens.space4),
            SwitchListTile(
              key: const Key('lend-fuel'),
              contentPadding: EdgeInsets.zero,
              value: _fuel,
              onChanged: (value) => setState(() => _fuel = value),
              title: Text(l10n.guestLendAllowFuel),
            ),
            SwitchListTile(
              key: const Key('lend-trips'),
              contentPadding: EdgeInsets.zero,
              value: _trips,
              onChanged: (value) => setState(() => _trips = value),
              title: Text(l10n.guestLendAllowTrips),
            ),
            SwitchListTile(
              key: const Key('lend-costs'),
              contentPadding: EdgeInsets.zero,
              value: _costs,
              onChanged: (value) => setState(() => _costs = value),
              title: Text(l10n.guestLendAllowCosts),
            ),
            SwitchListTile(
              key: const Key('lend-history'),
              contentPadding: EdgeInsets.zero,
              value: _history,
              onChanged: (value) => setState(() => _history = value),
              title: Text(l10n.guestLendAllowHistory),
              subtitle: Text(l10n.guestLendAllowHistoryHint),
            ),
            if (_error case final message?) ...[
              const SizedBox(height: GarageTokens.space3),
              Text(message, style: TextStyle(color: context.tokens.danger)),
            ],
            const SizedBox(height: GarageTokens.space5),
            FilledButton(
              key: const Key('lend-create'),
              onPressed: _create,
              child: Text(l10n.guestLendAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    final code = await ref
        .read(guestPassControllerProvider.notifier)
        .lend(
          vehicleId: widget.vehicleId,
          validDays: _days,
          label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          canLogFuel: _fuel,
          canLogTrips: _trips,
          canLogCosts: _costs,
          canViewHistory: _history,
        );
    if (!mounted) {
      return;
    }
    setState(() {
      if (code == null) {
        _error = l10n.errorGeneric;
      } else {
        _code = code;
      }
    });
  }
}

/// The code, large and monospace, with the one action that matters.
class _Handover extends StatelessWidget {
  const _Handover({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    return Padding(
      padding: const EdgeInsets.all(GarageTokens.space5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.guestLendCreated,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: GarageTokens.space5),
          Center(
            child: SelectableText(
              code,
              key: const Key('lend-code'),
              style: GarageTheme.numeric(
                Theme.of(context).textTheme.headlineMedium!,
              ).copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(height: GarageTokens.space5),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              messenger.showSnackBar(
                SnackBar(content: Text(l10n.guestLendCopied)),
              );
            },
            icon: const Icon(Icons.copy_outlined),
            label: Text(l10n.guestLendCopy),
          ),
          const SizedBox(height: GarageTokens.space3),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }
}
