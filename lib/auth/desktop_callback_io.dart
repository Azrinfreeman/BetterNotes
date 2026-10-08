import 'dart:async';
import 'dart:io';

class DesktopCallback {
  DesktopCallback._(this._server);

  static const redirectUrl = 'http://127.0.0.1:48555/auth/callback';
  final HttpServer _server;

  static Future<DesktopCallback> start() async => DesktopCallback._(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 48555),
  );

  Future<String> waitForCode() async {
    try {
      final request = await _server.first.timeout(const Duration(minutes: 3));
      final code = request.uri.queryParameters['code'];
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><title>BetterNotes</title>'
        '<p>${code == null ? 'Sign-in was cancelled.' : 'Signed in. You can return to BetterNotes.'}</p>',
      );
      await request.response.close();
      if (code == null) {
        throw StateError('Google sign-in did not return a code.');
      }
      return code;
    } finally {
      await _server.close(force: true);
    }
  }

  Future<void> close() => _server.close(force: true);
}
