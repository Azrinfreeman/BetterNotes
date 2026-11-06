import 'dart:convert';

import 'package:http/http.dart' as http;

/// The Google account that granted access, shown so a backup cannot silently
/// land in the wrong account. Display only; never used for authorization.
class GoogleDriveAccount {
  const GoogleDriveAccount({required this.email});
  final String email;

  /// Returns null when the identity cannot be read. Callers must treat a
  /// missing account as unknown rather than as a failed backup.
  static Future<GoogleDriveAccount?> fetch(http.Client client) async {
    try {
      final response = await client
          .get(Uri.https('www.googleapis.com', '/oauth2/v3/userinfo'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is! Map) return null;
      final email = data['email'];
      final verified = data['email_verified'];
      if (email is! String || verified == false) return null;
      final value = email.trim();
      if (value.isEmpty ||
          value.length > 254 ||
          !value.contains('@') ||
          value.contains(RegExp(r'\s'))) {
        return null;
      }
      return GoogleDriveAccount(email: value);
    } catch (_) {
      return null;
    }
  }
}
