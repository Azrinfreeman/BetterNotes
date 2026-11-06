import 'dart:async';
import 'dart:io';

import 'package:better_notes/data/google_drive_auth_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'uses PKCE, rejects unrelated callbacks, and handles denied consent',
    () async {
      final ready = Completer<Uri>();
      final authorization = GoogleDriveAuthorization(
        clientId: 'desktop-client',
        openBrowser: (uri) async {
          ready.complete(uri);
          return true;
        },
      );
      final future = authorization.connect(timeout: const Duration(seconds: 5));
      final expectation = expectLater(future, throwsA(isA<Exception>()));
      final url = await ready.future;
      expect(url.queryParameters['code_challenge_method'], 'S256');
      expect(
        url.queryParameters['scope'],
        'openid email https://www.googleapis.com/auth/drive.appdata',
      );
      final redirect = Uri.parse(url.queryParameters['redirect_uri']!);
      expect(redirect.host, InternetAddress.loopbackIPv4.address);
      final unrelated = await http.get(
        redirect.replace(queryParameters: {'state': 'wrong'}),
      );
      expect(unrelated.statusCode, 400);
      final denied = await http.get(
        redirect.replace(
          queryParameters: {
            'state': url.queryParameters['state']!,
            'error': 'access_denied',
          },
        ),
      );
      expect(denied.statusCode, 400);
      await expectation;
    },
  );

  test('sign-in fails promptly if browser cannot be opened', () async {
    final authorization = GoogleDriveAuthorization(
      clientId: 'desktop-client',
      openBrowser: (_) async => false,
    );
    await expectLater(authorization.connect(), throwsStateError);
    await expectLater(authorization.connect(), throwsStateError);
  });

  test('cancelling sign-in releases its listener', () async {
    final opened = Completer<void>();
    final authorization = GoogleDriveAuthorization(
      clientId: 'desktop-client',
      openBrowser: (_) async {
        opened.complete();
        return true;
      },
    );
    final future = authorization.connect(timeout: const Duration(seconds: 5));
    final result = expectLater(future, throwsA(anything));
    await opened.future;
    await Future<void>.delayed(Duration.zero);
    await authorization.cancel();
    await result;
  });
}
