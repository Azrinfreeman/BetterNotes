import 'package:better_notes/data/backup.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;

Widget _app(
  NotesController store,
  String id, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: betterNotesTheme(brightness),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    quill.FlutterQuillLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: NotePage(controller: store, noteId: id),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('right click changes only selected text color', (tester) async {
    final (db, store, note) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('context-color');
      final store = NotesController(LocalStore.fromDatabase(db), null);
      await store.load();
      final note = await store.create();
      await store.save(
        note.copyWith(
          plainText: 'Hello rest',
          delta: [
            {'insert': 'Hello rest\n'},
          ],
        ),
      );
      return (db, store, note);
    }))!;
    await tester.pumpWidget(_app(store, note.id));
    await tester.pumpAndSettle();
    final editorWidget = find.byType(quill.QuillEditor);
    final editor = tester.widget<quill.QuillEditor>(editorWidget).controller;
    await tester.tapAt(tester.getTopLeft(editorWidget) + const Offset(20, 15));
    editor.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      quill.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(editorWidget) + const Offset(20, 15),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await _tapVisible(tester, find.text('Change color'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hex color'),
      '123ABC',
    );
    await _tapVisible(tester, find.text('Apply'));
    final ops = editor.document.toDelta().toJson();
    expect(ops.first['insert'], 'Hello');
    expect(ops.first['attributes'], {'color': '#123ABC'});
    expect(ops[1]['insert'], ' rest\n');
    expect(ops[1]['attributes'], isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    await tester.runAsync(db.close);
  });

  testWidgets('selected text styles undo, save, reopen and survive backup', (
    tester,
  ) async {
    final (db, store, note) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('text-styles');
      final store = NotesController(LocalStore.fromDatabase(db), null);
      await store.load();
      final note = await store.create();
      await store.save(
        note.copyWith(
          plainText: 'Hello rest',
          delta: [
            {'insert': 'Hello rest\n'},
          ],
        ),
      );
      return (db, store, note);
    }))!;
    await tester.pumpWidget(_app(store, note.id));
    await tester.pumpAndSettle();
    final editor = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    editor.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      quill.ChangeSource.local,
    );
    await _tapVisible(tester, find.byTooltip('Text style options'));
    await _tapVisible(tester, find.byType(quill.QuillToolbarFontSizeButton));
    await _tapVisible(tester, find.text('24'));
    await _tapVisible(tester, find.byTooltip('Text color'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Hex color'),
      '#123abc',
    );
    await _tapVisible(tester, find.text('Apply'));
    final styled = editor.document.toDelta().toJson();
    expect(styled.first['insert'], 'Hello');
    expect(styled.first['attributes'], {'size': 24.0, 'color': '#123ABC'});
    expect(styled[1]['insert'], ' rest\n');
    expect(styled[1]['attributes'], isNull);
    expect(
      editor.selection,
      const TextSelection(baseOffset: 0, extentOffset: 5),
    );

    editor.document.history.lastRecorded = 0;
    await _tapVisible(tester, find.byTooltip('Highlight color'));
    await _tapVisible(tester, find.byTooltip('Gold'));
    await _tapVisible(tester, find.text('Apply'));
    expect(
      editor.getSelectionStyle().attributes['background']?.value,
      '#F9A825',
    );
    editor.undo();
    await tester.pump();
    expect(editor.document.toDelta().toJson(), styled);
    editor.redo();
    await tester.pump();
    expect(
      editor.getSelectionStyle().attributes['background']?.value,
      '#F9A825',
    );
    await tester.runAsync(store.flushAllEditors);
    final saved = store.noteById(note.id)!.delta;
    final backup = (await tester.runAsync(
      () => NoteBackup.export(LocalStore.fromDatabase(db), guestOwner),
    ))!;
    final preview = NoteBackup.validate(backup);
    expect(preview.notes.single.delta, saved);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(store, note.id));
    await tester.pumpAndSettle();
    final reopened = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    expect(reopened.document.toDelta().toJson(), saved);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    await tester.runAsync(db.close);
  });

  testWidgets('headings, lists, quotes and styles for newly typed text', (
    tester,
  ) async {
    final (db, store, note) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('block-text-styles');
      final store = NotesController(LocalStore.fromDatabase(db), null);
      await store.load();
      final note = await store.create();
      await store.save(
        note.copyWith(
          plainText: 'Heading\nTask',
          delta: [
            {'insert': 'Heading\nTask\n'},
          ],
        ),
      );
      return (db, store, note);
    }))!;
    await tester.pumpWidget(_app(store, note.id));
    await tester.pumpAndSettle();
    final editor = tester
        .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
        .controller;
    editor.updateSelection(
      const TextSelection.collapsed(offset: 0),
      quill.ChangeSource.local,
    );
    await _tapVisible(tester, find.byTooltip('Text style options'));
    await _tapVisible(
      tester,
      find.byType(quill.QuillToolbarSelectHeaderStyleDropdownButton),
    );
    await _tapVisible(tester, find.text('Heading 1'));
    expect(editor.getSelectionStyle().attributes['header']?.value, 1);
    editor.updateSelection(
      const TextSelection.collapsed(offset: 8),
      quill.ChangeSource.local,
    );
    final panel = find.byKey(const ValueKey('text-style-panel'));
    Finder toggle(quill.Attribute attribute) => find.descendant(
      of: panel,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is quill.QuillToolbarToggleStyleButton &&
            widget.attribute == attribute,
      ),
    );
    await _tapVisible(tester, toggle(quill.Attribute.ol));
    expect(editor.getSelectionStyle().attributes['list']?.value, 'ordered');
    await _tapVisible(tester, toggle(quill.Attribute.ol));
    await _tapVisible(tester, toggle(quill.Attribute.blockQuote));
    expect(editor.getSelectionStyle().attributes['blockquote']?.value, true);
    await _tapVisible(tester, toggle(quill.Attribute.blockQuote));
    editor.updateSelection(
      const TextSelection(baseOffset: 8, extentOffset: 12),
      quill.ChangeSource.local,
    );
    await _tapVisible(tester, toggle(quill.Attribute.inlineCode));
    expect(editor.getSelectionStyle().attributes['code']?.value, true);
    await _tapVisible(tester, find.byType(quill.QuillToolbarClearFormatButton));
    editor.updateSelection(
      const TextSelection.collapsed(offset: 12),
      quill.ChangeSource.local,
    );
    await _tapVisible(tester, find.byType(quill.QuillToolbarFontSizeButton));
    await _tapVisible(tester, find.text('18'));
    await _tapVisible(tester, find.byTooltip('Text color'));
    await _tapVisible(tester, find.byTooltip('Green'));
    await _tapVisible(tester, find.text('Apply'));
    editor.replaceText(
      12,
      0,
      ' new',
      const TextSelection.collapsed(offset: 16),
    );
    await tester.pumpAndSettle();
    final delta = editor.document.toDelta().toJson();
    final added = delta.firstWhere((op) => op['insert'] == ' new');
    expect(added['attributes'], {'size': 18.0, 'color': '#2E7D32'});
    expect(
      delta.any(
        (op) =>
            op['attributes'] is Map && (op['attributes'] as Map)['header'] == 1,
      ),
      isTrue,
    );
    expect(editor.document.toPlainText(), 'Heading\nTask new\n');
    await tester.runAsync(store.flushAllEditors);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
    await tester.runAsync(db.close);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'text styles and color dialog fit 320px at 200% in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (db, store, note) = (await tester.runAsync(() async {
          final db = await databaseFactoryMemory.openDatabase(
            'small-text-$brightness',
          );
          final store = NotesController(LocalStore.fromDatabase(db), null);
          await store.load();
          final note = await store.create();
          await store.save(
            note.copyWith(
              plainText: 'Keep',
              delta: [
                {'insert': 'Keep\n'},
              ],
            ),
          );
          return (db, store, note);
        }))!;
        await tester.pumpWidget(
          _app(store, note.id, brightness: brightness, scale: 2),
        );
        await tester.pumpAndSettle();
        final editor = tester
            .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
            .controller;
        editor.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
          quill.ChangeSource.local,
        );
        await _tapVisible(tester, find.byTooltip('Text style options'));
        expect(tester.takeException(), isNull);
        await _tapVisible(tester, find.byTooltip('Text color'));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Hex color'),
          'invalid',
        );
        await _tapVisible(tester, find.text('Apply'));
        expect(
          find.text('Enter six hex digits, such as #795082.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await _tapVisible(tester, find.text('Cancel'));
        expect(editor.document.toPlainText(), 'Keep\n');
        expect(editor.getSelectionStyle().attributes['color'], isNull);
        await _tapVisible(tester, find.byTooltip('Text color'));
        await _tapVisible(tester, find.byTooltip('Blue'));
        await _tapVisible(tester, find.text('Apply'));
        expect(
          editor.getSelectionStyle().attributes['color']?.value,
          '#1565C0',
        );
        await _tapVisible(tester, find.byTooltip('Text color'));
        await _tapVisible(tester, find.text('Reset color'));
        expect(editor.getSelectionStyle().attributes['color'], isNull);
        await _tapVisible(
          tester,
          find.byType(quill.QuillToolbarFontSizeButton),
        );
        await _tapVisible(tester, find.text('32'));
        expect(editor.getSelectionStyle().attributes['size']?.value, 32.0);
        await _tapVisible(
          tester,
          find.byType(quill.QuillToolbarClearFormatButton),
        );
        expect(editor.getSelectionStyle().attributes['size'], isNull);
        expect(editor.document.toPlainText(), 'Keep\n');
        expect(
          tester.getSize(find.byType(quill.QuillEditor)).height,
          greaterThan(0),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        await tester.runAsync(db.close);
      },
    );
  }
}
