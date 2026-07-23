import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/garage_theme.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/settings/providers/settings_providers.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  await initializeDateFormatting();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The anon key was renamed publishableKey in supabase_flutter; the value is
    // the same public key, still gated by RLS.
    publishableKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: GarageApp()));
}

class GarageApp extends ConsumerStatefulWidget {
  const GarageApp({super.key});

  @override
  ConsumerState<GarageApp> createState() => _GarageAppState();
}

class _GarageAppState extends ConsumerState<GarageApp> {
  StreamSubscription<AuthState>? _authEvents;

  @override
  void initState() {
    super.initState();
    // The reset email signs the user in with a recovery session; without this
    // prompt they would land on the dashboard with no way to set the new
    // password they asked for.
    _authEvents = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _promptForNewPassword();
      }
    });
  }

  @override
  void dispose() {
    _authEvents?.cancel();
    super.dispose();
  }

  Future<void> _promptForNewPassword() async {
    final dialogContext = rootNavigatorKey.currentContext;
    if (dialogContext == null) {
      return;
    }
    final newPassword = await showDialog<String>(
      context: dialogContext,
      builder: (context) => const _NewPasswordDialog(),
    );
    if (newPassword == null) {
      return;
    }
    await ref.read(authControllerProvider.notifier).updatePassword(newPassword);
    final messengerContext = rootNavigatorKey.currentContext;
    if (messengerContext == null ||
        !messengerContext.mounted ||
        ref.read(authControllerProvider).hasError) {
      return;
    }
    ScaffoldMessenger.of(messengerContext).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(messengerContext)!.authPasswordUpdated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: GarageTheme.light(),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(l10n.authSetNewPasswordTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _password,
          obscureText: true,
          autofocus: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(labelText: l10n.authPassword),
          validator: (value) => (value != null && value.length >= 8)
              ? null
              : l10n.authPasswordTooShort,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_password.text);
            }
          },
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
