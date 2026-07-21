import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/household.dart';
import '../data/household_repository.dart';
import '../data/supabase_household_repository.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return SupabaseHouseholdRepository(ref.watch(supabaseClientProvider));
});

/// The household the app is currently showing, or null when the signed-in user
/// has not created or joined one yet. v1 assumes one household per user; the
/// schema permits more, so this takes the first.
final currentHouseholdProvider = FutureProvider<Household?>((ref) async {
  final households = await ref.watch(householdRepositoryProvider).myHouseholds();
  return households.isEmpty ? null : households.first;
});

final householdControllerProvider =
    AsyncNotifierProvider<HouseholdController, void>(HouseholdController.new);

class HouseholdController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createHousehold(String name) async {
    await _run(
      () => ref.read(householdRepositoryProvider).create(name.trim()),
    );
  }

  Future<void> joinHousehold(String code) async {
    await _run(
      () => ref
          .read(householdRepositoryProvider)
          .joinWithCode(code.trim().toUpperCase()),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    try {
      await action();
      ref.invalidate(currentHouseholdProvider);
      await ref.read(currentHouseholdProvider.future);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
    }
  }
}
