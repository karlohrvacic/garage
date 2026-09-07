import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle_part.dart';
import 'package:garage/features/parts/data/supabase_vehicle_part_repository.dart';

void main() {
  final row = {
    'id': 'p1',
    'vehicle_id': 'v1',
    'service_type_key': 'service_oil_change',
    'spec': '5W-30 ACEA C3',
    'notes': 'Castrol Edge, 4.3 l with filter',
    'created_by': 'u1',
    'created_at': '2026-09-07T10:00:00Z',
  };

  test('maps every column onto the entity', () {
    expect(
      vehiclePartFromRow(row),
      VehiclePart(
        id: 'p1',
        vehicleId: 'v1',
        serviceTypeKey: 'service_oil_change',
        spec: '5W-30 ACEA C3',
        notes: 'Castrol Edge, 4.3 l with filter',
        createdBy: 'u1',
        createdAt: DateTime.utc(2026, 9, 7, 10),
      ),
    );
  });

  test('an author since deleted still reads', () {
    expect(vehiclePartFromRow({...row, 'created_by': null}).createdBy, '');
  });

  test('writes only the columns an edit may change, trimmed', () {
    final written = vehiclePartToRow(
      const VehiclePart(
        id: 'p1',
        vehicleId: 'v1',
        serviceTypeKey: 'service_oil_change',
        spec: '  5W-30 ACEA C3 ',
        createdBy: 'u1',
      ),
    );

    expect(written.keys, {'service_type_key', 'spec', 'notes'});
    expect(written['spec'], '5W-30 ACEA C3');
  });
}
