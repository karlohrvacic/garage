import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/guest_pass.dart';
import '../../../domain/entities/service_entry.dart';
import '../data/guest_pass_repository.dart';
import '../../household/providers/household_providers.dart';
import '../data/supabase_guest_pass_repository.dart';

final guestPassRepositoryProvider = Provider<GuestPassRepository>((ref) {
  return SupabaseGuestPassRepository(ref.watch(supabaseClientProvider));
});

/// Every pass ever minted for this vehicle — the owner's view.
final vehicleGuestPassesProvider =
    FutureProvider.family<List<GuestPass>, String>((ref, vehicleId) async {
      return ref.watch(guestPassRepositoryProvider).forVehicle(vehicleId);
    });

/// The passes the signed-in user holds — the borrower's view.
final myGuestPassesProvider = FutureProvider<List<GuestPass>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return const [];
  }
  return ref.watch(guestPassRepositoryProvider).mine();
});

/// What was done to a vehicle, as the signed-in user is allowed to see it.
///
/// Costs arrive null for a borrower whose pass does not carry prices, and the
/// masking is the database's, not this provider's.
final lentServiceHistoryProvider =
    FutureProvider.family<List<ServiceEntry>, String>((ref, vehicleId) async {
      return ref.watch(guestPassRepositoryProvider).serviceHistory(vehicleId);
    });

/// The live pass this user holds on a vehicle, if any. Null for the owner.
final guestPassForVehicleProvider = Provider.family<GuestPass?, String>((
  ref,
  vehicleId,
) {
  final passes = switch (ref.watch(myGuestPassesProvider)) {
    AsyncData(:final value) => value,
    _ => const <GuestPass>[],
  };
  final now = DateTime.now().toUtc();
  for (final pass in passes) {
    if (pass.vehicleId == vehicleId &&
        pass.stateAt(now) == GuestPassState.live) {
      return pass;
    }
  }
  return null;
});

final guestPassControllerProvider =
    AsyncNotifierProvider<GuestPassController, void>(GuestPassController.new);

class GuestPassController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the new code, or null when the write failed.
  Future<String?> lend({
    required String vehicleId,
    required DateTime endsAt,
    DateTime? startsAt,
    String? label,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
    bool canViewPrices = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final code = await ref
          .read(guestPassRepositoryProvider)
          .create(
            vehicleId: vehicleId,
            endsAt: endsAt,
            startsAt: startsAt,
            label: label,
            canLogFuel: canLogFuel,
            canLogTrips: canLogTrips,
            canLogCosts: canLogCosts,
            canViewHistory: canViewHistory,
            canViewPrices: canViewPrices,
          );
      ref.invalidate(vehicleGuestPassesProvider(vehicleId));
      state = const AsyncValue.data(null);
      return code;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return null;
    }
  }

  /// Moves an existing pass's end date. "He rang and needs it one more day"
  /// used to mean revoking and minting a second code for the same person.
  Future<bool> extend(GuestPass pass, DateTime endsAt) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(guestPassRepositoryProvider).extend(pass.id, endsAt);
      ref
        ..invalidate(vehicleGuestPassesProvider(pass.vehicleId))
        ..invalidate(myGuestPassesProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }

  Future<bool> revoke(GuestPass pass) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(guestPassRepositoryProvider).revoke(pass.id);
      ref.invalidate(vehicleGuestPassesProvider(pass.vehicleId));
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }

  /// Claims a pass. Returns the vehicle it opened, or null when it was
  /// refused — an unknown code, one already in somebody else's hands, or one
  /// for a car the caller is already in the garage of.
  Future<String?> redeem(String code) async {
    state = const AsyncValue.loading();
    try {
      final vehicleId = await ref
          .read(guestPassRepositoryProvider)
          .redeem(code);
      // The borrowed car appears in the app's own fetch, which is scoped by
      // policy rather than by anything the client filters.
      ref
        ..invalidate(garageBootstrapProvider)
        ..invalidate(myGuestPassesProvider);
      state = const AsyncValue.data(null);
      return vehicleId;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return null;
    }
  }
}
