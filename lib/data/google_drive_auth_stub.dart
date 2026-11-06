import 'package:oauth2/oauth2.dart' as oauth2;

class GoogleDriveAuthorization {
  GoogleDriveAuthorization({
    required String clientId,
    String clientSecret = '',
  });
  Future<oauth2.Client> connect({
    Duration timeout = const Duration(minutes: 2),
  }) => Future.error(UnsupportedError('Google Drive sign-in is unavailable.'));
  Future<void> cancel() async {}
}
