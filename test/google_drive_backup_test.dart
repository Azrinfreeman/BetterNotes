import 'dart:convert';
import 'dart:typed_data';

import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/google_drive_backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sembast/sembast_memory.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, Object?> _pending(String id, DateTime created) => {
  'id': id,
  'createdTime': created.toIso8601String(),
  'size': '10',
  'appProperties': {
    'kind': 'betternotes-snapshot',
    'state': 'pending',
    'device': 'PC',
    'sha256': 'a' * 64,
  },
};

Map<String, Object?> _ready(String id, DateTime created, String device) => {
  'id': id,
  'createdTime': created.toIso8601String(),
  'size': '10',
  'appProperties': {
    'kind': 'betternotes-snapshot',
    'state': 'ready',
    'device': device,
    'sha256': 'a' * 64,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'publishes only after a downloaded archive passes verification',
    () async {
      final db = await databaseFactoryMemory.openDatabase('drive-snapshot');
      final bytes = await NoteBackup.export(
        LocalStore.fromDatabase(db),
        guestOwner,
      );
      final digest = sha256.convert(bytes).toString();
      final calls = <String>[];
      final deleted = <String>[];
      final props = {
        'kind': 'betternotes-snapshot',
        'state': 'ready',
        'device': 'PC',
        'sha256': digest,
      };
      final file = {
        'id': 'file-1',
        'createdTime': '2026-11-06T00:00:00Z',
        'size': '${bytes.length}',
        'appProperties': props,
      };
      var corrupt = false;
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'POST') {
          return _json({'id': 'file-1'});
        }
        if (request.method == 'GET' &&
            request.url.queryParameters['alt'] == 'media') {
          return http.Response.bytes(
            corrupt ? [1, 2] : bytes,
            200,
            headers: {'content-type': 'application/zip'},
          );
        }
        if (request.method == 'PATCH') {
          return _json(file);
        }
        if (request.method == 'DELETE') {
          deleted.add(request.url.pathSegments.last);
          return http.Response('', 204);
        }
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
      });
      final service = GoogleDriveBackup(client);
      final snapshot = await service.upload(bytes, device: 'PC');
      expect(snapshot.id, 'file-1');
      expect(calls.map((call) => call.split(' ').first), [
        'POST',
        'GET',
        'PATCH',
      ]);
      expect(deleted, isEmpty);
      expect(await service.download(snapshot), bytes);
      corrupt = true;
      calls.clear();
      await expectLater(service.upload(bytes, device: 'PC'), throwsStateError);
      // The unfinished upload is removed instead of being left in Drive.
      expect(calls.map((call) => call.split(' ').first), [
        'POST',
        'GET',
        'DELETE',
      ]);
      expect(deleted, ['file-1']);
      await expectLater(service.download(snapshot), throwsFormatException);
      client.close();
      await db.close();
    },
  );

  test('lists all pages and rejects malformed snapshot metadata', () async {
    var requests = 0;
    final digest = sha256.convert(Uint8List.fromList([1])).toString();
    final client = MockClient((request) async {
      requests++;
      expect(request.url.queryParameters['spaces'], 'appDataFolder');
      final second = request.url.queryParameters['pageToken'] == 'next';
      final data = second
          ? {
              'files': [
                {'id': 'bad'},
              ],
            }
          : {
              'nextPageToken': 'next',
              'files': [
                {
                  'id': 'ok',
                  'createdTime': '2026-11-06T00:00:00Z',
                  'size': '1',
                  'appProperties': {
                    'kind': 'betternotes-snapshot',
                    'state': 'ready',
                    'device': 'PC',
                    'sha256': digest,
                  },
                },
              ],
            };
      return _json(data);
    });
    final snapshots = await GoogleDriveBackup(client).list();
    expect(requests, 2);
    expect(snapshots.single.id, 'ok');
    client.close();
  });

  test('rejects a repeated page token rather than looping forever', () async {
    final client = MockClient(
      (request) async => _json({'nextPageToken': 'same', 'files': []}),
    );
    await expectLater(GoogleDriveBackup(client).list(), throwsStateError);
    client.close();
  });

  test('keeps only the newest snapshots made by this device', () async {
    final deleted = <String>[];
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.pathSegments.last);
        return http.Response('', 204);
      }
      return _json({
        'files': [
          _ready('pc-1', DateTime.utc(2026, 1, 5), 'PC'),
          _ready('pc-2', DateTime.utc(2026, 1, 4), 'PC'),
          _ready('pc-3', DateTime.utc(2026, 1, 3), 'PC'),
          _ready('pc-4', DateTime.utc(2026, 1, 2), 'PC'),
          _ready('pc-5', DateTime.utc(2026, 1, 1), 'PC'),
          _ready('other', DateTime.utc(2026, 1, 1), 'Laptop'),
        ],
      });
    });
    final result = await GoogleDriveBackup(client).pruneDevice(device: 'PC');
    expect(deleted, ['pc-4', 'pc-5']);
    expect(result.removed, 2);
    expect(result.failed, 0);
    client.close();
  });

  test('cleanup removes stale unfinished uploads across all pages', () async {
    final deleted = <String>[];
    var pages = 0;
    final client = MockClient((request) async {
      if (request.method == 'DELETE') {
        final id = request.url.pathSegments.last;
        deleted.add(id);
        if (id == 'locked') return http.Response('', 500);
        return http.Response('', 204);
      }
      expect(request.url.queryParameters['q'], contains("value='pending'"));
      pages++;
      return _json(
        pages == 1
            ? {
                'nextPageToken': 'second',
                'files': [
                  _pending('old-1', DateTime.utc(2026, 1, 1)),
                  // Another device may still be uploading this one.
                  _pending('fresh', DateTime.utc(2026, 1, 1, 11, 55)),
                ],
              }
            : {
                'files': [
                  _pending('old-2', DateTime.utc(2026, 1, 1, 9)),
                  _pending('locked', DateTime.utc(2026, 1, 1, 8)),
                ],
              },
      );
    });
    final result = await GoogleDriveBackup(client).discardPending(
      minimumAge: const Duration(minutes: 15),
      now: DateTime.utc(2026, 1, 1, 12),
    );
    expect(pages, 2);
    expect(deleted, ['old-1', 'old-2', 'locked']);
    expect(deleted, isNot(contains('fresh')));
    expect(result.removed, 2);
    expect(result.failed, 1);
    client.close();
  });
}
