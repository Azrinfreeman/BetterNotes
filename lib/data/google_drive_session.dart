import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers a Google sign-in across launches so automatic backups can run.
/// Only the refresh token and the display email are stored.
abstract class DriveSessionStore {
  Future<String?> readRefreshToken();
  Future<String?> readEmail();
  Future<void> save({required String refreshToken, String? email});
  Future<void> clear();
}

/// Keeps the refresh token in the platform's secure storage: on Windows the
/// value is encrypted with a key kept in Windows Credential Manager.
class SecureDriveSessionStore implements DriveSessionStore {
  SecureDriveSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'betternotes.drive.refreshToken';
  static const _emailKey = 'betternotes.drive.email';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readRefreshToken() => _read(_tokenKey);

  @override
  Future<String?> readEmail() => _read(_emailKey);

  Future<String?> _read(String key) async {
    try {
      final value = (await _storage.read(key: key))?.trim();
      return value == null || value.isEmpty ? null : value;
    } catch (_) {
      // A missing secure store (or a locked key) means "no saved sign-in".
      return null;
    }
  }

  @override
  Future<void> save({required String refreshToken, String? email}) async {
    await _storage.write(key: _tokenKey, value: refreshToken);
    final label = email?.trim();
    if (label != null && label.isNotEmpty) {
      await _storage.write(key: _emailKey, value: label);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _emailKey);
  }
}
