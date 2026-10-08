class DesktopCallback {
  DesktopCallback._();
  static const redirectUrl = 'http://127.0.0.1:48555/auth/callback';
  static Future<DesktopCallback> start() =>
      throw UnsupportedError('Desktop callback is unavailable on the web.');
  Future<String> waitForCode() =>
      throw UnsupportedError('Desktop callback is unavailable on the web.');
  Future<void> close() async {}
}
