import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/garage_tokens.dart';
import '../../../domain/auth/email_link.dart';
import '../providers/auth_providers.dart';

/// Where an emailed confirmation or password-reset link lands.
///
/// This exists so the link in the email can point at *this* app's host rather
/// than at Supabase's. An Android app link is matched against the URL the
/// person taps, and a link that goes to `supabase.co` and redirects here is
/// never offered to the app — the browser has already taken it. Carrying the
/// token hash to a path this app claims is what lets a tap in a mail client
/// open the installed app, while the same URL still works in a browser for
/// anyone who has not installed it.
///
/// Both kinds land here and both end in the app: `verifyOTP` signs the user in
/// either way, so the router's gates decide where. A recovery additionally
/// raises `passwordRecovery`, which `main.dart` answers with the new-password
/// prompt on the root navigator — it appears over whatever the gates landed on,
/// which is what the old redirect-through-Supabase flow did too.
class ConfirmEmailScreen extends ConsumerStatefulWidget {
  const ConfirmEmailScreen({required this.link, super.key});

  /// Null when the URL carried nothing usable: typed by hand, a stale
  /// bookmark, or a template whose variables did not interpolate.
  final EmailLink? link;

  @override
  ConsumerState<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  late Future<void> _confirming;

  @override
  void initState() {
    super.initState();
    // Started here rather than in build: a rebuild must not spend the token a
    // second time, and the second spend of a single-use hash always fails.
    final link = widget.link;
    _confirming = link == null
        ? Future.error(const AppFailure(kind: AppFailureKind.unknown))
        : ref.read(authRepositoryProvider).confirmEmailLink(link);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space6),
          child: FutureBuilder<void>(
            future: _confirming,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: GarageTokens.space4),
                    Text(l10n.authConfirmChecking),
                  ],
                );
              }

              if (!snapshot.hasError) {
                // Signed in either way, so the router's gates know where to go
                // better than this screen does. That includes a recovery: the
                // new-password prompt `main.dart` raises lives on the root
                // navigator and appears over wherever the gates land, which is
                // what the old redirect-to-the-dashboard flow did too. Staying
                // here to host the dialog would strand the user on this screen
                // the moment they answered it.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.go('/');
                  }
                });
                return const SizedBox.shrink();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.link_off,
                    size: 40,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: GarageTokens.space4),
                  Text(
                    l10n.authConfirmFailedTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: GarageTokens.space2),
                  Text(
                    widget.link == null
                        ? l10n.authConfirmNoLink
                        : l10n.authConfirmFailedBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: GarageTokens.space5),
                  FilledButton(
                    key: const Key('confirm-to-sign-in'),
                    onPressed: () => context.go('/sign-in'),
                    child: Text(l10n.authConfirmSignIn),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
