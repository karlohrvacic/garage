import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `scripts/serve_web.py` is how a desktop screen is looked at before a
/// release. If it answered differently from the Cloudflare Worker, the look
/// would be at a different site: no SPA fallback means every deep link 404s,
/// and no `_headers` means the page is never cross-origin isolated.
void main() {
  late Directory root;
  late Process server;
  late int port;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('serve_web');
    File('${root.path}/index.html').writeAsStringSync('<html>app</html>');
    File('${root.path}/main.dart.js').writeAsStringSync('// js');
    Directory('${root.path}/assets').createSync();
    File('${root.path}/assets/FontManifest.json').writeAsStringSync('[]');
    File('${root.path}/_headers').writeAsStringSync(
      '# Every page.\n'
      '/*\n'
      '  Cross-Origin-Opener-Policy: same-origin\n'
      '  Cross-Origin-Embedder-Policy: require-corp\n'
      '# One route.\n'
      '/company\n'
      '  X-Company: yes\n',
    );
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    port = probe.port;
    await probe.close();
    server = await Process.start('python3', [
      'scripts/serve_web.py',
      root.path,
      '$port',
    ]);
    unawaited(server.stderr.drain<void>());
    await server.stdout
        .transform(utf8.decoder)
        .firstWhere((chunk) => chunk.contains('Serving'));
  });

  tearDownAll(() async {
    server.kill();
    await server.exitCode;
    await root.delete(recursive: true);
  });

  Future<(HttpClientResponse, String)> get(String path) async {
    final client = HttpClient();
    try {
      final response = await (await client.get(
        '127.0.0.1',
        port,
        path,
      )).close();
      return (response, await response.transform(utf8.decoder).join());
    } finally {
      client.close();
    }
  }

  test('a route only the app knows gets index.html', () async {
    final (response, body) = await get('/company');
    expect(response.statusCode, 200);
    expect(body, contains('app'));
  });

  test('and carries the headers the build asks for', () async {
    final (response, _) = await get('/company');
    expect(response.headers.value('cross-origin-opener-policy'), 'same-origin');
    expect(
      response.headers.value('cross-origin-embedder-policy'),
      'require-corp',
    );
  });

  test('a rule for one route reaches that route, and no other', () async {
    // index.html answers /company, but the Worker matches rules against the
    // path that was asked for, so an exact rule has to follow the request.
    final (route, _) = await get('/company');
    final (file, _) = await get('/main.dart.js');
    expect(route.headers.value('x-company'), 'yes');
    expect(file.headers.value('x-company'), isNull);
  });

  test('a file is served as itself', () async {
    final (response, body) = await get('/main.dart.js');
    expect(response.statusCode, 200);
    expect(body, '// js');
  });

  test('a directory is not an asset, so it gets index.html', () async {
    for (final path in ['/', '/assets', '/assets/']) {
      final (response, body) = await get(path);
      expect(response.statusCode, 200, reason: path);
      expect(body, '<html>app</html>', reason: path);
    }
  });

  test('the headers file is not served, as the Worker does not', () async {
    final (_, body) = await get('/_headers');
    expect(body, isNot(contains('Cross-Origin')));
  });
}
