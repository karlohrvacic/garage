import 'dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../errors/app_failure.dart';
import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';
import 'failure_message.dart';

/// The red trash backdrop revealed behind a row swiped toward deletion.
class DeleteSwipeBackground extends StatelessWidget {
  const DeleteSwipeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: GarageTokens.space5),
      decoration: BoxDecoration(
        color: tokens.danger,
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
      ),
      child: Icon(Icons.delete_outline, color: tokens.surface),
    );
  }
}

/// The one deletion confirmation used everywhere an entry can be removed.
Future<bool> confirmDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      actionsOverflowDirection: garageActionsOverflowDirection,
      actionsOverflowAlignment: garageActionsOverflowAlignment,
      title: Text(l10n.confirmDeleteTitle),
      content: Text(l10n.confirmDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.tokens.danger,
            foregroundColor: context.tokens.surface,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.commonDelete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Runs a swipe-away deletion and reports it honestly.
///
/// The row is off the screen before [delete] even starts, so a rejected delete
/// has to say so somewhere the user will see it, and the list has to be
/// refetched either way — which is also what puts the row back when the server
/// kept it.
Future<void> deleteSwipedEntry(
  BuildContext context, {
  required Future<void> Function() delete,
  required VoidCallback refresh,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await delete();
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(failureMessage(l10n, AppFailure.from(error)))),
    );
  } finally {
    refresh();
  }
}
