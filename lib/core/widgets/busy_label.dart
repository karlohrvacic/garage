import 'package:flutter/material.dart';

/// A button's label while its work is in flight: the same small spinner the
/// sign-in button shows, so every submit says "working" the same way rather
/// than some dimming and one spinning.
class BusyLabel extends StatelessWidget {
  const BusyLabel({required this.busy, required this.child, super.key});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!busy) {
      return child;
    }
    return const SizedBox(
      height: 18,
      width: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
