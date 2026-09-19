import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/supabase/date_column.dart';
import 'package:garage/domain/company/assignment_resolution.dart';
import 'package:garage/domain/entities/vehicle_assignment.dart';

/// Who had a car on a day exists twice: `driver_on()` in SQL, which the push
/// run and the console ask, and [AssignmentResolution] here, which the
/// sheets, the exports and the reimbursements read. Neither can call the
/// other, so both answer to `test/fixtures/assignment_resolution.json` — the
/// arrangement `economy_spans.json` set for the economy rule. The RLS suite
/// runs the same cases through the function.
const _fixturePath = 'test/fixtures/assignment_resolution.json';

final Map<String, dynamic> _fixture =
    jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;

List<VehicleAssignment> get _assignments => [
  for (final row
      in (_fixture['assignments'] as List).cast<Map<String, dynamic>>())
    VehicleAssignment(
      id: row['id'] as String,
      vehicleId: row['vehicle_id'] as String,
      userId: row['user_id'] as String,
      fromDate: dateFromColumn(row['from_date'] as String),
      toDate: switch (row['to_date'] as String?) {
        null => null,
        final to => dateFromColumn(to),
      },
    ),
];

List<Map<String, dynamic>> get _cases =>
    (_fixture['cases'] as List).cast<Map<String, dynamic>>();

void main() {
  test('the fixture holds both outcomes', () {
    // Guards the guard: a file that only ever expected null would pass every
    // case below without checking a single window.
    expect(_cases.where((it) => it['expected'] != null), isNotEmpty);
    expect(_cases.where((it) => it['expected'] == null), isNotEmpty);
  });

  group('driverOn', () {
    for (final testCase in _cases) {
      test(testCase['name'] as String, () {
        final answer = AssignmentResolution.driverOn(
          _assignments,
          vehicleId: testCase['vehicle_id'] as String,
          on: dateFromColumn(testCase['on'] as String),
        );

        expect(answer, testCase['expected']);
      });
    }

    test('a local time is judged by its calendar day', () {
      // A sheet hands over the day it shows, which is local; the window is
      // in dates. Half past eleven on the 31st is still the 31st.
      final answer = AssignmentResolution.driverOn(
        _assignments,
        vehicleId: 'v1',
        on: DateTime(2026, 5, 31, 23, 30),
      );

      expect(answer, 'ana');
    });

    test('a window whose account was deleted resolves to nobody', () {
      // The row stays in the log with a null user (0080 sets null rather
      // than cascading), and nobody is the honest answer for its days.
      final orphaned = [
        VehicleAssignment(
          id: 'a9',
          vehicleId: 'v9',
          userId: null,
          fromDate: DateTime.utc(2026, 1, 1),
        ),
      ];

      expect(
        AssignmentResolution.driverOn(
          orphaned,
          vehicleId: 'v9',
          on: DateTime.utc(2026, 3, 1),
        ),
        isNull,
      );
    });
  });

  group('driverOf', () {
    // The name an export cell, a report line and the data screen print:
    // one helper, so the three cannot disagree on what a missing driver
    // looks like.
    const names = {'ana': 'Ana', 'marko': 'Marko'};

    test('is the name of whoever had the car that day', () {
      expect(
        AssignmentResolution.driverOf(
          _assignments,
          names: names,
          vehicleId: 'v1',
          on: DateTime.utc(2026, 5, 15),
        ),
        'Ana',
      );
    });

    test('is blank on a day nobody had the car', () {
      expect(
        AssignmentResolution.driverOf(
          _assignments,
          names: names,
          vehicleId: 'v3',
          on: DateTime.utc(2026, 6, 1),
        ),
        '',
      );
    });

    test('is blank for a driver the garage no longer names', () {
      expect(
        AssignmentResolution.driverOf(
          _assignments,
          names: const {'ana': 'Ana'},
          vehicleId: 'v1',
          on: DateTime.utc(2026, 7, 1),
        ),
        '',
      );
    });

    test('or the word the caller has for one, where a blank would mislead', () {
      // The ledger names a driver on every row; a blank there reads as a
      // day nobody had the car, which is a different fact.
      expect(
        AssignmentResolution.driverOf(
          _assignments,
          names: const {'ana': 'Ana'},
          vehicleId: 'v1',
          on: DateTime.utc(2026, 7, 1),
          former: 'Former member',
        ),
        'Former member',
      );
      expect(
        AssignmentResolution.driverOf(
          _assignments,
          names: const {'ana': 'Ana'},
          vehicleId: 'v3',
          on: DateTime.utc(2026, 6, 1),
          former: 'Former member',
        ),
        '',
        reason: 'a day nobody had the car is still a blank',
      );
    });
  });

  group('the open assignment', () {
    test('is the window that holds today, for the grid', () {
      final open = AssignmentResolution.openFor(
        _assignments,
        vehicleId: 'v1',
        today: DateTime.utc(2026, 9, 19),
      );

      expect(open?.id, 'a2');
      expect(open?.isOpen, isTrue);
    });

    test('is nothing on a car whose windows have all closed', () {
      expect(
        AssignmentResolution.openFor(
          _assignments,
          vehicleId: 'v2',
          today: DateTime.utc(2026, 9, 19),
        ),
        isNull,
      );
    });

    test('the history of a car runs newest first', () {
      final history = AssignmentResolution.historyOf(_assignments, 'v1');

      expect(history.map((it) => it.id), ['a2', 'a1']);
    });

    test('the history of a car never assigned is empty', () {
      expect(AssignmentResolution.historyOf(_assignments, 'v3'), isEmpty);
    });
  });
}
