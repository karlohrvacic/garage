import 'package:flutter_test/flutter_test.dart';
import 'package:garage/domain/maintenance/make_key.dart';

void main() {
  test('case, diacritics and whitespace do not make a second make', () {
    expect(MakeKey.of('Škoda'), 'skoda');
    expect(MakeKey.of('SKODA'), 'skoda');
    expect(MakeKey.of('  skoda '), 'skoda');
    expect(MakeKey.of('Citroën'), 'citroen');
  });

  test('the common abbreviations are the make they abbreviate', () {
    expect(MakeKey.of('VW'), 'volkswagen');
    expect(MakeKey.of('Mercedes'), 'mercedes_benz');
    expect(MakeKey.of('Mercedes-Benz'), 'mercedes_benz');
    expect(MakeKey.of('Cupra'), 'seat');
  });

  test('a make nobody has a row for still normalises', () {
    expect(MakeKey.of('Geely'), 'geely');
    expect(MakeKey.of('Alfa Romeo'), 'alfaromeo');
  });

  test('nothing gives nothing', () {
    expect(MakeKey.of(null), isNull);
    expect(MakeKey.of(''), isNull);
    expect(MakeKey.of('   '), isNull);
    expect(MakeKey.of('---'), isNull);
  });
}
