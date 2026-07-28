import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/theme/garage_tokens.dart';
import 'package:garage/core/widgets/gauge_arc.dart';

void main() {
  const tokens = GarageTokens.dark;

  test('healthy fractions render in accent', () {
    expect(GaugeArc.gaugeColor(tokens, 1.0), tokens.accent);
    expect(GaugeArc.gaugeColor(tokens, 0.5), tokens.accent);
    expect(GaugeArc.gaugeColor(tokens, 0.16), tokens.accent);
  });

  test('depleted fractions render in danger', () {
    expect(GaugeArc.gaugeColor(tokens, 0.15), tokens.danger);
    expect(GaugeArc.gaugeColor(tokens, 0.0), tokens.danger);
  });

  test('out-of-range fractions are clamped', () {
    expect(GaugeArc.gaugeColor(tokens, 1.4), tokens.accent);
    expect(GaugeArc.gaugeColor(tokens, -0.2), tokens.danger);
  });
}
