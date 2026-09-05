import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/documents/document_expiry.dart';
import 'package:garage/domain/entities/vehicle_document.dart';

final _today = DateTime.utc(2026, 9, 4);

VehicleDocument doc({
  String id = 'd1',
  DocumentType type = DocumentType.registration,
  DateTime? expiresOn,
}) {
  return VehicleDocument(
    id: id,
    vehicleId: 'v1',
    type: type,
    createdBy: 'u1',
    expiresOn: expiresOn,
  );
}

void main() {
  group('what an expiry date says today', () {
    test('a date comfortably ahead is valid', () {
      expect(
        documentExpiryState(
          expiresOn: DateTime.utc(2026, 12, 1),
          today: _today,
        ),
        DocumentExpiryState.valid,
      );
    });

    test('inside the notice window it is expiring', () {
      expect(
        documentExpiryState(
          expiresOn: DateTime.utc(2026, 9, 20),
          today: _today,
        ),
        DocumentExpiryState.expiring,
      );
    });

    test('the last valid day is still valid, not expired', () {
      // A certificate valid *until* the 4th covers the 4th. Calling it expired
      // on its own last day would send somebody to a testing station a day
      // early, every year.
      expect(
        documentExpiryState(expiresOn: _today, today: _today),
        DocumentExpiryState.expiring,
      );
    });

    test('the day after is expired', () {
      expect(
        documentExpiryState(expiresOn: DateTime.utc(2026, 9, 3), today: _today),
        DocumentExpiryState.expired,
      );
    });

    test('no date recorded says nothing', () {
      expect(
        documentExpiryState(expiresOn: null, today: _today),
        DocumentExpiryState.undated,
      );
    });

    test('the window is a month, because paperwork needs an appointment', () {
      expect(documentNoticeDays, 30);
    });
  });

  group('how many days are left', () {
    test('counts calendar days, and today is zero', () {
      expect(daysUntilExpiry(expiresOn: _today, today: _today), 0);
      expect(
        daysUntilExpiry(expiresOn: DateTime.utc(2026, 9, 14), today: _today),
        10,
      );
    });

    test('is negative once it has passed', () {
      expect(
        daysUntilExpiry(expiresOn: DateTime.utc(2026, 8, 31), today: _today),
        -4,
      );
    });

    test('is null with no date', () {
      expect(daysUntilExpiry(expiresOn: null, today: _today), isNull);
    });
  });

  group('the order they are shown in', () {
    test('puts the most urgent first and the undated last', () {
      final sorted = documentsByUrgency([
        doc(id: 'none', type: DocumentType.other),
        doc(
          id: 'far',
          type: DocumentType.greenCard,
          expiresOn: DateTime.utc(2027, 1, 1),
        ),
        doc(
          id: 'expired',
          type: DocumentType.roadworthiness,
          expiresOn: DateTime.utc(2026, 6, 1),
        ),
        doc(
          id: 'soon',
          type: DocumentType.insuranceLiability,
          expiresOn: DateTime.utc(2026, 9, 20),
        ),
      ]);

      expect(sorted.map((d) => d.id), ['expired', 'soon', 'far', 'none']);
    });

    test('leaves the given list alone', () {
      final given = [
        doc(id: 'b', expiresOn: DateTime.utc(2027, 1, 1)),
        doc(
          id: 'a',
          type: DocumentType.greenCard,
          expiresOn: DateTime.utc(2026, 6, 1),
        ),
      ];
      documentsByUrgency(given);

      expect(given.map((d) => d.id), ['b', 'a']);
    });
  });

  group('the reminder a document raises', () {
    test('is the maintenance type its paperwork already had', () {
      expect(DocumentType.registration.serviceTypeKey, 'service_registration');
      expect(
        DocumentType.roadworthiness.serviceTypeKey,
        'service_technical_inspection',
      );
    });

    test('is none for a document the app has no name for', () {
      expect(DocumentType.other.serviceTypeKey, isNull);
    });
  });
}
