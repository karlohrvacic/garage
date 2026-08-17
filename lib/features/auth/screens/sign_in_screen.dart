import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import '../../../core/links/url_opener.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/google_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/labeled_field.dart';
import '../providers/auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

/// The GARAGE_ wordmark: uppercase mono with the cursor tick in dash amber.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontFamily: 'JetBrainsMono',
      fontWeight: FontWeight.w500,
      letterSpacing: 2,
    );
    return Text.rich(
      TextSpan(
        text: 'GARAGE',
        style: style,
        children: [
          TextSpan(
            text: '_',
            style: style?.copyWith(color: context.tokens.accent),
          ),
        ],
      ),
    );
  }
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (!ref.read(authControllerProvider).hasError) {
      TextInput.finishAutofillContext();
    }
  }

  Future<void> _forgotPassword() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_email.text.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.authInvalidEmail)));
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (!mounted || ref.read(authControllerProvider).hasError) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.authResetSent)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    final failure = state.error is AppFailure
        ? state.error! as AppFailure
        : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // The hints below were already here; the group was not, and it
              // is what lets a manager treat the two fields as one credential
              // and offer to save it.
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Wordmark(),
                      const SizedBox(height: GarageTokens.space2),
                      Text(
                        l10n.authTagline,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: GarageTokens.space8),
                      Text(
                        l10n.authSignInTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: GarageTokens.space4),
                      // Following the link from a confirmation email and
                      // landing on a bare sign-in form, with no word about
                      // why, is the worst moment in the whole funnel: the user
                      // did exactly what was asked and the app acted as though
                      // nothing had happened. Supabase puts the reason in the
                      // URL; nothing read it.
                      if (ref.watch(authLinkFailureProvider) != null) ...[
                        Text(
                          l10n.authLinkFailed,
                          style: TextStyle(color: context.tokens.danger),
                        ),
                        const SizedBox(height: GarageTokens.space4),
                      ],
                      LabeledField(
                        label: l10n.authEmail,
                        child: TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
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
                        autofillHints: const [AutofillHints.password],
                        validator: (value) =>
                            (value != null && value.length >= 8)
                            ? null
                            : l10n.authPasswordTooShort,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: state.isLoading ? null : _forgotPassword,
                          child: Text(l10n.authForgotPassword),
                        ),
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
                        child: state.isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.authSignInAction),
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
                      const SizedBox(height: GarageTokens.space3),
                      TextButton(
                        onPressed: () => context.push('/sign-up'),
                        child: Text(l10n.authNoAccount),
                      ),
                      // The only thing a visitor who has not already decided
                      // to use this ever saw was a password box: the web app
                      // redirects straight here and says nothing about what it
                      // is for.
                      TextButton(
                        key: const Key('what-garage-does'),
                        onPressed: () =>
                            ref.read(urlOpenerProvider)(GarageLinks.features),
                        child: Text(l10n.authWhatIsThis),
                      ),
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
