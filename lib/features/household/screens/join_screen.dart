import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/household.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../providers/household_providers.dart';
import '../providers/pending_invite.dart';

/// Where an invite link lands.
///
/// The person opening one has, by definition, no household yet, and often no
/// account either. Both of the app's gates would otherwise bounce them: to
/// sign-in, which loses the code, and then to onboarding, which asks them to
/// type it in by hand. So this screen sits outside both and handles each case
/// itself, joining without asking when there is nothing left to ask.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  bool _joining = false;
  bool _joined = false;
  AppFailure? _failure;

  String get _code => widget.code.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    // After the first frame: joining invalidates providers this build is
    // reading, and signing out to the auth screens is a navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    if (!mounted) {
      return;
    }
    final signedIn = ref.read(currentUserIdProvider) != null;
    if (!signedIn) {
      // Kept so the link still means something after the detour through
      // sign-in, which is the whole difference between a link and a code.
      ref.read(pendingInviteProvider.notifier).remember(_code);
      return;
    }

    final household = await ref.read(currentHouseholdProvider.future);
    if (!mounted || household != null) {
      return;
    }
    await _join();
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _failure = null;
    });
    try {
      await ref.read(householdRepositoryProvider).joinWithCode(_code);
      ref.read(pendingInviteProvider.notifier).clear();
      ref.invalidate(currentHouseholdProvider);
      await ref.read(currentHouseholdProvider.future);
      if (mounted) {
        setState(() => _joined = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _failure = AppFailure.from(error));
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final signedIn = ref.watch(currentUserIdProvider) != null;
    final household = ref.watch(currentHouseholdProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: AdaptiveContent(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _code,
                  textAlign: TextAlign.center,
                  style: GarageTheme.numeric(
                    Theme.of(context).textTheme.headlineMedium!,
                  ),
                ),
                const SizedBox(height: GarageTokens.space5),
                ..._body(
                  context,
                  l10n,
                  signedIn: signedIn,
                  household: household,
                ),
                if (_failure != null) ...[
                  const SizedBox(height: GarageTokens.space4),
                  Text(
                    failureMessage(l10n, _failure!),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.tokens.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(
    BuildContext context,
    AppLocalizations l10n, {
    required bool signedIn,
    required Household? household,
  }) {
    if (!signedIn) {
      return [
        Text(l10n.joinInvited, textAlign: TextAlign.center),
        const SizedBox(height: GarageTokens.space5),
        FilledButton(
          onPressed: () => context.go('/sign-up'),
          child: Text(l10n.authSignUpAction),
        ),
        const SizedBox(height: GarageTokens.space3),
        OutlinedButton(
          onPressed: () => context.go('/sign-in'),
          child: Text(l10n.authSignInAction),
        ),
      ];
    }

    // Joining a second household would put the user somewhere the rest of the
    // app cannot show them: every screen reads whichever household comes back
    // first. Saying so is better than appearing to work.
    if (household != null && !_joined) {
      return [
        Text(
          l10n.joinAlreadyMember(household.name),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: GarageTokens.space5),
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.joinOpenGarage),
        ),
      ];
    }

    if (_joined) {
      return [
        Text(l10n.joinDone, textAlign: TextAlign.center),
        const SizedBox(height: GarageTokens.space5),
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.joinOpenGarage),
        ),
      ];
    }

    if (_joining) {
      return [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: GarageTokens.space4),
        Text(l10n.joinJoining, textAlign: TextAlign.center),
      ];
    }

    // Only reachable when the join failed: offer the retry rather than
    // stranding them on an explanation with no way forward.
    return [
      FilledButton(onPressed: _join, child: Text(l10n.onboardingJoinAction)),
    ];
  }
}
