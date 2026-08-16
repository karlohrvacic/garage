import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_redirect.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link outside the app.
typedef UrlOpener = Future<void> Function(Uri url);

/// Leaving the app is a side effect like any other, so it goes through a
/// provider: screens ask for an opener rather than calling the plugin, and
/// tests substitute a recorder for the browser.
final urlOpenerProvider = Provider<UrlOpener>((ref) {
  return (url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  };
});

/// The public pages the app links out to. Both are served by the web build
/// (`web/privacy.html`, `web/delete-account.html`) and are the URLs declared
/// in the Play Console listing.
abstract final class GarageLinks {
  static const host = 'garage.hrva.cc';

  static final Uri privacyPolicy = Uri.parse('https://$host/privacy');

  /// The link that carries an invite code.
  ///
  /// A code alone has to be read out, retyped, and typed correctly. The link
  /// opens the app straight onto the invite when it is installed (Android app
  /// links verify this host) and the web app when it is not, so the person
  /// invited does not have to know which they have.
  static Uri invite(String code) =>
      Uri.parse('https://$host$joinRoute/${code.toUpperCase()}');

  static Uri mapSearch({required double lat, required double lng}) {
    final query = Uri.encodeComponent('$lat,$lng');
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  }
}
