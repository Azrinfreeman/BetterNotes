import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

/// Synthetic scale checks. Timings are debug-mode VM numbers on whatever
/// machine runs the suite; the generous bounds catch order-of-magnitude
/// regressions, not release performance.
void main() {
  test('a 100,000-character formatted note loads, edits, and serializes', () {
    final delta = <Map<String, dynamic>>[];
    for (var i = 0; i < 4000; i++) {
      delta.add({
        'insert': 'Paragraph $i with some words',
        if (i.isEven) 'attributes': {'bold': true},
      });
      delta.add({'insert': '\n'});
    }
    final watch = Stopwatch()..start();
    final document = quill.Document.fromJson(delta);
    final load = watch.elapsedMilliseconds;
    watch.reset();
    final plain = document.toPlainText();
    final controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    controller.replaceText(0, 0, 'x', const TextSelection.collapsed(offset: 1));
    final edit = watch.elapsedMilliseconds;
    watch.reset();
    final encoded = jsonEncode(document.toDelta().toJson());
    final note = Note.fromJson(
      Note.fresh(guestOwner)
          .copyWith(delta: document.toDelta().toJson(), plainText: plain)
          .toJson(),
    );
    final serialize = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print(
      'Large note (${plain.length} chars): load $load ms, edit $edit ms, '
      'serialize $serialize ms',
    );
    expect(plain.length, greaterThan(100000));
    expect(note.delta, isNotEmpty);
    expect(encoded.length, greaterThan(100000));
    expect(load, lessThan(10000));
    expect(edit, lessThan(10000));
    expect(serialize, lessThan(10000));
    controller.dispose();
  });

  test('image-heavy library exports, validates, and imports', () async {
    final db = await databaseFactoryMemory.openDatabase('large-backup.db');
    final store = LocalStore.fromDatabase(db);
    final random = Random(3);
    for (var i = 0; i < 40; i++) {
      // Random bytes do not compress, so this is a worst case for archives.
      final bytes = Uint8List.fromList(
        List.generate(512 * 1024, (_) => random.nextInt(256)),
      );
      final imageId = 'image-$i-${'a' * 8}';
      await store.putImage(imageId, bytes);
      await store.putNote(
        Note.fresh(guestOwner).copyWith(
          plainText: 'note $i',
          delta: [
            {'insert': 'note $i\n'},
          ],
          images: [imageId],
        ),
      );
    }
    final watch = Stopwatch()..start();
    final archive = await NoteBackup.export(store, guestOwner);
    final export = watch.elapsedMilliseconds;
    watch.reset();
    final backup = NoteBackup.validate(archive);
    final validate = watch.elapsedMilliseconds;
    watch.reset();
    await backup.importInto(store, guestOwner);
    final import = watch.elapsedMilliseconds;
    // ignore: avoid_print
    print(
      'Backup ${archive.length ~/ 1024} KB, 40 images: export $export ms, '
      'validate $validate ms, import $import ms',
    );
    expect(await store.notesFor(guestOwner), hasLength(80));
    expect(export, lessThan(30000));
    expect(validate, lessThan(30000));
    expect(import, lessThan(30000));
    await db.close();
  });
}
