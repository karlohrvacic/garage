import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

/// A month name over a list, the same eyebrow style Timeline has always
/// grouped by. One widget so a driver moving between Fuel, Servis, Povijest
/// and Troškovi sees the same landmark rather than four house styles for one
/// idea. See decision 62.
class MonthHeader extends StatelessWidget {
  const MonthHeader({required this.month, required this.locale, super.key});

  /// UTC, day-of-month 1 — what [MonthGroup.month] already is.
  final DateTime month;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GarageTokens.space4,
        GarageTokens.space4,
        GarageTokens.space4,
        GarageTokens.space2,
      ),
      child: Text(
        DateFormat.yMMMM(locale).format(month).toUpperCase(),
        style: GarageTheme.eyebrow(context),
      ),
    );
  }
}
