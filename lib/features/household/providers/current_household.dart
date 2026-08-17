import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/household.dart';

const _selectedHouseholdKey = 'selected_household_id';

/// Which of the user's households the app is currently showing.
///
/// Stored on the device rather than on the account: two people share a
/// household, and which one *this phone* was last looking at is a property of
/// the phone, not of the person. It also means switching on a laptop does not
/// yank the phone in someone's pocket to a different garage.
final selectedHouseholdIdProvider =
    NotifierProvider<SelectedHouseholdId, String?>(SelectedHouseholdId.new);

class SelectedHouseholdId extends Notifier<String?> {
  /// Completes once the stored choice has been read back. Nothing in the app
  /// awaits it — providers rebuild when it lands — but a test needs a point to
  /// wait for that is not a guessed number of event-loop turns.
  late Future<void> loaded;

  /// Whether this session has made a choice of its own. The read from storage
  /// is in flight while the app is already usable, so somebody who switches
  /// garages in that window would otherwise be yanked back by a value that was
  /// stale before it arrived.
  bool _chosen = false;

  @override
  String? build() {
    loaded = _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_selectedHouseholdKey);
    if (_chosen) {
      return;
    }
    state = stored;
  }

  Future<void> select(String? householdId) async {
    _chosen = true;
    state = householdId;
    final prefs = await SharedPreferences.getInstance();
    if (householdId == null) {
      await prefs.remove(_selectedHouseholdKey);
    } else {
      await prefs.setString(_selectedHouseholdKey, householdId);
    }
  }
}

/// Picks the household to show out of the ones the user belongs to.
///
/// Falls back to the first when the stored choice is not among them — which
/// happens after leaving a household, after being removed from one, and on a
/// device that has never chosen. Falling back rather than showing nothing
/// matters: a stale id must not be able to make the app look like the user has
/// no garage at all, which would route them back through onboarding.
Household? chooseHousehold(List<Household> households, String? selectedId) {
  if (households.isEmpty) {
    return null;
  }
  for (final household in households) {
    if (household.id == selectedId) {
      return household;
    }
  }
  return households.first;
}
