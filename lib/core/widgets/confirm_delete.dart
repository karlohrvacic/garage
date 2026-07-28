import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';

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
