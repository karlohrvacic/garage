import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../core/widgets/failure_message.dart';
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
    await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(authControllerProvider);
    final failure = state.error is AppFailure ? state.error! as AppFailure : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignUpTitle)),
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
                    TextFormField(
                      controller: _name,
                      decoration:
                          InputDecoration(labelText: l10n.authDisplayName),
                      validator: (value) =>
                          (value != null && value.trim().isNotEmpty)
                              ? null
                              : l10n.authNameRequired,
                    ),
                    const SizedBox(height: GarageTokens.space4),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
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
                      child: Text(l10n.authSignUpAction),
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
