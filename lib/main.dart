import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/garage_theme.dart';
import 'features/settings/providers/settings_providers.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();
  initializeDateFormatting();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    // The anon key was renamed publishableKey in supabase_flutter; the value is
    // the same public key, still gated by RLS.
    publishableKey: Env.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: GarageApp()));
}

class GarageApp extends ConsumerWidget {
  const GarageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
