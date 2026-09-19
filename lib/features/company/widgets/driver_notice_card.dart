import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';

import '../../../core/theme/garage_tokens.dart';
import '../providers/driver_notice.dart';

/// What the privacy policy promises a driver is told in-app, the first time
/// they open "My cars": who sees what they log.
class DriverNoticeCard extends ConsumerWidget {
  const DriverNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hidden until the device has answered, so a phone that has seen it
    // never flashes it for a frame. A device that cannot answer still owes
    // the sentence: it is a promise, and a guess would break it in silence.
    // The provider has recorded why by the time the error reaches here.
    final owed = switch (ref.watch(driverNoticeSeenProvider)) {
      AsyncData(:final value) => !value,
      AsyncError() => true,
      _ => false,
    };
    if (!owed) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: GarageTokens.space2),
      child: Card(
        key: const Key('driver-notice'),
        child: Padding(
          padding: const EdgeInsets.all(GarageTokens.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.companyDriverNoticeTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: GarageTokens.space2),
              Text(l10n.companyDriverNoticeBody),
              const SizedBox(height: GarageTokens.space2),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  key: const Key('driver-notice-dismiss'),
                  onPressed: () =>
                      ref.read(driverNoticeSeenProvider.notifier).markSeen(),
                  child: Text(l10n.companyDriverNoticeDismiss),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
