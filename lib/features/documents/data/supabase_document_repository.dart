import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/supabase/date_column.dart';
import '../../../core/sync/read_cache.dart';
import '../../../domain/entities/vehicle_document.dart';
import 'document_repository.dart';

class SupabaseDocumentRepository implements DocumentRepository {
  SupabaseDocumentRepository(this._client, {required this._cache});

  final SupabaseClient _client;
  final ReadCache _cache;

  @override
  Future<List<VehicleDocument>> forVehicle(String vehicleId) async {
    try {
      final rows = await _cache.rows(
        'documents/$vehicleId',
        () => _client
            .from('vehicle_documents')
            .select()
            .eq('vehicle_id', vehicleId)
            // Nulls last, so a document with no expiry does not lead a list
            // whose whole point is what runs out first.
            .order('expires_on', ascending: true, nullsFirst: false)
            .retry(enabled: false),
      );
      return rows.map(documentFromRow).toList(growable: false);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> save(VehicleDocument document) async {
    try {
      // An upsert, so "add" and "correct" are one path and a save that timed
      // out lands on the same client-minted id when it is tried again rather
      // than as a second row.
      //
      // `created_by` is always the caller, never the row's original author:
      // Postgres checks `insert ... on conflict do update` against the insert
      // policy as well as the update one, and that policy demands
      // `created_by = auth.uid()`. Sending somebody else's id refuses the
      // write outright — which is what stopped the second member of a
      // household correcting a document the first one filed. The
      // `pin_created_by` trigger (migration 0051) puts the original author
      // back on the update branch, so attribution still survives the edit.
      await _client.from('vehicle_documents').upsert({
        if (document.id.isNotEmpty) 'id': document.id,
        ...documentToRow(document),
        'created_by': _client.auth.currentUser!.id,
      });
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('vehicle_documents').delete().eq('id', id);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}

Map<String, dynamic> documentToRow(VehicleDocument document) {
  String? trimmed(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  return {
    'vehicle_id': document.vehicleId,
    'doc_type': document.type.key,
    'label': trimmed(document.label),
    'number': trimmed(document.number),
    'issuer': trimmed(document.issuer),
    'issued_on': document.issuedOn == null
        ? null
        : dateToColumn(document.issuedOn!),
    'expires_on': document.expiresOn == null
        ? null
        : dateToColumn(document.expiresOn!),
    'notes': trimmed(document.notes),
  };
}

VehicleDocument documentFromRow(Map<String, dynamic> row) {
  return VehicleDocument(
    id: row['id'] as String,
    vehicleId: row['vehicle_id'] as String,
    type: DocumentType.fromKey(row['doc_type'] as String),
    label: row['label'] as String?,
    number: row['number'] as String?,
    issuer: row['issuer'] as String?,
    issuedOn: row['issued_on'] == null
        ? null
        : dateFromColumn(row['issued_on'] as String),
    expiresOn: row['expires_on'] == null
        ? null
        : dateFromColumn(row['expires_on'] as String),
    notes: row['notes'] as String?,
    createdBy: row['created_by'] as String? ?? '',
    createdAt: switch (row['created_at']) {
      final String written => DateTime.parse(written).toUtc(),
      _ => null,
    },
  );
}
