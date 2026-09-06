/// A journey somebody makes over and over, named once so it can be compared
/// with itself.
///
/// Household-scoped, and holding no addresses: see `0061_routes.sql` for why
/// both of those are deliberate.
class TripRoute {
  const TripRoute({
    required this.id,
    required this.householdId,
    required this.name,
    this.createdBy = '',
    this.createdAt,
  });

  final String id;
  final String householdId;
  final String name;
  final String createdBy;
  final DateTime? createdAt;

  /// The route this name already refers to, or null.
  ///
  /// Matches how the database decides: the unique index is on `lower(name)`,
  /// so anything this treats as new and the index treats as existing would be
  /// offered to the user and then refused on save. Trimming is safe alongside
  /// that only because every write trims first.
  static TripRoute? matching(String name, Iterable<TripRoute> routes) {
    final wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) {
      return null;
    }
    for (final route in routes) {
      if (route.name.trim().toLowerCase() == wanted) {
        return route;
      }
    }
    return null;
  }

  static int byName(TripRoute a, TripRoute b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  @override
  bool operator ==(Object other) =>
      other is TripRoute &&
      other.id == id &&
      other.householdId == householdId &&
      other.name == name &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, householdId, name, createdBy, createdAt);
}
