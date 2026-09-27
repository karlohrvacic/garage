import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/vehicle.dart';
import '../../../domain/entries/quick_entry_target.dart';
import '../providers/vehicle_providers.dart';
import '../widgets/vehicle_picker.dart';

/// Where the Android launcher's shortcuts and home-screen widgets land: one
/// route for a fill-up, one for an expense, each handing this its own sheet.
///
/// Not a screen anybody looks at: it resolves which car the entry belongs
/// to, opens [openSheet] over itself, and then replaces itself with the
/// dashboard — so dismissing the sheet leaves the person somewhere they can
/// use rather than on a blank route with an empty back stack.
///
/// The signed-out and no-garage cases never reach here at all; `garageRedirect`
/// bounces them to sign-in and onboarding like any other screen. What is left
/// for this widget is the third empty case, a garage with no car, and the
/// answer to that is the dashboard too: its empty state is the screen that
/// explains how to add one.
class QuickEntryScreen extends ConsumerStatefulWidget {
  const QuickEntryScreen({super.key, required this.openSheet});

  /// Opens the entry sheet for one car and completes when it closes.
  final Future<Object?> Function(BuildContext context, String vehicleId)
  openSheet;

  @override
  ConsumerState<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends ConsumerState<QuickEntryScreen> {
  /// Whether the garage has already been turned into a destination. The whole
  /// widget is a one-shot, and a rebuild must not open a second sheet.
  bool _acted = false;

  Future<void> _open(List<Vehicle> vehicles) async {
    switch (QuickEntryTarget.forGarage(vehicles)) {
      case NoVehicleToLog():
        break;
      case LogThisVehicle(:final vehicleId):
        await widget.openSheet(context, vehicleId);
      case AskWhichVehicle(vehicles: final choices):
        final picked = await showVehiclePicker(context, choices);
        if (picked != null && mounted) {
          await widget.openSheet(context, picked);
        }
    }

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched rather than read. Every provider auto-disposes in Riverpod 3, so
    // a bare `ref.read(...future)` from a callback tears the fetch down while
    // it is still in flight and the await never returns — which here would
    // mean a shortcut that opens a blank screen and stays there.
    final garage = ref.watch(allVehiclesProvider);

    // A failed load is treated as an empty garage rather than given a failure
    // screen of its own: an offline cold start is the likely error here, and
    // the dashboard this falls back to already knows how to say the garage
    // could not be loaded, and how to retry.
    //
    // Asked by `hasValue`/`hasError` and not by matching `AsyncData` and
    // `AsyncError`: a Riverpod 3 provider whose first load throws settles as
    // an `AsyncLoading` *carrying* the error, so matching on the class alone
    // leaves this route waiting forever on a state that will never arrive.
    final List<Vehicle>? vehicles;
    if (garage.hasValue) {
      vehicles = garage.requireValue;
    } else if (garage.hasError) {
      vehicles = const [];
    } else {
      vehicles = null;
    }

    if (!_acted && vehicles != null) {
      final resolved = vehicles;
      _acted = true;
      // A route cannot push a modal while it is still being built.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(resolved));
    }

    // Deliberately empty, and deliberately not a spinner. This is visible for
    // the frame or two the garage takes to load and is behind a modal barrier
    // after that, so a spinner would be a flash of movement nobody reads — and
    // an indefinite animation here means `pumpAndSettle` never returns for any
    // test that touches this route. The Scaffold is what keeps the frame the
    // app's own background colour rather than white in a dark theme.
    return const Scaffold(body: SizedBox.expand());
  }
}
