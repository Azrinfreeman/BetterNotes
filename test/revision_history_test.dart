import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/data/revision.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<(NotesController, LocalStore, Database)> _open(String name) async {
  final db = await databaseFactoryMemory.openDatabase(name);
  final store = LocalStore.fromDatabase(db);
  final controller = NotesController(store, null)
    ..revisionInterval = Duration.zero;
  await controller.load();
  return (controller, store, db);
}

Note _withText(Note note, String text) => note.copyWith(
  plainText: text,
  delta: [
    {'insert': '$text\n'},
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('edits create throttled checkpoints capped at 20 per note', () async {
    final (controller, store, db) = await _open('rev-cap');
    final note = await controller.create();
    await controller.save(_withText(note, 'v0'));
    expect(await store.revisionsFor(note.id), isEmpty);
    for (var i = 1; i <= 25; i++) {
      await controller.save(_withText(controller.noteById(note.id)!, 'v$i'));
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final kept = await controller.revisions(note.id);
    expect(kept, hasLength(maxRevisionsPerNote));
    expect(kept.first.plainText, 'v24');
    expect(kept.last.plainText, 'v5');

    controller.revisionInterval = const Duration(minutes: 5);
    await controller.save(_withText(controller.noteById(note.id)!, 'later'));
    expect((await controller.revisions(note.id)).first.plainText, 'v24');
    // Metadata-only saves never checkpoint.
    controller.revisionInterval = Duration.zero;
    await controller.save(
      controller.noteById(note.id)!.copyWith(colorIndex: 4),
    );
    expect((await controller.revisions(note.id)).first.plainText, 'v24');
    controller.dispose();
    await db.close();
  });

  test('restoring creates a separate note with copied images', () async {
    final (controller, store, db) = await _open('rev-restore');
    final note = await controller.create();
    final imageId = await controller.cacheImage(Uint8List.fromList([7, 8]));
    await controller.save(
      note.copyWith(
        title: 'Plan',
        plainText: 'old',
        images: [imageId],
        delta: [
          {'insert': 'old'},
          {
            'insert': {'image': imageId},
          },
          {'insert': '\n'},
        ],
      ),
    );
    await controller.save(_withText(controller.noteById(note.id)!, 'new'));
    final revision = (await controller.revisions(note.id)).single;
    expect(revision.plainText, 'old');

    final copy = (await controller.restoreRevision(revision.id))!;
    expect(copy.id, isNot(note.id));
    expect(copy.title, startsWith('Plan (version '));
    expect(copy.plainText, 'old');
    expect(copy.images.single, isNot(imageId));
    expect(inlineImageIds(copy.delta), {copy.images.single});
    expect(await controller.image(copy.id, copy.images.single), [7, 8]);
    expect(controller.noteById(note.id)!.plainText, 'new');
    expect(await store.revisionById(revision.id), isNotNull);
    expect(await controller.restoreRevision('missing'), isNull);

    await controller.delete(controller.noteById(note.id)!);
    expect(await store.revisionsFor(note.id), hasLength(1));
    await controller.purge(note.id);
    expect(await store.revisionsFor(note.id), isEmpty);
    controller.dispose();
    await db.close();
  });

  test('backups include history and remap it on import', () async {
    final (controller, store, db) = await _open('rev-backup');
    final note = await controller.create();
    final imageId = await controller.cacheImage(Uint8List.fromList([1, 2, 3]));
    await controller.save(
      note.copyWith(
        plainText: 'first',
        images: [imageId],
        delta: [
          {'insert': 'first'},
          {
            'insert': {'image': imageId},
          },
          {'insert': '\n'},
        ],
      ),
    );
    // The image is removed afterwards; only the old version still needs it.
    await controller.save(
      controller
          .noteById(note.id)!
          .copyWith(
            plainText: 'second',
            images: [],
            delta: [
              {'insert': 'second\n'},
            ],
          ),
    );
    final bytes = await controller.exportBackup();
    final backup = NoteBackup.validate(bytes);
    expect(backup.revisions, hasLength(1));
    expect(backup.assets.keys, contains(imageId));

    await backup.importInto(store, guestOwner);
    await controller.reload();
    final copies = controller.notes.where((n) => n.id != note.id).toList();
    expect(copies, hasLength(1));
    final history = await controller.revisions(copies.single.id);
    expect(history, hasLength(1));
    expect(history.single.plainText, 'first');
    expect(history.single.noteId, copies.single.id);
    expect(history.single.images.single, isNot(imageId));
    expect(inlineImageIds(history.single.delta), {
      history.single.images.single,
    });
    expect(
      await store.getImage(history.single.images.single),
      Uint8List.fromList([1, 2, 3]),
    );
    // The original note's history is untouched by the import.
    expect(await controller.revisions(note.id), hasLength(1));
    controller.dispose();
    await db.close();
  });

  test('backups without history stay version 1 and still import', () async {
    final (controller, _, db) = await _open('rev-v1');
    await controller.create();
    final bytes = await controller.exportBackup();
    final directory = ZipDecoder().decodeBytes(bytes);
    expect(directory.findFile('revisions.json'), isNull);
    final manifest = jsonDecode(
      utf8.decode(directory.findFile('manifest.json')!.content),
    ) as Map;
    expect(manifest['version'], 1);
    expect(NoteBackup.validate(bytes).revisions, isEmpty);
    controller.dispose();
    await db.close();
  });

  test('tampered history is rejected', () async {
    final (controller, _, db) = await _open('rev-tamper');
    final note = await controller.create();
    await controller.save(_withText(note, 'a'));
    await controller.save(_withText(controller.noteById(note.id)!, 'b'));
    final good = await controller.exportBackup();

    Uint8List rebuild(void Function(List<dynamic> revisions) change) {
      final source = ZipDecoder().decodeBytes(good);
      final entries = <String, Uint8List>{
        for (final file in source)
          file.name: Uint8List.fromList(file.content as List<int>),
      };
      final list = jsonDecode(utf8.decode(entries['revisions.json']!)) as List;
      change(list);
      entries['revisions.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(list)),
      );
      final manifest =
          jsonDecode(utf8.decode(entries['manifest.json']!)) as Map;
      manifest['hashes'] = {
        for (final entry in entries.entries)
          if (entry.key != 'manifest.json')
            entry.key: sha256.convert(entry.value).toString(),
      };
      entries['manifest.json'] = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      final archive = Archive();
      for (final entry in entries.entries) {
        archive.add(
          ArchiveFile(entry.key, entry.value.length, entry.value)
            ..compression = CompressionType.none,
        );
      }
      return ZipEncoder().encodeBytes(archive);
    }

    expect(NoteBackup.validate(rebuild((_) {})).revisions, hasLength(1));
    expect(
      () => NoteBackup.validate(
        rebuild((list) => (list.first as Map)['note_id'] = 'unknown'),
      ),
      throwsFormatException,
    );
    expect(
      () => NoteBackup.validate(
        rebuild((list) => (list.first as Map)['images'] = ['missing-asset']),
      ),
      throwsFormatException,
    );
    expect(
      () => NoteBackup.validate(
        rebuild((list) => (list.first as Map)['content'] = []),
      ),
      throwsFormatException,
    );
    expect(
      () => NoteBackup.validate(
        rebuild((list) => list.add(Map.of(list.first as Map))),
      ),
      throwsFormatException,
    );
    controller.dispose();
    await db.close();
  });
}
