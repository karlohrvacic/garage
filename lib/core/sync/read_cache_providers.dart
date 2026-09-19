import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_client_provider.dart';
import 'read_cache.dart';
import 'read_cache_store.dart';

/// Where a read's last good rows are kept. Overridden in tests, which must
/// not reach for the device's preferences.
final readCacheStoreProvider = Provider<ReadCacheStore>((ref) {
  return PrefsReadCacheStore();
});

final readCacheProvider = Provider<ReadCache>((ref) {
  return ReadCache(
    store: ref.watch(readCacheStoreProvider),
    userId: () => ref.read(currentUserIdProvider),
  );
});

/// Which reads are being shown from a copy, for the banner.
final staleReadsProvider = Provider<ValueListenable<StaleReads>>((ref) {
  return ref.watch(readCacheProvider).stale;
});
