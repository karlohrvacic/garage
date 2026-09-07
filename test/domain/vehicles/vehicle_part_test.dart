import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/entities/vehicle_part.dart';

VehiclePart part(String key, String spec) => VehiclePart(
  id: key,
  vehicleId: 'v1',
  serviceTypeKey: key,
  spec: spec,
  createdBy: 'u1',
);

void main() {
  final parts = [
    part('service_oil_change', '5W-30 ACEA C3'),
    part('service_oil_filter', 'W 712/95'),
    part('service_wipers', '600 mm / 400 mm'),
  ];

  test('a job with a spec finds it', () {
    expect(
      VehicleParts.forJob(parts, 'service_oil_change')?.spec,
      '5W-30 ACEA C3',
    );
  });

  test('a job without one finds nothing, rather than the nearest', () {
    expect(VehicleParts.forJob(parts, 'service_brake_fluid'), isNull);
  });

  test('a bundled visit collects every spec it covers, in order', () {
    final found = VehicleParts.forJobs(parts, [
      'service_oil_filter',
      'service_oil_change',
    ]);

    expect(found.map((p) => p.spec), ['W 712/95', '5W-30 ACEA C3']);
  });

  test('a visit whose jobs have no specs collects nothing', () {
    expect(VehicleParts.forJobs(parts, ['service_coolant']), isEmpty);
  });

  test('an empty garage answers nothing rather than throwing', () {
    expect(VehicleParts.forJob(const [], 'service_oil_change'), isNull);
    expect(VehicleParts.forJobs(const [], ['service_oil_change']), isEmpty);
  });
}
