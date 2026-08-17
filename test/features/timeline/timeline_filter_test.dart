import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/timeline/providers/timeline_providers.dart';
import 'package:garage/features/timeline/timeline_filter.dart';

TimelineItem item({
  required TimelineKind kind,
  required String text,
  DateTime? date,
}) {
  return TimelineItem(
    kind: kind,
    entryId: text,
    date: date ?? DateTime.utc(2026, 6, 1),
    vehicleId: text,
    amount: null,
    createdBy: 'u1',
  );
}

/// The row's rendered text, which is what a person is searching against — not
/// the record's fields.
String textOf(TimelineItem entry) => entry.vehicleId;

final _log = [
  item(kind: TimelineKind.fuel, text: 'Fill-up Golf Karlo INA'),
  item(kind: TimelineKind.service, text: 'Oil change Golf Ana'),
  item(kind: TimelineKind.cost, text: 'Insurance Clio Karlo'),
  item(kind: TimelineKind.trip, text: 'Zagreb Split Clio'),
];

void main() {
  test('no query and no kinds is everything', () {
    expect(
      filterTimeline(_log, searchableText: textOf),
      hasLength(_log.length),
    );
  });

  test('a term matches anywhere in the row', () {
    final found = filterTimeline(_log, query: 'clio', searchableText: textOf);

    expect(found, hasLength(2));
  });

  test('every term has to match, in any order', () {
    // "golf oil" and "oil golf" are the same search. Making the user guess
    // which word the app wants first is the kind of thing that trains people
    // not to use search at all.
    for (final query in ['golf oil', 'oil golf']) {
      final found = filterTimeline(_log, query: query, searchableText: textOf);

      expect(found, hasLength(1), reason: '"$query" should find the service');
      expect(found.single.kind, TimelineKind.service);
    }
  });

  test('a term nothing has matches nothing', () {
    expect(
      filterTimeline(_log, query: 'motorcycle', searchableText: textOf),
      isEmpty,
    );
  });

  test('case and extra spaces do not matter', () {
    expect(
      filterTimeline(_log, query: '  KARLO   ina ', searchableText: textOf),
      hasLength(1),
    );
  });

  test('an empty set of kinds means every kind', () {
    // Not "none". The alternative leaves no state that means "no filter", and
    // makes the chips read as six things to switch off.
    expect(
      filterTimeline(_log, kinds: const {}, searchableText: textOf),
      hasLength(_log.length),
    );
  });

  test('a chosen kind narrows to it', () {
    final found = filterTimeline(
      _log,
      kinds: const {TimelineKind.cost},
      searchableText: textOf,
    );

    expect(found, hasLength(1));
    expect(found.single.kind, TimelineKind.cost);
  });

  test('several kinds are a union, not an intersection', () {
    final found = filterTimeline(
      _log,
      kinds: const {TimelineKind.cost, TimelineKind.trip},
      searchableText: textOf,
    );

    expect(found, hasLength(2));
  });

  test('a kind and a term apply together', () {
    final found = filterTimeline(
      _log,
      query: 'clio',
      kinds: const {TimelineKind.trip},
      searchableText: textOf,
    );

    expect(found, hasLength(1));
    expect(found.single.kind, TimelineKind.trip);
  });

  test('the order history was in is the order it stays in', () {
    final found = filterTimeline(_log, query: 'karlo', searchableText: textOf);

    expect(found.map(textOf), [
      'Fill-up Golf Karlo INA',
      'Insurance Clio Karlo',
    ], reason: 'a filter must not reorder a log sorted by time');
  });
}
