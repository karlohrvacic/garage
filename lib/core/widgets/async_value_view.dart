import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../errors/app_failure.dart';
import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';
import 'empty_state_art.dart';
import 'failure_message.dart';

/// Renders the four states every async screen has. Centralising it is what
/// stops "loading" and "empty" from quietly collapsing into the same blank
/// screen as the feature count grows.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.data,
    this.empty,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T value) data;
  final Widget Function()? empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                failureMessage(l10n, AppFailure.from(error)),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tokens.danger),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: GarageTokens.space4),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(l10n.commonRetry),
                ),
              ],
            ],
          ),
        ),
      ),
      data: (value) {
        if (empty != null && value is Iterable && value.isEmpty) {
          return Center(child: empty!());
        }
        return data(value);
      },
    );
  }
}

/// The standard empty-state body: a line of explanation and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, this.action, this.motif, super.key});

  final String message;
  final Widget? action;

  /// A thin-line drawing above the sentence, or null for none.
  ///
  /// Optional so the nine screens that already had an empty state keep the
  /// one they have, and additive for the same reason: art belongs on the
  /// screens a person lands on with nothing yet, not on every branch that
  /// happens to return no rows.
  ///
  /// It drops itself on a short window; see [EmptyStateArt.maybeShow].
  final EmptyStateMotif? motif;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GarageTokens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (motif case final motif?)
            if (EmptyStateArt.maybeShow(context, motif) case final art?) ...[
              art,
              const SizedBox(height: GarageTokens.space5),
            ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.tokens.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: GarageTokens.space4),
            // Filled buttons take the width they are given; across a desktop
            // pane that is a metre of amber.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: action!,
            ),
          ],
        ],
      ),
    );
  }
}
