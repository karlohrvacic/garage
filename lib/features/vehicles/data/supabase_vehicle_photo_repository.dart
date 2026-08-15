import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import 'vehicle_photo_repository.dart';

/// How long a photo link stays good. A vehicle screen is looked at for
/// seconds, and a link that outlives the session is a link that can leak.
const _signedUrlSeconds = 600;

const _bucket = 'vehicle-photos';

class SupabaseVehiclePhotoRepository implements VehiclePhotoRepository {
  SupabaseVehiclePhotoRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> upload({
    required String householdId,
    required String vehicleId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final path = VehiclePhotos.pathFor(
      householdId: householdId,
      vehicleId: vehicleId,
    );
    try {
      // Upsert: the path is fixed per vehicle, so a second photo replaces the
      // first instead of leaving one behind that nothing points at.
      await _client.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return path;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Uri?> viewUrl(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    try {
      final url = await _client.storage
          .from(_bucket)
          .createSignedUrl(path, _signedUrlSeconds);
      return Uri.parse(url);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _client.storage.from(_bucket).remove([path]);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}
