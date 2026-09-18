import 'package:flutter/material.dart';

import '../theme/garage_tokens.dart';
import 'adaptive.dart';

/// One row of [showPickOne].
class PickOption<T> {
  const PickOption(
    this.value,
    this.label, {
    this.subtitle,
    this.icon,
    this.key,
  });

  final T value;
  final String label;

  /// What the row is for, when the label alone does not say: long labels
  /// get a line each here, which is why a list is a sheet and not a menu.
  final String? subtitle;
  final IconData? icon;
  final Key? key;
}

/// Asks for one of [options] and hands back the value of the row tapped, or
/// null when the question is put away.
///
/// Six lists were a bare bottom sheet each and two were a `SimpleDialog`, so
/// the same question slid up on one screen, popped up on another, and on a
/// wide window stretched across the monitor.
Future<T?> showPickOne<T>(
  BuildContext context, {
  String? title,
  required List<PickOption<T>> options,
}) {
  return showAdaptiveChoice<T>(
    context,
    (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(
          // A sheet has its drag handle above the title; a dialog has nothing.
          top: GarageBreakpoints.isWide(context) ? GarageTokens.space4 : 0,
          bottom: GarageTokens.space2,
        ),
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GarageTokens.space4,
                0,
                GarageTokens.space4,
                GarageTokens.space2,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          for (final option in options)
            ListTile(
              key: option.key,
              leading: option.icon == null ? null : Icon(option.icon),
              title: Text(option.label),
              subtitle: option.subtitle == null ? null : Text(option.subtitle!),
              onTap: () => Navigator.of(context).pop(option.value),
            ),
        ],
      ),
    ),
  );
}
