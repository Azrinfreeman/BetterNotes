import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

/// Four notes with distinct dates, titles, colors, reminders, and lengths.
Future<(NotesController, Database, Map<String, String>)> _library(
  String name,
) async {
  final db = await databaseFactoryMemory.openDatabase(name);
  final store = LocalStore.fromDatabase(db);
  final controller = NotesController(store, null);
  await controller.load();
  final ids = <String, String>{};
  Future<void> add(
    String title, {
    required int created,
    required int updated,
    int color = 0,
    String body = 'x',
    bool favorite = false,
    DateTime? remind,
  }) async {
    final note = (await controller.create()).copyWith(
      title: title,
      plainText: body,
      colorIndex: color,
      favorite: favorite,
      remindAt: remind,
      createdAt: DateTime.utc(2024, 1, created),
      updatedAt: DateTime.utc(2024, 2, updated),
    );
    await store.putNote(note);
    ids[title] = note.id;
  }

  await add('Banana', created: 3, updated: 1, color: 5, body: 'short');
  await add(
    'apple',
    created: 1,
    updated: 4,
    color: 2,
    body: 'a much longer body of text than the others',
    favorite: true,
  );
  await add(
    'Cherry',
    created: 4,
    updated: 2,
    color: 2,
    remind: DateTime.utc(2030, 1, 5),
  );
  await add(
    'date',
    created: 2,
    updated: 3,
    color: 0,
    remind: DateTime.utc(2030, 1, 1),
  );
  await controller.reload();
  return (controller, db, ids);
}

List<String> _titles(NotesController c) => [
  for (final note in c.librarySearch('')) note.title,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every sort order orders notes as described', () async {
    final (c, db, _) = await _library('sort-orders');
    await c.setLibraryOptions(favoritesFirst: false);
    Future<List<String>> by(NoteSort sort) async {
      await c.setLibraryOptions(sort: sort);
      return _titles(c);
    }

    expect(await by(NoteSort.updated), ['apple', 'date', 'Cherry', 'Banana']);
    expect(await by(NoteSort.updatedOldest), [
      'Banana',
      'Cherry',
      'date',
      'apple',
    ]);
    expect(await by(NoteSort.created), ['Cherry', 'Banana', 'date', 'apple']);
    expect(await by(NoteSort.createdOldest), [
      'apple',
      'date',
      'Banana',
      'Cherry',
    ]);
    expect(await by(NoteSort.title), ['apple', 'Banana', 'Cherry', 'date']);
    expect(await by(NoteSort.titleDesc), ['date', 'Cherry', 'Banana', 'apple']);
    // Soonest reminder first; notes without one follow by latest edit.
    expect(await by(NoteSort.reminder), ['date', 'Cherry', 'apple', 'Banana']);
    // Lowest color index first, ties by latest edit.
    expect(await by(NoteSort.color), ['date', 'apple', 'Cherry', 'Banana']);
    expect((await by(NoteSort.length)).first, 'apple');
    c.dispose();
    await db.close();
  });

  test('favorites-first can be turned off and everything persists', () async {
    final (c, db, _) = await _library('sort-favorites');
    await c.setLibraryOptions(sort: NoteSort.titleDesc);
    expect(_titles(c).first, 'apple'); // favorite pinned above 'date'
    await c.setLibraryOptions(favoritesFirst: false);
    expect(_titles(c).first, 'date');
    await c.setLibraryOptions(sort: NoteSort.createdOldest);
    c.dispose();

    final reopened = NotesController(LocalStore.fromDatabase(db), null);
    await reopened.load();
    expect(reopened.noteSort, NoteSort.createdOldest);
    expect(reopened.favoritesFirst, isFalse);
    // Reset filters returns the sort to the default but keeps the preference.
    await reopened.setLibraryOptions(reset: true);
    expect(reopened.noteSort, NoteSort.updated);
    expect(reopened.favoritesFirst, isFalse);
    reopened.dispose();
    await db.close();
  });

  test('older saved sort names still load', () async {
    final db = await databaseFactoryMemory.openDatabase('sort-legacy');
    final store = LocalStore.fromDatabase(db);
    await store.setSetting('libraryOptions', {
      'view': 'notes',
      'sort': 'title',
      'tags': [],
    });
    final c = NotesController(store, null);
    await c.load();
    expect(c.noteSort, NoteSort.title);
    expect(c.favoritesFirst, isTrue);
    await store.setSetting('libraryOptions', {'sort': 'someFutureSort'});
    final d = NotesController(store, null);
    await d.load();
    expect(d.noteSort, NoteSort.updated);
    c.dispose();
    d.dispose();
    await db.close();
  });

  testWidgets('the sort menu lists every order and cards show the date used', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(470, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (controller, db, _) =
        await tester.runAsync(() => _library('sort-ui')) ??
        (throw StateError('setup failed'));
    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.textContaining('Created '), findsNothing);

    await tester.tap(find.byKey(const ValueKey('sort-order')));
    await tester.pumpAndSettle();
    for (final label in [
      'Recently edited',
      'Least recently edited',
      'Newest created',
      'Oldest created',
      'Title A–Z',
      'Title Z–A',
      'Reminder date',
      'Color',
      'Longest first',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await tester.tap(find.text('Oldest created').last);
    await tester.pumpAndSettle();
    expect(controller.noteSort, NoteSort.createdOldest);
    expect(find.textContaining('Created '), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('favorites-first')));
    await tester.tap(find.byKey(const ValueKey('favorites-first')));
    await tester.pumpAndSettle();
    expect(controller.favoritesFirst, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });
}
