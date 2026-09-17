import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A Supabase client whose server is [answer], for tests of the requests a
/// repository really makes rather than of a stand-in for them.
///
/// Every request is kept in [requests], bodies included; a multipart upload
/// arrives with its parts written out, so the type a file was sent as can be
/// read back. [answer] returns a status and a JSON body; anything it does not
/// know is a 404.
class FakeSupabaseServer {
  FakeSupabaseServer(this.answer);

  final (int, Object)? Function(http.Request request) answer;
  final List<http.Request> requests = [];

  late final SupabaseClient client = SupabaseClient(
    'http://127.0.0.1:54321',
    'anon-key',
    httpClient: MockClient((request) async {
      requests.add(request);
      final (status, body) =
          _auth(request) ??
          answer(request) ??
          (404, const {'message': 'not found'});
      // The client reads the request back off the response.
      return http.Response(
        jsonEncode(body),
        status,
        request: request,
        headers: {'content-type': 'application/json'},
      );
    }),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  /// Signs [client] in as [userId], for code that reads the current user.
  Future<void> signIn({String userId = 'u1'}) async {
    _userId = userId;
    await client.auth.signInWithPassword(
      email: 'driver@example.com',
      password: 'password',
    );
  }

  String _userId = 'u1';

  (int, Object)? _auth(http.Request request) {
    if (request.url.path != '/auth/v1/token') {
      return null;
    }
    final exp = DateTime.now().add(const Duration(hours: 1));
    String part(Map<String, Object> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final token = [
      part({'alg': 'HS256', 'typ': 'JWT'}),
      part({
        'sub': _userId,
        'role': 'authenticated',
        'exp': exp.millisecondsSinceEpoch ~/ 1000,
      }),
      'signature',
    ].join('.');
    return (
      200,
      {
        'access_token': token,
        'token_type': 'bearer',
        'expires_in': 3600,
        'expires_at': exp.millisecondsSinceEpoch ~/ 1000,
        'refresh_token': 'refresh',
        'user': {
          'id': _userId,
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'driver@example.com',
          'app_metadata': <String, Object>{},
          'user_metadata': <String, Object>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      },
    );
  }
}
