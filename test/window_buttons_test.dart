import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/desktop/windows_notes_io.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'note header hides, stays open for colors, and controls its window',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(470, 520);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const channel = MethodChannel('window_manager');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'isAlwaysOnTop' || call.method == 'isMaximized') {
          return false;
        }
        return null;
      });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      final (db, controller, note) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase('note-header.db');
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        await controller.setCustomWindowButtons(true);
        return (db, controller, await controller.create());
      }))!;
      var created = 0;
      var closed = 0;
      await tester.pumpWidget(
        NoteWindowApp(
          controller: controller,
          noteId: note.id,
          onClose: () async {
            closed++;
          },
          onNewNote: () async {
            created++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close window'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
      double opacity() => tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('note-header-opacity')),
          )
          .opacity;
      expect(opacity(), 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(400, 300));
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('note-header-hover'))),
      );
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.tap(find.byTooltip('New note'));
      expect(created, 1);
      await tester.tap(find.byTooltip('Always on top'));
      await tester.pumpAndSettle();
      expect(
        calls
            .lastWhere((c) => c.method == 'setAlwaysOnTop')
            .arguments['isAlwaysOnTop'],
        true,
      );
      await tester.tap(find.byTooltip('Change color'));
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(400, 300));
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 1);
      await tester.tap(find.byTooltip('Grass'));
      await tester.pumpAndSettle();
      expect(controller.noteById(note.id)!.colorIndex, 6);
      await mouse.moveTo(const Offset(400, 300));
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(), 0);
      await mouse.moveTo(
        tester.getCenter(find.byKey(const ValueKey('note-header-hover'))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Turn off always on top'));
      await tester.pumpAndSettle();
      expect(
        calls
            .lastWhere((c) => c.method == 'setAlwaysOnTop')
            .arguments['isAlwaysOnTop'],
        false,
      );
      await tester.tap(find.byTooltip('Close note'));
      await tester.pumpAndSettle();
      expect(closed, 1);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        controller.dispose();
        await db.close();
      });
      debugDefaultTargetPlatformOverride = null;
    },
  );

  test(
    'window button preference survives restart and can return to Windows',
    () async {
      final db = await databaseFactoryMemory.openDatabase('window-buttons.db');
      final store = LocalStore.fromDatabase(db);
      final first = NotesController(store, null);
      await first.load();
      expect(first.customWindowButtons, isFalse);
      await first.setCustomWindowButtons(true);
      first.dispose();
      final second = NotesController(store, null);
      await second.load();
      expect(second.customWindowButtons, isTrue);
      await second.setCustomWindowButtons(false);
      second.dispose();
      final third = NotesController(store, null);
      await third.load();
      expect(third.customWindowButtons, isFalse);
      third.dispose();
      await db.close();
    },
  );

  test('open note windows receive button changes with their shared state', () {
    final remote = RemoteNoteEditorStore(
      WindowController.fromWindowId('parent'),
      'note',
    );
    remote.applyState({'customWindowButtons': true, 'inlineImages': true});
    expect(remote.customWindowButtons, isTrue);
    expect(remote.inlineImages, isTrue);
    remote.applyState({'customWindowButtons': false});
    expect(remote.customWindowButtons, isFalse);
    expect(remote.inlineImages, isFalse);
    remote.dispose();
  });

  testWidgets(
    'switch buttons on Settings without losing the route; controls work',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = const Size(470, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <MethodCall>[];
      var maximized = false;
      const channel = MethodChannel('window_manager');
      const startup = MethodChannel('betternotes/windows');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'isMaximized') return maximized;
        if (call.method == 'isFullScreen') return false;
        if (call.method == 'maximize') maximized = true;
        if (call.method == 'unmaximize') maximized = false;
        return null;
      });
      messenger.setMockMethodCallHandler(startup, (_) async => false);
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(startup, null);
      });
      final (db, controller) = (await tester.runAsync(() async {
        final db = await databaseFactoryMemory.openDatabase(
          'window-buttons-ui.db',
        );
        final controller = NotesController(LocalStore.fromDatabase(db), null);
        await controller.load();
        return (db, controller);
      }))!;
      addTearDown(
        () => tester.runAsync(() async {
          controller.dispose();
          await db.close();
        }),
      );
      await tester.pumpWidget(BetterNotesApp(controller: controller));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      final windowButtons = find.byKey(const ValueKey('window-buttons'));
      await tester.ensureVisible(windowButtons);
      await tester.pumpAndSettle();
      await tester.tap(windowButtons);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BetterNotes').last);
      await tester.pumpAndSettle();
      expect(controller.customWindowButtons, isTrue);
      expect(find.text('Window buttons'), findsOneWidget);
      expect(find.byTooltip('Close window'), findsOneWidget);
      expect(
        calls
            .lastWhere((c) => c.method == 'setTitleBarStyle')
            .arguments['titleBarStyle'],
        'hidden',
      );

      await tester.tap(find.byTooltip('Minimize'));
      await tester.tap(find.byTooltip('Maximize'));
      await tester.pumpAndSettle();
      expect(maximized, isTrue);
      // Double-clicking the draggable title also restores a maximized window.
      final title = find.text('Settings');
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(maximized, isFalse);
      await tester.tap(find.byTooltip('Close window'));
      expect(calls.any((c) => c.method == 'minimize'), isTrue);
      expect(calls.any((c) => c.method == 'close'), isTrue);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('BetterNotes'), findsOneWidget);
      expect(find.byTooltip('Close window'), findsOneWidget);
      final settingsCenter = tester.getCenter(find.byTooltip('Settings'));
      final minimizeCenter = tester.getCenter(find.byTooltip('Minimize'));
      expect(minimizeCenter.dy, settingsCenter.dy);
      expect(minimizeCenter.dx, greaterThan(settingsCenter.dx));
      expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
      final titleCenter = tester.getCenter(find.text('BetterNotes'));
      await tester.dragFrom(titleCenter, const Offset(25, 0));
      await tester.pumpAndSettle();
      expect(calls.any((c) => c.method == 'startDragging'), isTrue);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(windowButtons);
      await tester.pumpAndSettle();
      await tester.tap(windowButtons);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Windows').last);
      await tester.pumpAndSettle();
      expect(controller.customWindowButtons, isFalse);
      expect(find.byTooltip('Close window'), findsNothing);
      expect(find.text('Window buttons'), findsOneWidget);
      expect(
        calls
            .lastWhere((c) => c.method == 'setTitleBarStyle')
            .arguments['titleBarStyle'],
        'normal',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
