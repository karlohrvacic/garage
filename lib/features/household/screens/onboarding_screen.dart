import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/failure_message.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/household_providers.dart';

/// Shown to a signed-in user who has no household yet: the two ways in are
/// creating one or redeeming someone's invite code.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _createKey = GlobalKey<FormState>();
  final _joinKey = GlobalKey<FormState>();

  /// Which half is showing. Creating is the default: somebody with a code
  /// arrived from a link that says so, and somebody without one is making
  /// their first garage.
  bool _joining = false;
  final _name = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(householdControllerProvider);
    final failure = state.error is AppFailure
        ? state.error! as AppFailure
        : null;
    final busy = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingTitle),
        actions: [
          TextButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: Text(l10n.onboardingSignOut),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Both halves were always here, stacked — and the second one
                  // sat below the fold on a phone with nothing to say it
                  // existed, so somebody holding an invite code was shown a
                  // form for making a garage and concluded that was the only
                  // option. Two segments make the choice the first thing on
                  // the screen instead of a scroll away.
                  SegmentedButton<bool>(
                    key: const Key('onboarding-choice'),
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(l10n.onboardingCreateTitle),
                        icon: const Icon(Icons.add_home_work_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(l10n.onboardingJoinTitle),
                        icon: const Icon(Icons.key_outlined),
                      ),
                    ],
                    selected: {_joining},
                    onSelectionChanged: (choice) =>
                        setState(() => _joining = choice.first),
                  ),
                  const SizedBox(height: GarageTokens.space6),
                  if (!_joining)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(GarageTokens.space5),
                        child: Form(
                          key: _createKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.onboardingCreateTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: GarageTokens.space1),
                              Text(
                                l10n.onboardingCreateHint,
                                style: TextStyle(color: context.tokens.muted),
                              ),
                              const SizedBox(height: GarageTokens.space4),
                              LabeledField(
                                label: l10n.onboardingHouseholdName,
                                child: TextFormField(
                                  controller: _name,
                                  validator: (value) =>
                                      (value != null && value.trim().isNotEmpty)
                                      ? null
                                      : l10n.onboardingNameRequired,
                                ),
                              ),
                              const SizedBox(height: GarageTokens.space4),
                              FilledButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        if (_createKey.currentState!
                                            .validate()) {
                                          ref
                                              .read(
                                                householdControllerProvider
                                                    .notifier,
                                              )
                                              .createHousehold(_name.text);
                                        }
                                      },
                                child: Text(l10n.onboardingCreateAction),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_joining)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(GarageTokens.space5),
                        child: Form(
                          key: _joinKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l10n.onboardingJoinTitle,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: GarageTokens.space1),
                              Text(
                                l10n.onboardingJoinHint,
                                style: TextStyle(color: context.tokens.muted),
                              ),
                              const SizedBox(height: GarageTokens.space4),
                              LabeledField(
                                label: l10n.onboardingInviteCode,
                                child: TextFormField(
                                  controller: _code,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  validator: (value) =>
                                      (value != null &&
                                          value.trim().length == 8)
                                      ? null
                                      : l10n.onboardingCodeInvalid,
                                ),
                              ),
                              const SizedBox(height: GarageTokens.space4),
                              OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () {
                                        if (_joinKey.currentState!.validate()) {
                                          ref
                                              .read(
                                                householdControllerProvider
                                                    .notifier,
                                              )
                                              .joinHousehold(_code.text);
                                        }
                                      },
                                child: Text(l10n.onboardingJoinAction),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (failure != null) ...[
                    const SizedBox(height: GarageTokens.space4),
                    Text(
                      failureMessage(l10n, failure),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.tokens.danger),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
