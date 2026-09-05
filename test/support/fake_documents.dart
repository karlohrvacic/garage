import 'package:garage/domain/entities/vehicle_document.dart';
import 'package:garage/features/documents/data/document_repository.dart';

/// An in-memory document store, so a harness that builds a backup or walks a
/// vehicle page does not reach for a real Supabase client.
///
/// Shared rather than redeclared per test file for the reason the entry
/// overrides are: the next thing that reads documents should not have to
/// discover this the hard way, three failures deep in an unrelated suite.
class FakeDocumentRepository implements DocumentRepository {
  FakeDocumentRepository([List<VehicleDocument> documents = const []])
    : documents = [...documents];

  final List<VehicleDocument> documents;
  final List<String> deleted = [];

  @override
  Future<List<VehicleDocument>> forVehicle(String vehicleId) async => [
    for (final document in documents)
      if (document.vehicleId == vehicleId) document,
  ];

  @override
  Future<void> save(VehicleDocument document) async {
    documents
      ..removeWhere((held) => held.id == document.id && document.id.isNotEmpty)
      ..add(document);
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    documents.removeWhere((document) => document.id == id);
  }
}
