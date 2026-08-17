import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/app_info.dart';
import '../../../core/errors/failure_log.dart';
import '../../../core/theme/garage_tokens.dart';

/// Hands text to the system share sheet. A provider so a test can read what
/// was shared instead of driving a platform dialog.
typedef DiagnosticsShare = Future<void> Function(String text);

final diagnosticsShareProvider = Provider<DiagnosticsShare>((ref) {
  return (text) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: 'Garage'));
  };
});

/// What the app knows about its own failures, where a user can reach it.
///
/// The failures were always recorded, and until this screen the only way to
/// read them was `adb logcat -s garage.failure` on a wired device — which is
/// to say, not at all for anyone in a closed test. "It said something went
/// wrong" was where every report stopped, and the cause the app had already
/// worked out was thrown away a moment later.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Newest first: a report is written about the thing that just happened,
    // and the log is stored oldest-first because that is the order it grows in.
    final failures = recordedFailures.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.diagnosticsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: l10n.diagnosticsShare,
            onPressed: failures.isEmpty ? null : _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.diagnosticsClear,
            onPressed: failures.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: failures.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(GarageTokens.space6),
                child: Text(
                  l10n.diagnosticsEmpty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(GarageTokens.space4),
              itemCount: failures.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: GarageTokens.space3),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // An app that promises no tracking owes an explanation for
                  // why it is keeping a list of errors at all.
                  return Padding(
                    padding: const EdgeInsets.only(bottom: GarageTokens.space2),
                    child: Text(
                      l10n.diagnosticsExplain,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return _Failure(line: failures[index - 1]);
              },
            ),
    );
  }

  Future<void> _share() async {
    await ref.read(diagnosticsShareProvider)(_report());
  }

  Future<void> _clear() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await clearRecordedFailures();
    if (!mounted) {
      return;
    }
    setState(() {});
    messenger.showSnackBar(SnackBar(content: Text(l10n.diagnosticsCleared)));
  }

  /// The text that ends up in a bug report. The version goes first because a
  /// log without a build is a log nobody can act on three releases later.
  String _report() {
    return [
      'Garage ${AppInfo.version} (${AppInfo.build})',
      ...recordedFailures,
    ].join('\n');
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GarageTokens.space3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(GarageTokens.radiusMd),
      ),
      // Selectable: on the web there is no share sheet worth the name, and
      // copying the one line that matters beats sharing all twenty.
      child: SelectableText(line, style: theme.textTheme.bodySmall),
    );
  }
}
