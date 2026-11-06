import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'backup.dart';

/// A verified snapshot recorded in the authenticated Google account.
class DriveSnapshot {
  const DriveSnapshot({
    required this.id,
    required this.createdAt,
    required this.device,
    required this.size,
    required this.sha256,
  });
  final String id;
  final DateTime createdAt;
  final String device;
  final int size;
  final String sha256;
}

/// Outcome of removing unfinished uploads left behind by failed transfers.
class DriveCleanupResult {
  const DriveCleanupResult({required this.removed, required this.failed});
  final int removed;
  final int failed;
}

/// Uses an already authenticated client; the caller owns and closes it.
class GoogleDriveBackup {
  GoogleDriveBackup(http.Client client) : _drive = drive.DriveApi(client);
  final drive.DriveApi _drive;
  static const _fields = 'id,createdTime,size,appProperties';
  static const _kindValue = 'betternotes-snapshot';
  static const _marker =
      "appProperties has { key='kind' and value='betternotes-snapshot' }";
  static const _readyQuery =
      "trashed = false and $_marker and appProperties has { key='state' and value='ready' }";
  static const _pendingQuery =
      "trashed = false and $_marker and appProperties has { key='state' and value='pending' }";
  static final _digestPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Never exposes a new snapshot until its downloaded content is verified.
  /// A failed transfer deletes its own unfinished file when Drive allows it.
  Future<DriveSnapshot> upload(
    Uint8List bytes, {
    required String device,
  }) async {
    NoteBackup.validate(bytes);
    final label = device.trim();
    if (label.isEmpty || label.length > 80) {
      throw ArgumentError('Device name must be 1–80 characters.');
    }
    final digest = sha256.convert(bytes).toString();
    final file = await _drive.files.create(
      drive.File()
        ..name = 'BetterNotes-${const Uuid().v4()}.zip'
        ..parents = ['appDataFolder']
        ..appProperties = {
          'kind': _kindValue,
          'state': 'pending',
          'device': label,
          'sha256': digest,
        },
      uploadMedia: drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/zip',
      ),
      $fields: _fields,
    );
    final id = file.id;
    if (id == null || id.isEmpty) {
      throw StateError('Drive did not return a backup ID.');
    }
    try {
      return await _publish(id, bytes, digest, label);
    } catch (_) {
      await _quietDelete(id);
      rethrow;
    }
  }

  Future<DriveSnapshot> _publish(
    String id,
    Uint8List bytes,
    String digest,
    String label,
  ) async {
    final uploaded = await _read(id);
    if (uploaded.length != bytes.length ||
        sha256.convert(uploaded).toString() != digest) {
      throw StateError('The uploaded backup failed verification.');
    }
    NoteBackup.validate(uploaded);
    final ready = await _drive.files.update(
      drive.File()
        ..appProperties = {
          'kind': _kindValue,
          'state': 'ready',
          'device': label,
          'sha256': digest,
        },
      id,
      $fields: _fields,
    );
    final snapshot = _snapshot(ready);
    if (snapshot == null ||
        snapshot.id != id ||
        snapshot.size != bytes.length ||
        snapshot.sha256 != digest ||
        snapshot.device != label) {
      throw StateError('Drive did not confirm the verified backup details.');
    }
    return snapshot;
  }

  /// Lists only published snapshots and follows all Drive result pages.
  Future<List<DriveSnapshot>> list() async {
    final result = <DriveSnapshot>[];
    for (final file in await _paged(_readyQuery)) {
      final snapshot = _snapshot(file);
      if (snapshot != null) result.add(snapshot);
    }
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Deletes unfinished uploads from earlier failed or interrupted transfers.
  ///
  /// Files younger than [minimumAge] are kept: another device may still be
  /// uploading one right now.
  Future<DriveCleanupResult> discardPending({
    Duration minimumAge = const Duration(minutes: 15),
    DateTime? now,
  }) async {
    final cutoff = (now ?? DateTime.now().toUtc()).subtract(minimumAge);
    final ids = <String>[];
    for (final file in await _paged(_pendingQuery)) {
      final id = file.id;
      final created = file.createdTime;
      if (id == null || id.isEmpty || created == null) continue;
      if (!created.isBefore(cutoff)) continue;
      ids.add(id);
    }
    var removed = 0;
    for (final id in ids) {
      if (await _quietDelete(id)) removed++;
    }
    return DriveCleanupResult(removed: removed, failed: ids.length - removed);
  }

  /// Deletes older verified snapshots made by this device, keeping the newest
  /// [keep]. Other devices' snapshots are never pruned automatically.
  Future<DriveCleanupResult> pruneDevice({
    required String device,
    int keep = 3,
  }) async {
    final label = device.trim();
    if (label.isEmpty) {
      throw ArgumentError('Device name must not be empty.');
    }
    if (keep < 1) {
      throw ArgumentError('At least one snapshot must be kept.');
    }
    final older = (await list())
        .where((snapshot) => snapshot.device == label)
        .skip(keep)
        .toList(growable: false);
    var removed = 0;
    for (final snapshot in older) {
      if (await _quietDelete(snapshot.id)) removed++;
    }
    return DriveCleanupResult(removed: removed, failed: older.length - removed);
  }

  /// Metadata and payload are both untrusted, including for listed snapshots.
  Future<Uint8List> download(DriveSnapshot snapshot) async {
    final bytes = await _read(snapshot.id);
    if (bytes.length != snapshot.size ||
        sha256.convert(bytes).toString() != snapshot.sha256) {
      throw const FormatException('Drive backup integrity check failed.');
    }
    NoteBackup.validate(bytes);
    return bytes;
  }

  Future<List<drive.File>> _paged(String query) async {
    final result = <drive.File>[];
    final seenTokens = <String>{};
    String? token;
    do {
      final page = await _drive.files.list(
        spaces: 'appDataFolder',
        q: query,
        $fields: 'nextPageToken,files($_fields)',
        pageSize: 100,
        pageToken: token,
      );
      result.addAll(page.files ?? <drive.File>[]);
      token = page.nextPageToken;
      if (token != null && token.isNotEmpty && !seenTokens.add(token)) {
        throw StateError('Drive returned a repeated page token.');
      }
    } while (token != null && token.isNotEmpty);
    return result;
  }

  Future<bool> _quietDelete(String id) async {
    try {
      await _drive.files.delete(id);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _read(String id) async {
    final media = await _drive.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in media.stream) {
      length += chunk.length;
      if (length > maxBackupBytes) {
        throw const FormatException('Drive backup exceeds 128 MB.');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  DriveSnapshot? _snapshot(drive.File file) {
    final props = file.appProperties;
    final id = file.id;
    final created = file.createdTime;
    final size = int.tryParse(file.size ?? '');
    final device = props?['device'];
    final digest = props?['sha256'];
    if (props?['kind'] != _kindValue ||
        props?['state'] != 'ready' ||
        id == null ||
        id.isEmpty ||
        created == null ||
        size == null ||
        size < 1 ||
        size > maxBackupBytes ||
        device == null ||
        device.trim().isEmpty ||
        device.length > 80 ||
        digest == null ||
        !_digestPattern.hasMatch(digest)) {
      return null;
    }
    return DriveSnapshot(
      id: id,
      createdAt: created,
      device: device,
      size: size,
      sha256: digest,
    );
  }
}
