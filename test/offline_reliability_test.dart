import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/backup_files_io.dart' as files;
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class ControlledStore extends LocalStore {
  ControlledStore(super.database) : super.fromDatabase();
  bool fail = false;
  Completer<void>? gate;
  final List<String> written = [];

  @override
  Future<void> putNote(Note note) async {
    await gate?.future;
    if (fail) throw StateError('Simulated disk failure');
    written.add(note.plainText);
    await super.putNote(note);
  }
}

class CancelledPicker extends FileSelectorPlatform {
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => null;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async => null;
}

Uint8List rewriteBackup(
  Uint8List original,
  void Function(Map<String, Uint8List>) change, {
  bool rehash = true,
}) {
  final decoded = ZipDecoder().decodeBytes(original);
  final entries = {
    for (final file in decoded) file.name: Uint8List.fromList(file.content),
  };
  change(entries);
  if (rehash) {
    final manifest = jsonDecode(utf8.decode(entries['manifest.json']!)) as Map;
    manifest['hashes'] = {
      for (final entry in entries.entries.where(
        (entry) => entry.key != 'manifest.json',
      ))
        entry.key: sha256.convert(entry.value).toString(),
    };
    entries['manifest.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest)),
    );
  }
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.add(
      ArchiveFile(entry.key, entry.value.length, entry.value)
        ..compression = CompressionType.none,
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main-window deletion offers Undo and Trash restores notes', (
    tester,
  ) async {
    final (db, controller, note) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('trash-ui.db');
      final controller = NotesController(LocalStore.fromDatabase(db), null);
      await controller.load();
      final note = await controller.create();
      await controller.save(
        note.copyWith(
          plainText: 'Recover this thought',
          delta: [
            {'insert': 'Recover this thought\n'},
          ],
        ),
      );
      return (db, controller, note);
    }))!;
    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.runAsync(
      () => controller.delete(controller.noteById(note.id)!),
    );
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Undo'));
      await controller.waitForWrites();
    });
    await tester.pumpAndSettle();
    expect(controller.notes.single.id, note.id);
    await tester.runAsync(() => controller.delete(controller.notes.single));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Recover this thought'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Restore'));
      await controller.waitForWrites();
    });
    await tester.pumpAndSettle();
    expect(find.text('Trash is empty'), findsOneWidget);
    expect(controller.notes.single.id, note.id);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  test(
    'delayed writes preserve newest text and simultaneous color changes',
    () async {
      final db = await databaseFactoryMemory.openDatabase('ordered-save.db');
      final store = ControlledStore(db);
      final controller = NotesController(store, null);
      await controller.load();
      final note = await controller.create();
      store.gate = Completer<void>();
      final first = controller.save(
        note.copyWith(
          plainText: 'first',
          delta: [
            {'insert': 'first\n'},
          ],
        ),
      );
      final color = controller.save(note.copyWith(colorIndex: 4));
      final latest = controller.save(
        note.copyWith(
          plainText: 'latest',
          delta: [
            {'insert': 'latest\n'},
          ],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.noteById(note.id)!.plainText, isEmpty);
      store.gate!.complete();
      await Future.wait([first, color, latest]);
      expect(controller.noteById(note.id)!.plainText, 'latest');
      expect(controller.noteById(note.id)!.colorIndex, 4);
      expect((await store.noteById(note.id))!.plainText, 'latest');
      controller.dispose();
      await db.close();
    },
  );

  test('Trash survives restart; stale queued saves cannot revive it', () async {
    final db = await databaseFactoryMemory.openDatabase('trash-recovery.db');
    final store = ControlledStore(db);
    final controller = NotesController(store, null);
    await controller.load();
    final note = await controller.create();
    final id = await controller.cacheImage(Uint8List.fromList([1, 2, 3]));
    await controller.save(
      note.copyWith(
        plainText: 'keep me',
        delta: [
          {'insert': 'keep me\n'},
          {
            'insert': {'image': id},
          },
          {'insert': '\n'},
        ],
        images: [id],
        strokes: [
          const InkStroke(
            color: 42,
            points: [
              [1, 2],
            ],
          ),
        ],
      ),
    );
    final saved = controller.noteById(note.id)!;
    store.gate = Completer<void>();
    final deleted = controller.delete(saved);
    final late = controller.save(saved.copyWith(plainText: 'late'));
    store.gate!.complete();
    await Future.wait([deleted, late]);
    expect(controller.noteById(note.id), isNull);
    expect(controller.trash.single.plainText, 'keep me');
    expect(controller.trash.single.deletedAt, isNotNull);
    expect(
      controller.trash.single.toRemoteJson(),
      isNot(contains('deleted_at')),
    );
    controller.dispose();
    final restored = NotesController(store, null);
    await restored.load();
    await restored.restore(note.id);
    expect(restored.notes.single.id, note.id);
    expect(restored.notes.single.deletedAt, isNull);
    expect(restored.notes.single.strokes.single.points, [
      [1, 2],
    ]);
    expect(await store.getImage(id), [1, 2, 3]);
    await restored.delete(restored.notes.single);
    await restored.purge(note.id);
    expect(await store.noteById(note.id), isNull);
    expect(await store.getImage(id), [1, 2, 3]);
    restored.dispose();
    await db.close();
  });

  test('backup round trip includes Trash, mixed images, ink and preferences with fresh IDs', () async {
    final db = await databaseFactoryMemory.openDatabase('backup-roundtrip.db');
    final store = LocalStore.fromDatabase(db);
    final controller = NotesController(store, null);
    await controller.load();
    final note = await controller.create();
    final above = await controller.cacheImage(Uint8List.fromList([1, 2, 3]));
    final inline = await controller.cacheImage(Uint8List.fromList([4, 5, 6]));
    await controller.save(
      note.copyWith(
        plainText: 'Formatted',
        delta: [
          {
            'insert': 'Formatted\n',
            'attributes': {'bold': true},
          },
          {
            'insert': {'image': inline},
          },
          {'insert': '\n'},
        ],
        images: [above, inline],
        strokes: [
          const InkStroke(
            color: 12,
            points: [
              [3, 4],
            ],
          ),
        ],
      ),
    );
    await controller.delete(controller.notes.single);
    await controller.setInlineImages(true);
    await store.setSetting('openNoteWindows', ['private-device-state']);
    await store.setSetting('unrelatedSecret', 'never-export');
    await store.putNote(Note.fresh('other-owner'));
    final bytes = await controller.exportBackup();
    final backup = NoteBackup.validate(bytes);
    expect(backup.notes, hasLength(1));
    expect(backup.trashCount, 1);
    expect(backup.preferences, {'inlineImages': true});
    await controller.setInlineImages(false);
    await controller.importBackup(
      backup,
      restorePreferences: true,
      expectedOwner: guestOwner,
    );
    expect(controller.trash, hasLength(2));
    final copy = controller.trash.firstWhere((value) => value.id != note.id);
    expect(copy.ownerId, guestOwner);
    expect(copy.images.toSet().intersection({above, inline}), isEmpty);
    expect(inlineImageIds(copy.delta), {copy.images.last});
    expect(copy.delta.first, backup.notes.single.delta.first);
    expect(copy.strokes.single.points, [
      [3, 4],
    ]);
    expect(await store.getImage(copy.images.first), [1, 2, 3]);
    expect(controller.inlineImages, isTrue);
    await controller.importBackup(backup, expectedOwner: guestOwner);
    expect(controller.trash, hasLength(3));
    controller.dispose();
    await db.close();
  });

  test('invalid backups change nothing; missing assets, hashes, paths, version and content are rejected', () async {
    final db = await databaseFactoryMemory.openDatabase('backup-validation.db');
    final store = LocalStore.fromDatabase(db);
    final controller = NotesController(store, null);
    await controller.load();
    final note = await controller.create();
    await controller.addImage(note, Uint8List.fromList([1]));
    final bytes = await controller.exportBackup();
    final image = controller.notes.single.images.single;
    final bad = <Uint8List>[
      Uint8List.fromList(bytes.take(bytes.length - 15).toList()),
      rewriteBackup(bytes, (entries) => entries.remove('assets/$image')),
      rewriteBackup(
        bytes,
        (entries) => entries['assets/$image'] = Uint8List.fromList([9]),
        rehash: false,
      ),
      rewriteBackup(bytes, (entries) => entries['../escaped'] = Uint8List(1)),
      rewriteBackup(bytes, (entries) {
        final manifest =
            jsonDecode(utf8.decode(entries['manifest.json']!)) as Map;
        manifest['version'] = 999;
        entries['manifest.json'] = Uint8List.fromList(
          utf8.encode(jsonEncode(manifest)),
        );
      }),
      rewriteBackup(bytes, (entries) {
        final notes = jsonDecode(utf8.decode(entries['notes.json']!)) as List;
        notes.first['content'] = [
          {'retain': 3},
        ];
        entries['notes.json'] = Uint8List.fromList(
          utf8.encode(jsonEncode(notes)),
        );
      }),
    ];
    for (final invalid in bad) {
      expect(() => NoteBackup.validate(invalid), throwsFormatException);
    }
    expect(await store.notesFor(guestOwner), hasLength(1));
    expect(await store.getImage(image), [1]);
    controller.dispose();
    await db.close();
  });

  test(
    'transaction failure rolls back staged notes, assets and preferences',
    () async {
      final db = await databaseFactoryMemory.openDatabase('backup-rollback.db');
      final store = LocalStore.fromDatabase(db);
      final existing = Note.fresh(guestOwner);
      await store.putNote(existing);
      final staged = Note.fresh(guestOwner);
      await expectLater(
        store.importCollection(
          [staged, existing],
          {
            'new-asset': Uint8List.fromList([2]),
          },
          {'theme': 'dark'},
        ),
        throwsStateError,
      );
      expect(await store.noteById(staged.id), isNull);
      expect(await store.getImage('new-asset'), isNull);
      expect(await store.getSetting<String>('theme'), isNull);
      expect(await store.notesFor(guestOwner), hasLength(1));
      await db.close();
    },
  );

  test('file dialog cancellation does not write or import', () async {
    final previous = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = CancelledPicker();
    try {
      expect(await files.pickBackup(), isNull);
      expect(
        await files.saveBackupFile(Uint8List.fromList([1]), 'backup.zip'),
        isFalse,
      );
    } finally {
      FileSelectorPlatform.instance = previous;
    }
  });

  test(
    'sync acknowledgements retain Trash metadata and newer local edits',
    () async {
      final db = await databaseFactoryMemory.openDatabase('sync-ack.db');
      final store = LocalStore.fromDatabase(db);
      final deletedAt = DateTime.utc(2026, 10, 8);
      final snapshot = Note.fresh(guestOwner)
          .copyWith(deleted: true, deletedAt: deletedAt);
      await store.putNote(snapshot);
      final remote = Note.fromJson({...snapshot.toRemoteJson(), 'revision': 1});
      await store.acknowledgeRemote(snapshot, remote);
      expect((await store.noteById(snapshot.id))!.deletedAt, deletedAt);
      final current = (await store.noteById(snapshot.id))!;
      await store.putNote(
        current.copyWith(
          deleted: false,
          plainText: 'restored and edited',
          dirty: true,
        ),
      );
      await store.acknowledgeRemote(current, remote.copyWith(revision: 2));
      final result = (await store.noteById(snapshot.id))!;
      expect(result.deleted, isFalse);
      expect(result.deletedAt, isNull);
      expect(result.plainText, 'restored and edited');
      expect(result.dirty, isTrue);
      expect(result.revision, 2);
      await db.close();
    },
  );

  testWidgets(
    'failed immediate close keeps editor and Retry persists final text',
    (tester) async {
      final (db, store, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase('failed-close.db');
        final store = ControlledStore(db);
        final controller = NotesController(store, null);
        await controller.load();
        final note = await controller.create();
        return (db, store, controller, note);
      }))!;
      var closed = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            quill.FlutterQuillLocalizations.delegate,
          ],
          home: NotePage(
            controller: controller,
            noteId: note.id,
            onClose: () async {
              closed++;
            },
          ),
        ),
      );
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      store.fail = true;
      editor.replaceText(
        0,
        0,
        'final unsaved text',
        const TextSelection.collapsed(offset: 18),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Close note'));
      await tester.pumpAndSettle();
      expect(closed, 0);
      expect(find.text('Retry'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.text('Save failed. Keep editing or retry.'),
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is Semantics &&
                          widget.properties.liveRegion == true,
                    ),
                  )
                  .first,
            )
            .properties
            .liveRegion,
        isTrue,
      );
      expect(editor.document.toPlainText(), 'final unsaved text\n');
      store.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(controller.noteById(note.id)!.plainText, 'final unsaved text');
      expect(find.text('Saved locally'), findsOneWidget);
      store.gate = Completer<void>();
      editor.replaceText(
        0,
        0,
        'latest ',
        const TextSelection.collapsed(offset: 7),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Close note'));
      await tester.pump();
      expect(closed, 0);
      editor.replaceText(
        0,
        0,
        'newest ',
        const TextSelection.collapsed(offset: 7),
      );
      store.gate!.complete();
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(
        controller.noteById(note.id)!.plainText,
        'newest latest final unsaved text',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        controller.dispose();
        await db.close();
      });
    },
  );

  test(
    'editor flush stops on failure and preserves remaining editors',
    () async {
      final db = await databaseFactoryMemory.openDatabase('flush-failure.db');
      final controller = NotesController(LocalStore.fromDatabase(db), null);
      final calls = <String>[];
      var fail = true;
      controller.registerEditor('first', () async {
        calls.add('first');
        if (fail) throw StateError('disk');
      });
      controller.registerEditor('second', () async {
        calls.add('second');
      });
      await expectLater(controller.flushAllEditors(), throwsStateError);
      expect(calls, ['first']);
      fail = false;
      await controller.flushAllEditors();
      expect(calls, ['first', 'first', 'second']);
      controller.dispose();
      await db.close();
    },
  );

  test('large collection search reuses sorting and invalidates after saves', () async {
    final db = await databaseFactoryMemory.openDatabase(
      'collection-baseline.db',
    );
    final store = LocalStore.fromDatabase(db);
    final controller = NotesController(store, null);
    for (final count in [100, 1000, 5000]) {
      await db.transaction((txn) async {
        final records = stringMapStoreFactory.store('notes');
        for (var index = 0; index < count; index++) {
          final note = Note.fresh(guestOwner).copyWith(
            id: 'note-$index',
            plainText: 'Synthetic saffron idea $index',
          );
          await records.record(note.id).put(txn, note.toJson());
        }
      });
      await controller.reload();
      final cached = controller.notes;
      final old = cached;
      final oldTimings = <int>[];
      final newTimings = <int>[];
      for (var run = 0; run < 100; run++) {
        var clock = Stopwatch()..start();
        final sorted = old.where((note) => !note.deleted).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        sorted
            .where((note) => note.plainText.toLowerCase().contains('saffron'))
            .toList();
        oldTimings.add(clock.elapsedMicroseconds);
        clock = Stopwatch()..start();
        final results = controller.search('saffron');
        newTimings.add(clock.elapsedMicroseconds);
        expect(results, hasLength(count));
        expect(identical(cached, controller.notes), isTrue);
      }
      oldTimings.sort();
      newTimings.sort();
      // Report synthetic debug/test timings; these are not release UI timings.
      // ignore: avoid_print
      print(
        'Collection $count: old p95 ${oldTimings[94]} us; cached p95 ${newTimings[94]} us',
      );
    }
    final first = controller.notes.first;
    await controller.save(first.copyWith(plainText: 'new keyword'));
    expect(controller.search('new keyword').single.id, first.id);
    controller.dispose();
    await db.close();
  });
}
