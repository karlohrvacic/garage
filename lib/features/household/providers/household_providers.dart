import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/household.dart';
import '../../vehicles/providers/vehicle_providers.dart';
import '../data/garage_bootstrap.dart';
import '../data/garage_bootstrap_cache.dart';
import 'member_providers.dart';
import '../data/merge_action.dart';
import '../data/household_repository.dart';
import 'current_household.dart';
import '../data/supabase_garage_bootstrap_repository.dart';
import '../data/supabase_household_repository.dart';

export 'current_household.dart'
    show chooseHousehold, selectedHouseholdIdProvider;

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return SupabaseHouseholdRepository(ref.watch(supabaseClientProvider));
});

/// Where the last garage this device saw is kept. Overridden in tests, which
/// must not reach for the device's preferences.
final garageBootstrapCacheProvider = Provider<GarageBootstrapCache>((ref) {
  return PrefsGarageBootstrapCache();
});

final garageBootstrapRepositoryProvider = Provider<GarageBootstrapRepository>((
  ref,
) {
  return SupabaseGarageBootstrapRepository(
    ref.watch(supabaseClientProvider),
    cache: ref.watch(garageBootstrapCacheProvider),
  );
});

/// The app's one startup fetch: every garage the user is in, and the vehicles
/// in each. Nothing else may fetch either on the way to a first frame.
///
/// **Invalidate this, not the providers derived from it.** They hold no
/// request of their own, so invalidating one of those rebuilds it against this
/// provider's cached value and quietly changes nothing —
/// `test/ci/garage_bootstrap_invalidation_test.dart` fails the build rather
/// than letting that reach anybody.
///
/// Depends on [currentUserIdProvider] so it refetches on every sign-in and
/// sign-out. Without that, this provider — kept alive for the app's lifetime by
/// the router — would cache one user's garages across an account switch on a
/// shared device, routing the next user past onboarding and showing them the
/// previous user's garage.
final garageBootstrapProvider =
    AsyncNotifierProvider<GarageBootstrapNotifier, GarageBootstrap>(
      GarageBootstrapNotifier.new,
    );

class GarageBootstrapNotifier extends AsyncNotifier<GarageBootstrap> {
  /// The garage this device saw last, drawn immediately, then corrected.
  ///
  /// A cold start used to wait on a round trip before it could show anything:
  /// engine, session, households and vehicles, *then* a dashboard. On a phone
  /// that has just woken up at a pump that is the whole app feeling slow, and
  /// the fill-up widget — the one entry point that exists to be fast — paid it
  /// every single time.
  ///
  /// So a cached garage is returned as data and the fetch runs behind it. The
  /// screen is drawn from something true a moment ago rather than from
  /// nothing, and the correction lands without anybody waiting for it.
  /// Which build a background refresh belongs to.
  ///
  /// `build` runs again on the same element whenever the signed-in user
  /// changes or something invalidates this — and the fetch from the *previous*
  /// build is still in flight. Landing it would put the account that just
  /// signed out back on screen, on a phone two people share. `ref.mounted`
  /// does not catch that: the element is still very much alive.
  int _generation = 0;

  @override
  Future<GarageBootstrap> build() async {
    final generation = ++_generation;
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) {
      return GarageBootstrap.empty;
    }
    final repository = ref.watch(garageBootstrapRepositoryProvider);
    final cached = await ref.watch(garageBootstrapCacheProvider).read(userId);
    if (cached == null) {
      return repository.load();
    }
    _refreshBehind(repository, generation);
    return cached;
  }

  void _refreshBehind(GarageBootstrapRepository repository, int generation) {
    unawaited(() async {
      try {
        final fresh = await repository.load();
        // Not just "is this notifier alive" but "is this still the question
        // being asked" — a newer build has newer data, and an older answer
        // arriving late is worse than none.
        if (ref.mounted && generation == _generation) {
          state = AsyncValue.data(fresh);
        }
      } catch (_) {
        // The cache is on the screen and it is not wrong enough to replace
        // with an error page. An offline cold start is the ordinary case
        // here, and a garage from a minute ago is what the user wants to see
        // while there is no signal — everything they might write is queued
        // anyway (`lib/core/sync/`).
      }
    }());
  }
}

