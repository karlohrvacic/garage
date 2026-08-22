import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/config/google_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../providers/auth_providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Through the container rather than `ref`, for the reason spelled out in
    // sign_in_screen.dart: a sign-up that works takes this screen away with it.
    final providers = ProviderScope.containerOf(context, listen: false);
    await providers
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
    // Tells the platform the form is done, which is what prompts a password
    // manager to offer to save what was just typed. Without it the credential
    // is never offered, and the next sign-in is a manual one forever.
    if (!providers.read(authControllerProvider).hasError) {
      TextInput.finishAutofillContext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    final failure = state.error is AppFailure
        ? state.error! as AppFailure
        : null;
    final pendingEmail = ref.watch(pendingEmailConfirmationProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignUpTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // The account exists but cannot be used yet, and the form has
              // nothing left to do: showing it again invites a second
              // registration with the same address.
              child: pendingEmail != null
                  ? _ConfirmEmail(email: pendingEmail)
                  // Password managers need a declared group and a hint per field.
                  // Without them Proton Pass, 1Password and the platform's own
                  // manager cannot fill this form or offer to save it — which
                  // pushes people toward a password they can type from memory.
                  : AutofillGroup(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LabeledField(
                              label: l10n.authDisplayName,
                              child: TextFormField(
                                controller: _name,
                                autofillHints: const [AutofillHints.name],
                                validator: (value) =>
                                    (value != null && value.trim().isNotEmpty)
                                    ? null
                                    : l10n.authNameRequired,
                              ),
                            ),
                            const SizedBox(height: GarageTokens.space4),
                            LabeledField(
                              label: l10n.authEmail,
                              child: TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                // `username` beside `email`: the account is identified
                                // by its address, and managers file it under both.
                                autofillHints: const [
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                validator: (value) =>
                                    (value != null && value.contains('@'))
                                    ? null
                                    : l10n.authInvalidEmail,
                              ),
                            ),
                            const SizedBox(height: GarageTokens.space4),
                            PasswordFormField(
                              controller: _password,
                              label: l10n.authPassword,
                              // newPassword, not password: this is what makes a
                              // manager offer to *generate* one here rather than
                              // suggest an existing credential.
                              autofillHints: const [AutofillHints.newPassword],
                              validator: (value) =>
                                  (value != null && value.length >= 8)
                                  ? null
                                  : l10n.authPasswordTooShort,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (failure != null) ...[
                              const SizedBox(height: GarageTokens.space4),
                              Text(
                                failureMessage(l10n, failure),
                                style: TextStyle(color: context.tokens.danger),
                              ),
                            ],
                            const SizedBox(height: GarageTokens.space6),
                            FilledButton(
                              onPressed: state.isLoading ? null : _submit,
                              child: Text(l10n.authSignUpAction),
                            ),
                            if (GoogleConfig.isConfigured) ...[
                              const SizedBox(height: GarageTokens.space3),
                              OutlinedButton(
                                onPressed: state.isLoading
                                    ? null
                                    : () => ref
                                          .read(authControllerProvider.notifier)
                                          .signInWithGoogle(),
                                child: Text(l10n.authContinueWithGoogle),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the screen says once the account exists but the address is unconfirmed.
///
/// Supabase answers a sign-up that needs confirmation with a user and no
/// session. The screen used to do nothing with that: the form stayed put, the
/// button looked like it had failed, and the one thing the person needed to
/// do — open their mail — went unmentioned.
class _ConfirmEmail extends ConsumerWidget {
  const _ConfirmEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.mark_email_unread_outlined,
          size: 48,
          color: context.tokens.accent,
        ),
        const SizedBox(height: GarageTokens.space4),
        Text(
          l10n.authConfirmEmailTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: GarageTokens.space2),
        // The address is named because a typo in it is the likeliest reason
        // no mail arrives, and it is the one thing the user can check.
        Text(l10n.authConfirmEmailBody(email), textAlign: TextAlign.center),
        const SizedBox(height: GarageTokens.space6),
        FilledButton(
          onPressed: () {
            ref.read(pendingEmailConfirmationProvider.notifier).state = null;
            context.push('/sign-in');
          },
          child: Text(l10n.authConfirmEmailAction),
        ),
      ],
    );
  }
}
