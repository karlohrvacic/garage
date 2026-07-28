import 'package:flutter/material.dart';

import '../theme/garage_tokens.dart';

/// A form field with its label set above the input instead of floating inside
/// it — the Night Shift form pattern.
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: GarageTokens.space2),
        child,
      ],
    );
  }
}

/// Password input with a visibility toggle. The toggle is the typo defense —
/// there is deliberately no confirm-password field anywhere in the app.
class PasswordFormField extends StatefulWidget {
  const PasswordFormField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final bool autofocus;

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: widget.label,
      child: TextFormField(
        controller: widget.controller,
        obscureText: !_visible,
        autofocus: widget.autofocus,
        autofillHints: widget.autofillHints,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
      ),
    );
  }
}
