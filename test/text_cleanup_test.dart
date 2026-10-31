import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:better_notes/ui/text_cleanup_dialog.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sembast/sembast_memory.dart' hide Finder;
import 'package:better_notes/data/text_cleanup.dart';
import 'package:better_notes/ui/note_quill_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as q;
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(
  Widget home, {
  Brightness brightness = Brightness.light,
  double scale = 1,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    q.FlutterQuillLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
      highContrast: true,
    ),
    child: child!,
  ),
  home: home,
);

void main() {
  const caret = TextSelection.collapsed(offset: 0);
  testWidgets('editor preview cancel, options, apply, undo and saved reopen', (
    tester,
  ) async {
    final (db, store, id) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('cleanup');
      final store = NotesController(LocalStore.fromDatabase(db), null);
      await store.load();
      final note = await store.create();
      await store.save(
        note.copyWith(
          delta: [
            {'insert': 'Hello  world  \n\n\n'},
          ],
          plainText: 'Hello  world  \n\n\n',
          tags: ['keep'],
        ),
      );
      return (db, store, note.id);
    }))!;
    await tester.pumpWidget(app(NotePage(controller: store, noteId: id)));
    await tester.pumpAndSettle();
    final live =
        tester.widget<q.QuillEditor>(find.byType(q.QuillEditor)).controller
            as NoteQuillController;
    final original = live.document.toDelta().toJson();
    Future<void> open() async {
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Clean up text\u2026'));
      await tester.tap(find.text('Clean up text\u2026'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(find.byType(TextCleanupDialog), findsOneWidget);
    expect(live.document.toDelta().toJson(), original);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(live.document.toDelta().toJson(), original);
    await open();
    await tester.tap(find.text('Reduce repeated spaces between words'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply cleanup'));
    await tester.pumpAndSettle();
    expect(live.document.toPlainText(), 'Hello world\n\n');
    live.undo();
    expect(live.document.toDelta().toJson(), original);
    live.redo();
    await tester.pumpAndSettle();
    await tester.runAsync(() => store.flushEditors());
    expect(store.noteById(id)!.tags, ['keep']);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(NotePage(controller: store, noteId: id)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<q.QuillEditor>(find.byType(q.QuillEditor))
          .controller
          .document
          .toPlainText(),
      'Hello world\n\n',
    );
    await open();
    expect(find.text('No cleanup needed'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply cleanup'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final reopened = tester
        .widget<q.QuillEditor>(find.byType(q.QuillEditor))
        .controller;
    reopened.replaceText(
      0,
      0,
      'x  \n',
      const TextSelection(baseOffset: 0, extentOffset: 4),
    );
    await open();
    expect(find.text('Clean up selection'), findsOneWidget);
    reopened.updateSelection(
      const TextSelection.collapsed(offset: 0),
      q.ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('The note changed. Close this preview and try again.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply cleanup'),
          )
          .onPressed,
      isNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(TextCleanupDialog), findsNothing);
    // Restore the clean state before checking durable storage.
    reopened.undo();
    await tester.runAsync(() => store.flushEditors());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final reloaded = NotesController(LocalStore.fromDatabase(db), null);
    await tester.runAsync(reloaded.load);
    expect(reloaded.noteById(id)!.plainText, 'Hello world');
    expect(
      q.Document.fromJson(reloaded.noteById(id)!.delta).toPlainText(),
      'Hello world\n\n',
    );
    reloaded.dispose();
    store.dispose();
    await tester.runAsync(db.close);
  });

  for (final size in [const Size(320, 700), const Size(700, 320)]) {
    for (final brightness in Brightness.values) {
      testWidgets('large-text preview and stale guard $size $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final live = q.QuillController.basic();
        live.replaceText(
          0,
          0,
          'Text  ',
          const TextSelection.collapsed(offset: 0),
        );
        final changes = ChangeNotifier();
        var current = true;
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TextCleanupDialog(
                      snapshot: live.document.toDelta(),
                      selection: live.selection,
                      liveController: live,
                      changes: changes,
                      isCurrent: () => current,
                      embedBuilders: const [],
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
            brightness: brightness,
            scale: 2,
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        current = false;
        changes.notifyListeners();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Apply cleanup'),
              )
              .onPressed,
          isNull,
        );
        await tester.ensureVisible(
          find.text('The note changed. Close this preview and try again.'),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(live.document.toPlainText(), 'Text  \n');
        await tester.pumpWidget(const SizedBox.shrink());
        live.dispose();
        changes.dispose();
      });
    }
  }
  test('large cleanup plans without altering words', () {
    final watch = Stopwatch()..start();
    final source = Delta()
      ..insert(List.filled(10000, 'hello  world  \n').join());
    final result = planTextCleanup(source, caret);
    expect(result.spacesRemoved, 20000);
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });
  test('deletions preserve split styles, emoji, links and are idempotent', () {
    final source = Delta()
      ..insert('\u{1f600} Hello', {'bold': true})
      ..insert('   ', {'link': 'https://example.com'})
      ..insert('world  \n\n\nend\n');
    final result = planTextCleanup(
      source,
      caret,
      const TextCleanupOptions(repeatedSpaces: true),
    );
    expect(
      q.Document.fromDelta(result.preview).toPlainText(),
      '\u{1f600} Hello world\n\nend\n',
    );
    expect(result.preview.toJson().first['attributes'], {'bold': true});
    expect(result.preview.toJson()[1]['attributes'], {
      'link': 'https://example.com',
    });
    expect(planTextCleanup(result.preview, caret).hasChanges, isFalse);
    expect(result.spacesRemoved, 4);
    expect(result.blankLinesRemoved, 1);
  });
  test(
    'protect block attributes, embeds, inline code and styled empty lines',
    () {
      for (final block in [
        'header',
        'list',
        'blockquote',
        'code-block',
        'unknown',
      ]) {
        final source = Delta()
          ..insert('text  ')
          ..insert('\n', {block: 1});
        expect(planTextCleanup(source, caret).hasChanges, isFalse);
      }
      final source = Delta()
        ..insert('code', {'code': true})
        ..insert('  \n')
        ..insert({'image': 'asset'})
        ..insert('  \n')
        ..insert('\n', {'bold': true})
        ..insert('\n');
      expect(planTextCleanup(source, caret).hasChanges, isFalse);
    },
  );
  test(
    'selection requires complete candidates and preserves outside content',
    () {
      final source = Delta()..insert('a  \nb   c\n');
      expect(
        planTextCleanup(
          source,
          const TextSelection(baseOffset: 1, extentOffset: 3),
        ).hasChanges,
        isFalse,
      );
      final result = planTextCleanup(
        source,
        const TextSelection(baseOffset: 0, extentOffset: 4),
      );
      expect(q.Document.fromDelta(result.preview).toPlainText(), 'a\nb   c\n');
      expect(
        result.selection,
        const TextSelection(baseOffset: 0, extentOffset: 2),
      );
      final protected = Delta()
        ..insert('a  ')
        ..insert('\n', {'list': 'bullet'});
      expect(
        planTextCleanup(
          protected,
          const TextSelection(baseOffset: 0, extentOffset: 3),
        ).hasChanges,
        isFalse,
      );
    },
  );
  test('preserve indentation, tabs, Unicode spaces, terminal newline', () {
    final source = Delta()..insert('  a\t  b\u00a0  c\n\n\n');
    final result = planTextCleanup(
      source,
      caret,
      const TextCleanupOptions(repeatedSpaces: true),
    );
    expect(
      q.Document.fromDelta(result.preview).toPlainText(),
      '  a\t  b\u00a0  c\n\n',
    );
    expect(planTextCleanup(Delta()..insert('\n'), caret).hasChanges, isFalse);
  });
  test('cleanup undo and redo are isolated from adjacent typing', () {
    final controller = NoteQuillController(
      document: q.Document.fromDelta(Delta()..insert('a  \n')),
      selection: caret,
      config: const q.QuillControllerConfig(),
      noteId: 'test',
      onClipboardError: (_) {},
    );
    addTearDown(controller.dispose);
    controller.replaceText(0, 0, 'x', const TextSelection.collapsed(offset: 1));
    final before = controller.document.toDelta().toJson();
    final result = planTextCleanup(
      controller.document.toDelta(),
      controller.selection,
    );
    controller.applyCleanup(result.change, result.selection);
    final after = controller.document.toDelta().toJson();
    controller.replaceText(0, 0, 'y', const TextSelection.collapsed(offset: 1));
    controller.undo();
    expect(controller.document.toDelta().toJson(), after);
    controller.undo();
    expect(controller.document.toDelta().toJson(), before);
    controller.redo();
    expect(controller.document.toDelta().toJson(), after);
    controller.undo();
    controller.undo();
    expect(controller.document.toPlainText(), 'a  \n');
  });
}
