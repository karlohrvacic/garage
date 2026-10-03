import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/workflow_steps.dart';

/// The first download has a budget (decision 189), checked after every web
/// build, so growth is a decision someone makes in a pull request rather than
/// something noticed a year later as a slow page.
void main() {
  final budget =
      jsonDecode(File('scripts/web_budget.json').readAsStringSync()) as Map;
  final files = (budget['files'] as Map).cast<String, Object?>();

  test('names the app, its renderers and its fonts, each in kilobytes', () {
    expect(
      files.keys,
      containsAll([
        'main.dart.wasm',
        'main.dart.js',
        'canvaskit/skwasm.wasm',
        // What Firefox and Safari fetch with main.dart.js, and the largest
        // file of all; the chromium variant beside it in the budget is only
        // for a Chromium browser that cannot run the wasm.
        'canvaskit/canvaskit.wasm',
        'assets/fonts/*.ttf',
      ]),
    );
    for (final MapEntry(:key, :value) in files.entries) {
      expect(
        value,
        isA<int>().having((kb) => kb, 'KB', greaterThan(0)),
        reason: key,
      );
    }
  });

  for (final path in [
    '.github/workflows/deploy-web.yml',
    '.github/workflows/ci.yml',
  ]) {
    test('$path checks it after the fonts are cut', () {
      final workflow = File(path).readAsStringSync();
      final fonts = workflow.indexOf('scripts/subset_web_fonts.sh');
      final budgetStep = workflow.indexOf('scripts/web_budget.py');
      expect(fonts, isNonNegative);
      expect(budgetStep, greaterThan(fonts));
    });
  }

  test('and the deploy stops before an over-budget build goes out', () {
    final web = File('.github/workflows/deploy-web.yml').readAsStringSync();
    final deploy = web.indexOf('command: deploy');
    final budgetStep = web.indexOf('scripts/web_budget.py');
    expect(deploy, isNonNegative, reason: 'no step runs `command: deploy`');
    expect(budgetStep, isNonNegative, reason: 'no step runs the budget');
    expect(budgetStep, lessThan(deploy));
  });

  test(
    'ci.yml checks it only when it has built the app; the deploy, always',
    () {
      // On main the deploy calls ci.yml, which then builds no web app: a check
      // that ran anyway would find no build/web and fail the deploy's checks.
      // The deploy always builds, and its step copied from ci.yml with the
      // pull-request condition would skip the budget on every push to main.
      final ci = File('.github/workflows/ci.yml').readAsStringSync();
      final build = conditionOf(ci, 'flutter build web');
      expect(
        build,
        isNotNull,
        reason: 'the web build here is pull requests only',
      );
      expect(conditionOf(ci, 'scripts/web_budget.py'), build);

      final web = File('.github/workflows/deploy-web.yml').readAsStringSync();
      expect(conditionOf(web, 'scripts/web_budget.py'), isNull);
    },
  );
}
