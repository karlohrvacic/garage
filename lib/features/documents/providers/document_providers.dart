import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../domain/documents/document_expiry.dart';
import '../../../domain/entities/vehicle_document.dart';
import '../data/document_repository.dart';
import '../data/supabase_document_repository.dart';

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return SupabaseDocumentRepository(ref.watch(supabaseClientProvider));
});

/// The documents held for one vehicle, most urgent first.
final vehicleDocumentsProvider =
    FutureProvider.family<List<VehicleDocument>, String>((
      ref,
      vehicleId,
    ) async {
      final documents = await ref
          .watch(documentRepositoryProvider)
          .forVehicle(vehicleId);
      return documentsByUrgency(documents);
    });
