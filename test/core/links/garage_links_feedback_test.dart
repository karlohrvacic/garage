import 'package:flutter_test/flutter_test.dart';
import 'package:garage/core/links/url_opener.dart';

void main() {
  group('the feedback email link', () {
    test('addresses the support inbox the Play listing already declares', () {
      final uri = GarageLinks.feedback(subject: 'Garage feedback');

      expect(uri.scheme, 'mailto');
      expect(uri.path, 'privacy@hrva.cc');
    });

    test('carries the subject as a query parameter', () {
      final uri = GarageLinks.feedback(subject: 'Garage feedback');

      expect(uri.queryParameters['subject'], 'Garage feedback');
    });

    test('the body is optional, and absent when not given', () {
      final uri = GarageLinks.feedback(subject: 'Garage feedback');

      expect(uri.queryParameters.containsKey('body'), isFalse);
    });

    test('a given body is carried too', () {
      final uri = GarageLinks.feedback(
        subject: 'Garage feedback',
        body: 'Garage 1.3.1 (5)\n\n',
      );

      expect(uri.queryParameters['body'], 'Garage 1.3.1 (5)\n\n');
    });

    test('special characters survive the round trip through Uri parsing', () {
      // A mailto: URI is text some app has to parse back out; an ampersand or
      // a newline written raw would either corrupt the query string or vanish
      // into the next field.
      final uri = GarageLinks.feedback(
        subject: 'Bug & crash report',
        body: 'Line one\nLine two',
      );
      final reparsed = Uri.parse(uri.toString());

      expect(reparsed.queryParameters['subject'], 'Bug & crash report');
      expect(reparsed.queryParameters['body'], 'Line one\nLine two');
    });
  });
}
