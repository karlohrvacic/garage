import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/app_info.dart';
import '../../../core/links/url_opener.dart';
import '../../../core/theme/garage_theme.dart';
import '../../../core/theme/garage_tokens.dart';

/// The promises the app makes, written down where a user can hold it to them.
///
/// This is the no-lock-in principle made visible: an app that can be left
/// easily has to say so somewhere, and the CSV export is what makes the claim
/// true rather than marketing.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(GarageTokens.space4),
        children: [
          Text('Garage', style: theme.textTheme.headlineSmall),
          const SizedBox(height: GarageTokens.space1),
          Text(
            l10n.aboutVersion(AppInfo.version, AppInfo.build),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: GarageTokens.space4),
          Text(l10n.aboutTagline, style: theme.textTheme.bodyMedium),
          const SizedBox(height: GarageTokens.space6),
          Padding(
            padding: const EdgeInsets.only(bottom: GarageTokens.space2),
            child: Text(
              l10n.aboutPromises.toUpperCase(),
              style: GarageTheme.eyebrow(context),
            ),
          ),
          _Promise(icon: Icons.block_outlined, text: l10n.aboutPromiseFree),
          _Promise(
            icon: Icons.file_download_outlined,
            text: l10n.aboutPromiseData,
          ),
          _Promise(icon: Icons.logout_outlined, text: l10n.aboutPromiseLeave),
          _Promise(
            icon: Icons.visibility_off_outlined,
            text: l10n.aboutPromisePrivacy,
          ),
          const Divider(height: GarageTokens.space8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.aboutPrivacyPolicy),
            onTap: () => ref.read(urlOpenerProvider)(GarageLinks.privacyPolicy),
          ),
          // Not a courtesy link. The AGPL obliges an instance people reach
          // over a network to offer them its source, and garage.hrva.cc is
          // one, so this row is how the licence is kept rather than merely
          // declared.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.code_outlined),
            title: Text(l10n.aboutSourceCode),
            subtitle: Text(l10n.aboutSourceCodeHint),
            onTap: () => ref.read(urlOpenerProvider)(GarageLinks.sourceCode),
          ),
          // The failure log was always kept and was reachable only over
          // `adb logcat` on a wired device, which no tester in the field has.
          // This is the difference between "it said something went wrong" and
          // a report somebody can act on.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(l10n.aboutDiagnostics),
            subtitle: Text(l10n.aboutDiagnosticsHint),
            onTap: () => context.push('/diagnostics'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.balance_outlined),
            title: Text(l10n.aboutLicences),
            subtitle: Text(l10n.aboutLicencesHint),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Garage',
              applicationVersion: l10n.aboutVersion(
                AppInfo.version,
                AppInfo.build,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GarageTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: GarageTokens.space3),
          // Expanded, not a fixed width: these sentences are long and the
          // Croatian ones are longer still.
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
