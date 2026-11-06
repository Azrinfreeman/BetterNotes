import 'dart:convert';

import 'package:better_notes/data/google_drive_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('reads the verified account email for display', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'www.googleapis.com');
      expect(request.url.path, '/oauth2/v3/userinfo');
      return http.Response(
        jsonEncode({'email': ' me@example.com ', 'email_verified': true}),
        200,
      );
    });
    final account = await GoogleDriveAccount.fetch(client);
    expect(account?.email, 'me@example.com');
    client.close();
  });

  test('a missing identity is unknown rather than a hard failure', () async {
    Future<GoogleDriveAccount?> read(http.Response response) async {
      final client = MockClient((request) async => response);
      final account = await GoogleDriveAccount.fetch(client);
      client.close();
      return account;
    }

    expect(
      await read(http.Response(jsonEncode({'email': 'a@b.c'}), 500)),
      isNull,
    );
    expect(
      await read(
        http.Response(
          jsonEncode({'email': 'a@b.c', 'email_verified': false}),
          200,
        ),
      ),
      isNull,
    );
    expect(await read(http.Response(jsonEncode({'email': 42}), 200)), isNull);
    expect(
      await read(http.Response(jsonEncode({'email': 'not an email'}), 200)),
      isNull,
    );
    expect(await read(http.Response('<html>', 200)), isNull);
  });

  test('a network error leaves the account unknown', () async {
    final client = MockClient(
      (request) async => throw http.ClientException('offline'),
    );
    expect(await GoogleDriveAccount.fetch(client), isNull);
    client.close();
  });
}
