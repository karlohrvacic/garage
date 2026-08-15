import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/supabase/supabase_client_provider.dart';
import 'package:garage/features/household/data/household_repository.dart';
import 'package:garage/features/household/providers/member_providers.dart';

const _members = [
  HouseholdMember(userId: 'u1', displayName: 'Karlo', role: 'admin'),
  HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
];

ProviderContainer containerWith({
  String? userId,
  List<HouseholdMember> members = _members,
}) {
  final container = ProviderContainer(
    overrides: [
      membersProvider.overrideWith((ref) async => members),
      currentUserIdProvider.overrideWithValue(userId),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the household creator is its admin', () async {
    final container = containerWith(userId: 'u1');

    expect(await container.read(isHouseholdAdminProvider.future), isTrue);
  });

  test('an ordinary member is not', () async {
    final container = containerWith(userId: 'u2');

    expect(await container.read(isHouseholdAdminProvider.future), isFalse);
  });

  test('someone who is not signed in is not', () async {
    final container = containerWith();

    expect(await container.read(isHouseholdAdminProvider.future), isFalse);
  });

  test('a user the member list does not know is not', () async {
    final container = containerWith(userId: 'stranger');

    expect(await container.read(isHouseholdAdminProvider.future), isFalse);
  });

  test('a household of one is that member’s, whatever the role says', () async {
    // A member who joined by code and then outlived everyone else must not be
    // locked out of their own household.
    final container = containerWith(
      userId: 'u2',
      members: const [
        HouseholdMember(userId: 'u2', displayName: 'Ana', role: 'member'),
      ],
    );

    expect(await container.read(isHouseholdAdminProvider.future), isTrue);
  });
}
