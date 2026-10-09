import 'dart:convert';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/data/clipboard_image.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image/image.dart' as img;
// The editor's native clipboard bridge is unavailable in widget tests.
// ignore: depend_on_referenced_packages
import 'package:quill_native_bridge_platform_interface/quill_native_bridge_platform_interface.dart';
import 'package:sembast/sembast_memory.dart';

class _NoRichClipboardBridge extends QuillNativeBridgePlatform {
  @override
  Future<bool> isSupported(QuillNativeBridgeFeature feature) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notes, images, and deletion survive a controller restart', () async {
    final db = await databaseFactoryMemory.openDatabase('note-flow-test.db');
    final store = LocalStore.fromDatabase(db);
    final first = NotesController(store, null);
    await first.load();

    final created = await first.create();
    await first.save(
      created.copyWith(
        plainText: 'Pick up oranges',
        delta: const [
          {'insert': 'Pick up oranges\n'},
        ],
        colorIndex: 2,
      ),
    );
    final saved = first.noteById(created.id)!;
    await first.addImage(saved, Uint8List.fromList([1, 2, 3]));
    expect(first.notes.single.plainText, 'Pick up oranges');
    first.dispose();

    final second = NotesController(store, null);
    await second.load();
    final restored = second.notes.single;
    expect(restored.colorIndex, 2);
    expect(await second.image(restored.id, restored.images.single), [1, 2, 3]);
    await second.delete(restored);
    expect(second.notes, isEmpty);
    second.dispose();
    await db.close();
  });

  testWidgets('the notes list filters saved note text', (tester) async {
    final (db, controller) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'note-search-test.db',
          );
          final store = LocalStore.fromDatabase(db);
          final controller = NotesController(store, null);
          await store.putNote(
            Note.fresh(guestOwner).copyWith(plainText: 'Saffron ideas'),
          );
          await controller.load();
          return (db, controller);
        }) ??
        (throw StateError('Could not set up widget test'));
    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text('Saffron ideas'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching notes'), findsOneWidget);
    expect(find.text('Saffron ideas'), findsNothing);

    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  testWidgets('a note written in the editor returns to the list', (
    tester,
  ) async {
    final (db, controller) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'note-editor-test.db',
          );
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          return (db, controller);
        }) ??
        (throw StateError('Could not set up widget test'));

    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a note'));
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller.replaceText(
      0,
      0,
      'Small bright idea',
      const TextSelection.collapsed(offset: 17),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Close note'));
    await tester.pumpAndSettle();
    expect(find.text('Small bright idea'), findsOneWidget);

    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  testWidgets('holding Backspace deletes repeatedly and saves the result', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final (db, controller, note) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'backspace-test.db',
          );
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          final note = await controller.create();
          return (db, controller, note);
        }) ??
        (throw StateError('Could not set up Backspace test'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: NotePage(controller: controller, noteId: note.id),
      ),
    );
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.controller.replaceText(
      0,
      0,
      'hello',
      const TextSelection.collapsed(offset: 5),
    );
    editor.focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    expect(editor.controller.document.toPlainText(), 'hell\n');
    for (final expected in ['hel\n', 'he\n', 'h\n', '\n', '\n']) {
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
      expect(editor.controller.document.toPlainText(), expected);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
    // A whole selection is removed once, then repeats continue at the caret.
    editor.controller.replaceText(
      0,
      0,
      'a👩‍💻e\u0301xyz',
      const TextSelection(baseOffset: 8, extentOffset: 11),
    );
    editor.controller.document.history.clear();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.backspace);
    expect(editor.controller.document.toPlainText(), 'a👩‍💻e\u0301\n');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
    expect(editor.controller.document.toPlainText(), 'a👩‍💻\n');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
    expect(editor.controller.document.toPlainText(), 'a\n');
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.backspace);
    expect(editor.controller.document.toPlainText(), '\n');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.backspace);
    // Undo remains available through the editor's normal history.
    editor.controller.undo();
    expect(editor.controller.document.toPlainText(), isNot('\n'));
    editor.controller.redo();
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.noteById(note.id)!.plainText, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
    debugDefaultTargetPlatformOverride = null;
  });

  for (final (pasteMode, inlineImages) in [
    for (final inline in [false, true])
      for (final mode in ['button', 'editor shortcut', 'note shortcut', 'text'])
        (mode, inline),
  ]) {
    testWidgets(
      'paste $pasteMode (inline: $inlineImages) stores clipboard content once',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final previousBridge = QuillNativeBridgePlatform.instance;
        QuillNativeBridgePlatform.instance = _NoRichClipboardBridge();
        addTearDown(() => QuillNativeBridgePlatform.instance = previousBridge);
        final (db, controller, note) =
            await tester.runAsync(() async {
              final db = await databaseFactoryMemory.openDatabase(
                'note-paste-$pasteMode-test.db',
              );
              final controller = NotesController(
                LocalStore.fromDatabase(db),
                null,
              );
              await controller.load();
              await controller.setInlineImages(inlineImages);
              final note = await controller.create();
              return (db, controller, note);
            }) ??
            (throw StateError('Could not set up paste test'));

        final png = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lQAAAABJRU5ErkJggg==',
        );
        var imageReads = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              quill.FlutterQuillLocalizations.delegate,
            ],
            home: NotePage(
              controller: controller,
              noteId: note.id,
              clipboardImageReader: () async {
                imageReads++;
                return pasteMode == 'text' ? null : png;
              },
            ),
          ),
        );
        await tester.pump();
        if (pasteMode == 'button') {
          await tester.tap(find.byTooltip('Paste image from clipboard'));
        } else {
          if (pasteMode != 'note shortcut') {
            tester
                .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
                .focusNode
                .requestFocus();
            await tester.pump();
          }
          if (pasteMode == 'text') {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              (call) async => call.method == 'Clipboard.getData'
                  ? {'text': 'Pasted text'}
                  : null,
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(SystemChannels.platform, null),
            );
          }
          Future<void> pasteShortcut() async {
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          }

          await pasteShortcut();
        }
        await tester.pumpAndSettle();
        expect(imageReads, 1);
        final saved = controller.noteById(note.id)!;
        if (pasteMode == 'text') {
          expect(saved.images, isEmpty);
          expect(
            tester
                .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
                .controller
                .document
                .toPlainText(),
            'Pasted text\n',
          );
        } else {
          expect(saved.images, hasLength(1));
          expect(
            inlineImageIds(saved.delta),
            inlineImages ? saved.images.toSet() : isEmpty,
          );
          final stored = await tester.runAsync(
            () => controller.image(note.id, saved.images.single),
          );
          expect(stored, png);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          controller.dispose();
          await db.close();
        });
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('Ctrl+N creates another note while the editor is open', (
    tester,
  ) async {
    final (db, controller) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'note-shortcut-test.db',
          );
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          return (db, controller);
        }) ??
        (throw StateError('Could not set up shortcut test'));

    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a note'));
    await tester.pumpAndSettle();
    expect(controller.notes, hasLength(1));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(controller.notes, hasLength(2));

    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  testWidgets('Ctrl+T toggles strikethrough on selected note text', (
    tester,
  ) async {
    final (db, controller, _) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'note-strike-shortcut-test.db',
          );
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          final fresh = await controller.create();
          final note = fresh.copyWith(
            delta: const [
              {'insert': 'hello\n'},
            ],
            plainText: 'hello',
          );
          await controller.save(note);
          return (db, controller, note);
        }) ??
        (throw StateError('Could not set up formatting test'));

    await tester.pumpWidget(BetterNotesApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    final editor = tester.widget<quill.QuillEditor>(
      find.byType(quill.QuillEditor),
    );
    editor.focusNode.requestFocus();
    await tester.pump();
    editor.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      quill.ChangeSource.local,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(
      editor.controller.document.toDelta().toJson().first['attributes'],
      containsPair('strike', true),
    );

    await tester.tap(find.byTooltip('Close note'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  testWidgets('note editor fits a small window with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(470, 550);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final (db, controller, note) =
        await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'note-large-text-test.db',
          );
          final controller = NotesController(LocalStore.fromDatabase(db), null);
          await controller.load();
          final note = await controller.create();
          return (db, controller, note);
        }) ??
        (throw StateError('Could not set up text scaling test'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: NotePage(controller: controller, noteId: note.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.runAsync(() async {
      controller.dispose();
      await db.close();
    });
  });

  test('Windows bitmap clipboard image becomes a valid PNG', () async {
    final bitmap = img.encodeBmp(img.Image(width: 4, height: 4));
    final normalized = await prepareClipboardImage(bitmap);
    expect(normalized.take(4), [0x89, 0x50, 0x4e, 0x47]);
    expect(img.decodePng(normalized), isNotNull);
  });
}
