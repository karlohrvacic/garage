import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every table in `public` has row-level security switched on, and something
/// granted to `authenticated` has at least one policy.
///
/// **The database is the security boundary, not the app.** A table created
/// without `enable row level security` is readable by every signed-in user of
/// the project the moment a grant reaches it, and nothing in the app would
/// look different: the screens that read it are already scoped by household in
/// their queries, so a household would see exactly what it expects while every
/// other household's rows sat one crafted request away.
///
/// `test_rls/rls_test.dart` is the real proof and it needs Docker, a Supabase
/// stack and every migration applied. This is the cheap half: a static read of
/// the migrations that fails in the ordinary suite, at the moment the
/// migration is written, rather than in the job somebody may not run locally.
///
/// It cannot tell a *good* policy from a bad one — only that the switch is on
/// and that something was written. The live suite is what checks the policies
/// actually isolate, including the positive control that a member can still
/// read.
void main() {
  final migrations = [
    for (final file in Directory('supabase/migrations').listSync())
      if (file is File && file.path.endsWith('.sql')) file.readAsStringSync(),
  ]..sort();
  final sql = migrations.join('\n');

  Set<String> matches(String pattern) => {
    for (final match in RegExp(pattern, caseSensitive: false).allMatches(sql))
      match.group(1)!,
  };

  final created = matches(r'create table (?:if not exists )?public\.(\w+)');
  final secured = matches(
    r'alter table public\.(\w+)\s+enable row level security',
  );
  final policied = matches(r'create policy \w+ on public\.(\w+)');
  final revoked = matches(
    r'revoke all on public\.(\w+) from anon, authenticated',
  );

  test('the migrations are actually being read', () {
    // A regex that stopped matching would make every test below pass over an
    // empty set, which is the failure mode a parsing test has.
    expect(created, contains('vehicles'));
    expect(created.length, greaterThan(15));
  });

  test('every table has row-level security switched on', () {
    expect(
      created.difference(secured),
      isEmpty,
      reason:
          'a table without RLS is readable by every signed-in user of the '
          'project, and no screen would look any different',
    );
  });

  test('and either carries a policy or is revoked outright', () {
    // RLS enabled with no policy denies everyone, which is the *safe* mistake
    // — but on a table users are meant to read it is still a mistake, and it
    // passes every "a stranger sees nothing" assertion the live suite makes.
    //
    // One table is deliberately in that state: `webhook_dispatch_config` is
    // operator configuration holding a dispatch token, reached by a
    // security-definer function and by nobody else. What makes that a
    // decision rather than an oversight is the `revoke` beside it, so that is
    // what this asks for rather than a list of names to keep in step.
    expect(
      created.difference(policied).difference(revoked),
      isEmpty,
      reason:
          'a table with no policy denies every user, including the '
          'household — unless it also revokes the grant, which says the '
          'silence was meant',
    );
  });
}
