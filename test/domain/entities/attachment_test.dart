import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/attachment.dart';

Attachment attachment({
  String id = 'a1',
  String fileName = 'receipt.jpg',
  String? contentType = 'image/jpeg',
  int? sizeBytes = 2048,
}) {
  return Attachment(
    id: id,
    vehicleId: 'v1',
    entryKind: AttachmentEntryKind.fuel,
    entryId: 'f1',
    storagePath: 'v1/abc-receipt.jpg',
    fileName: fileName,
    contentType: contentType,
    sizeBytes: sizeBytes,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 7, 24, 10, 30),
  );
}

void main() {
  group('equality', () {
    test('field-identical instances are equal and share a hash code', () {
      expect(attachment(), attachment());
      expect(attachment().hashCode, attachment().hashCode);
    });

    test('a differing id breaks equality', () {
      expect(attachment(id: 'a2'), isNot(attachment()));
    });

    test('a differing file name breaks equality', () {
      expect(attachment(fileName: 'invoice.pdf'), isNot(attachment()));
    });

    test('toString names the type and the file', () {
      expect(attachment().toString(), contains('Attachment('));
      expect(attachment().toString(), contains('receipt.jpg'));
    });
  });

  group('what it is', () {
    test('a JPEG is an image, so it can be shown as a thumbnail', () {
      expect(attachment().isImage, isTrue);
    });

    test('a PDF is not', () {
      expect(attachment(contentType: 'application/pdf').isImage, isFalse);
    });

    test('an unknown type falls back to the file extension', () {
      expect(attachment(contentType: null).isImage, isTrue);
      expect(
        attachment(contentType: null, fileName: 'policy.pdf').isImage,
        isFalse,
      );
    });

    test('the extension check ignores case', () {
      expect(
        attachment(contentType: null, fileName: 'RECEIPT.PNG').isImage,
        isTrue,
      );
    });
  });

  group('entry kinds', () {
    test('map to the keys the table stores', () {
      expect(AttachmentEntryKind.fuel.key, 'fuel');
      expect(AttachmentEntryKind.service.key, 'service');
      expect(AttachmentEntryKind.cost.key, 'cost');
    });

    test('parse back from those keys', () {
      expect(
        AttachmentEntryKind.fromKey('service'),
        AttachmentEntryKind.service,
      );
    });

    test('an unknown key is refused rather than guessed', () {
      expect(() => AttachmentEntryKind.fromKey('nope'), throwsArgumentError);
    });
  });

  group('storage paths', () {
    test('are keyed by vehicle, so one RLS rule covers every entry kind', () {
      final path = Attachment.storagePathFor(
        vehicleId: 'v1',
        uniqueId: 'abc',
        fileName: 'receipt.jpg',
      );

      expect(path, 'v1/abc-receipt.jpg');
    });

    test('strip characters that would break a storage key', () {
      final path = Attachment.storagePathFor(
        vehicleId: 'v1',
        uniqueId: 'abc',
        fileName: 'račun 1/2 (kopija).jpg',
      );

      expect(path, 'v1/abc-racun_1_2_kopija.jpg');
    });

    test('keep a name that is already clean', () {
      final path = Attachment.storagePathFor(
        vehicleId: 'v1',
        uniqueId: 'abc',
        fileName: 'INA-2026-07.pdf',
      );

      expect(path, 'v1/abc-INA-2026-07.pdf');
    });
  });
}
