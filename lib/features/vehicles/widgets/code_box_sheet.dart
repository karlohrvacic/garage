import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/unit_format.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../domain/entities/code_description.dart';
import '../../../core/router/app_redirect.dart';
import '../../settings/providers/unit_providers.dart';
import '../providers/guest_pass_providers.dart';
import '../../../core/widgets/discard_guard.dart';

/// One box for every code somebody can be handed.
///
/// A garage invite, a vehicle transfer and a lending pass are all eight
/// characters and look identical. Three screens under three names made telling
/// them apart the holder's problem; this asks the server what the code is,
/// says plainly what using it will do, and only then does it.
Future<void> showCodeBoxSheet(BuildContext context) {
  return showAdaptiveEntrySheet<void>(context, (_) => const _CodeBoxForm());
}

class _CodeBoxForm extends ConsumerStatefulWidget {
  const _CodeBoxForm();

  @override
  ConsumerState<_CodeBoxForm> createState() => _CodeBoxFormState();
}

class _CodeBoxFormState extends ConsumerState<_CodeBoxForm> {
  final _code = TextEditingController();
  CodeDescription? _found;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final format = UnitFormat(
      locale: Localizations.localeOf(context).languageCode,
      preferences: ref.watch(unitPreferencesProvider),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DiscardGuard(controllers: [_code]),
              Text(
                l10n.codeBoxTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: GarageTokens.space4),
              LabeledField(
                label: l10n.onboardingInviteCode,
                child: TextField(
                  key: const Key('code-box-input'),
                  controller: _code,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  style: GarageTheme.numericField(context),
                  onChanged: (_) => setState(() {
                    _found = null;
                    _error = null;
                  }),
                ),
              ),
              if (_error case final message?) ...[
                const SizedBox(height: GarageTokens.space3),
                Text(message, style: TextStyle(color: context.tokens.danger)),
              ],
              // What it is, and what using it will do, in the words of the
              // thing it actually is.
              if (_found case final found?) ...[
                const SizedBox(height: GarageTokens.space4),
                Text(key: const Key('code-box-explains'), switch (found.kind) {
                  // No owner's name: the server does not disclose one, and the
                  // car and the date are what the holder needs.
                  CodeKind.lending => l10n.codeBoxLending(
                    found.subject,
                    format.formatDate(found.until.toLocal()),
                  ),
                  CodeKind.transfer => l10n.codeBoxTransfer(found.subject),
                  CodeKind.invite => l10n.codeBoxInvite(found.subject),
                }),
              ],
              const SizedBox(height: GarageTokens.space5),
              FilledButton(
                key: const Key('code-box-submit'),
                onPressed: _busy ? null : (_found == null ? _look : _use),
                child: Text(_found == null ? l10n.commonNext : l10n.codeBoxUse),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _look() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    final found = await ref
        .read(guestPassControllerProvider.notifier)
        .describe(_code.text);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      if (found == null) {
        _error = l10n.codeBoxUnknown;
      } else if (found.spent) {
        _error = l10n.codeBoxSpent;
      } else {
        _found = found;
      }
    });
  }

  Future<void> _use() async {
    final found = _found;
    if (found == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);

    switch (found.kind) {
      case CodeKind.lending:
        final vehicleId = await ref
            .read(guestPassControllerProvider.notifier)
            .redeem(_code.text);
        if (!mounted) {
          return;
        }
        if (vehicleId == null) {
          setState(() {
            _busy = false;
            _error = l10n.guestRedeemFailed;
          });
          return;
        }
        navigator.pop();
        // The tab first, the car on top of it: a pushed route on its own has
        // no bottom bar and nothing to go back to.
        router.go('/vehicles');
        router.push('/vehicles/$vehicleId');
      case CodeKind.transfer:
        navigator.pop();
        router.push('/transfer?code=${_code.text.trim().toUpperCase()}');
      case CodeKind.invite:
        navigator.pop();
        router.push('$joinRoute/${_code.text.trim().toUpperCase()}');
    }
  }
}
