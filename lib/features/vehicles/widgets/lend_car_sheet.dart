import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/date_pickers.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/guest_pass_providers.dart';
import '../../../core/widgets/discard_guard.dart';

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

  /// A window, not a length. Today to a week today is the common loan; a car
  /// promised for next weekend is the reason this is two dates.
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 7));
  bool _fuel = true;
  bool _trips = true;
  // Off by default. Fuel and drives are what somebody borrowing a car does;
  // entering a service invoice or a cost against a car that is not theirs is
  // not, and a default that assumes it is asks the owner to notice and
  // untick.
  bool _costs = false;
  bool _history = false;
  bool _prices = false;

  /// Set once the pass exists. The form becomes the handover: a code nobody
  /// read is a pass nobody can use.
  String? _code;
  String? _error;

  /// The window the form opened with, so that choosing different dates
  /// counts as work the discard guard should ask about.
  late final DateTime _openedFrom;
  late final DateTime _openedTo;

  @override
  void initState() {
    super.initState();
    _openedFrom = _from;
    _openedTo = _to;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  /// Anything changed from how the form opened. Only the form asks: once the
  /// code is on screen, the pass exists and closing loses nothing.
  bool _changed() =>
      _from != _openedFrom ||
      _to != _openedTo ||
      !_fuel ||
      !_trips ||
      _costs ||
      _history ||
      _prices;

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
            DiscardGuard(controllers: [_label], alsoDirty: _changed),
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
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.guestLendFrom,
                    child: OutlinedButton(
                      key: const Key('lend-from'),
                      onPressed: () => _pick(isStart: true),
                      child: Text(_dayLabel(context, _from)),
                    ),
                  ),
                ),
                const SizedBox(width: GarageTokens.space3),
                Expanded(
                  child: LabeledField(
                    label: l10n.guestLendUntil,
                    child: OutlinedButton(
                      key: const Key('lend-to'),
                      onPressed: () => _pick(isStart: false),
                      child: Text(_dayLabel(context, _to)),
                    ),
                  ),
                ),
              ],
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
              // Prices go with history: on their own they would grant access
              // to figures for work the holder cannot see.
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
                key: const Key('lend-prices'),
                contentPadding: const EdgeInsets.only(
                  left: GarageTokens.space4,
                ),
                value: _prices,
                onChanged: (value) => setState(() => _prices = value),
                title: Text(l10n.guestLendAllowPrices),
                subtitle: Text(l10n.guestLendAllowPricesHint),
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

  String _dayLabel(BuildContext context, DateTime day) {
    final l10n = AppLocalizations.of(context)!;
    final today = DateTime.now();
    if (day.year == today.year &&
        day.month == today.month &&
        day.day == today.day) {
      return l10n.guestLendStartsToday;
    }
    return UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.read(unitPreferencesProvider),
    ).formatDate(day);
  }

  Future<void> _pick({required bool isStart}) async {
    final current = isStart ? _from : _to;
    final today = DateTime.now();
    final picked = await showGarageDatePicker(
      context: context,
      initialDate: current,
      // A loan is the one date in this app that is *supposed* to be in the
      // future, so the usual "nothing after today" bound is the wrong one.
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isStart) {
        _from = picked;
        // Dragging the start past the end would make a window nobody meant;
        // the end follows rather than the form refusing.
        if (!_to.isAfter(_from)) {
          _to = _from.add(const Duration(days: 1));
        }
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_to.isAfter(_from)) {
      setState(() => _error = l10n.guestLendWindowBackwards);
      return;
    }
    final today = DateTime.now();
    final startsToday =
        _from.year == today.year &&
        _from.month == today.month &&
        _from.day == today.day;
    final code = await ref
        .read(guestPassControllerProvider.notifier)
        .lend(
          vehicleId: widget.vehicleId,
          // The end of the chosen day, not its midnight: a pass "until
          // Sunday" that dies at Saturday midnight is a bug report.
          endsAt: DateTime(_to.year, _to.month, _to.day, 23, 59).toUtc(),
          // Null when it starts today, which is what the table means by "usable
          // the moment it is handed over" — a start stamped an hour ago would
          // read as a booking that has already begun.
          startsAt: startsToday
              ? null
              : DateTime(_from.year, _from.month, _from.day).toUtc(),
          label: _label.text.trim().isEmpty ? null : _label.text.trim(),
          canLogFuel: _fuel,
          canLogTrips: _trips,
          canLogCosts: _costs,
          canViewHistory: _history,
          canViewPrices: _prices,
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
