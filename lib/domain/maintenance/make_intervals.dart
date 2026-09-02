/// One make's typical interval for one service type.
///
/// [spikeRow] is the make as it appears in the first column of §2 of
/// `docs/research/2026-09-02-service-interval-presets-spike.md`, which is
/// where every number here was sourced. A test checks it exists there, so a
/// row cannot be added without going through the spike.
class MakeInterval {
  const MakeInterval(
    this.make,
    this.serviceTypeKey, {
    this.km,
    this.months,
    required this.spikeRow,
  });

  final String make;
  final String serviceTypeKey;
  final int? km;
  final int? months;
  final String spikeRow;
}

const _oil = 'service_oil_change';
const _coolant = 'service_coolant';
const _cabin = 'service_cabin_filter';
const _air = 'service_air_filter';

/// The per-make overlay. Rules, from the design spec:
///
/// - The shorter official regime wins. VAG LongLife (30,000 km / 2 yr) and
///   Renault TCe (30,000 km / 2 yr) are not defaults; the person on them
///   edits once.
/// - A half the make gives no figure for is left null, and the generic
///   preset supplies it.
/// - A condition-based make (BMW, Ford oil) has no oil row on purpose: the
///   car's own indicator is the authority.
/// - Kia and Mazda coolant are the first fill; the second comes sooner.
///   Recorded as a sharp edge, not modelled.
const makeIntervals = <MakeInterval>[
  // VAG: one regime, four badges.
  MakeInterval('skoda', _oil, km: 15000, months: 12, spikeRow: 'Škoda'),
  MakeInterval('skoda', _cabin, km: 30000, months: 24, spikeRow: 'Škoda'),
  MakeInterval('skoda', _air, km: 60000, months: 48, spikeRow: 'Škoda'),
  MakeInterval(
    'volkswagen',
    _oil,
    km: 15000,
    months: 12,
    spikeRow: 'Volkswagen',
  ),
  MakeInterval(
    'volkswagen',
    _cabin,
    km: 30000,
    months: 24,
    spikeRow: 'Volkswagen',
  ),
  MakeInterval(
    'volkswagen',
    _air,
    km: 60000,
    months: 48,
    spikeRow: 'Volkswagen',
  ),
  MakeInterval('seat', _oil, km: 15000, months: 12, spikeRow: 'Seat / Cupra'),
  MakeInterval('seat', _cabin, km: 30000, months: 24, spikeRow: 'Seat / Cupra'),
  MakeInterval('seat', _air, km: 60000, months: 48, spikeRow: 'Seat / Cupra'),
  MakeInterval('audi', _oil, km: 15000, months: 12, spikeRow: 'Audi'),
  MakeInterval('audi', _cabin, km: 30000, months: 24, spikeRow: 'Audi'),
  MakeInterval('audi', _air, km: 60000, months: 48, spikeRow: 'Audi'),

  // Stellantis.
  MakeInterval('opel', _oil, km: 25000, months: 12, spikeRow: 'Opel'),
  MakeInterval('opel', _coolant, months: 60, spikeRow: 'Opel'),
  MakeInterval('opel', _air, km: 30000, months: 24, spikeRow: 'Opel'),
  MakeInterval('peugeot', _oil, km: 25000, months: 12, spikeRow: 'Peugeot'),
  MakeInterval('peugeot', _coolant, months: 60, spikeRow: 'Peugeot'),
  MakeInterval('peugeot', _cabin, months: 12, spikeRow: 'Peugeot'),
  MakeInterval('peugeot', _air, km: 30000, months: 24, spikeRow: 'Peugeot'),
  MakeInterval('citroen', _oil, km: 25000, months: 12, spikeRow: 'Citroën'),
  MakeInterval('citroen', _coolant, months: 60, spikeRow: 'Citroën'),
  MakeInterval('citroen', _cabin, months: 12, spikeRow: 'Citroën'),
  MakeInterval('citroen', _air, km: 30000, months: 24, spikeRow: 'Citroën'),
  MakeInterval('fiat', _oil, km: 15000, months: 12, spikeRow: 'Fiat'),
  MakeInterval('fiat', _coolant, km: 120000, months: 60, spikeRow: 'Fiat'),
  MakeInterval('fiat', _air, km: 60000, months: 48, spikeRow: 'Fiat'),

  // Renault group.
  MakeInterval('renault', _oil, km: 15000, months: 12, spikeRow: 'Renault'),
  MakeInterval('renault', _coolant, months: 60, spikeRow: 'Renault'),
  MakeInterval('renault', _air, km: 60000, months: 48, spikeRow: 'Renault'),
  MakeInterval('dacia', _oil, km: 15000, months: 12, spikeRow: 'Dacia'),
  MakeInterval('dacia', _coolant, km: 90000, months: 60, spikeRow: 'Dacia'),
  MakeInterval('dacia', _cabin, km: 15000, months: 12, spikeRow: 'Dacia'),
  MakeInterval('dacia', _air, km: 30000, months: 24, spikeRow: 'Dacia'),

  // Japanese and Korean.
  MakeInterval('toyota', _oil, km: 15000, months: 12, spikeRow: 'Toyota'),
  MakeInterval('toyota', _coolant, km: 160000, months: 96, spikeRow: 'Toyota'),
  MakeInterval('toyota', _air, km: 30000, spikeRow: 'Toyota'),
  MakeInterval('suzuki', _oil, km: 15000, months: 12, spikeRow: 'Suzuki'),
  MakeInterval('suzuki', _air, km: 30000, spikeRow: 'Suzuki'),
  MakeInterval('hyundai', _oil, km: 15000, months: 12, spikeRow: 'Hyundai'),
  MakeInterval(
    'hyundai',
    _coolant,
    km: 120000,
    months: 96,
    spikeRow: 'Hyundai',
  ),
  MakeInterval('hyundai', _air, km: 45000, spikeRow: 'Hyundai'),
  MakeInterval('kia', _oil, km: 15000, months: 12, spikeRow: 'Kia'),
  MakeInterval('kia', _coolant, km: 210000, months: 120, spikeRow: 'Kia'),
  MakeInterval('kia', _cabin, km: 30000, months: 24, spikeRow: 'Kia'),
  MakeInterval('kia', _air, km: 60000, months: 48, spikeRow: 'Kia'),
  MakeInterval('mazda', _oil, km: 20000, months: 12, spikeRow: 'Mazda'),
  MakeInterval('mazda', _coolant, km: 200000, months: 120, spikeRow: 'Mazda'),
  MakeInterval('mazda', _cabin, km: 40000, months: 24, spikeRow: 'Mazda'),
  MakeInterval('mazda', _air, km: 60000, months: 36, spikeRow: 'Mazda'),
  MakeInterval('nissan', _oil, km: 15000, months: 12, spikeRow: 'Nissan'),
  MakeInterval('nissan', _coolant, km: 145000, months: 96, spikeRow: 'Nissan'),
  MakeInterval('nissan', _cabin, km: 30000, months: 24, spikeRow: 'Nissan'),
  MakeInterval('nissan', _air, km: 30000, months: 24, spikeRow: 'Nissan'),

  // German premium and Ford: oil is condition-based, so no oil row.
  MakeInterval(
    'mercedes_benz',
    _oil,
    km: 25000,
    months: 12,
    spikeRow: 'Mercedes-Benz',
  ),
  MakeInterval('mercedes_benz', _cabin, months: 24, spikeRow: 'Mercedes-Benz'),
  MakeInterval('bmw', _cabin, months: 24, spikeRow: 'BMW'),
  MakeInterval('bmw', _air, km: 60000, months: 48, spikeRow: 'BMW'),
  MakeInterval('ford', _coolant, km: 150000, months: 120, spikeRow: 'Ford'),
];
