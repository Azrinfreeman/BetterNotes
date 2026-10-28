import 'dart:async';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:better_notes/ui/note_quill_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('betternotes/clipboard');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var text = 'previous clipboard';
  var rich = '';
  final writes = <MethodCall>[];
  final errors = <Object>[];

  NoteQuillController editor(String id) => NoteQuillController(
    document: quill.Document.fromJson([
      {
        'insert': 'Bright',
        'attributes': {'bold': true},
      },
      {'insert': ' idea\nSecond line\n'},
    ]),
    selection: const TextSelection(baseOffset: 0, extentOffset: 11),
    config: const quill.QuillControllerConfig(),
    noteId: id,
    onClipboardError: errors.add,
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    text = 'previous clipboard';
    rich = '';
    writes.clear();
    errors.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'write') {
        writes.add(call);
        final args = call.arguments as Map;
        text = args['text'] as String;
        rich = args['data'] as String;
      }
      return call.method == 'read' ? rich : null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': text};
      if (call.method == 'Clipboard.setData') {
        throw StateError(
          'Windows copies must not issue a second clearing write',
        );
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('copy writes selected multiline text once and preserves formatting across notes', () async {
    final source = editor('source');
    source.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 23),
      quill.ChangeSource.local,
    );
    await source.copySelection();
    expect(writes, hasLength(1));
    expect(text, 'Bright idea\nSecond line');
    final target = editor('target');
    target.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
    expect(await target.pasteCopiedText(), isTrue);
    expect(
      target.document.toPlainText(),
      startsWith('Bright idea\nSecond lineBright'),
    );
    expect(target.document.collectStyle(0, 6).attributes['bold']?.value, true);
    expect(target.selection.baseOffset, 23);
    source.dispose();
    target.dispose();
  });

  test('collapsed Copy and Cut leave previous clipboard untouched', () async {
    final source = editor('source');
    source.updateSelection(
      const TextSelection.collapsed(offset: 4),
      quill.ChangeSource.local,
    );
    expect(source.clipboardSelection(true), isFalse);
    expect(source.clipboardSelection(false), isFalse);
    await source.copySelection();
    expect(text, 'previous clipboard');
    expect(writes, isEmpty);
    source.dispose();
  });

  test(
    'cut waits for clipboard success and leaves content on failure',
    () async {
      final source = editor('source');
      final original = source.document.toPlainText();
      final pending = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        await pending.future;
        throw PlatformException(code: 'clipboard_write');
      });
      final cut = source.copySelection(copy: false);
      expect(source.document.toPlainText(), original);
      pending.complete();
      await cut;
      expect(source.document.toPlainText(), original);
      expect(errors, hasLength(1));
      source.dispose();
    },
  );

  test(
    'successful cut deletes once and does not delete edits made during a write',
    () async {
      final source = editor('source');
      await source.copySelection(copy: false);
      expect(source.document.toPlainText(), '\nSecond line\n');
      final pending = Completer<void>();
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => pending.future,
      );
      source.updateSelection(
        const TextSelection(baseOffset: 1, extentOffset: 7),
        quill.ChangeSource.local,
      );
      final cut = source.copySelection(copy: false);
      source.replaceText(0, 0, 'new', const TextSelection.collapsed(offset: 3));
      final changed = source.document.toPlainText();
      pending.complete();
      await cut;
      expect(source.document.toPlainText(), changed);
      source.dispose();
    },
  );

  test(
    'foreign clipboard text does not reuse a stale rich selection',
    () async {
      final source = editor('source');
      await source.copySelection();
      text = 'from another app';
      expect(await source.pasteCopiedText(), isFalse);
      source.dispose();
    },
  );

  testWidgets(
    'editor grows on resize, keyboard Copy uses one write, long content scrolls',
    (tester) async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(470, 550);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final (db, store, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase('resize-copy');
        final store = NotesController(LocalStore.fromDatabase(db), null);
        await store.load();
        final note = await store.create();
        return (db, store, note);
      }))!;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            quill.FlutterQuillLocalizations.delegate,
          ],
          home: NotePage(
            controller: store,
            noteId: note.id,
            clipboardImageReader: () async => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byType(quill.QuillEditor);
      final small = tester.getSize(finder);
      tester.view.physicalSize = const Size(1100, 900);
      await tester.pumpAndSettle();
      final large = tester.getSize(finder);
      expect(large.width, greaterThan(small.width + 500));
      expect(large.height, greaterThan(small.height + 250));
      final widget = tester.widget<quill.QuillEditor>(finder);
      final controller = widget.controller;
      controller.replaceText(
        0,
        0,
        'Clipboard check',
        const TextSelection(baseOffset: 0, extentOffset: 15),
      );
      widget.focusNode.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(text, 'Clipboard check');
      expect(writes, hasLength(1));
      final origin = tester.getTopLeft(finder);
      final rightClick = await tester.startGesture(
        origin + const Offset(30, 15),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await rightClick.up();
      await tester.pumpAndSettle();
      final selected = controller.document.getPlainText(
        controller.selection.start,
        controller.selection.end - controller.selection.start,
      );
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(text, selected);
      expect(writes, hasLength(2));
      controller.replaceText(
        0,
        controller.document.length - 1,
        List.generate(100, (i) => 'Line $i').join('\n'),
        const TextSelection.collapsed(offset: 0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final outer = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(outer.position.maxScrollExtent, greaterThan(0));
      outer.position.jumpTo(0);
      controller.updateSelection(
        TextSelection.collapsed(offset: controller.document.length - 1),
        quill.ChangeSource.local,
      );
      await tester.pumpAndSettle();
      expect(
        outer.position.pixels,
        greaterThan(0),
        reason: 'Caret must remain visible at the end of a long note',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        store.dispose();
        await db.close();
      });
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
