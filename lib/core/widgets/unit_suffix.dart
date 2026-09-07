import 'package:flutter/material.dart';

/// A unit shown beside a field, whether or not anything has been typed.
///
/// `InputDecoration.suffixText` is hidden while the field is empty and
/// unfocused — Flutter's own behaviour, and reasonable for a hint. It is wrong
/// for a unit: "l", "€/l" and "km" are part of the question being asked, not a
/// decoration on the answer, and a row of three empty boxes said nothing about
/// what went in them until you tapped one. Reported as "why is the unit shown
/// only when a value is entered".
///
/// `suffixIcon` is the slot that is always painted, so the unit goes there,
/// sized down to a label rather than an icon's 48-pixel box.
Widget unitSuffix(BuildContext context, String unit) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: 12),
    child: Align(
      alignment: Alignment.centerRight,
      widthFactor: 1,
      child: Text(
        unit,
        style:
            Theme.of(context).inputDecorationTheme.suffixStyle ??
            Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
      ),
    ),
  );
}
