import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/guest_pass.dart';
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

final guestPassControllerProvider =
    AsyncNotifierProvider<GuestPassController, void>(GuestPassController.new);

class GuestPassController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Returns the new code, or null when the write failed.
  Future<String?> lend({
    required String vehicleId,
    required int validDays,
    String? label,
    DateTime? startsAt,
    bool canLogFuel = true,
    bool canLogTrips = true,
    bool canLogCosts = true,
    bool canViewHistory = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final code = await ref
          .read(guestPassRepositoryProvider)
          .create(
            vehicleId: vehicleId,
            validDays: validDays,
            label: label,
            startsAt: startsAt,
            canLogFuel: canLogFuel,
            canLogTrips: canLogTrips,
            canLogCosts: canLogCosts,
            canViewHistory: canViewHistory,
          );
      ref.invalidate(vehicleGuestPassesProvider(vehicleId));
      state = const AsyncValue.data(null);
      return code;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return null;
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
