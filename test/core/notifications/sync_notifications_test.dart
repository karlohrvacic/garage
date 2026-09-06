import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/notifications/notification_providers.dart';
import 'package:garage/core/notifications/notification_service.dart';
import 'package:garage/features/dashboard/providers/dashboard_providers.dart';
import 'package:garage/features/maintenance/providers/maintenance_providers.dart';
import 'package:garage/features/vehicles/providers/vehicle_providers.dart';
import 'package:garage/l10n/app_localizations_en.dart';

/// Holds the permission prompt open, which is what the system dialog does on
/// a first run.
class SlowPermission extends NotificationService {
  final permission = Completer<bool>();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() => permission.future;

  @override
  Future<void> cancelAll() async {}
}

void main() {
  testWidgets('a sync survives the screen going away mid-prompt', (
    tester,
  ) async {
    // Seen on a device: the permission dialog on a first run holds this open
    // long enough for the dashboard to be rebuilt away, and the reads that
    // followed the await threw "Using ref when a widget has been unmounted".
    // Two unhandled exceptions at startup, and no notifications scheduled.
    final service = SlowPermission();
    late Future<void> sync;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          allVehiclesProvider.overrideWith((ref) async => const []),
          householdProjectionsProvider.overrideWith((ref) async => const []),
          bundlesProvider.overrideWith((ref) async => const []),
          pushRemindersActiveProvider.overrideWithValue(false),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            sync = syncNotifications(ref, AppLocalizationsEn());
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // The screen is replaced while the prompt is still up.
    await tester.pumpWidget(const SizedBox.shrink());
    service.permission.complete(true);

    await expectLater(sync, completes);
  });
}
