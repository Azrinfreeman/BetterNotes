@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/backup_files_web.dart' as files;
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:web/web.dart' as web;

void main() {
  test(
    'browser upload and cancellation use the validated backup format',
    () async {
      final db = await databaseFactoryMemory.openDatabase('browser-backup.db');
      final store = LocalStore.fromDatabase(db);
      final note = Note.fresh(guestOwner).copyWith(
        plainText: 'browser note',
        delta: [
          {'insert': 'browser note\n'},
        ],
      );
      await store.putNote(note);
      final bytes = await NoteBackup.export(store, guestOwner);
      final upload = files.pickBackup();
      final input = web.document.querySelector(
        'input[type=file]',
      ) as web.HTMLInputElement;
      final transfer = web.DataTransfer();
      transfer.items.add(web.File([bytes.toJS].toJS, 'backup.zip'));
      input.files = transfer.files;
      input.dispatchEvent(web.Event('change'));
      final received = (await upload)!;
      expect(received, bytes);
      final backup = NoteBackup.validate(received);
      await backup.importInto(store, guestOwner);
      final notes = await store.notesFor(guestOwner);
      expect(notes, hasLength(2));
      expect(notes.map((value) => value.id).toSet(), hasLength(2));
      final cancelled = files.pickBackup();
      (web.document.querySelector('input[type=file]') as web.HTMLInputElement)
          .dispatchEvent(web.Event('cancel'));
      expect(await cancelled, isNull);
      expect(web.document.querySelector('input[type=file]'), isNull);
      expect(
        () => NoteBackup.validate(Uint8List.fromList([1, 2])),
        throwsFormatException,
      );
      await db.close();
    },
  );
}
