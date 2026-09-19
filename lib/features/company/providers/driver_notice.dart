import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_log.dart';

const _key = 'company.driver_notice.seen';

/// Whether this device has shown the driver what their administrator sees.
///
/// On the device rather than on the account: the sentence is owed the first
/// time "My cars" opens on a phone, and a phone that was reset owes it again.
/// The same bargain the transfer notices make.
class DriverNoticeSeen extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (error) {
      // The card treats a store that cannot answer as owing the notice, and
      // that guess must leave a trace: a value under the key that is not a
      // bool is a device this app did not write, which is worth knowing.
      reportFailure(AppFailure.from(error));
      rethrow;
    }
  }

  /// The driver has read it; this device does not show it again.
  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = const AsyncValue.data(true);
  }
}

final driverNoticeSeenProvider = AsyncNotifierProvider<DriverNoticeSeen, bool>(
  DriverNoticeSeen.new,
);
