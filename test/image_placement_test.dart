import 'dart:convert';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:better_notes/ui/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets('image placement is selectable and survives restart', (
    tester,
  ) async {
    final (db, controller) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('image-settings.db');
      final controller = NotesController(LocalStore.fromDatabase(db), null);
      await controller.load();
      return (db, controller);
    }))!;
    expect(controller.inlineImages, isFalse);
    await tester.pumpWidget(
      MaterialApp(home: SettingsPage(controller: controller)),
    );
    await tester.tap(find.byKey(const ValueKey('image-placement')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Within note').last);
    await tester.pumpAndSettle();
    expect(controller.inlineImages, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      final restored = NotesController(LocalStore.fromDatabase(db), null);
      await restored.load();
      expect(restored.inlineImages, isTrue);
      await restored.setInlineImages(false);
      restored.dispose();
      final finalController = NotesController(
        LocalStore.fromDatabase(db),
        null,
      );
      await finalController.load();
      expect(finalController.inlineImages, isFalse);
      finalController.dispose();
      await db.close();
    });
  });

  test('conflict copies remap inline image IDs and preserve formatting', () {
    final delta = [
      {
        'insert': 'Before\n',
        'attributes': {'bold': true},
      },
      {
        'insert': {'image': 'original'},
      },
      {'insert': '\nAfter\n'},
    ];
    final remapped = remapInlineImages(delta, {'original': 'copy'});
    expect(inlineImageIds(remapped), {'copy'});
    expect(remapped.first, delta.first);
    expect(inlineImageIds(delta), {'original'});
    expect(
      quill.Document.fromJson(remapped).toPlainText(),
      'Before\n\uFFFC\nAfter\n',
    );
  });

  testWidgets(
    'inline images split paragraphs, undo, reopen, and coexist with above images',
    (tester) async {
      tester.view.physicalSize = const Size(470, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lQAAAABJRU5ErkJggg==',
      );
      final (db, controller, noteId) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase('inline-editor.db');
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        final note = await controller.create();
        await controller.addImage(note, png);
        await controller.setInlineImages(true);
        return (db, controller, note.id);
      }))!;
      Widget page() => MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: NotePage(
          controller: controller,
          noteId: noteId,
          clipboardImageReader: () async => png,
        ),
      );
      await tester.pumpWidget(page());
      var editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      editor.replaceText(
        0,
        0,
        'First line',
        const TextSelection.collapsed(offset: 10),
      );
      editor.document.history.clear();
      await tester.tap(find.byTooltip('Paste image from clipboard'));
      await tester.pumpAndSettle();
      expect(editor.document.toPlainText(), 'First line\n\uFFFC\n\n');
      expect(editor.selection.baseOffset, 13);
      var note = controller.noteById(noteId)!;
      final inlineId = inlineImageIds(note.delta).single;
      expect(note.images, hasLength(2));
      expect(find.byKey(ValueKey('above-image-$inlineId')), findsNothing);
      expect(find.byKey(ValueKey('inline-image-$inlineId')), findsOneWidget);
      final inlineCard = find.byKey(ValueKey('inline-image-$inlineId'));
      expect(tester.getSize(inlineCard).width, lessThanOrEqualTo(430));
      await tester.ensureVisible(inlineCard);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: inlineCard, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(Dialog))).pop();
      await tester.pumpAndSettle();
      editor.undo();
      await tester.pumpAndSettle();
      expect(editor.document.toPlainText(), 'First line\n');
      expect(controller.noteById(noteId)!.images, hasLength(1));
      expect(find.byKey(ValueKey('above-image-$inlineId')), findsNothing);
      expect(
        await tester.runAsync(() => controller.image(noteId, inlineId)),
        png,
      );
      editor.redo();
      await tester.pumpAndSettle();
      expect(inlineImageIds(controller.noteById(noteId)!.delta), {inlineId});
      editor.replaceText(
        13,
        0,
        'More text',
        const TextSelection.collapsed(offset: 17),
      );
      editor.document.history.clear();
      await tester.tap(find.byTooltip('Paste image from clipboard'));
      await tester.pumpAndSettle();
      expect(
        editor.document.toPlainText(),
        'First line\n\uFFFC\nMore\n\uFFFC\n text\n',
      );
      note = controller.noteById(noteId)!;
      expect(inlineImageIds(note.delta), hasLength(2));
      expect(note.images, hasLength(3));
      expect(note.plainText, isNot(contains('\uFFFC')));
      await tester.runAsync(() => controller.setInlineImages(false));
      await tester.pumpAndSettle();
      expect(inlineImageIds(controller.noteById(noteId)!.delta), hasLength(2));
      editor.document.history.clear();
      final removeFirst = find.descendant(
        of: find.byKey(ValueKey('inline-image-$inlineId')),
        matching: find.byTooltip('Remove image'),
      );
      await tester.ensureVisible(removeFirst);
      await tester.pumpAndSettle();
      await tester.tap(removeFirst);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(inlineImageIds(controller.noteById(noteId)!.delta), hasLength(1));
      editor.undo();
      await tester.pumpAndSettle();
      expect(inlineImageIds(controller.noteById(noteId)!.delta), hasLength(2));
      final expectedDelta = controller.noteById(noteId)!.delta;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() => controller.reload());
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      expect(editor.document.toDelta().toJson(), expectedDelta);
      expect(find.byKey(ValueKey('inline-image-$inlineId')), findsOneWidget);
      expect(find.byKey(ValueKey('above-image-$inlineId')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        controller.dispose();
        await db.close();
      });
    },
  );
}
