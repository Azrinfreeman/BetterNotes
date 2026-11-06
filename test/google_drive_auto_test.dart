import 'dart:typed_data';

import 'package:better_notes/data/google_drive_session.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _MemorySessions implements DriveSessionStore {
  String? token;
  String? email;

  @override
  Future<String?> readRefreshToken() async => token;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> save({required String refreshToken, String? email}) async {
    token = refreshToken;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('daily Drive backup uploads when due and records its status', () async {
    final db = await databaseFactoryMemory.openDatabase('drive-auto');
    final sessions = _MemorySessions();
    final uploads = <Uint8List>[];
    final devices = <String>[];
    final controller = NotesController(
      LocalStore.fromDatabase(db),
      null,
      driveSessions: sessions,
      driveUploader: (bytes, device) async {
        uploads.add(bytes);
        devices.add(device);
      },
    );
    await controller.load();
    await controller.create();

    // Enabling without a saved sign-in must be refused, not silently ignored.
    expect(await controller.setDriveAutoEnabled(true), isFalse);
    expect(controller.driveAutoEnabled, isFalse);

    await controller.saveDriveSession(
      refreshToken: 'refresh-1',
      email: 'me@example.com',
    );
    expect(sessions.token, 'refresh-1');
    expect(await controller.setDriveAutoEnabled(true), isTrue);
    expect(controller.driveAutoEnabled, isTrue);

    expect(await controller.runDriveAutoBackup(force: true), isTrue);
    expect(uploads, hasLength(1));
    expect(uploads.single, isNotEmpty);
    expect(devices.single, isNotEmpty);
    expect(controller.driveAutoLast, isNotNull);
    expect(controller.driveAutoError, isNull);

    // Not due again until the interval passes.
    expect(await controller.runDriveAutoBackup(), isFalse);
    expect(uploads, hasLength(1));

    controller.dispose();
    final reopened = NotesController(
      LocalStore.fromDatabase(db),
      null,
      driveSessions: sessions,
    );
    await reopened.load();
    expect(reopened.driveAutoEnabled, isTrue);
    expect(reopened.driveAutoLast, isNotNull);
    reopened.dispose();
    await db.close();
  });

  test(
    'a failed upload is reported and leaves the last success intact',
    () async {
      final db = await databaseFactoryMemory.openDatabase('drive-auto-error');
      final sessions = _MemorySessions()..token = 'refresh-1';
      var fail = false;
      final controller = NotesController(
        LocalStore.fromDatabase(db),
        null,
        driveSessions: sessions,
        driveUploader: (bytes, device) async {
          if (fail) throw Exception('offline');
        },
      );
      await controller.load();
      await controller.create();
      expect(await controller.setDriveAutoEnabled(true), isTrue);
      expect(await controller.runDriveAutoBackup(force: true), isTrue);
      final first = controller.driveAutoLast;

      fail = true;
      expect(await controller.runDriveAutoBackup(force: true), isFalse);
      expect(controller.driveAutoError, contains('Google Drive backup failed'));
      expect(controller.driveAutoLast, first);

      fail = false;
      expect(await controller.runDriveAutoBackup(force: true), isTrue);
      expect(controller.driveAutoError, isNull);

      // Disconnecting forgets the token and turns the schedule off.
      await controller.forgetDriveSession();
      expect(sessions.token, isNull);
      expect(controller.driveAutoEnabled, isFalse);
      expect(controller.driveAutoLast, isNull);
      expect(await controller.runDriveAutoBackup(force: true), isFalse);

      controller.dispose();
      await db.close();
    },
  );
}
