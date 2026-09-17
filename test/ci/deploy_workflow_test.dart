import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks on the deploy configuration itself. None of this is exercised by the
/// app's tests, and every item here has a failure mode that only shows up in a
/// release: a bundle Play rejects, or an Android build configured differently
/// from the web one against the same database.
String get _play =>
    File('.github/workflows/deploy-play.yml').readAsStringSync();

String get _web => File('.github/workflows/deploy-web.yml').readAsStringSync();

String get _ci => File('.github/workflows/ci.yml').readAsStringSync();

String get _functions =>
    File('.github/workflows/deploy-functions.yml').readAsStringSync();

void main() {
  /// Defines that are legitimately one platform's own. Anything outside this
  /// set must match across both, so a divergence is always a deliberate entry
  /// here rather than something that drifted.
  ///
  /// Push is Android-only because web push additionally needs a service worker
  /// (`firebase-messaging-sw.js`) that is not written; handing the web build
  /// Firebase config without one would half-enable a feature that cannot work.
  const platformSpecific = {
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
  };

  test('every job pins the same Flutter, rather than floating on stable', () {
    // A job that only says `channel: stable` picks up whatever Flutter is
    // newest that morning, so a tree that formats clean today fails tomorrow
    // with nobody having touched it — which is exactly how this was found.
    // The deploy jobs were already pinned; CI was not, so the suite deciding
    // whether code may ship ran on a different SDK from the one that ships.
    final pins = <String>{};
    for (final workflow in [_ci, _web, _play]) {
      for (final line in workflow.split('\n')) {
        if (line.contains('flutter-version:')) {
          pins.add(line.split(':').last.replaceAll(RegExp(r"[\s']"), ''));
        }
      }
      expect(
        RegExp(r'uses: subosito/flutter-action').allMatches(workflow).length,
        RegExp(r'flutter-version:').allMatches(workflow).length,
        reason: 'a Flutter setup step in this workflow pins no version',
      );
    }

    expect(
      pins,
      hasLength(1),
      reason: 'workflows disagree on a version: $pins',
    );
  });

  test('the tenancy job hands the suite every key it asks for', () {
    // The suite stops in setUpAll when one is missing, and a stopped setUpAll
    // reports "0 tests passed, 2 failed" with no clue which key or why. The
    // account-deletion cases need the service role, and the job exported only
    // the anon key until they existed.
    final suite = File('test_rls/rls_test.dart').readAsStringSync();
    final wanted = RegExp(
      r"Platform\.environment\['(\w+)'\]",
    ).allMatches(suite).map((match) => match.group(1)!).toSet();

    expect(wanted, contains('SUPABASE_SERVICE_ROLE_KEY'));
    for (final key in wanted) {
      expect(_ci, contains('$key='), reason: 'the rls job never exports $key');
    }
  });

  test('web and Android are built against the same configuration', () {
    final defines = RegExp(r'--dart-define=(\w+)=');
    final webKeys = defines.allMatches(_web).map((m) => m.group(1)!).toSet();
    final playKeys = defines.allMatches(_play).map((m) => m.group(1)!).toSet();

    expect(
      playKeys.difference(platformSpecific),
      webKeys.difference(platformSpecific),
      reason:
          'a define on one platform and not the other means the two talk to '
          'different backends, or one loses Google sign-in',
    );
  });

  test('every Android-only define is passed a secret, not left empty', () {
    // An unset secret is an empty string, which silently disables push rather
    // than failing the build — so the wiring is what has to be checked here.
    for (final define in platformSpecific) {
      expect(
        _play,
        contains('$define: \${{ secrets.$define }}'),
        reason: '$define is passed to the build but never read from secrets',
      );
    }
  });

  test('the bundle is uploaded under the id the app is built with', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final applicationId = RegExp(
      r'applicationId\s*=\s*"([^"]+)"',
    ).firstMatch(gradle)!.group(1);

    expect(_play, contains('packageName: $applicationId'));
  });

  test('signing is required, not silently skipped', () {
    // build.gradle.kts falls back to debug signing when key.properties is
    // absent. In CI that would produce a bundle Play refuses, after a full
    // build — so the workflow has to fail before building instead.
    expect(
      _play,
      contains('ANDROID_KEYSTORE_BASE64'),
      reason: 'the release must be signed with the upload key',
    );
    expect(_play.contains('exit 1'), isTrue);
  });

  /// The tag is the release: it names the version, the track and, on
  /// production, how far the release goes. A shell step decides all three, so
  /// it is run here against the refs a release really pushes rather than read.
  /// The upload action refuses `inProgress` without a fraction and `completed`
  /// with one, and it says so only after a full build.
  group('a tag chooses the track and the rollout', () {
    /// The `run:` block of the step with `id: version`, outdented into a
    /// script.
    String versionScript() {
      final lines = _play.split('\n');
      final step = lines.indexWhere((line) => line.trim() == 'id: version');
      final run = lines.indexWhere((line) => line.trim() == 'run: |', step);
      final indent = lines[run].indexOf('run:') + 2;
      return lines
          .skip(run + 1)
          .takeWhile(
            (line) => line.trim().isEmpty || line.startsWith(' ' * indent),
          )
          .map((line) => line.length > indent ? line.substring(indent) : '')
          .join('\n');
    }

    /// A repository of its own, so what `git` answers does not depend on how
    /// the machine running the tests cloned this one: CI checks out without
    /// tags. It has one commit, [tags] on it, and this repo's pubspec.
    Directory checkout(List<String> tags) {
      final directory = Directory.systemTemp.createTempSync('garage-checkout');
      addTearDown(() => directory.deleteSync(recursive: true));
      File('pubspec.yaml').copySync('${directory.path}/pubspec.yaml');
      void git(List<String> args) {
        final result = Process.runSync('git', [
          '-c', 'user.email=ci@example.com', '-c', 'user.name=ci', //
          '-c', 'commit.gpgsign=false', '-c', 'tag.gpgsign=false',
          ...args,
        ], workingDirectory: directory.path);
        expect(result.exitCode, 0, reason: '${result.stderr}');
      }

      git(['init', '-q']);
      git(['add', 'pubspec.yaml']);
      git(['commit', '-q', '-m', 'release']);
      for (final tag in tags) {
        git(['tag', tag]);
      }
      return directory;
    }

    ({int exitCode, String log, Map<String, String> outputs}) release({
      required String refType,
      String refName = '',
      String chosenTrack = '',
      List<String> tags = const [],
    }) {
      final directory = Directory.systemTemp.createTempSync('garage-release');
      addTearDown(() => directory.deleteSync(recursive: true));
      final outputs = File('${directory.path}/outputs')..createSync();
      final script = File('${directory.path}/version.sh')
        ..writeAsStringSync(versionScript());
      final repository = checkout(tags);

      // What Actions runs a step with when it says `shell: bash`. Left
      // unsaid, the step gets plain `bash -e`: no pipefail, and a failed
      // `grep | awk | cut` ships an empty version name instead of stopping.
      final result = Process.runSync(
        'bash',
        ['--noprofile', '--norc', '-eo', 'pipefail', script.path],
        environment: {
          'GITHUB_REF_TYPE': refType,
          'GITHUB_REF_NAME': refName,
          'GITHUB_OUTPUT': outputs.path,
          'CHOSEN_TRACK': chosenTrack,
        },
        workingDirectory: repository.path,
      );
      return (
        exitCode: result.exitCode,
        log: '${result.stdout}${result.stderr}',
        outputs: {
          for (final line in outputs.readAsLinesSync())
            if (line.contains('='))
              line.substring(0, line.indexOf('=')): line.substring(
                line.indexOf('=') + 1,
              ),
        },
      );
    }

    const tags = {
      'v1.7.0': (track: 'alpha', status: 'completed', fraction: ''),
      'v1.7.0-internal': (track: 'internal', status: 'completed', fraction: ''),
      'v1.7.0-beta': (track: 'beta', status: 'completed', fraction: ''),
      'v1.7.0-production': (
        track: 'production',
        status: 'completed',
        fraction: '',
      ),
      'v1.7.0-staged': (
        track: 'production',
        status: 'inProgress',
        fraction: '0.2',
      ),
    };

    for (final MapEntry(key: tag, value: want) in tags.entries) {
      test('$tag is 1.7.0 on ${want.track}, ${want.status}', () {
        final got = release(refType: 'tag', refName: tag);

        expect(got.exitCode, 0, reason: got.log);
        expect(got.outputs['name'], '1.7.0');
        expect(got.outputs['track'], want.track);
        expect(got.outputs['status'], want.status);
        expect(got.outputs['fraction'], want.fraction);
      });
    }

    test('the step asks for the shell this file runs it in', () {
      final lines = _play.split('\n');
      final step = lines.indexWhere((line) => line.trim() == 'id: version');
      final run = lines.indexWhere((line) => line.trim() == 'run: |', step);

      expect(
        lines.sublist(step, run).map((line) => line.trim()),
        contains('shell: bash'),
        reason: 'without it Actions drops pipefail and these tests prove less',
      );
    });

    test('a tag with no version in it stops the job', () {
      // `v-staged` matches the `v*` trigger, and an empty name would build.
      for (final tag in ['v-staged', 'v-production', 'v1.7-production']) {
        expect(
          release(refType: 'tag', refName: tag).exitCode,
          1,
          reason: tag,
        );
      }
    });

    test('a release with no track stops rather than reaching the upload', () {
      // The upload action reads an empty `tracks` as production.
      final got = release(refType: 'branch', refName: 'main');

      expect(got.exitCode, 1);
    });

    test('an unknown suffix stops the job and names the ones that exist', () {
      final got = release(refType: 'tag', refName: 'v1.7.0-prod');

      expect(got.exitCode, 1);
      for (final suffix in ['-internal', '-beta', '-production', '-staged']) {
        expect(got.log, contains(suffix));
      }
    });

    test('a manual run is a full release to the track from the dropdown', () {
      // An empty `status` is not the action's default but an invalid one, so
      // the path with no tag has to say `completed` for itself.
      final got = release(
        refType: 'branch',
        refName: 'main',
        chosenTrack: 'production',
      );

      expect(got.exitCode, 0, reason: got.log);
      expect(got.outputs['name'], matches(RegExp(r'^\d+\.\d+\.\d+$')));
      expect(got.outputs['track'], 'production');
      expect(got.outputs['status'], 'completed');
      expect(got.outputs['fraction'], '');
    });

    test('a manual run from a branch is the version the tags are at', () {
      // Without a tag of its own the run used pubspec's version, which nobody
      // maintains: 1.3.1 while the releases were past 1.6.
      final got = release(
        refType: 'branch',
        refName: 'main',
        chosenTrack: 'internal',
        tags: ['v2.4.0-staged'],
      );

      expect(got.exitCode, 0, reason: got.log);
      expect(got.outputs['name'], '2.4.0');
    });

    test('and pubspec only when there are no tags at all', () {
      final version = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);

      final got = release(
        refType: 'branch',
        refName: 'main',
        chosenTrack: 'internal',
      );

      expect(got.exitCode, 0, reason: got.log);
      expect(got.outputs['name'], version);
    });

    test('a manual run started from a staged tag is not staged', () {
      // The dropdown can be run against any ref, a tag included. Left to the
      // tag, `-staged` plus "internal" would ask Play to stage a track that
      // cannot be staged, and say so after the build.
      final got = release(
        refType: 'tag',
        refName: 'v1.7.0-staged',
        chosenTrack: 'internal',
      );

      expect(got.exitCode, 0, reason: got.log);
      expect(got.outputs['name'], '1.7.0');
      expect(got.outputs['track'], 'internal');
      expect(got.outputs['status'], 'completed');
      expect(got.outputs['fraction'], '');
    });

    test('the upload is told what the tag decided', () {
      expect(_play, contains(r'tracks: ${{ steps.version.outputs.track }}'));
      expect(_play, contains(r'status: ${{ steps.version.outputs.status }}'));
      expect(
        _play,
        contains(r'userFraction: ${{ steps.version.outputs.fraction }}'),
      );
    });

    test('the runbook names the share the workflow starts at', () {
      final fraction = release(
        refType: 'tag',
        refName: 'v1.7.0-staged',
      ).outputs['fraction'];
      expect(fraction, isNotNull, reason: 'a staged tag sets no fraction');
      final percent = (double.parse(fraction!) * 100).round();

      // The row of the tag table, not any mention of a percentage: the same
      // runbook also says what the share used to be and what it cannot be.
      final promised = RegExp(
        r'-staged` \| production, (\d+)% of users',
      ).firstMatch(File('docs/RUNBOOK-update.md').readAsStringSync())?.group(1);

      expect(
        promised,
        '$percent',
        reason: 'the runbook promises a different share from the one uploaded',
      );
    });
  });

  /// The full description had no length test, unlike the release notes, and
  /// both languages were sitting ten characters under Play's cap — so the next
  /// feature worth a sentence had nowhere to go and nothing would have said so
  /// until the upload was rejected.
  group('the store listing', () {
    final listing = File('docs/play-store-listing.md').readAsStringSync();

    /// The fenced blocks under "Full description", in document order: English
    /// then Croatian. Read from the document rather than duplicated here,
    /// because a copy is one more thing to keep in step with the thing it
    /// describes.
    List<String> fullDescriptions() {
      final body = listing
          .split('## Full description')
          .last
          .split('## Graphic assets')
          .first;
      return [
        for (final match in RegExp(
          r'^```\n(.*?)^```',
          multiLine: true,
          dotAll: true,
        ).allMatches(body))
          match.group(1)!.trim(),
      ];
    }

    test('carries a full description for every language the app ships in', () {
      // Read from `lib/l10n/` rather than counted: Italian was added to the
      // app and its listing written afterwards, and a hard-coded two would
      // have gone on passing with the shop window a language short.
      final locales = Directory('lib/l10n')
          .listSync()
          .map((file) => RegExp(r'app_(\w+)\.arb$').firstMatch(file.path))
          .nonNulls
          .length;

      expect(fullDescriptions(), hasLength(locales));
    });

    test('keeps each within the 4000 characters Play accepts', () {
      for (final description in fullDescriptions()) {
        expect(
          description.length,
          lessThanOrEqualTo(4000),
          reason:
              'Play rejects a longer one; adding a line here means trimming '
              'another, the same trade the 500-character release notes make',
        );
      }
    });

    /// The backtick-quoted value on each language's bullet, within one
    /// section. Scoped by heading because the title and the short description
    /// are written the same way, and a regex over the whole file happily
    /// measures one against the other's cap.
    List<String> quotedUnder(String heading) {
      final section = listing.split(heading).last.split('\n## ').first;
      return [
        for (final match in RegExp(
          r'\*\*(?:English|Hrvatski):\*\*\s+`([^`]+)`',
        ).allMatches(section))
          match.group(1)!,
      ];
    }

    test('keeps each store title within 30', () {
      final titles = quotedUnder('## Store title');
      expect(titles, hasLength(2), reason: 'one title per language');
      for (final title in titles) {
        expect(title.length, lessThanOrEqualTo(30));
      }
    });

    test('keeps each short description within 80', () {
      final shorts = quotedUnder('## Short description');
      expect(
        shorts,
        hasLength(2),
        reason: 'one short description per language',
      );
      for (final short in shorts) {
        expect(short.length, lessThanOrEqualTo(80));
      }
    });
  });

  group('release notes', () {
    final directory = Directory('distribution/whatsnew');

    test('exist for every language the app itself ships in', () {
      // Read from `lib/l10n/` rather than listed here. Italian was added to
      // the app in one change and would have shipped to Italian testers with
      // release notes in English, which nothing else would have caught: the
      // ARB tests check translations exist, not that the shop window keeps up.
      final locales = Directory('lib/l10n')
          .listSync()
          .map((file) => RegExp(r'app_(\w+)\.arb$').firstMatch(file.path))
          .nonNulls
          .map((match) => match.group(1)!)
          .toSet();
      final names = directory
          .listSync()
          .map((entry) => entry.uri.pathSegments.last)
          .toSet();

      expect(locales, contains('en'), reason: 'guards the guard');
      for (final locale in locales) {
        expect(
          names.any((name) => name.startsWith('whatsnew-$locale')),
          isTrue,
          reason:
              'the app ships in $locale and has no release notes in it; Play '
              'would describe this release to those testers in English',
        );
      }
    });

    test('are within the 500 characters Play accepts', () {
      for (final file in directory.listSync().whereType<File>()) {
        expect(
          file.readAsStringSync().trim().length,
          lessThanOrEqualTo(500),
          reason: '${file.path} would be rejected at upload',
        );
      }
    });
  });

  group('the edge functions deploy themselves', () {
    /// Every directory under `supabase/functions` that is actually a
    /// function: one with an `index.ts` the platform can serve. `_test` holds
    /// the shared fake and has none.
    Set<String> functionDirectories() {
      return {
        for (final entry in Directory('supabase/functions').listSync())
          if (entry is Directory && File('${entry.path}/index.ts').existsSync())
            entry.path.split(Platform.pathSeparator).last,
      };
    }

    test('the directory scan finds the functions that exist', () {
      expect(functionDirectories(), contains('public-api'));
      expect(functionDirectories(), isNot(contains('_test')));
    });

    test('and the workflow names every one of them', () {
      // The deploy list is written out rather than globbed, on purpose: a
      // directory added later should be a decision. This is what makes
      // forgetting that decision loud — otherwise a fifth function would ship
      // its code to git and never to Supabase, and the old one would keep
      // answering correctly with last month's behaviour.
      for (final name in functionDirectories()) {
        expect(
          _functions,
          contains(name),
          reason: '$name is a function the deploy workflow never deploys',
        );
      }
    });

    test('it checks the functions before it deploys them', () {
      // `deno check` is the only thing that compiles these files at all, and
      // this workflow can be dispatched by hand without CI having run.
      expect(_functions, contains('deno check'));
      expect(_functions, contains('deno test'));
    });
  });
}
