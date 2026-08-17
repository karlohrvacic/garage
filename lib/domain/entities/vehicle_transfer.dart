/// A vehicle offered to another garage, and whether it has been claimed.
///
/// The seller's side of a transfer. Once a code is redeemed the vehicle row
/// belongs to the buyer's household and the seller can no longer read it —
/// this row is all that is left saying the car was ever theirs, which is why
/// the nickname is captured here rather than looked up.
class VehicleTransfer {
  const VehicleTransfer({
    required this.id,
    required this.vehicleId,
    this.vehicleNickname,
    this.redeemedAt,
  });

  final String id;
  final String vehicleId;

  /// What the vehicle was called when it was offered, or null for a transfer
  /// created before that was recorded.
  final String? vehicleNickname;

  /// When the new owner claimed it, or null while the code is outstanding.
  final DateTime? redeemedAt;

  bool get isRedeemed => redeemedAt != null;

  @override
  bool operator ==(Object other) {
    return other is VehicleTransfer &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.vehicleNickname == vehicleNickname &&
        other.redeemedAt == redeemedAt;
  }

  @override
  int get hashCode => Object.hash(id, vehicleId, vehicleNickname, redeemedAt);

  @override
  String toString() {
    return 'VehicleTransfer(id: $id, vehicleId: $vehicleId, '
        'vehicleNickname: $vehicleNickname, redeemedAt: $redeemedAt)';
  }
}
