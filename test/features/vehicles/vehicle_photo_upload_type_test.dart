import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:garage/features/vehicles/data/supabase_vehicle_photo_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_supabase_http.dart';

final jpeg = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  ...List.filled(64, 0),
]);

/// A vehicle photo is stored at `<garage>/<vehicle>`, a path with no
/// extension, so storage cannot guess its type — and the bucket accepts only
/// images (migration 0075). Merging garages copies photos with no type at
/// all, which is how this came up.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a photo sent with no type is sent as what it is', () async {
    final fake = FakeSupabaseServer((request) {
      if (request.url.path.startsWith('/storage/v1/object/vehicle-photos/')) {
        return (200, {'Key': 'vehicle-photos/h1/v1'});
      }
      return null;
    });

    await SupabaseVehiclePhotoRepository(
      fake.client,
    ).upload(householdId: 'h1', vehicleId: 'v1', bytes: jpeg);

    final upload = fake.requests.single;
    expect(upload.url.path, '/storage/v1/object/vehicle-photos/h1/v1');
    expect(
      latin1.decode(upload.bodyBytes).toLowerCase(),
      contains('content-type: image/jpeg'),
    );
  });
}
