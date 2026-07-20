import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/garage_theme.dart';
import 'l10n/app_localizations.dart';

void main() {
  initializeDateFormatting();
  runApp(const GarageApp());
}

class GarageApp extends StatelessWidget {
  const GarageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: GarageTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Center(child: Text('Garage'))),
    );
  }
}
