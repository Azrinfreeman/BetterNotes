import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/data/templates.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
// ignore: depend_on_referenced_packages
import 'package:quill_native_bridge_platform_interface/quill_native_bridge_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _NoRichClipboardBridge extends QuillNativeBridgePlatform {
  @override
  Future<bool> isSupported(QuillNativeBridgeFeature feature) async => false;
}

Future<(NotesController, Database)> _open(String name) async {
  final db = await databaseFactoryMemory.openDatabase(name);
  final controller = NotesController(LocalStore.fromDatabase(db), null);
  await controller.load();
  return (controller, db);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('duplicate copies content with fresh IDs and separate images', () async {
    final (controller, db) = await _open('round-b-duplicate');
    final note = await controller.create();
    final imageId = await controller.cacheImage(Uint8List.fromList([1, 2, 3]));
    await controller.save(
      note.copyWith(
        title: 'Plan',
        tags: ['work'],
        colorIndex: 3,
        plainText: 'hello',
        images: [imageId],
        delta: [
          {'insert': 'hello'},
          {
            'insert': {'image': imageId},
          },
          {'insert': '\n'},
        ],
      ),
    );
    final copy = (await controller.duplicate(note.id))!;
    expect(copy.id, isNot(note.id));
    expect(copy.title, 'Plan copy');
    expect(copy.tags, ['work']);
    expect(copy.colorIndex, 3);
    expect(copy.images, hasLength(1));
    expect(copy.images.single, isNot(imageId));
    expect(inlineImageIds(copy.delta), {copy.images.single});
    expect(await controller.image(copy.id, copy.images.single), [1, 2, 3]);
    expect(controller.noteById(note.id)!.images, [imageId]);
    expect(controller.notes, hasLength(2));
    controller.dispose();
    await db.close();
  });

  test('templates create titled notes with checklists', () async {
    final (controller, db) = await _open('round-b-template');
    final template = noteTemplates.firstWhere((t) => t.id == 'daily');
    final note = await controller.createFromTemplate(template);
    expect(note.title, 'Today');
    expect(note.tasks.total, 5);
    expect(note.plainText, contains('Top priorities'));
    expect(quill.Document.fromJson(note.delta).toPlainText(), isNotEmpty);
    for (final t in noteTemplates) {
      expect(() => quill.Document.fromJson(t.delta), returnsNormally);
    }
    controller.dispose();
    await db.close();
  });

  test('tags rename, merge, and delete across notes', () async {
    final (controller, db) = await _open('round-b-tags');
    final a = await controller.create();
    final b = await controller.create();
    final c = await controller.create();
    await controller.save(a.copyWith(tags: ['work', 'ideas']));
    await controller.save(b.copyWith(tags: ['job']));
    await controller.save(c.copyWith(tags: ['ideas']));
    expect(controller.tagCounts, {'work': 1, 'ideas': 2, 'job': 1});

    await controller.setLibraryOptions(tags: ['job']);
    expect(await controller.renameTag('job', 'Work'), 1);
    expect(controller.noteById(b.id)!.tags, ['work']);
    expect(controller.selectedTags, ['work']);
    expect(controller.noteById(b.id)!.dirty, isTrue);

    expect(await controller.renameTag('work', 'work'), 2);
    expect(controller.noteById(a.id)!.tags, ['ideas', 'work']);
    expect(controller.tagCounts['work'], 2);

    expect(await controller.deleteTag('ideas'), 2);
    expect(controller.noteById(a.id)!.tags, ['work']);
    expect(controller.noteById(c.id)!.tags, isEmpty);
    expect(controller.availableTags, ['work']);
    controller.dispose();
    await db.close();
  });

  test('text statistics ignore image placeholders and newlines', () {
    expect(textStats('').words, 0);
    expect(textStats('').minutes, 0);
    final s = textStats('one two\nthree ￼ four\n');
    expect(s.words, 4);
    expect(s.characters, 'one twothree  four'.length);
    expect(s.minutes, 1);
    expect(textStats('word ' * 401).minutes, 3);
  });

  for (final plain in [false, true]) {
    testWidgets(
      plain
          ? 'Ctrl+Shift+V pastes clipboard text without formatting'
          : 'a URL pasted over selected text becomes a link',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final previousBridge = QuillNativeBridgePlatform.instance;
        QuillNativeBridgePlatform.instance = _NoRichClipboardBridge();
        addTearDown(() => QuillNativeBridgePlatform.instance = previousBridge);
        final (controller, db, note) =
            await tester.runAsync(() async {
              final (controller, db) = await _open('round-b-paste-$plain');
              return (controller, db, await controller.create());
            }) ??
            (throw StateError('Could not set up paste test'));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const [
              quill.FlutterQuillLocalizations.delegate,
            ],
            home: NotePage(
              controller: controller,
              noteId: note.id,
              clipboardImageReader: () async => null,
            ),
          ),
        );
        await tester.pump();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? {'text': plain ? 'plain words' : 'https://example.com/a'}
              : null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final editor = tester.widget<quill.QuillEditor>(
          find.byType(quill.QuillEditor),
        );
        editor.focusNode.requestFocus();
        await tester.pump();
        editor.controller.replaceText(
          0,
          0,
          'docs',
          const TextSelection.collapsed(offset: 4),
        );
        if (!plain) {
          editor.controller.updateSelection(
            const TextSelection(baseOffset: 0, extentOffset: 4),
            quill.ChangeSource.local,
          );
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        if (plain) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        if (plain) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        if (plain) {
          expect(editor.controller.document.toPlainText(), 'docsplain words\n');
        } else {
          expect(editor.controller.document.toPlainText(), 'docs\n');
          expect(
            editor.controller.document
                .collectStyle(0, 4)
                .attributes[quill.Attribute.link.key]
                ?.value,
            'https://example.com/a',
          );
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
}
