import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/company/missing_receipts.dart';
import 'package:garage/domain/company/money_entry.dart';

MoneyEntry entry(
  String id,
  DateTime on, {
  String vehicleId = 'v1',
  double amount = 10,
}) {
  return MoneyEntry(
    kind: MoneyEntryKind.cost,
    id: id,
    vehicleId: vehicleId,
    date: on,
    amount: amount,
  );
}

void main() {
  test('the month\'s entries with no receipt, oldest first', () {
    final missing = MissingReceipts.inMonth(
      entries: [
        entry('late', DateTime.utc(2026, 9, 20)),
        entry('early', DateTime.utc(2026, 9, 2)),
        entry('has-one', DateTime.utc(2026, 9, 10)),
        entry('august', DateTime.utc(2026, 8, 31)),
      ],
      entryIdsWithAttachments: {'has-one'},
      month: DateTime.utc(2026, 9),
    );

    expect(missing.map((it) => it.id), ['early', 'late']);
  });

  test('a month with nothing in it is empty, not an error', () {
    expect(
      MissingReceipts.inMonth(
        entries: [entry('august', DateTime.utc(2026, 8, 31))],
        entryIdsWithAttachments: const {},
        month: DateTime.utc(2026, 9),
      ),
      isEmpty,
    );
  });

  test('an entry for nothing still wants its receipt', () {
    // A fill-up with no total never becomes a money entry, but a cost of
    // zero is a row somebody typed, and the accountant asks about it too.
    expect(
      MissingReceipts.inMonth(
        entries: [entry('free', DateTime.utc(2026, 9, 2), amount: 0)],
        entryIdsWithAttachments: const {},
        month: DateTime.utc(2026, 9),
      ).map((it) => it.id),
      ['free'],
    );
  });
}
