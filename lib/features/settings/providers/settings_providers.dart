import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../domain/entities/household.dart';
import '../../household/providers/household_providers.dart';

const _localeKey = 'locale_override';

/// The device language override. Null means follow the system locale. Persisted
/// so the choice survives a restart. Wired into [MaterialApp.router]'s `locale`.
final localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code != null && code.isNotEmpty) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, void>(SettingsController.new);

/// Persists household-level settings (units, currency, bundling window) and
/// refreshes the household so every unit-aware screen re-renders at once.
class SettingsController extends AsyncNotifier<void> {
  Future<void> _queue = Future.value();

  @override
  Future<void> build() async {}

  /// Saves one change as a patch on the freshest household, with saves
  /// serialized. Two quick edits used to race: the second was built from the
  /// household as rendered before the first save landed, silently reverting it.
  Future<void> save(Household Function(Household) patch) {
    final task = _queue.then((_) => _save(patch));
    _queue = task.then((_) {}, onError: (_) {});
    return task;
  }

  Future<void> _save(Household Function(Household) patch) async {
    state = const AsyncValue.loading();
    try {
      final base = await ref.read(currentHouseholdProvider.future);
      if (base == null) {
        state = const AsyncValue.data(null);
        return;
      }
      await ref.read(householdRepositoryProvider).updateSettings(patch(base));
      ref.invalidate(currentHouseholdProvider);
      await ref.read(currentHouseholdProvider.future);
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(AppFailure.from(error), stackTrace);
    }
  }
}
