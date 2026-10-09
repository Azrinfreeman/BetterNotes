import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/desktop/windows_notes_io.dart';
import 'package:better_notes/main.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('measure themes used when a note changes', () {
    final themes = <ThemeData>[];
    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        final theme = betterNotesTheme(brightness, highContrast: highContrast);
        expect(theme.brightness, brightness);
        expect(
          identical(
            theme,
            betterNotesTheme(brightness, highContrast: highContrast),
          ),
          isTrue,
        );
        themes.add(theme);
      }
    }
    expect(themes.toSet(), hasLength(4));
    final timer = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      for (final brightness in Brightness.values) {
        for (final highContrast in [false, true]) {
          betterNotesTheme(brightness, highContrast: highContrast);
        }
      }
    }
    timer.stop();
    // A diagnostic, not a timing assertion: CI machine speeds vary.
    debugPrint(
      'Theme work per note notification: '
      '${(timer.elapsedMicroseconds / 20000).toStringAsFixed(2)} ms',
    );
  });

  testWidgets('new note waits for opening and repeated card clicks coalesce', (
    tester,
  ) async {
    final (db, controller) = (await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('open-ui.db');
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
    var gate = Completer<void>();
    final opened = <String>[];
    await tester.pumpWidget(
      BetterNotesApp(
        controller: controller,
        openNoteWindow: (id) {
          opened.add(id);
          return gate.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(opened, hasLength(1));
    expect(controller.notes, hasLength(1));
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    gate = Completer<void>();
    final card = find.text('Empty note');
    await tester.tap(card);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(card);
    expect(opened, hasLength(2));
    gate.completeError(StateError('Simulated open failure'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open note:'), findsOneWidget);
    gate = Completer<void>();
    await tester.tap(card);
    expect(opened, hasLength(3));
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'native openings coalesce, serialize and recover from failure',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const windowsChannel = MethodChannel('mixin.one/desktop_multi_window');
      const methodChannel = MethodChannel(
        'mixin.one/desktop_multi_window/channels',
      );
      const managerChannel = MethodChannel('window_manager');
      const runnerChannel = MethodChannel('betternotes/windows');
      final windows = <Map<String, dynamic>>[
        {'windowId': 'main', 'windowArgument': ''},
      ];
      final started = Completer<void>();
      final gate = Completer<void>();
      var creates = 0;
      var fail = false;
      var focuses = 0;
      var focusReady = true;
      var nativeShows = 0;
      var activations = 0;
      var failActivate = false;
      var flushes = 0;
      Future<dynamic> fromChild(String method, dynamic args) async {
        const codec = StandardMethodCodec();
        final reply = Completer<ByteData?>();
        // ignore: deprecated_member_use
        await messenger.handlePlatformMessage(
          methodChannel.name,
          codec.encodeMethodCall(
            MethodCall('methodCall', {
              'channel': 'mixin.one/window_controller/main',
              'method': method,
              'arguments': args,
            }),
          ),
          reply.complete,
        );
        return codec.decodeEnvelope((await reply.future)!);
      }

      messenger.setMockMethodCallHandler(windowsChannel, (call) async {
        switch (call.method) {
          case 'window_show':
            nativeShows++;
            return null;
          case 'getWindowDefinition':
            return windows.first;
          case 'getAllWindows':
            return windows.toList();
          case 'createWindow':
            creates++;
            if (fail) {
              throw PlatformException(code: 'test-create-failed');
            }
            final id = 'child-$creates';
            windows.add({
              'windowId': id,
              'windowArgument': (call.arguments as Map)['arguments'],
            });
            await fromChild('ready', id);
            return id;
          default:
            return null;
        }
      });
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        if (call.method == 'invokeMethod' &&
            (call.arguments as Map)['method'] == 'activate') {
          activations++;
          if (failActivate) {
            throw PlatformException(code: 'activation-failed');
          }
          if (activations == 1) {
            started.complete();
            await gate.future;
          }
        }
        if (call.method == 'invokeMethod' &&
            (call.arguments as Map)['method'] == 'flush') {
          flushes++;
          return true;
        }
        if (call.method == 'invokeMethod' &&
            (call.arguments as Map)['method'] == 'focus') {
          focuses++;
          if (!focusReady) {
            throw PlatformException(code: 'CHANNEL_NOT_FOUND');
          }
        }
        return null;
      });
      messenger.setMockMethodCallHandler(managerChannel, (_) async => null);
      messenger.setMockMethodCallHandler(runnerChannel, (_) async => null);
      final db = await databaseFactoryMemory.openDatabase('open-native.db');
      final controller = NotesController(LocalStore.fromDatabase(db), null);
      final coordinator = await createDesktopCoordinator();
      addTearDown(() async {
        controller.dispose();
        windowManager.removeListener(coordinator);
        await WindowController.fromWindowId('main')
            .setWindowMethodHandler(null);
        for (final channel in [
          windowsChannel,
          methodChannel,
          managerChannel,
          runnerChannel,
        ]) {
          messenger.setMockMethodCallHandler(channel, null);
        }
        await db.close();
      });
      await controller.load();
      final first = await controller.create();
      final second = await controller.create();
      final third = await controller.create();
      await coordinator.bindMain(controller);
      expect(creates, 1); // One ready spare, with no note record created.
      expect(controller.notes, hasLength(3));
      await coordinator.flushChildren();
      expect(flushes, 0); // Parked engines are excluded from saving.
      final opening = coordinator.openNote(first.id);
      final duplicate = coordinator.openNote(first.id);
      final another = coordinator.openNote(second.id);
      expect(identical(opening, duplicate), isTrue);
      await started.future;
      expect(creates, 1);
      gate.complete();
      await Future.wait([opening, duplicate, another]);
      expect(creates, 2);
      expect(
        windows
            .skip(1)
            .map(
              (window) =>
                  (jsonDecode(window['windowArgument'] as String)
                      as Map)['noteId'],
            ),
        [null, second.id],
      );
      await coordinator.openNote(first.id);
      expect(creates, 2);
      expect(focuses, 1);
      focusReady = false;
      await coordinator.openNote(first.id);
      expect(creates, 2);
      expect(nativeShows, 2);
      focusReady = true;
      fail = true;
      await expectLater(
        coordinator.openNote(third.id),
        throwsA(isA<PlatformException>()),
      );
      fail = false;
      await coordinator.openNote(third.id);
      expect(creates, 4);
      expect(
        await controller.store.getSetting<List>('openNoteWindows'),
        containsAll([first.id, second.id, third.id]),
      );
      await coordinator.flushChild(first.id);
      expect(flushes, 1); // Assignment, rather than launch arguments, is used.
      expect(
        await fromChild('closed', {'noteId': first.id, 'windowId': 'child-1'}),
        isTrue,
      );
      expect(
        await fromChild('closed', {'noteId': second.id, 'windowId': 'child-2'}),
        isFalse,
      ); // Only one spare is retained.
      failActivate = true;
      await expectLater(
        coordinator.openNote(second.id),
        throwsA(isA<WindowChannelException>()),
      );
      failActivate = false;
      await coordinator.openNote(second.id);
      expect(creates, 4); // Reuse the parked engine for a different note.
      expect(activations, 3);
      await coordinator.flushChild(second.id);
      expect(flushes, 2);
    },
    skip: !Platform.isWindows,
  );

  test('reused remote editors reject state from a previous note', () {
    final remote = RemoteNoteEditorStore(
      WindowController.fromWindowId('main'),
      null,
    );
    final first = Note.fresh('local');
    final second = Note.fresh('local');
    remote.activate(first.id, {'note': first.toJson(), 'theme': 'dark'});
    expect(remote.noteById(first.id)?.id, first.id);
    remote.park();
    expect(remote.noteById(first.id), isNull);
    remote.unpark(first.id);
    expect(remote.noteById(first.id)?.id, first.id);
    remote.park();
    remote.activate(second.id, {'note': second.toJson(), 'theme': 'light'});
    remote.applyState({'note': first.toJson(), 'theme': 'dark'});
    expect(remote.noteById(second.id)?.id, second.id);
    expect(remote.noteById(first.id), isNull);
    expect(remote.themeMode, ThemeMode.light);
    remote.dispose();
  });
}
