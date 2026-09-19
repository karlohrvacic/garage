import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every list a Supabase repository reads goes through the read cache, so a
/// screen shows what it last saw when there is no signal. A repository added
/// later cannot quietly opt out: name the method here, with the reason, or
/// wrap its query.
void main() {
  const exempt = {
    // Keys and webhooks are managed online, and never read at a pump. A
    // hook's delivery log is watched live while a test is out; what the
    // phone last saw of it is not worth showing.
    'supabase_api_access_repository.dart': {'keys', 'webhooks', 'deliveries'},
    // A list of files, whose bytes are not cached either.
    'supabase_attachment_repository.dart': {'forEntry'},
    // Has its own cache, keyed the same way (decision 126); the helper is
    // part of that one fetch.
    'supabase_garage_bootstrap_repository.dart': {'_lentVehicles'},
    // The bootstrap covers households; invites are managed online.
    'supabase_household_repository.dart': {'myHouseholds', 'invites'},
    // A borrowed car's history is read by a guest, online, through an rpc.
    'supabase_guest_pass_repository.dart': {'serviceHistory'},
    // The bootstrap covers vehicles; a transfer is accepted online.
    'supabase_vehicle_repository.dart': {'forHousehold', 'transfersOffered'},
  };

  test('every Supabase list read goes through the read cache', () {
    final missing = <String>[];
    final files = Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
          final name = file.uri.pathSegments.last;
          return name.startsWith('supabase_') &&
              name.endsWith('_repository.dart');
        });
    final read = RegExp(r'Future<List<[^>]+>+\s+(\w+)\(');
    for (final file in files) {
      final name = file.uri.pathSegments.last;
      final source = file.readAsStringSync();
      final starts = read.allMatches(source).toList();
      for (var i = 0; i < starts.length; i++) {
        final method = starts[i].group(1)!;
        if (exempt[name]?.contains(method) ?? false) {
          continue;
        }
        final end = i + 1 < starts.length ? starts[i + 1].start : source.length;
        final body = source.substring(starts[i].start, end);
        if (!body.contains('_cache.rows(')) {
          missing.add('$name#$method');
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'wrap the query in _cache.rows(key, () => …) or name the method in '
          '`exempt` with the reason it is read online only',
    );
  });

  test('the exemptions still name real methods', () {
    for (final entry in exempt.entries) {
      final file = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .firstWhere((it) => it.uri.pathSegments.last == entry.key);
      final source = file.readAsStringSync();
      for (final method in entry.value) {
        expect(
          source,
          contains(' $method('),
          reason: '${entry.key} no longer has $method; drop the exemption',
        );
      }
    }
  });
}
