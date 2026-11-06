import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

import 'google_drive_config.dart';
import 'google_drive_errors.dart';

/// Uploads one archive. Injected in tests; the default path uses a refresh
/// token and the Drive API.
typedef DriveBackupUploader = Future<void> Function(
  Uint8List bytes,
  String device,
);

/// Builds an authenticated client from a saved refresh token. The token is
/// exchanged on first use, because the stored credentials start expired.
oauth2.Client googleDriveClientFromRefreshToken(
  String refreshToken, {
  http.Client? httpClient,
  String? clientId,
  String? clientSecret,
}) {
  final id = clientId ?? googleDriveDesktopClientId;
  if (id.trim().isEmpty) {
    throw DriveNotConfiguredException();
  }
  final secret = (clientSecret ?? googleDriveDesktopClientSecret).trim();
  return oauth2.Client(
    oauth2.Credentials(
      '',
      refreshToken: refreshToken,
      tokenEndpoint: Uri.https('oauth2.googleapis.com', '/token'),
      expiration: DateTime.fromMillisecondsSinceEpoch(0),
    ),
    identifier: id,
    secret: secret.isEmpty ? null : secret,
    basicAuth: false,
    httpClient: httpClient,
  );
}
