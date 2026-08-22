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

/// The public pages the app links out to. Two are served by the web build
/// (`web/privacy.html`, `web/delete-account.html`) and are the URLs declared
/// in the Play Console listing; the third is the source itself.
abstract final class GarageLinks {
  static const host = 'garage.hrva.cc';

  static final Uri privacyPolicy = Uri.parse('https://$host/privacy');

  /// Where the source is, which under the AGPL is not a courtesy.
  ///
  /// Section 13 obliges an instance people reach over a network to offer them
  /// its source, and the web build is exactly that. So this link is a licence
  /// term wearing the clothes of a menu row: the About screen shows it, and
  /// `test/features/settings/about_screen_test.dart` fails if it stops.
  static final Uri sourceCode = Uri.parse(
    'https://github.com/karlohrvacic/garage',
  );

  /// The public page describing what the app does.
  ///
  /// A visitor to garage.hrva.cc is redirected straight to a sign-in form and
  /// told nothing: the app has no landing page, so the only thing a person who
  /// has not already decided to use it ever sees is a password box.
  static final Uri features = Uri.parse('https://$host/features');

  /// Where an emailed confirmation link comes back to.
  ///
  /// The web build is served from this host, so the app is already there to
  /// pick up the session. On Android the same URL opens the web app when the
  /// link is followed on another device, which is the common case: people
  /// register on a phone and open their mail on a laptop.
  static final Uri confirmEmail = Uri.parse('https://$host/');

  /// The link that carries an invite code.
  ///
  /// A code alone has to be read out, retyped, and typed correctly. The link
  /// opens the app straight onto the invite when it is installed (Android app
  /// links verify this host) and the web app when it is not, so the person
  /// invited does not have to know which they have.
  static Uri invite(String code) =>
      Uri.parse('https://$host$joinRoute/${code.toUpperCase()}');

  /// The URL the Android launcher's fill-up shortcut and home-screen widget
  /// open.
  ///
  /// Built here rather than written into the Android resources alone so that
  /// one file decides what the app's own links look like, and so
  /// `test/ci/launcher_entry_points_test.dart` has something to compare the
  /// resource against. Nothing in the app opens this: the shortcut hands it to
  /// the activity, and Flutter turns it into the initial route.
  static final Uri logFuel = Uri.parse('https://$host$quickFuelRoute');

  static Uri mapSearch({required double lat, required double lng}) {
    final query = Uri.encodeComponent('$lat,$lng');
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
  }
}
