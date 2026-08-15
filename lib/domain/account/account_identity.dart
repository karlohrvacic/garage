/// Who the app says you are: the name and address to show for the signed-in
/// account.
///
/// The name is chosen with the same precedence the `handle_new_user` trigger
/// uses for the profile row (migration 0011) — display name from the sign-up
/// form, then Google's `full_name`, then a bare `name`, then the part of the
/// address before the `@`. Diverging from it would mean the same person is
/// called one thing on this screen and another in the household list.
class AccountIdentity {
  const AccountIdentity({required this.name, required this.email});

  final String name;
  final String email;

  static AccountIdentity of({
    required String? email,
    required Map<String, dynamic> metadata,
  }) {
    final address = email?.trim() ?? '';
    return AccountIdentity(
      name:
          _first(metadata, const ['display_name', 'full_name', 'name']) ??
          _localPart(address),
      email: address,
    );
  }

  static String? _first(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static String _localPart(String email) => email.split('@').first;
}
