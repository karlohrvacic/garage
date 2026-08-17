import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/household.dart';
import '../data/household_repository.dart';
import 'current_household.dart';
import '../data/supabase_household_repository.dart';

export 'current_household.dart'
    show chooseHousehold, selectedHouseholdIdProvider;

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return SupabaseHouseholdRepository(ref.watch(supabaseClientProvider));
});

/// Every household the signed-in user belongs to. Empty before they have
/// created or joined one, and empty when signed out.
///
/// Depends on [currentUserProvider] so it refetches on every sign-in and
/// sign-out. Without that, this provider — kept alive for the app's lifetime by
/// the router — would cache one user's households across an account switch on a
/// shared device, routing the next user past onboarding and showing them the
/// previous user's garage.
final myHouseholdsProvider = FutureProvider<List<Household>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const [];
  }
  return ref.watch(householdRepositoryProvider).myHouseholds();
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

  /// The household a create or join just produced becomes the current one.
  /// Making somebody switch to the garage they have this second created would
  /// be a step with one possible answer.
  Future<void> _run(Future<String> Function() action) async {
    state = const AsyncValue.loading();
    try {
      final householdId = await action();
      await ref.read(selectedHouseholdIdProvider.notifier).select(householdId);
      ref
        ..invalidate(myHouseholdsProvider)
        ..invalidate(currentHouseholdProvider);
      await ref.read(currentHouseholdProvider.future);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
    }
  }
}
