import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import 'dialog_actions.dart';
import 'labeled_field.dart';

/// Asks for one line of text and hands it back, trimmed, or null if cancelled.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initialValue = '',
  Key? fieldKey,
  bool capitalise = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => TextPrompt(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
      fieldKey: fieldKey,
      capitalise: capitalise,
    ),
  );
}

/// A one-field prompt that owns its controller.
///
/// Written because the alternatives both misbehave: disposing the controller
/// as soon as `showDialog` returns tears it out from under the dialog's exit
/// animation ("A TextEditingController was used after being disposed"), and
/// not disposing it at all leaks one per prompt. A widget with a lifecycle is
/// the thing that has somewhere correct to do it.
class TextPrompt extends StatefulWidget {
  const TextPrompt({
    super.key,
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initialValue = '',
    this.fieldKey,
    this.capitalise = false,
  });

  final String title;
  final String label;
  final String confirmLabel;
  final String initialValue;
  final Key? fieldKey;
  final bool capitalise;

  @override
  State<TextPrompt> createState() => TextPromptState();
}

class TextPromptState extends State<TextPrompt> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      scrollable: true,
      actionsOverflowDirection: garageActionsOverflowDirection,
      actionsOverflowAlignment: garageActionsOverflowAlignment,
      title: Text(widget.title),
      content: LabeledField(
        label: widget.label,
        child: TextField(
          key: widget.fieldKey,
          controller: _controller,
          autofocus: true,
          textCapitalization: widget.capitalise
              ? TextCapitalization.characters
              : TextCapitalization.sentences,
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
