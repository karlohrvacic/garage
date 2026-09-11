import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/code_description.dart';
import '../../../domain/entities/household.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/adaptive.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../vehicles/providers/guest_pass_providers.dart';
import '../providers/household_providers.dart';
import '../providers/pending_invite.dart';

/// Where an invite link lands.
///
/// The person opening one often has no account, and usually no household. Both
/// of the app's gates would otherwise bounce them: to sign-in, which loses the
/// code, and then to onboarding, which asks them to type it in by hand. So this
/// screen sits outside both and handles each case itself, joining without
/// asking when there is nothing left to ask.
///
/// The code is described before anything is done with it, so the screen can
/// say which garage the invite is for. It once said only which garage the
/// visitor was already in, and a friend opening a link for one garage read
/// "You are already in their own garage" as the link having landed them in the
/// wrong place.
///
/// Somebody already in a garage is joining a second one, which the app now
/// supports; the join is offered rather than performed, because opening a link
/// out of curiosity should not silently move them. Somebody already in the
/// garage the invite is for is offered the door, not the join: the backend
/// would accept it and change nothing.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({required this.code, super.key});

  final String code;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  bool _joining = false;
  bool _joined = false;
  bool _described = false;
  bool _deciding = false;
  CodeDescription? _invite;
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
    if (!mounted || _deciding) {
      return;
    }
    _deciding = true;
    try {
      await _decideOnce();
    } finally {
      _deciding = false;
    }
  }

  Future<void> _decideOnce() async {
    final signedIn = ref.read(currentUserIdProvider) != null;
    if (!signedIn) {
      // Kept so the link still means something after the detour through
      // sign-in, which is the whole difference between a link and a code.
      ref.read(pendingInviteProvider.notifier).remember(_code);
      return;
    }

    final invite = await _describe();
    final household = await ref.read(currentHouseholdProvider.future);
    if (!mounted) {
      return;
    }
    if (invite == null || invite.spent || invite.member || household != null) {
      // Nothing to do, or nothing to do *silently*: somebody already in a
      // garage gets the button rather than being switched into somebody
      // else's the moment they tap a link.
      return;
    }
    await _join();
  }

  Future<CodeDescription?> _describe() async {
    try {
      final found = await ref.read(guestPassRepositoryProvider).describe(_code);
      // The link is for a garage. A lending or transfer code pasted into an
      // invite URL is not one the join could redeem anyway.
      final invite = found?.kind == CodeKind.invite ? found : null;
      if (mounted) {
        setState(() {
          _invite = invite;
          _described = true;
        });
      }
      return invite;
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = AppFailure.from(error);
          _described = true;
        });
      }
      return null;
    }
  }

  Future<void> _join() async {
    setState(() {
      _joining = true;
      _failure = null;
    });
    try {
      final householdId = await ref
          .read(householdRepositoryProvider)
          .joinWithCode(_code);
      ref.read(pendingInviteProvider.notifier).clear();
      // The garage they just joined is the one they came here to see, even if
      // they were already in another.
      await ref.read(selectedHouseholdIdProvider.notifier).select(householdId);
      ref
        ..invalidate(garageBootstrapProvider)
        ..invalidate(currentHouseholdProvider);
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

    // The session can arrive after this screen is already up: a link tapped on
    // a cold start builds it before supabase_flutter has restored one, and
    // `/join` sits outside both gates — see [garageRedirect] — so nothing
    // navigates away and rebuilds it when the session lands. Deciding only in
    // [initState] left the screen spinning for good over an invite it had
    // never described, because describing happens past the signed-in gate.
    ref.listen(currentUserIdProvider, (before, after) {
      if (before == null && after != null) {
        _decide();
      }
    });

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

    if (_joining || !_described) {
      return [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: GarageTokens.space4),
        Text(l10n.joinJoining, textAlign: TextAlign.center),
      ];
    }

    final invite = _invite;
    if (invite == null) {
      // Described and found wanting. A failure to describe at all is shown
      // below the body, in red, by the caller.
      return [
        if (_failure == null)
          Text(l10n.codeBoxUnknown, textAlign: TextAlign.center),
      ];
    }
    if (invite.spent) {
      return [Text(l10n.codeBoxSpent, textAlign: TextAlign.center)];
    }
    if (invite.member) {
      return [
        Text(
          l10n.joinAlreadyMember(invite.subject),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: GarageTokens.space5),
        FilledButton(
          onPressed: () => context.go('/'),
          child: Text(l10n.joinOpenGarage),
        ),
      ];
    }

    // Either the join failed, or the user is already in a garage and this
    // invite is for a second one. Both want the same button.
    return [
      Text(
        household == null
            ? l10n.joinFor(invite.subject)
            : l10n.joinSecondGarage(household.name, invite.subject),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: GarageTokens.space5),
      FilledButton(onPressed: _join, child: Text(l10n.onboardingJoinAction)),
    ];
  }
}
