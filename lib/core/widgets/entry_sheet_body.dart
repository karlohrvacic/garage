import 'package:flutter/material.dart';

import '../theme/garage_tokens.dart';

/// The shape every entry form in this app takes: a title, some fields, and a
/// confirming button at the bottom.
///
/// Tyres and API access were the two surfaces still building their own
/// `AlertDialog`s, so on a phone they arrived as centre-screen dialogs while
/// every other form in the app slid up as a sheet — the same act of typing a
/// few fields, presented two different ways depending on which screen you
/// happened to be on. Routed through [showAdaptiveEntrySheet] with this body,
/// they get the phone/desktop split for free: a bottom sheet on a phone, a
/// centred dialog on a desktop window.
///
/// Deliberately not a copy of the entry sheets' own bodies. Those own
/// controllers, validation and a repository call and are properly stateful;
/// this is for the short prompts that only need to collect a value and hand
/// it back through `Navigator.pop`.
class EntrySheetBody extends StatelessWidget {
  const EntrySheetBody({
    required this.title,
    required this.fields,
    required this.confirmLabel,
    required this.onConfirm,
    super.key,
    this.onCancel,
    this.cancelLabel,
  }) : assert(
         (onCancel == null) == (cancelLabel == null),
         'a cancel action needs a label, and a label needs an action',
       );

  final String title;
  final List<Widget> fields;
  final String confirmLabel;
  final VoidCallback onConfirm;

  /// A phone sheet can be swiped away and a desktop dialog dismissed by
  /// tapping outside it, so this is a convenience rather than the only way
  /// out. Offered anyway on the surfaces that had one before.
  final VoidCallback? onCancel;
  final String? cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GarageTokens.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: GarageTokens.space4),
              ...fields,
              const SizedBox(height: GarageTokens.space5),
              FilledButton(onPressed: onConfirm, child: Text(confirmLabel)),
              if (onCancel case final cancel?) ...[
                const SizedBox(height: GarageTokens.space3),
                TextButton(onPressed: cancel, child: Text(cancelLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
