/// What a piece of paper is. Stored as the language-neutral key the
/// `vehicle_documents.doc_type` column checks against.
///
/// Deliberately short. Every type here is one a Croatian household is either
/// legally required to hold or is asked for at a border, and each has a date
/// that costs money to miss. [other] is the escape hatch for the rest, and is
/// the only type a vehicle may hold more than one of.
enum DocumentType {
  registration('registration'),
  roadworthiness('roadworthiness'),
  insuranceLiability('insurance_liability'),
  insuranceComprehensive('insurance_comprehensive'),
  greenCard('green_card'),
  other('other');

  const DocumentType(this.key);

  /// The stored key, deliberately not [name]: renaming the Dart value must
  /// not reinterpret rows already written.
  final String key;

  /// Anything unrecognised reads as [other] rather than throwing. A type
  /// stored by a newer build is still a document the household holds, and
  /// hiding it would be worse than showing it under a general heading.
  static DocumentType fromKey(String key) {
    for (final type in values) {
      if (type.key == key) {
        return type;
      }
    }
    return DocumentType.other;
  }

  /// The reminder this type comes due as, or null when it has none.
  ///
  /// Reusing the maintenance service types is what makes a document turn up
  /// in the planner, on the dashboard and in a notification without any of
  /// them learning what a document is. It also means a registration paid for
  /// in the cost sheet and a registration certificate recorded here settle
  /// the *same* reminder, rather than raising two that each say the other is
  /// wrong.
  String? get serviceTypeKey => switch (this) {
    DocumentType.registration => 'service_registration',
    DocumentType.roadworthiness => 'service_technical_inspection',
    DocumentType.insuranceLiability => 'service_insurance',
    DocumentType.insuranceComprehensive => 'service_insurance_comprehensive',
    DocumentType.greenCard => 'service_green_card',
    // Whatever the household is keeping here, the app has no name for it and
    // so has nothing to call the reminder it would raise.
    DocumentType.other => null,
  };
}

/// One document held for a vehicle: what it is, what is written on it, and
/// when it stops being valid.
///
/// The expiry is the reason this table exists. Everything else is optional,
/// because a household that records only "the registration runs out on 3
/// June" has recorded the thing that matters.
class VehicleDocument {
  const VehicleDocument({
    required this.id,
    required this.vehicleId,
    required this.type,
    required this.createdBy,
    this.label,
    this.number,
    this.issuer,
    this.issuedOn,
    this.expiresOn,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String vehicleId;
  final DocumentType type;

  /// What the household calls this one. Only meaningful for
  /// [DocumentType.other], where the type says nothing.
  final String? label;

  /// The number on the paper — a policy number, a certificate number.
  final String? number;

  /// Who issued it: an insurer, a testing station.
  final String? issuer;

  /// UTC date-only, like every domain [DateTime].
  final DateTime? issuedOn;
  final DateTime? expiresOn;

  final String? notes;
  final String createdBy;
  final DateTime? createdAt;

  VehicleDocument copyWith({
    String? id,
    String? vehicleId,
    DocumentType? type,
    String? createdBy,
    // Nullable fields take a wrapper so copyWith can clear them: a plain
    // `DateTime? expiresOn` could never tell "leave it" from "clear it", and
    // an expiry entered by mistake has to be removable.
    Object? label = _unset,
    Object? number = _unset,
    Object? issuer = _unset,
    Object? issuedOn = _unset,
    Object? expiresOn = _unset,
    Object? notes = _unset,
    DateTime? createdAt,
  }) {
    return VehicleDocument(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      type: type ?? this.type,
      createdBy: createdBy ?? this.createdBy,
      label: label == _unset ? this.label : label as String?,
      number: number == _unset ? this.number : number as String?,
      issuer: issuer == _unset ? this.issuer : issuer as String?,
      issuedOn: issuedOn == _unset ? this.issuedOn : issuedOn as DateTime?,
      expiresOn: expiresOn == _unset ? this.expiresOn : expiresOn as DateTime?,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is VehicleDocument &&
        other.id == id &&
        other.vehicleId == vehicleId &&
        other.type == type &&
        other.label == label &&
        other.number == number &&
        other.issuer == issuer &&
        other.issuedOn == issuedOn &&
        other.expiresOn == expiresOn &&
        other.notes == notes &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    vehicleId,
    type,
    label,
    number,
    issuer,
    issuedOn,
    expiresOn,
    notes,
    createdBy,
    createdAt,
  );

  @override
  String toString() =>
      'VehicleDocument(id: $id, vehicleId: $vehicleId, type: ${type.key}, '
      'number: $number, issuedOn: $issuedOn, expiresOn: $expiresOn)';
}

const _unset = Object();
