import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:url_launcher/url_launcher.dart';

import 'google_drive_config.dart';
import 'google_drive_errors.dart';

/// Windows-only interactive authorization. Tokens live only in the returned
/// client and are discarded when it is closed; no credential is saved to disk.
class GoogleDriveAuthorization {
  GoogleDriveAuthorization({
    required this.clientId,
    this.clientSecret = '',
    Future<bool> Function(Uri)? openBrowser,
  }) : _openBrowser = openBrowser ?? _launch;

  final String clientId;

  /// Google's Desktop-app clients still require this value at the token
  /// endpoint. Google documents it as non-confidential for installed apps, and
  /// PKCE protects the exchange.
  final String clientSecret;
  final Future<bool> Function(Uri) _openBrowser;
  HttpServer? _server;
  bool _connecting = false;

  static Future<bool> _launch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<oauth2.Client> connect({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (clientId.trim().isEmpty) {
      throw DriveNotConfiguredException();
    }
    if (_connecting) throw StateError('Google sign-in is already in progress.');
    _connecting = true;
    late final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } catch (_) {
      _connecting = false;
      rethrow;
    }
    _server = server;
    final random = Random.secure();
    final state = base64Url
        .encode(List<int>.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    final grant = oauth2.AuthorizationCodeGrant(
      clientId,
      Uri.https('accounts.google.com', '/o/oauth2/v2/auth'),
      Uri.https('oauth2.googleapis.com', '/token'),
      secret: clientSecret.trim().isEmpty ? null : clientSecret.trim(),
      basicAuth: false,
    );
    final redirect = Uri.parse(
      'http://127.0.0.1:${server.port}/oauth2callback',
    );
    final url = grant.getAuthorizationUrl(
      redirect,
      // `openid email` only names the signed-in account for display; Drive
      // access stays limited to the hidden app data folder.
      scopes: googleDriveScopes,
      state: state,
    );
    var connected = false;
    try {
      if (!await _openBrowser(url)) {
        throw StateError('Could not open the browser for Google sign-in.');
      }
      final request = await server
          .firstWhere((request) {
            if (request.method == 'GET' &&
                request.uri.path == redirect.path &&
                request.uri.queryParameters['state'] == state) {
              return true;
            }
            request.response.statusCode = HttpStatus.badRequest;
            unawaited(request.response.close());
            return false;
          })
          .timeout(timeout);
      try {
        final client = await grant.handleAuthorizationResponse(
          request.uri.queryParameters,
        );
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          'Google sign-in completed. You can return to BetterNotes.',
        );
        await request.response.close();
        connected = true;
        return client;
      } catch (error) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.text;
        request.response.write(
          'Google sign-in did not complete. Return to BetterNotes.',
        );
        if (error is oauth2.AuthorizationException) {
          request.response.write('\n\n${error.error}: ${error.description}');
        }
        await request.response.close();
        rethrow;
      }
    } finally {
      await server.close(force: true);
      _server = null;
      _connecting = false;
      if (!connected) grant.close();
    }
  }

  /// Closes the callback listener. The pending connection completes with error.
  Future<void> cancel() async => _server?.close(force: true);
}
