import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../providers/guest_pass_providers.dart';

/// Claiming a car somebody lent you.
///
/// Deliberately separate from joining a garage: the two take a code of the
/// same shape and mean completely different things, and a single field that
/// silently did either would make "what did I just agree to" unanswerable.
class GuestRedeemScreen extends ConsumerStatefulWidget {
  const GuestRedeemScreen({super.key});

  @override
  ConsumerState<GuestRedeemScreen> createState() => _GuestRedeemScreenState();
}

class _GuestRedeemScreenState extends ConsumerState<GuestRedeemScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GaragePageScaffold(
      title: l10n.guestRedeemTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.guestRedeemIntro,
              style: TextStyle(color: context.tokens.muted),
            ),
            const SizedBox(height: GarageTokens.space5),
            LabeledField(
              label: l10n.guestRedeemTitle,
              child: TextField(
                key: const Key('redeem-code'),
                controller: _code,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: GarageTheme.numericField(
                  context,
                ).copyWith(letterSpacing: 3),
              ),
            ),
            if (_error case final message?) ...[
              const SizedBox(height: GarageTokens.space3),
              Text(message, style: TextStyle(color: context.tokens.danger)),
            ],
            const SizedBox(height: GarageTokens.space5),
            FilledButton(
              key: const Key('redeem-submit'),
              onPressed: _busy ? null : _redeem,
              child: Text(l10n.guestRedeemAction),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _redeem() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    final vehicleId = await ref
        .read(guestPassControllerProvider.notifier)
        .redeem(_code.text);

    if (!mounted) {
      return;
    }
    if (vehicleId == null) {
      // One message for every refusal. Distinguishing "expired" from "already
      // in use" here would tell somebody holding a code they should not have
      // which of the two it is.
      setState(() {
        _busy = false;
        _error = l10n.guestRedeemFailed;
      });
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.guestRedeemDone)));
    router.go('/vehicles/$vehicleId');
  }
}
