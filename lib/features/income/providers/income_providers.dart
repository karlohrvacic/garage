import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/entities/income_entry.dart';
import '../data/income_repository.dart';
import '../data/supabase_income_repository.dart';

final incomeRepositoryProvider = Provider<IncomeRepository>((ref) {
  return SupabaseIncomeRepository(ref.watch(supabaseClientProvider));
});

/// A vehicle's income entries, newest first.
final incomeEntriesProvider = FutureProvider.family<List<IncomeEntry>, String>((
  ref,
  vehicleId,
) async {
  return ref.watch(incomeRepositoryProvider).forVehicle(vehicleId);
});
