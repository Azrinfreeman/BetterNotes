import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/markdown_export.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Future<(NotesController, Database)> _open(String name) async {
  final db = await databaseFactoryMemory.openDatabase(name);
  final controller = NotesController(LocalStore.fromDatabase(db), null);
  await controller.load();
  return (controller, db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Markdown keeps headings, lists, checklists, links and tags', () {
    final note = Note.fresh(guestOwner).copyWith(
      title: 'Plan',
      tags: ['work'],
      delta: [
        {'insert': 'Intro'},
        {
          'insert': '\n',
          'attributes': {'header': 2},
        },
        {
          'insert': 'bold',
          'attributes': {'bold': true},
        },
        {'insert': ' and '},
        {
          'insert': 'site',
          'attributes': {'link': 'https://example.com'},
        },
        {'insert': '\n'},
        {'insert': 'one'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'two'},
        {
          'insert': '\n',
          'attributes': {'list': 'ordered'},
        },
        {'insert': 'todo'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
        {'insert': 'done'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
      ],
    );
    expect(
      noteMarkdown(note),
      '# Plan\n\n'
      '## Intro\n'
      '**bold** and [site](https://example.com)\n'
      '1. one\n'
      '2. two\n'
      '- [ ] todo\n'
      '- [x] done\n\n'
      'Tags: #work\n',
    );
  });

  test(
    'export is a plain file for one text note and a ZIP with images',
    () async {
      final text = Note.fresh(guestOwner).copyWith(
        title: 'a/b: c',
        delta: [
          {'insert': 'hi\n'},
        ],
      );
      final single = await exportMarkdown([text], (_, _) async => null);
      expect(single.name, 'ab c.md');
      expect(utf8.decode(single.bytes), contains('hi'));

      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0, 0, 0]);
      final withImage = Note.fresh(guestOwner).copyWith(
        title: 'Pic',
        images: ['img-1'],
        delta: [
          {
            'insert': {'image': 'img-1'},
          },
          {'insert': '\n'},
        ],
      );
      final duplicateTitle = text.copyWith(title: 'Pic');
      final zip = await exportMarkdown([
        withImage,
        duplicateTitle,
      ], (_, id) async => id == 'img-1' ? png : null);
      expect(zip.mimeType, 'application/zip');
      final files = ZipDecoder().decodeBytes(zip.bytes);
      final names = files.map((f) => f.name).toSet();
      expect(names, {'images/img-1.png', 'Pic.md', 'Pic 2.md'});
      final md = utf8.decode(files.findFile('Pic.md')!.content);
      expect(md, contains('![](images/img-1.png)'));
    },
  );

  test('Trash retention removes only expired local notes', () async {
    final (controller, db) = await _open('round-b-retention');
    final old = await controller.create();
    final recent = await controller.create();
    final kept = await controller.create();
    await controller.delete(old);
    await controller.delete(recent);
    await controller.setTrashRetentionDays(7);
    expect(controller.trash, hasLength(2));
    final removed = await controller.purgeExpiredTrash(
      now: DateTime.now().add(const Duration(days: 8)),
    );
    expect(removed, 2);
    expect(controller.trash, isEmpty);
    expect(controller.noteById(kept.id), isNotNull);
    await controller.setTrashRetentionDays(0);
    expect(await controller.purgeExpiredTrash(), 0);
    controller.dispose();
    await db.close();
  });

  test('bulk actions and the compact view persist', () async {
    final (controller, db) = await _open('round-b-bulk');
    final a = await controller.create();
    final b = await controller.create();
    final c = await controller.create();
    final ids = [a.id, b.id];
    expect(await controller.bulkFavorite(ids, true), 2);
    expect(await controller.bulkColor(ids, 5), 2);
    expect(await controller.bulkAddTags(ids, ['x', 'y']), 2);
    expect(controller.noteById(a.id)!.tags, ['x', 'y']);
    expect(controller.noteById(b.id)!.colorIndex, 5);
    expect(controller.noteById(c.id)!.favorite, isFalse);
    expect(await controller.bulkArchive([a.id]), 1);
    expect(await controller.bulkFavorite([a.id], false), 0);
    expect(await controller.bulkTrash([b.id, c.id]), 2);
    expect(controller.notes, isEmpty);
    expect(controller.trash, hasLength(2));
    await controller.setLibraryOptions(compact: true);
    controller.dispose();

    final reopened = NotesController(LocalStore.fromDatabase(db), null);
    await reopened.load();
    expect(reopened.compactView, isTrue);
    reopened.dispose();
    await db.close();
  });

  testWidgets('compact list view and long-press multi-select at 470 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(470, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (controller, db, ids) =
        await tester.runAsync(() async {
          final (controller, db) = await _open('round-b-ui');
          final a = await controller.create();
          final b = await controller.create();
          await controller.save(
            a.copyWith(
              title: 'Alpha',
              delta: [
                {'insert': 'first\n'},
              ],
              plainText: 'first\n',
            ),
          );
          await controller.save(
            b.copyWith(
              title: 'Beta',
              delta: [
                {'insert': 'second\n'},
              ],
              plainText: 'second\n',
            ),
          );
          return (controller, db, [a.id, b.id]);
        }) ??
        (throw StateError('setup failed'));
    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Compact list view'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Card view'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Favorite selected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('selected'), findsNothing);
    expect(
      [for (final id in ids) controller.noteById(id)!.favorite],
      [true, true],
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });
}
