import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/files/file_picker.dart';
import 'package:garage/core/links/url_opener.dart';
import 'package:garage/domain/entities/attachment.dart';
import 'package:garage/features/attachments/providers/attachment_providers.dart';
import 'package:garage/features/attachments/widgets/entry_attachments.dart';

import '../../support/pump_screen.dart';
import 'attachment_providers_test.dart' show FakeAttachmentRepository;

/// A repository whose view links never resolve, for the failure path.
class UnreachableAttachmentRepository extends FakeAttachmentRepository {
  UnreachableAttachmentRepository(super.stored);

  @override
  Future<Uri> viewUrl(Attachment attachment) async => throw Exception('nope');
}

Attachment attachment({
  String id = 'a1',
  String fileName = 'receipt.jpg',
  String? contentType = 'image/jpeg',
}) {
  return Attachment(
    id: id,
    vehicleId: 'v1',
    entryKind: AttachmentEntryKind.fuel,
    entryId: 'f1',
    storagePath: 'v1/$id-$fileName',
    fileName: fileName,
    contentType: contentType,
    sizeBytes: 1024,
    createdBy: 'u1',
    createdAt: DateTime.utc(2026, 7, 24),
  );
}

Future<NavigationLog> pumpStrip(
  WidgetTester tester, {
  required FakeAttachmentRepository repository,
  XFile? picked,
  List<Uri>? opened,
}) {
  return pumpScreen(
    tester,
    const Scaffold(
      body: EntryAttachments(
        vehicleId: 'v1',
        kind: AttachmentEntryKind.fuel,
        entryId: 'f1',
      ),
    ),
    surface: const Size(420, 800),
    overrides: [
      attachmentRepositoryProvider.overrideWithValue(repository),
      filePickerProvider.overrideWithValue(() async => picked),
      urlOpenerProvider.overrideWithValue((url) async => opened?.add(url)),
    ],
  );
}

/// A file too big for the bucket, as a phone photo routinely is.
XFile oversizedFile({String name = 'photo.jpg'}) {
  return XFile.fromData(
    Uint8List(Attachment.maxUploadBytes + 1),
    name: name,
    path: name,
    mimeType: 'image/jpeg',
  );
}

XFile pickedFile({String name = 'pump.jpg'}) {
  // path as well as name: the dart:io XFile reads its name off the path.
  return XFile.fromData(
    Uint8List.fromList([1, 2, 3, 4]),
    name: name,
    path: name,
    mimeType: 'image/jpeg',
  );
}

void main() {
  testWidgets('an entry with nothing attached still offers to attach', (
    tester,
  ) async {
    await pumpStrip(tester, repository: FakeAttachmentRepository());
    await tester.pumpAndSettle();

    expect(find.text('Attachments'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });

  testWidgets('each attachment is listed by name', (tester) async {
    await pumpStrip(
      tester,
      repository: FakeAttachmentRepository([
        attachment(),
        attachment(id: 'a2', fileName: 'policy.pdf', contentType: null),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('receipt.jpg'), findsOneWidget);
    expect(find.text('policy.pdf'), findsOneWidget);
  });

  testWidgets('picking a file uploads it against the entry', (tester) async {
    final repository = FakeAttachmentRepository();
    await pumpStrip(tester, repository: repository, picked: pickedFile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('upload:pump.jpg:4'));
    expect(find.text('pump.jpg'), findsOneWidget);
  });

  testWidgets('a file over the limit is refused before it is sent', (
    tester,
  ) async {
    // The server does not refuse this cleanly — an oversized body has its
    // connection cut — so it reached the app as a transport error and was
    // reported as "No connection. Check your network and retry.", which is
    // both wrong and impossible to act on for a file that will never fit.
    final repository = FakeAttachmentRepository();
    await pumpStrip(tester, repository: repository, picked: oversizedFile());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((call) => call.startsWith('upload:')),
      isEmpty,
      reason: 'nothing should leave the device',
    );
    expect(find.textContaining('the limit is 10.0 MB'), findsOneWidget);
    expect(find.textContaining('No connection'), findsNothing);
  });

  testWidgets('cancelling the picker uploads nothing', (tester) async {
    final repository = FakeAttachmentRepository();
    await pumpStrip(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(
      repository.calls.where((call) => call.startsWith('upload')),
      isEmpty,
    );
  });

  testWidgets('tapping an attachment opens its signed link', (tester) async {
    final opened = <Uri>[];
    await pumpStrip(
      tester,
      repository: FakeAttachmentRepository([attachment()]),
      opened: opened,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('receipt.jpg'));
    await tester.pumpAndSettle();

    expect(opened, [Uri.parse('https://example.test/v1/a1-receipt.jpg')]);
  });

  testWidgets('removing an attachment asks first', (tester) async {
    final repository = FakeAttachmentRepository([attachment()]);
    await pumpStrip(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Delete entry?'), findsOneWidget);
    expect(repository.calls.where((c) => c.startsWith('delete')), isEmpty);
  });

  testWidgets('a confirmed removal deletes the file', (tester) async {
    final repository = FakeAttachmentRepository([attachment()]);
    await pumpStrip(tester, repository: repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('delete:a1'));
    expect(find.text('receipt.jpg'), findsNothing);
  });

  testWidgets('a link that cannot be opened is reported, not swallowed', (
    tester,
  ) async {
    final opened = <Uri>[];
    await pumpStrip(
      tester,
      repository: UnreachableAttachmentRepository([attachment()]),
      opened: opened,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('receipt.jpg'));
    await tester.pumpAndSettle();

    expect(opened, isEmpty);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
