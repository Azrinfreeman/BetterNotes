import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

/// What a Drive failure means for the person using the app, so the UI can show
/// an actionable message without inspecting exception text.
enum DriveFailure { notConfigured, denied, timedOut, network, integrity, other }

/// Thrown when no Google OAuth client ID was supplied at build time.
class DriveNotConfiguredException extends StateError {
  DriveNotConfiguredException()
    : super('Google Drive is not configured for this build.');
}

DriveFailure classifyDriveError(Object error) {
  if (error is DriveNotConfiguredException) {
    return DriveFailure.notConfigured;
  }
  if (error is TimeoutException) return DriveFailure.timedOut;
  if (error is oauth2.AuthorizationException) return DriveFailure.denied;
  if (error is http.ClientException) return DriveFailure.network;
  if (error is FormatException) return DriveFailure.integrity;
  return DriveFailure.other;
}
