import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/auth_link.dart';

void main() {
  test('a link that worked carries no error', () {
    expect(authErrorFromUrl(Uri.parse('https://garage.hrva.cc/')), isNull);
  });

  test('an expired confirmation link says so, in the fragment', () {
    // Where the implicit flow puts it, and where nothing was looking: the
    // user followed the link the email asked them to and arrived at a screen
    // that said nothing at all.
    final url = Uri.parse(
      'https://garage.hrva.cc/#error=access_denied&error_code=otp_expired'
      '&error_description=Email+link+is+invalid+or+has+expired',
    );

    expect(authErrorFromUrl(url), 'Email link is invalid or has expired');
  });

  test('and in the query, which is where the other flow puts it', () {
    final url = Uri.parse(
      'https://garage.hrva.cc/?error=access_denied'
      '&error_description=Email+link+is+invalid+or+has+expired',
    );

    expect(authErrorFromUrl(url), 'Email link is invalid or has expired');
  });

  test('a bare error code is still better than nothing', () {
    final url = Uri.parse('https://garage.hrva.cc/#error=access_denied');

    expect(authErrorFromUrl(url), 'access_denied');
  });

  test('a session arriving normally is not mistaken for an error', () {
    final url = Uri.parse(
      'https://garage.hrva.cc/#access_token=abc&token_type=bearer',
    );

    expect(authErrorFromUrl(url), isNull);
  });

  test('an empty description falls through to the code', () {
    final url = Uri.parse(
      'https://garage.hrva.cc/#error=access_denied&error_description=',
    );

    expect(authErrorFromUrl(url), 'access_denied');
  });

  test('a fragment that is not query-shaped does not throw', () {
    expect(
      authErrorFromUrl(Uri.parse('https://garage.hrva.cc/#/vehicles')),
      isNull,
      reason: 'hash routing leaves paths here, and they are not errors',
    );
  });
}
