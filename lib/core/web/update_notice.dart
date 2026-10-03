import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:garage/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../app_info.dart';

/// Whether this build checks for a newer one: the web only. A phone is
/// updated by Play, and a test has no server to ask.
final updateCheckEnabledProvider = Provider<bool>((ref) => kIsWeb);

/// The build number the site is serving now, from the `version.json` Flutter
/// writes beside the app, or null when it cannot be read.
final publishedBuildProvider = Provider<Future<String?> Function()>((ref) {
  return () async {
    final address = Uri.base
        .resolve('/version.json')
        .replace(
          queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'},
        );
    final response = await http.get(address);
    if (response.statusCode != 200) {
      return null;
    }
    final body = jsonDecode(response.body);
    return body is Map ? body['build_number']?.toString() : null;
  };
});

/// Loads the page again, which is how a browser takes up a new build.
final pageReloaderProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    await launchUrl(Uri.base, webOnlyWindowName: '_self');
  };
});

/// Whether [published] is newer than [running]. Build numbers are the commit
/// count, so newer is larger; anything unreadable is not newer.
bool isNewerBuild({required String running, required String? published}) {
  final now = int.tryParse(running);
  final next = int.tryParse(published ?? '');
  return now != null && next != null && next > now;
}

/// Tells a tab that has been open a while that a newer build is out.
///
/// A browser runs the build it loaded until the page is loaded again, and a
/// desk leaves the app open for days, so a fix shipped on Monday was still
/// missing on Friday. The check runs when the tab comes back into view and
/// every half hour; the notice waits for the reader to reload rather than
/// reloading for them, because a half-typed fill-up would go with the page.
class UpdateNotice extends ConsumerStatefulWidget {
  const UpdateNotice({required this.child, super.key});

  final Widget child;

  static const Duration interval = Duration(minutes: 30);

  @override
  ConsumerState<UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends ConsumerState<UpdateNotice> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  /// Once said, not repeated every half hour until the reload.
  bool _told = false;

  @override
  void initState() {
    super.initState();
    if (!ref.read(updateCheckEnabledProvider)) {
      return;
    }
    _timer = Timer.periodic(UpdateNotice.interval, (_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_told || !mounted) {
      return;
    }
    final String? published;
    try {
      published = await ref.read(publishedBuildProvider)();
    } on Object {
      // Offline, or an answer that is not the file: the next check asks
      // again, and there is nothing worth telling anybody.
      return;
    }
    if (!mounted ||
        !isNewerBuild(running: AppInfo.build, published: published)) {
      return;
    }
    _told = true;
    final l10n = AppLocalizations.of(context)!;
    // Read now: the notice sits in the app's messenger and can outlive this.
    final reload = ref.read(pageReloaderProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.webUpdateReady),
        duration: const Duration(days: 1),
        action: SnackBarAction(
          label: l10n.webUpdateReload,
          onPressed: () => reload(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
