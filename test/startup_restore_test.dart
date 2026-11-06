import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/data/note.dart';
import 'package:better_notes/desktop/windows_notes_io.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

class _Desktop {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  static const native = MethodChannel('mixin.one/desktop_multi_window');
  static const messages = MethodChannel(
    'mixin.one/desktop_multi_window/channels',
  );
  static const runner = MethodChannel('betternotes/windows');
  static const manager = MethodChannel('window_manager');
  final windows = <Map<String, dynamic>>[
    {'windowId': 'main', 'windowArgument': ''},
  ];
  final createdNotes = <String?>[];
  final presented = <String, bool>{};
  final discarded = <String>[];
  final failNotes = <String>{};
  final createSignals = <int, Completer<void>>{};
  final focused = <String>[];
  late Database db;
  late NotesController controller;
  late DesktopCoordinator coordinator;
  bool autoReady = false;
  bool failFlush = false;
  int libraryShows = 0;
  int nativeCalls = 0;
  int maxNativeCalls = 0;

  Future<dynamic> fromChild(String method, dynamic args) async {
    const codec = StandardMethodCodec();
    final reply = Completer<ByteData?>();
    // ignore: deprecated_member_use
    await messenger.handlePlatformMessage(
      messages.name,
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

  String idFor(String? note) => 'child-${createdNotes.indexOf(note) + 1}';
  Future<void> ready(String? note) async => fromChild('ready', idFor(note));
  Future<void> created(int count) => createdNotes.length >= count
      ? Future<void>.value()
      : createSignals
            .putIfAbsent(count, Completer<void>.new)
            .future
            .timeout(const Duration(seconds: 3));

  Future<void> init({int concurrency = 2}) async {
    messenger.setMockMethodCallHandler(native, (call) async {
      switch (call.method) {
        case 'getWindowDefinition':
          return windows.first;
        case 'getAllWindows':
          return windows.toList();
        case 'createWindow':
          nativeCalls++;
          if (nativeCalls > maxNativeCalls) maxNativeCalls = nativeCalls;
          try {
            final argument = (call.arguments as Map)['arguments'] as String;
            final noteId = (jsonDecode(argument) as Map)['noteId'] as String?;
            if (failNotes.contains(noteId)) {
              throw PlatformException(code: 'create_failed');
            }
            createdNotes.add(noteId);
            final id = 'child-${createdNotes.length}';
            windows.add({'windowId': id, 'windowArgument': argument});
            createSignals.remove(createdNotes.length)?.complete();
            if (autoReady) await fromChild('ready', id);
            return id;
          } finally {
            nativeCalls--;
          }
        default:
          return null;
      }
    });
    messenger.setMockMethodCallHandler(messages, (call) async {
      if (call.method != 'invokeMethod') return null;
      final args = call.arguments as Map;
      final method = args['method'];
      final id = (args['channel'] as String).split('/').last;
      if (method == 'present') presented[id] = args['arguments'] as bool;
      if (method == 'focus') focused.add(id);
      if (method == 'flush') {
        if (failFlush) throw PlatformException(code: 'save_failed');
        return true;
      }
      if (method == 'close' || method == 'abort_startup') {
        windows.removeWhere((window) => window['windowId'] == id);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(runner, (call) async {
      if (call.method == 'discardStartupWindow') {
        discarded.add(call.arguments as String);
        windows.removeWhere((window) => window['windowId'] == call.arguments);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(manager, (call) async {
      if (call.method == 'show') libraryShows++;
      return call.method == 'isMinimized' ? false : null;
    });
    db = await databaseFactoryMemory.openDatabase('restore');
    controller = NotesController(LocalStore.fromDatabase(db), null);
    await controller.load();
    controller.fastNoteOpening = false;
    coordinator = await createDesktopCoordinator();
    expect(coordinator.startupConcurrency, 1); // Safe production default.
    coordinator.startupConcurrency = concurrency;
  }

  Future<List<Note>> notes(int count) async => [
    for (var i = 0; i < count; i++) await controller.create(),
  ];

  Future<void> bind(List<dynamic> remembered) async {
    await controller.store.setSetting('openNoteWindows', remembered);
    await coordinator.bindMain(controller, diagnosticMode: true);
    expect(createdNotes, isEmpty);
  }

  Future<List> get remembered async =>
      (await controller.store.getSetting<List>('openNoteWindows'))!;

  Future<void> dispose() async {
    await coordinator.dispose();
    controller.dispose();
    await db.close();
    for (final channel in [native, messages, runner, manager]) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('binding is immediate; two readiness waits overlap and clicks promote queued restores', () async {
    final desktop = _Desktop();
    await desktop.init();
    addTearDown(desktop.dispose);
    final notes = await desktop.notes(4);
    await desktop.bind(notes.map((note) => note.id).toList());
    final restore = desktop.coordinator.restoreSession();
    expect(identical(restore, desktop.coordinator.restoreSession()), isTrue);
    await desktop.created(2);
    expect(desktop.createdNotes, [notes[0].id, notes[1].id]);
    expect(desktop.presented, isEmpty);
    final clicked = desktop.coordinator.openNote(notes[3].id);
    expect(
      identical(clicked, desktop.coordinator.openNote(notes[3].id)),
      isTrue,
    );
    await desktop.ready(notes[0].id);
    await desktop.created(3);
    expect(desktop.createdNotes.last, notes[3].id);
    await desktop.ready(notes[3].id);
    await clicked;
    await desktop.created(4);
    await desktop.ready(notes[1].id);
    await desktop.ready(notes[2].id);
    await restore;
    expect(desktop.maxNativeCalls, 1);
    expect(desktop.presented[desktop.idFor(notes[3].id)], isTrue);
    expect(desktop.presented[desktop.idFor(notes[0].id)], isFalse);
    expect(desktop.createdNotes.toSet(), hasLength(4));
    expect(await desktop.remembered, containsAll(notes.map((note) => note.id)));
  }, skip: !Platform.isWindows);

  test('bad IDs and failed windows do not block the rest; failed session IDs survive retry', () async {
    final desktop = _Desktop();
    await desktop.init();
    addTearDown(desktop.dispose);
    desktop.autoReady = true;
    final notes = await desktop.notes(4);
    await desktop.controller.archive(notes[2].id);
    await desktop.controller.delete(notes[3]);
    desktop.failNotes.add(notes[0].id);
    await desktop.bind([
      notes[0].id,
      notes[0].id,
      42,
      'missing',
      notes[1].id,
      notes[2].id,
      notes[3].id,
    ]);
    await desktop.coordinator.restoreSession();
    expect(desktop.createdNotes, [notes[1].id]);
    expect(await desktop.remembered, [notes[0].id, notes[1].id]);
    expect(desktop.controller.windowRestoreFailure, contains('1 note window'));
    desktop.failNotes.clear();
    await desktop.controller.retryWindowRestore!();
    expect(desktop.createdNotes, [notes[1].id, notes[0].id]);
    expect(desktop.controller.windowRestoreFailure, isNull);
  }, skip: !Platform.isWindows);

  test(
    'a timed-out hidden child is discarded; late ready cannot block retry',
    () async {
      final desktop = _Desktop();
      await desktop.init();
      addTearDown(desktop.dispose);
      final notes = await desktop.notes(2);
      desktop.coordinator.childReadyTimeout = const Duration(milliseconds: 200);
      await desktop.bind(notes.map((note) => note.id).toList());
      final restore = desktop.coordinator.restoreSession();
      await desktop.created(2);
      expect(desktop.libraryShows, 1);
      await desktop.ready(notes[1].id);
      await restore;
      expect(desktop.discarded, ['child-1']);
      expect(desktop.presented.keys, ['child-2']);
      expect(await desktop.remembered, contains(notes[0].id));
      await desktop.fromChild('ready', 'child-1');
      desktop.autoReady = true;
      await desktop.coordinator.openNote(notes[0].id);
      expect(desktop.createdNotes, hasLength(3));
      expect(desktop.presented['child-3'], isTrue);
    },
    skip: !Platform.isWindows,
  );

  test(
    'shutdown during restore preserves pending IDs and flushes ready editors',
    () async {
      final desktop = _Desktop();
      await desktop.init();
      addTearDown(desktop.dispose);
      final notes = await desktop.notes(4);
      await desktop.bind(notes.map((note) => note.id).toList());
      final restore = desktop.coordinator.restoreSession();
      await desktop.created(2);
      final quit = desktop.coordinator.quit();
      await desktop.ready(notes[0].id);
      await desktop.ready(notes[1].id);
      await Future.wait([restore, quit]);
      expect(desktop.createdNotes, hasLength(2));
      expect(desktop.windows, hasLength(1));
      expect(await desktop.remembered, notes.map((note) => note.id).toList());
      expect(desktop.controller.saveFailure, isNull);
    },
    skip: !Platform.isWindows,
  );

  test('a note closed during restore is not reopened; queued deleted notes are skipped', () async {
    final desktop = _Desktop();
    await desktop.init();
    addTearDown(desktop.dispose);
    final notes = await desktop.notes(3);
    await desktop.bind(notes.map((note) => note.id).toList());
    final restore = desktop.coordinator.restoreSession();
    await desktop.created(2);
    await desktop.controller.delete(notes[2]);
    await desktop.ready(notes[0].id);
    await desktop.coordinator.openNote(notes[0].id);
    await desktop.fromChild('closed', {
      'noteId': notes[0].id,
      'windowId': 'child-1',
    });
    await desktop.ready(notes[1].id);
    await restore;
    expect(desktop.createdNotes, hasLength(2));
    expect(await desktop.remembered, [notes[1].id]);
  }, skip: !Platform.isWindows);

  test(
    'failed shutdown keeps editors and resumes pending restoration',
    () async {
      final desktop = _Desktop();
      await desktop.init();
      addTearDown(desktop.dispose);
      final notes = await desktop.notes(4);
      await desktop.bind(notes.map((note) => note.id).toList());
      final restore = desktop.coordinator.restoreSession();
      await desktop.created(2);
      desktop.failFlush = true;
      final quit = desktop.coordinator.quit();
      await desktop.ready(notes[0].id);
      await desktop.ready(notes[1].id);
      await Future.wait([restore, quit]);
      desktop.failFlush = false;
      await desktop.created(4);
      await desktop.ready(notes[2].id);
      await desktop.ready(notes[3].id);
      await desktop.coordinator.restoreSession();
      expect(desktop.windows, hasLength(5));
      expect(desktop.presented, hasLength(4));
      expect(desktop.controller.saveFailure, contains('App kept open'));
      expect(
        await desktop.remembered,
        containsAll(notes.map((note) => note.id)),
      );
    },
    skip: !Platform.isWindows,
  );
}
