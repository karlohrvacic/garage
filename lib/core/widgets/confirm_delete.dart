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

/// A confirmation for something that cannot be taken back.
///
/// Parameterised because it was not, and the one caller that is not a deletion
/// borrowed it anyway: handing a vehicle to its next owner asked "Delete
/// entry? This cannot be undone." over a red **Delete** button, which names
/// the wrong act entirely — nothing is deleted, and the seller could
/// reasonably believe they were about to destroy the car's history.
///
/// [title] is optional because a question that asks itself needs no heading
/// over it. [confirmKey] is for a test that has to press this button and no
/// other one with the same label.
Future<bool> confirmDestructive(
  BuildContext context, {
  String? title,
  required String body,
  required String confirmLabel,
  Key? confirmKey,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      // A long question at a large font on a small phone scrolls rather than
      // pushing its buttons off the screen.
      scrollable: true,
      actionsOverflowDirection: garageActionsOverflowDirection,
      actionsOverflowAlignment: garageActionsOverflowAlignment,
      title: title == null ? null : Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: confirmKey,
          style: FilledButton.styleFrom(
            backgroundColor: context.tokens.danger,
            foregroundColor: context.tokens.surface,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// A confirmation for something that is not a deletion.
///
/// Same shape as [confirmDestructive] without the red button: an action that
/// *adds* is not destructive, and dressing it in the deletion styling would
/// teach people to read red as "any confirmation" — which is how a real
/// deletion stops registering.
Future<bool> confirmAction(
  BuildContext context, {
  String? title,
  required String body,
  required String confirmLabel,
  Key? confirmKey,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      actionsOverflowDirection: garageActionsOverflowDirection,
      actionsOverflowAlignment: garageActionsOverflowAlignment,
      title: title == null ? null : Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Something to read, with one way out: not a question, so there is no
/// Cancel, and not a form, so it is not a sheet.
Future<void> showNotice(
  BuildContext context, {
  String? title,
  required Widget content,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: title == null ? null : Text(title),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    ),
  );
}

/// The one deletion confirmation used everywhere an entry can be removed.
Future<bool> confirmDelete(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return confirmDestructive(
    context,
    title: l10n.confirmDeleteTitle,
    body: l10n.confirmDeleteBody,
    confirmLabel: l10n.commonDelete,
  );
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
