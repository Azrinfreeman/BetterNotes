import 'dart:convert';

import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy records load with defaults without rewriting content', () async {
    final db = await databaseFactoryMemory.openDatabase('legacy-organization');
    final store = LocalStore.fromDatabase(db);
    final json = Note.fresh(guestOwner).toJson();
    for (final key in ['title', 'favorite', 'tags', 'archived_at']) {
      json.remove(key);
    }
    final legacy = Note.fromJson(json);
    expect(legacy.title, '');
    expect(legacy.favorite, isFalse);
    expect(legacy.tags, isEmpty);
    expect(legacy.archivedAt, isNull);
    expect(legacy.displayTitle, 'Empty note');
    expect(
      legacy.copyWith(plainText: '\n  First line\nNext').displayTitle,
      'First line',
    );
    expect(legacy.copyWith(images: ['image']).displayTitle, 'Image note');
    await store.putNote(legacy);
    await store.setSetting('localSchemaVersion', 1);
    final controller = NotesController(store, null);
    await controller.load();
    expect(await store.getSetting<int>('localSchemaVersion'), 2);
    expect(controller.notes.single.delta, json['content']);
    expect(
      controller.notes.single.toRemoteJson().keys,
      isNot(contains('title')),
    );
    expect(
      controller.notes.single.toRemoteJson().keys,
      isNot(contains('archived_at')),
    );
    controller.dispose();
    await db.close();
  });

  test(
    'title search, favorites, tags and views compose and preferences restart',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'library-organization',
      );
      final store = LocalStore.fromDatabase(db);
      final controller = NotesController(store, null);
      final old = DateTime.utc(2020);
      final favorite = Note.fresh(guestOwner).copyWith(
        title: 'Zebra',
        favorite: true,
        tags: [' Work ', 'work', 'IDEAS'],
        updatedAt: old,
      );
      final ordinary = Note.fresh(guestOwner)
          .copyWith(title: 'Alpha', plainText: 'Budget', tags: ['work']);
      final archived = Note.fresh(guestOwner)
          .copyWith(title: 'Archived budget', tags: ['work'], archivedAt: old);
      final deleted = Note.fresh(guestOwner)
          .copyWith(title: 'Deleted budget', deleted: true);
      for (final note in [favorite, ordinary, archived, deleted]) {
        await store.putNote(note);
      }
      await controller.load();
      expect(favorite.tags, ['ideas', 'work']);
      expect(controller.notes.map((note) => note.id), [
        favorite.id,
        ordinary.id,
      ]);
      await controller.setLibraryOptions(
        tags: ['work', 'ideas'],
        sort: NoteSort.title,
      );
      expect(controller.librarySearch('zEbRa').single.id, favorite.id);
      expect(controller.librarySearch('Budget'), isEmpty);
      await controller.setLibraryOptions(
        view: LibraryView.archive,
        tags: ['work'],
      );
      expect(controller.librarySearch('budget').single.id, archived.id);
      await controller.setLibraryOptions(view: LibraryView.allActive);
      expect(
        controller.librarySearch('budget').map((note) => note.id).toSet(),
        {ordinary.id, archived.id},
      );
      await controller.setLibraryOptions(view: LibraryView.favorites, tags: []);
      expect(controller.librarySearch('').single.id, favorite.id);
      controller.dispose();
      final restored = NotesController(store, null);
      await restored.load();
      expect(restored.libraryView, LibraryView.favorites);
      expect(restored.noteSort, NoteSort.title);
      await restored.setLibraryOptions(reset: true);
      expect(restored.libraryView, LibraryView.notes);
      expect(restored.selectedTags, isEmpty);
      expect(restored.noteSort, NoteSort.updated);
      restored.dispose();
      await db.close();
    },
  );

  test('archive flushes first, retains bounds and refuses late saves or failed flush', () async {
    final db = await databaseFactoryMemory.openDatabase('archive-organization');
    final store = LocalStore.fromDatabase(db);
    final controller = NotesController(store, null);
    await controller.load();
    final note = await controller.create();
    await store.setSetting('windowBounds:${note.id}', [10, 20, 470, 520]);
    controller.registerEditor(
      note.id,
      () => controller.save(
        controller
            .noteById(note.id)!
            .copyWith(
              plainText: 'Flushed text',
              delta: [
                {'insert': 'Flushed text\n'},
              ],
            ),
      ),
    );
    var desktopFlushes = 0;
    controller.flushDesktopEditor = (_) async {
      desktopFlushes++;
    };
    await controller.archive(note.id);
    expect(desktopFlushes, 1);
    expect(controller.notes, isEmpty);
    expect(controller.archiveNotes.single.plainText, 'Flushed text');
    await controller.save(note.copyWith(plainText: 'Late stale text'));
    expect(controller.archiveNotes.single.plainText, 'Flushed text');
    expect(await store.getSetting<List>('windowBounds:${note.id}'), [
      10,
      20,
      470,
      520,
    ]);
    await controller.archive(note.id, archived: false);
    controller.registerEditor(
      note.id,
      () async => throw StateError('Disk failed'),
    );
    await expectLater(controller.archive(note.id), throwsStateError);
    expect(controller.notes.single.archivedAt, isNull);
    controller.dispose();
    await db.close();
  });

  test(
    'metadata and checklists survive restart, Trash and backup copies',
    () async {
      final db = await databaseFactoryMemory.openDatabase(
        'backup-organization',
      );
      final store = LocalStore.fromDatabase(db);
      final controller = NotesController(store, null);
      await controller.load();
      final note = await controller.create();
      await controller.save(
        note.copyWith(
          title: 'Tasks',
          favorite: true,
          tags: [' Home '],
          plainText: 'Buy fruit\nCall home',
          delta: [
            {'insert': 'Buy fruit'},
            {
              'insert': '\n',
              'attributes': {'list': 'checked'},
            },
            {'insert': 'Call home'},
            {
              'insert': '\n',
              'attributes': {'list': 'unchecked'},
            },
          ],
        ),
      );
      await controller.archive(note.id);
      await controller.delete(controller.noteById(note.id)!);
      await controller.restore(note.id);
      expect(controller.archiveNotes.single.tasks, (done: 1, total: 2));
      expect(
        await controller.exportText(),
        contains('[x] Buy fruit\n[ ] Call home'),
      );
      final backup = NoteBackup.validate(await controller.exportBackup());
      await backup.importInto(store, guestOwner);
      controller.dispose();
      final restored = NotesController(store, null);
      await restored.load();
      expect(restored.archiveNotes, hasLength(2));
      expect(
        restored.archiveNotes.map((note) => note.id).toSet(),
        hasLength(2),
      );
      for (final copy in restored.archiveNotes) {
        expect(copy.title, 'Tasks');
        expect(copy.favorite, isTrue);
        expect(copy.tags, ['home']);
        expect(copy.tasks, (done: 1, total: 2));
      }
      restored.dispose();
      await db.close();
    },
  );

  test(
    'cloud acknowledgements preserve local organization and concurrent changes',
    () async {
      final db = await databaseFactoryMemory.openDatabase('sync-organization');
      final store = LocalStore.fromDatabase(db);
      final local = Note.fresh('owner').copyWith(
        title: 'Local title',
        favorite: true,
        tags: ['ideas'],
        archivedAt: DateTime.utc(2026),
      );
      await store.putNote(local);
      final server = Note.fromJson(local.toRemoteJson())
          .copyWith(revision: 1, dirty: false, plainText: 'Remote body');
      await store.acknowledgeRemote(local, server);
      final acknowledged = (await store.noteById(local.id))!;
      expect(acknowledged.title, 'Local title');
      expect(acknowledged.favorite, isTrue);
      expect(acknowledged.tags, ['ideas']);
      expect(acknowledged.archivedAt, local.archivedAt);
      expect(acknowledged.plainText, 'Remote body');
      await store.putNote(acknowledged.copyWith(title: 'Concurrent title'));
      await store.acknowledgeRemote(acknowledged, server.copyWith(revision: 2));
      expect((await store.noteById(local.id))!.title, 'Concurrent title');
      await db.close();
    },
  );

  testWidgets(
    'find selects formatted text across image offsets and preserves Ctrl+F',
    (tester) async {
      final (db, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase(
          'find-organization',
        );
        final store = LocalStore.fromDatabase(db);
        final controller = NotesController(store, null);
        await controller.load();
        final note = await controller.create();
        final image = await controller.cacheImage(Uint8List.fromList([1]));
        await controller.save(
          note.copyWith(
            images: [image],
            plainText: 'Hello hello',
            delta: [
              {
                'insert': 'Hel',
                'attributes': {'bold': true},
              },
              {'insert': 'lo\n'},
              {
                'insert': {'image': image},
              },
              {'insert': '\nhello\n'},
            ],
          ),
        );
        return (db, controller, controller.noteById(note.id)!);
      }))!;
      var libraryFinds = 0;
      await tester.pumpWidget(
        NoteWindowApp(
          controller: controller,
          noteId: note.id,
          onClose: () async {},
          onFindNotes: () async {
            libraryFinds++;
          },
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      final before = jsonEncode(editor.document.toDelta().toJson());
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('find-in-note')),
        'HELLO',
      );
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('find-in-note')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(
        editor.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(
        editor.selection,
        const TextSelection(baseOffset: 8, extentOffset: 13),
      );
      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(editor.selection.baseOffset, 0);
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pump();
      expect(editor.selection.baseOffset, 8);
      expect(jsonEncode(editor.document.toDelta().toJson()), before);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byKey(const ValueKey('find-in-note')), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(libraryFinds, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'checklist toolbar and toggles undo, redo and reopen with inline images',
    (tester) async {
      final (db, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase(
          'checklist-organization',
        );
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        final note = await controller.create();
        final image = await controller.cacheImage(Uint8List.fromList([1]));
        await controller.save(
          note.copyWith(
            images: [image],
            plainText: 'Task',
            delta: [
              {'insert': 'Task\n'},
              {
                'insert': {'image': image},
              },
              {'insert': '\n'},
            ],
          ),
        );
        return (db, controller, note);
      }))!;
      Widget app() => NoteWindowApp(
        controller: controller,
        noteId: note.id,
        onClose: () async {},
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      editor.updateSelection(
        const TextSelection.collapsed(offset: 0),
        quill.ChangeSource.local,
      );
      await tester.tap(find.byType(quill.QuillToolbarToggleCheckListButton));
      await tester.pumpAndSettle();
      expect(editor.getSelectionStyle().attributes['list']?.value, 'unchecked');
      // Start a separate undo group, as with two deliberate user actions.
      editor.document.history.lastRecorded = 0;
      await tester.tap(
        find
            .descendant(
              of: find.byType(quill.QuillCheckboxPoint).first,
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(editor.getSelectionStyle().attributes['list']?.value, 'checked');
      editor.undo();
      await tester.pump();
      expect(
        Note.fresh(guestOwner)
            .copyWith(delta: editor.document.toDelta().toJson())
            .tasks,
        (done: 0, total: 1),
      );
      editor.redo();
      await tester.pump();
      expect(
        Note.fresh(guestOwner)
            .copyWith(delta: editor.document.toDelta().toJson())
            .tasks,
        (done: 1, total: 1),
      );
      await tester.runAsync(controller.flushAllEditors);
      expect(controller.noteById(note.id)!.tasks, (done: 1, total: 1));
      expect(inlineImageIds(controller.noteById(note.id)!.delta), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final reopened = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      expect(
        reopened.document.toDelta().toJson(),
        controller.noteById(note.id)!.delta,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );

  testWidgets(
    'title, tag, favorite and archive controls keep unsaved text at 470 px',
    (tester) async {
      tester.view.physicalSize = const Size(470, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (db, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase(
          'organization-controls',
        );
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        final note = await controller.create();
        await controller.save(
          note.copyWith(
            plainText: 'Draft',
            delta: [
              {'insert': 'Draft\n'},
            ],
          ),
        );
        return (db, controller, note);
      }))!;
      await tester.pumpWidget(BetterNotesApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      editor.replaceText(
        0,
        5,
        'Unsaved draft',
        const TextSelection.collapsed(offset: 13),
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Title and tags'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('note-title')),
        'Project plan',
      );
      await tester.enterText(
        find.byKey(const ValueKey('note-tags')),
        ' Work, IDEAS, work ',
      );
      await tester.tap(find.text('Save'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();
      expect(controller.noteById(note.id)!.title, 'Project plan');
      expect(controller.noteById(note.id)!.tags, ['ideas', 'work']);
      expect(controller.noteById(note.id)!.plainText, 'Unsaved draft');
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Favorite'));
      await tester.pumpAndSettle();
      expect(controller.noteById(note.id)!.favorite, isTrue);
      editor.replaceText(
        0,
        13,
        'Final draft',
        const TextSelection.collapsed(offset: 11),
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive note'));
      await tester.pumpAndSettle();
      expect(controller.archiveNotes.single.plainText, 'Final draft');
      expect(find.byType(quill.QuillEditor), findsNothing);
      await tester.tap(find.byTooltip('Browse notes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Project plan'), findsOneWidget);
      await tester.ensureVisible(find.text('Restore from Archive'));
      await tester.pumpAndSettle();
      expect(find.text('Restore from Archive').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Restore from Archive'));
      await tester.pumpAndSettle();
      expect(controller.archiveNotes, isEmpty);
      await tester.tap(find.byTooltip('Browse notes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Project plan'), findsOneWidget);
      await tester.tap(find.byTooltip('Browse notes'));
      await tester.pumpAndSettle();
      final drawer = find.byType(Drawer);
      final filterTags = find.descendant(
        of: drawer,
        matching: find.text('Filter by tags'),
      );
      await tester.scrollUntilVisible(
        filterTags,
        200,
        scrollable: find.descendant(
          of: drawer,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(filterTags);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ideas'));
      await tester.tap(find.text('work'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(controller.selectedTags, ['ideas', 'work']);
      expect(controller.librarySearch('').single.id, note.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );
}
