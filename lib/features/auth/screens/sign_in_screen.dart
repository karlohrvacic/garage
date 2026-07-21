import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/google_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
import '../providers/auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
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
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    final failure = state.error is AppFailure ? state.error! as AppFailure : null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GarageTokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.authSignInTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: GarageTokens.space6),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: l10n.authEmail),
                      validator: (value) =>
                          (value != null && value.contains('@'))
                              ? null
                              : l10n.authInvalidEmail,
                    ),
                    const SizedBox(height: GarageTokens.space4),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(labelText: l10n.authPassword),
                      validator: (value) => (value != null && value.length >= 8)
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
                      child: state.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
