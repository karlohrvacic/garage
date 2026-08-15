import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/api/api_access.dart';
import '../../household/providers/household_providers.dart';
import '../data/api_access_repository.dart';
import '../data/supabase_api_access_repository.dart';

final apiAccessRepositoryProvider = Provider<ApiAccessRepository>((ref) {
  return SupabaseApiAccessRepository(ref.watch(supabaseClientProvider));
});

/// The household's API keys, newest first. Empty before a household exists.
final apiKeysProvider = FutureProvider<List<ApiKeyRecord>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) {
    return const [];
  }
  return ref.watch(apiAccessRepositoryProvider).keys(household.id);
});

/// The household's webhooks, newest first.
final webhooksProvider = FutureProvider<List<Webhook>>((ref) async {
  final household = await ref.watch(currentHouseholdProvider.future);
  if (household == null) {
    return const [];
  }
  return ref.watch(apiAccessRepositoryProvider).webhooks(household.id);
});