/// Every household the signed-in user belongs to. Empty before they have
/// created or joined one, and empty when signed out.
final myHouseholdsProvider = FutureProvider<List<Household>>((ref) async {
  return (await ref.watch(garageBootstrapProvider.future)).households;
});

/// The household the app is currently showing, or null when the signed-in user
/// has not created or joined one yet.
final currentHouseholdProvider = FutureProvider<Household?>((ref) async {
  final households = await ref.watch(myHouseholdsProvider.future);
  return chooseHousehold(households, ref.watch(selectedHouseholdIdProvider));
});

final householdControllerProvider =
    AsyncNotifierProvider<HouseholdController, void>(HouseholdController.new);

class HouseholdController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createHousehold(String name) async {
    await _run(() => ref.read(householdRepositoryProvider).create(name.trim()));
  }

  Future<void> joinHousehold(String code) async {
    await _run(
      () => ref
          .read(householdRepositoryProvider)
          .joinWithCode(code.trim().toUpperCase()),
    );
  }

  /// Switches which household the app is showing. Everything downstream reads
  /// the current household, so invalidating it is what makes the whole app
  /// change garage rather than each screen having to know it happened.
  Future<void> switchTo(String householdId) async {
    await ref.read(selectedHouseholdIdProvider.notifier).select(householdId);
    ref.invalidate(currentHouseholdProvider);
    await ref.read(currentHouseholdProvider.future);
  }

  /// Promotes or demotes a member.
  ///
  /// The garage always keeps an admin: demoting the last one hands the role to
  /// the longest-standing other member, which the caller may want to say out
  /// loud, so the members list is refetched rather than patched locally.
  Future<bool> setRole({
    required String householdId,
    required String userId,
    required String role,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(householdRepositoryProvider)
          .setRole(householdId: householdId, userId: userId, role: role);
      ref.invalidate(membersProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      return false;
    }
  }

  /// Empties one garage into this one and deletes it.
  ///
  /// Everything is invalidated afterwards rather than surgically patched: a
  /// merge moves vehicles, members and history at once, and there is no part
  /// of the app that is still safely holding the old picture.
  Future<MergeOutcome?> mergeInto({
    required Household absorbed,
    required Household surviving,
  }) async {
    state = const AsyncValue.loading();
    try {
      final outcome = await mergeGarages(
        households: ref.read(householdRepositoryProvider),
        vehicles: ref.read(vehicleRepositoryProvider),
        photos: ref.read(vehiclePhotoRepositoryProvider),
        absorbed: absorbed,
        surviving: surviving,
      );
      await ref.read(selectedHouseholdIdProvider.notifier).select(surviving.id);
      ref
        ..invalidate(garageBootstrapProvider)
        ..invalidate(currentHouseholdProvider)
        ..invalidate(membersProvider);
      await ref.read(currentHouseholdProvider.future);
      state = const AsyncValue.data(null);
      return outcome;
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
      rethrow;
    }
  }

  /// The household a create or join just produced becomes the current one.
  /// Making somebody switch to the garage they have this second created would
  /// be a step with one possible answer.
  Future<void> _run(Future<String> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final householdId = await action();
      await ref.read(selectedHouseholdIdProvider.notifier).select(householdId);
      ref
        ..invalidate(garageBootstrapProvider)
        ..invalidate(currentHouseholdProvider);
      await ref.read(currentHouseholdProvider.future);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
    }
  }
}

/// What a merge would move, for the confirmation to name rather than ask a
/// bare "are you sure".
class MergePreview {
  const MergePreview({required this.vehicles, required this.people});

  final int vehicles;
  final int people;
}

final mergePreviewProvider = FutureProvider.family<MergePreview, String>((
  ref,
  householdId,
) async {
  final bootstrap = await ref.watch(garageBootstrapProvider.future);
  final members = await ref
      .watch(householdRepositoryProvider)
      .members(householdId);
  return MergePreview(
    vehicles: bootstrap.vehiclesFor(householdId).length,
    people: members.length,
  );
});
