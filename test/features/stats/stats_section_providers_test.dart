import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/stats/stats_section.dart';
import 'package:garage/features/stats/providers/stats_section_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer makeContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every section is shown until one is turned off', () {
    final container = makeContainer();
    final sections = container.read(hiddenStatsSectionsProvider.notifier);

    for (final section in StatsSection.values) {
      expect(sections.isVisible(section), isTrue);
    }
  });

  test('hiding one section leaves the rest alone', () async {
    final container = makeContainer();
    final sections = container.read(hiddenStatsSectionsProvider.notifier);

    await sections.setVisible(StatsSection.spendByStation, false);

    expect(sections.isVisible(StatsSection.spendByStation), isFalse);
    expect(sections.isVisible(StatsSection.spendByKind), isTrue);
  });

  test('a hidden section can be shown again', () async {
    final container = makeContainer();
    final sections = container.read(hiddenStatsSectionsProvider.notifier);

    await sections.setVisible(StatsSection.records, false);
    await sections.setVisible(StatsSection.records, true);

    expect(sections.isVisible(StatsSection.records), isTrue);
  });

  test('the choice survives a restart', () async {
    final first = makeContainer();
    await first
        .read(hiddenStatsSectionsProvider.notifier)
        .setVisible(StatsSection.monthlySpend, false);

    final second = makeContainer();
    await second.read(hiddenStatsSectionsProvider.notifier).loaded;

    expect(
      second.read(hiddenStatsSectionsProvider),
      contains(StatsSection.monthlySpend),
    );
  });

  test('showing everything clears the lot', () async {
    final container = makeContainer();
    final sections = container.read(hiddenStatsSectionsProvider.notifier);
    await sections.setVisible(StatsSection.records, false);
    await sections.setVisible(StatsSection.categories, false);

    await sections.showAll();

    expect(container.read(hiddenStatsSectionsProvider), isEmpty);
  });

  test(
    'a stored key that no longer exists is ignored, not crashed on',
    () async {
      // A section dropped in a later release leaves its key in everybody's
      // preferences forever.
      SharedPreferences.setMockInitialValues({
        'stats_hidden_sections': ['records', 'a_section_that_was_removed'],
      });
      final container = makeContainer();
      await container.read(hiddenStatsSectionsProvider.notifier).loaded;

      expect(container.read(hiddenStatsSectionsProvider), {
        StatsSection.records,
      });
    },
  );
}
