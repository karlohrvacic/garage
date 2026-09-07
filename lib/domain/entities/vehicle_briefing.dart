/// What somebody holding your car is always shown, whatever the pass allows.
///
/// Four answers to four questions a borrower actually has: how far has it
/// gone, what runs out while I have it, what is already wrong with it, and
/// what is it standing on. No money, no document numbers, no history — those
/// are the owner's, and the function that fills this in decides field by
/// field rather than granting rows (see `guest_vehicle_briefing`).
class VehicleBriefing {
  const VehicleBriefing({
    this.odometerKm,
    this.documents = const [],
    this.problems = const [],
    this.tyres = const [],
  });

  /// The furthest reading anybody has logged, from whichever table it came.
  /// Null on a car nobody has logged anything against.
  final int? odometerKm;

  final List<BriefedDocument> documents;
  final List<BriefedProblem> problems;
  final List<BriefedTyres> tyres;

  bool get isEmpty =>
      odometerKm == null &&
      documents.isEmpty &&
      problems.isEmpty &&
      tyres.isEmpty;
}

/// A paper and the day it stops being valid. Deliberately not its number:
/// that is in the glovebox, and it is the owner's to share or not.
class BriefedDocument {
  const BriefedDocument({required this.type, required this.expiresOn});

  final String type;
  final DateTime expiresOn;
}

class BriefedProblem {
  const BriefedProblem({required this.note, required this.noticedOn});

  final String note;
  final DateTime noticedOn;
}

class BriefedTyres {
  const BriefedTyres({required this.season, this.fittedOn});

  final String season;
  final DateTime? fittedOn;
}
