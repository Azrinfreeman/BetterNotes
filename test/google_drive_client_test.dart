import 'dart:convert';

import 'package:better_notes/data/google_drive_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('exchanges a saved refresh token before the first request', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url}');
      if (request.url.path == '/token') {
        final body = Uri.splitQueryString(request.body);
        expect(body['grant_type'], 'refresh_token');
        expect(body['refresh_token'], 'saved-token');
        expect(body['client_id'], 'test-client');
        expect(body['client_secret'], 'test-secret');
        expect(request.headers['authorization'], isNull);
        return http.Response(
          jsonEncode({
            'access_token': 'fresh',
            'expires_in': 3600,
            'token_type': 'Bearer',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.headers['authorization'], 'Bearer fresh');
      return http.Response(
        jsonEncode({'files': []}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final oauth = googleDriveClientFromRefreshToken(
      'saved-token',
      clientId: 'test-client',
      clientSecret: 'test-secret',
      httpClient: client,
    );
    final response = await oauth.get(
      Uri.https('www.googleapis.com', '/drive/v3/files'),
    );
    expect(response.statusCode, 200);
    expect(calls, hasLength(2));
    expect(oauth.credentials.refreshToken, 'saved-token');
    oauth.close();
  });

  test('requires a client ID before building a client', () {
    expect(
      () => googleDriveClientFromRefreshToken('token', clientId: ' '),
      throwsA(isA<StateError>()),
    );
  });
}
