import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/supabase/refused_if_none.dart';

void main() {
  test('a row read back is a write that landed', () {
    expect(
      () => refusedIfNone(
        const [
          {'id': 'f1'},
        ],
        table: 'fuel_entries',
        write: 'update',
        id: 'f1',
      ),
      returnsNormally,
    );
  });

  test('none read back is the permission failure, and it names the row', () {
    expect(
      () => refusedIfNone(
        const [],
        table: 'fuel_entries',
        write: 'delete',
        id: 'f1',
      ),
      throwsA(
        isA<AppFailure>()
            .having((it) => it.kind, 'kind', AppFailureKind.permission)
            .having(
              (it) => it.debugMessage,
              'debugMessage',
              'fuel_entries delete of f1 touched no row: filtered by policy',
            ),
      ),
    );
  });
}
