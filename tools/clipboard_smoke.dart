// Native integration check: flutter run -d windows -t tools/clipboard_smoke.dart
// Uses an in-memory notebook; never opens the user's library.
import 'dart:io';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:better_notes/ui/note_quill_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:sembast/sembast_memory.dart';
import 'package:window_manager/window_manager.dart';

void check(bool condition, String label) {
  if (!condition) throw StateError(label);
  stdout.writeln('PASS: $label');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final errors = <Object>[];
  final source = NoteQuillController(
    noteId: 'native-source',
    document: quill.Document.fromJson([
      {
        'insert': 'Bright idea',
        'attributes': {'bold': true},
      },
      {'insert': '\nSecond line\n'},
    ]),
    selection: const TextSelection(baseOffset: 0, extentOffset: 23),
    config: const quill.QuillControllerConfig(),
    onClipboardError: errors.add,
  );
  try {
    await source.copySelection();
    check(errors.isEmpty, 'native copy completes without an error');
    check(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text ==
          'Bright idea\nSecond line',
      'Windows Unicode clipboard holds selected multiline text',
    );
    final target = NoteQuillController(
      noteId: 'native-target',
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
      config: const quill.QuillControllerConfig(),
      onClipboardError: errors.add,
    );
    check(
      await target.pasteCopiedText(),
      'another note reads the native rich clipboard format',
    );
    check(
      target.document.toPlainText() == 'Bright idea\nSecond line\n' &&
          target.document.collectStyle(0, 11).attributes['bold']?.value == true,
      'cross-note paste preserves text and bold formatting',
    );
    source.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
    await source.copySelection();
    check(
      (await Clipboard.getData(Clipboard.kTextPlain))?.text ==
          'Bright idea\nSecond line',
      'empty selection preserves the Windows clipboard',
    );
    source.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 11),
      quill.ChangeSource.local,
    );
    await source.copySelection(copy: false);
    check(
      source.document.toPlainText() == '\nSecond line\n' &&
          (await Clipboard.getData(Clipboard.kTextPlain))?.text ==
              'Bright idea',
      'Cut saves text to Windows before removing it',
    );
    target.dispose();

    final db = await databaseFactoryMemory.openDatabase('native-resize');
    final store = NotesController(LocalStore.fromDatabase(db), null);
    await store.load();
    final note = await store.create();
    final rootKey = GlobalKey();
    runApp(
      MaterialApp(
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
        ],
        home: NotePage(key: rootKey, controller: store, noteId: note.id),
      ),
    );
    await windowManager.ensureInitialized();
    Future<Size> resize(Size size) async {
      await windowManager.setSize(size);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await WidgetsBinding.instance.endOfFrame;
      Element? editor;
      void visit(Element node) {
        if (node.widget is quill.QuillEditor) editor = node;
        node.visitChildren(visit);
      }

      (rootKey.currentContext! as Element).visitChildren(visit);
      return (editor!.findRenderObject()! as RenderBox).size;
    }

    final small = await resize(const Size(470, 550));
    final large = await resize(const Size(1100, 900));
    check(
      large.width > small.width + 500 && large.height > small.height + 250,
      'native window resizing grows the editor in both dimensions',
    );
    stdout.writeln('NATIVE_CLIPBOARD_RESIZE_OK');
    await stdout.flush();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('NATIVE_CHECK_FAILED: $error\n$stack');
    await stderr.flush();
    exit(1);
  }
}
