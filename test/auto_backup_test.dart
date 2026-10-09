import 'dart:io';
import 'dart:typed_data';

import 'package:better_notes/data/auto_backup_io.dart';
import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'automatic backups keep only the newest ones and leave other files',
    () async {
      final dir = await Directory.systemTemp.createTemp('bn-auto-');
      addTearDown(() => dir.delete(recursive: true));
      File('${dir.path}${Platform.pathSeparator}keep-me.zip')
          .writeAsStringSync('x');
      for (var i = 1; i <= 4; i++) {
        await writeAutoBackup(
          dir.path,
          Uint8List.fromList([i]),
          DateTime(2026, 10, i, 9),
          2,
        );
      }
      final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList()
        ..sort();
      expect(names, [
        'BetterNotes-auto-20261003-090000.zip',
        'BetterNotes-auto-20261004-090000.zip',
        'keep-me.zip',
      ]);
      await expectLater(
        writeAutoBackup(
          '${dir.path}${Platform.pathSeparator}gone',
          Uint8List(1),
          DateTime.now(),
          2,
        ),
        throwsA(isA<FileSystemException>()),
      );
    },
  );

  test(
    'the controller backs up when due, records status, and reports failure',
    () async {
      final dir = await Directory.systemTemp.createTemp('bn-auto-ctl-');
      addTearDown(() => dir.delete(recursive: true));
      final db = await databaseFactoryMemory.openDatabase('auto-backup');
      final controller = NotesController(LocalStore.fromDatabase(db), null);
      await controller.load();
      await controller.create();
      expect(await controller.runAutoBackup(force: true), isFalse); // no folder

      await controller.setAutoBackupFolder(dir.path);
      expect(await controller.runAutoBackup(), isTrue);
      expect(controller.autoBackupLast, isNotNull);
      final files = dir.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(
        NoteBackup.validate(files.single.readAsBytesSync()).notes,
        hasLength(1),
      );

      expect(await controller.runAutoBackup(), isFalse); // not due yet
      expect(files, hasLength(1));

      await dir.delete(recursive: true);
      expect(await controller.runAutoBackup(force: true), isFalse);
      expect(controller.autoBackupError, contains('Automatic backup failed'));
      await dir.create();
      expect(await controller.runAutoBackup(force: true), isTrue);
      expect(controller.autoBackupError, isNull);

      controller.dispose();
      final reopened = NotesController(LocalStore.fromDatabase(db), null);
      await reopened.load();
      expect(reopened.autoBackupFolder, dir.path);
      expect(reopened.autoBackupLast, isNotNull);
      await reopened.setAutoBackupFolder(null);
      expect(reopened.autoBackupFolder, isNull);
      reopened.dispose();
      await db.close();
    },
  );
}
