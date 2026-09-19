/// A write that row-level security filters away is not an error to Postgres.
/// The update or delete matches zero rows, PostgREST answers 204 rather than
/// `42501`, and a sheet that only awaited the call would say "saved" over a
/// row that did not change. Every entry write the app makes therefore ends in
/// `.select('id')` and hands the answer here: the row is readable to whoever
/// is asking — the sheet was opened from it — so an empty answer is the
/// policy saying no, not a row that was never there.
///
/// A driver is who reaches this (migration 0080): their select policies are
/// per car and their update and delete policies per author, so the admin's
/// fill-up on the car handed to them opens the same sheet with the same Save.
/// An insert the policy refuses is a real `42501` — there is a new row for
/// the check to fail on — and never needs this; a table with no driver write
/// policy at all answers an update or a delete the same silent way, so a
/// repository that lets a driver edit one belongs here too.
library;

import '../errors/app_failure.dart';

void refusedIfNone(
  List<Object?> rows, {
  required String table,
  required String write,
  required String id,
}) {
  if (rows.isEmpty) {
    throw AppFailure(
      kind: AppFailureKind.permission,
      debugMessage: '$table $write of $id touched no row: filtered by policy',
    );
  }
}
