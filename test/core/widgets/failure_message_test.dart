import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/errors/app_failure.dart';
import 'package:garage/core/errors/failure_log.dart';
import 'package:garage/core/widgets/failure_message.dart';
import 'package:garage/l10n/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final l10n = AppLocalizationsEn();

  // The log outlives a restart now, so clearing it reaches storage and storage
  // needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await clearRecordedFailures();
  });

  test('a person is told something they can act on, not a backend message', () {
    final message = failureMessage(
      l10n,
      const AppFailure(
        kind: AppFailureKind.network,
        debugMessage: 'ClientException: Connection reset by peer',
      ),
    );

    expect(message, l10n.errorNoConnection);
    expect(message, isNot(contains('ClientException')));
  });

  test('showing a failure records what actually went wrong', () {
    failureMessage(
      l10n,
      const AppFailure(
        kind: AppFailureKind.unknown,
        debugMessage: 'AuthApiException: Unacceptable audience in id_token',
      ),
    );

    expect(
      recordedFailures.single,
      contains('Unacceptable audience'),
      reason: 'a generic sentence on screen must not mean a lost cause in logs',
    );
  });

  test('every kind maps to a message', () {
    for (final kind in AppFailureKind.values) {
      expect(failureMessage(l10n, AppFailure(kind: kind)), isNotEmpty);
    }
  });
}
