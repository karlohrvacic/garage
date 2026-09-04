import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../theme/garage_theme.dart';
import '../theme/garage_tokens.dart';
import '../errors/app_failure.dart';

/// How long a write may take before the app stops waiting on it. Long enough
/// for a bad connection at a petrol station, short enough that the person is
/// told, rather than left with a spinner and no way out.
const writeTimeout = Duration(seconds: 20);

/// A repository write with a deadline; the timeout surfaces as a failure of
/// its own, whose message says the save may still have landed.
Future<T> writeWithTimeout<T>(Future<T> write) => write.timeout(writeTimeout);

/// An insert of an entry that carries its own id (see `newEntryId`).
///
/// A conflict on such an insert means the previous attempt landed after the
/// sheet stopped waiting for it: the entry is there, once, which is what
/// the person wanted. Anything else is rethrown.
Future<void> writeNew(Future<void> Function() insert) async {
  try {
    await writeWithTimeout(insert());
  } on AppFailure catch (failure) {
    if (failure.kind != AppFailureKind.conflict) {
      rethrow;
    }
  }
}

/// After a few seconds of a save still running, a line under the button:
/// a spinner alone is "it is saving" for five seconds and "it is broken"
/// after ten.
class StillSavingNote extends StatefulWidget {
  const StillSavingNote({required this.busy, super.key});

  final bool busy;

  /// How long a spinner is allowed to speak for itself.
  static const patience = Duration(seconds: 5);

  @override
  State<StillSavingNote> createState() => _StillSavingNoteState();
}

class _StillSavingNoteState extends State<StillSavingNote> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(StillSavingNote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) {
      _watch();
    }
  }

  void _watch() {
    _timer?.cancel();
    _timer = null;
    if (!widget.busy) {
      if (_slow) {
        setState(() => _slow = false);
      }
      return;
    }
    _timer = Timer(StillSavingNote.patience, () {
      if (mounted) {
        setState(() => _slow = true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_slow) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: GarageTokens.space2),
      child: Text(
        AppLocalizations.of(context)!.saveStillSaving,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.tokens.muted),
      ),
    );
  }
}
