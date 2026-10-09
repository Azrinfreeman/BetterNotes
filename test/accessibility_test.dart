import 'dart:convert';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/desktop/windows_notes_io.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:better_notes/ui/note_page.dart';
import 'package:better_notes/ui/notes_home.dart';
import 'package:better_notes/ui/settings_page.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

Widget _app(Widget home, Brightness brightness, double scale) => MaterialApp(
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
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'header preference survives restart and reaches child windows',
    () async {
      final db = await databaseFactoryMemory.openDatabase('accessible-header');
      final store = LocalStore.fromDatabase(db);
      final first = NotesController(store, null);
      await first.load();
      expect(first.alwaysShowNoteHeader, false);
      await first.setAlwaysShowNoteHeader(true);
      first.dispose();
      final second = NotesController(store, null);
      await second.load();
      expect(second.alwaysShowNoteHeader, true);
      final remote = RemoteNoteEditorStore(
        WindowController.fromWindowId('parent'),
        'note',
      );
      remote.applyState({'alwaysShowNoteHeader': true});
      expect(remote.alwaysShowNoteHeader, true);
      remote.applyState({'alwaysShowNoteHeader': false});
      expect(remote.alwaysShowNoteHeader, false);
      remote.dispose();
      second.dispose();
      await db.close();
    },
  );

  test('text and note header colors retain readable contrast', () {
    double ratio(Color a, Color b) {
      final x = a.computeLuminance();
      final y = b.computeLuminance();
      return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
    }

    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        final theme = betterNotesTheme(brightness, highContrast: highContrast);
        final colors = theme.colorScheme;
        for (final pair in [
          (colors.onSurface, theme.scaffoldBackgroundColor),
          (colors.onSurface, colors.surfaceContainerHigh),
          (colors.onSurfaceVariant, colors.surfaceContainer),
          (colors.onPrimary, colors.primary),
        ]) {
          expect(ratio(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
      }
    }
    for (final color in noteColors) {
      expect(
        ratio(const Color(0xFF2E2631), Color(color)),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets(
    'hidden header supports keyboard, touch and accessibility preferences',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(470, 520);
      tester.view.devicePixelRatio = 1;
      const channel = MethodChannel('window_manager');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (['isAlwaysOnTop', 'isMaximized'].contains(call.method)) {
          return false;
        }
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        messenger.setMockMethodCallHandler(channel, null);
      });
      final (db, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase(
          'accessible-window',
        );
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        return (db, controller, await controller.create());
      }))!;
      final semantics = tester.ensureSemantics();
      var created = 0;
      Widget app(Key key) => NoteWindowApp(
        key: key,
        controller: controller,
        noteId: note.id,
        onClose: () async {},
        onNewNote: () async {
          created++;
        },
      );
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('note-header-opacity')),
          )
          .opacity;
      await tester.pumpWidget(app(const ValueKey('keyboard')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(created, 1);
      expect(
        tester
            .getSemantics(find.byTooltip('Close note'))
            .getSemanticsData()
            .tooltip,
        'Close note',
      );
      await tester.pumpWidget(app(const ValueKey('touch')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 0);
      await tester.tapAt(const Offset(20, 260), kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 1);
      for (final feature in [
        const FakeAccessibilityFeatures(accessibleNavigation: true),
        const FakeAccessibilityFeatures(disableAnimations: true),
      ]) {
        tester.platformDispatcher.accessibilityFeaturesTestValue = feature;
        await tester.pumpWidget(app(ValueKey(feature)));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        expect(opacity(), 1);
        if (feature.disableAnimations) {
          expect(
            tester
                .widget<AnimatedOpacity>(
                  find.byKey(const ValueKey('note-header-opacity')),
                )
                .duration,
            Duration.zero,
          );
        }
      }
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.runAsync(() => controller.setAlwaysShowNoteHeader(true));
      await tester.pumpWidget(app(const ValueKey('preference')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 1);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 470.0]) {
      testWidgets(
        'library, settings and editor at $width px, 200% text, $brightness',
        (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final (db, controller, note) = (await tester.runAsync(() async {
            final db = await databaseFactoryMemory.openDatabase(
              'scaled-$width-$brightness',
            );
            final controller = NotesController(
              LocalStore.fromDatabase(db),
              null,
            );
            await controller.load();
            final note = (await controller.create()).copyWith(
              title: 'A long title with readable text',
              tags: ['ideas', 'work'],
              favorite: true,
              images: ['missing-image'],
              delta: [
                {'insert': 'Tasks and notes'},
                {
                  'insert': '\n',
                  'attributes': {'list': 'unchecked'},
                },
              ],
              plainText: 'Tasks and notes',
            );
            await controller.save(note);
            return (db, controller, note);
          }))!;
          await tester.pumpWidget(
            _app(NotesHome(controller: controller), brightness, 2),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Search recovery must remove the query and return to the Notes view.
          await tester.enterText(find.byType(TextField), 'no such note');
          await tester.pumpAndSettle();
          for (
            var attempt = 0;
            attempt < 8 &&
                find.text('Show all notes').hitTestable().evaluate().isEmpty;
            attempt++
          ) {
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -160),
            );
            await tester.pumpAndSettle();
          }
          expect(find.text('Show all notes').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Show all notes'));
          await tester.pumpAndSettle();
          expect(controller.librarySearch('').single.id, note.id);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          await tester.pumpWidget(
            _app(SettingsPage(controller: controller), brightness, 2),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('Keyboard shortcuts'),
            240,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text('Keyboard shortcuts'));
          await tester.pumpAndSettle();
          expect(find.text('In a note'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          await tester.pumpWidget(
            _app(
              NotePage(controller: controller, noteId: note.id),
              brightness,
              2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Image unavailable'), findsOneWidget);
          await tester.ensureVisible(find.text('Retry image'));
          await tester.pumpAndSettle();
          expect(find.text('Retry image').hitTestable(), findsOneWidget);
          await tester.tap(find.text('Retry image'));
          await tester.pumpAndSettle();
          expect(find.text('Image unavailable'), findsOneWidget);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          await tester.runAsync(db.close);
        },
      );
    }
  }

  testWidgets(
    'find input and help dialog never format or paste images into the note',
    (tester) async {
      final (db, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase('scoped-shortcuts');
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        final note = (await controller.create()).copyWith(
          delta: [
            {'insert': 'find this text\n'},
          ],
          plainText: 'find this text',
        );
        await controller.save(note);
        return (db, controller, note);
      }))!;
      var clipboardReads = 0;
      await tester.pumpWidget(
        _app(
          NotePage(
            controller: controller,
            noteId: note.id,
            clipboardImageReader: () async {
              clipboardReads++;
              return null;
            },
          ),
          Brightness.light,
          1,
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester
          .widget<quill.QuillEditor>(find.byType(quill.QuillEditor))
          .controller;
      final original = jsonEncode(editor.document.toDelta().toJson());
      Future<void> ctrl(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await ctrl(LogicalKeyboardKey.keyH);
      await tester.enterText(
        find.byKey(const ValueKey('find-in-note')),
        'text',
      );
      await ctrl(LogicalKeyboardKey.keyT);
      await ctrl(LogicalKeyboardKey.keyV);
      expect(clipboardReads, 0);
      expect(jsonEncode(editor.document.toDelta().toJson()), original);
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await ctrl(LogicalKeyboardKey.keyD);
      expect(controller.noteById(note.id), isNotNull);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('find-in-note')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(db.close);
    },
  );
}
