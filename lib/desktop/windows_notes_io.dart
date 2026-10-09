import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../data/note.dart';
import '../state/note_editor_store.dart';
import '../state/notes_controller.dart';

Future<DesktopCoordinator> createDesktopCoordinator() async {
  if (!Platform.isWindows) return DesktopCoordinator._();
  final window = await WindowController.fromCurrentEngine();
  if (window.arguments.isEmpty) return DesktopCoordinator._(window: window);
  final args = Map<String, dynamic>.from(jsonDecode(window.arguments) as Map);
  if (args['type'] != 'note') return DesktopCoordinator._(window: window);
  final coordinator = DesktopCoordinator._(
    window: window,
    noteId: args['noteId'] as String?,
    parentId: args['parentId'] as String,
    initialBounds: args['bounds'] as List<dynamic>?,
  );
  await coordinator._prepareChild();
  return coordinator;
}

class DesktopCoordinator with WindowListener {
  DesktopCoordinator._({
    this._window,
    this.noteId,
    this._parentId,
    this._initialBounds,
  });

  final WindowController? _window;
  String? noteId;
  final String? _parentId;
  final List<dynamic>? _initialBounds;
  final ValueNotifier<int> _closeRequests = ValueNotifier<int>(0);
  final ValueNotifier<int> _searchRequests = ValueNotifier<int>(0);
  final Set<String> _openIds = {};
  NotesController? _mainController;
  RemoteNoteEditorStore? _remote;
  Timer? _boundsTimer;
  bool _closing = false;
  bool _shuttingDown = false;
  Timer? _broadcastTimer;
  bool _pushing = false;
  bool _pushAgain = false;
  final Map<String, String> _deliveredStates = {};
  final Map<String, Future<void>> _openingNotes = {};
  Future<void> _openTail = Future<void>.value();
  final Map<String, String?> _assignments = {};
  final Set<String> _readyWindows = {};
  final Map<String, Completer<void>> _readyWaiters = {};
  WindowController? _idleWindow;

  bool get isNoteWindow => _parentId != null;
  bool get supportsNoteWindows => _window != null && !isNoteWindow;
  ValueListenable<int>? get closeRequests =>
      isNoteWindow ? _closeRequests : null;
  ValueListenable<int>? get searchRequests =>
      supportsNoteWindows ? _searchRequests : null;

  Future<void> bindMain(NotesController controller) async {
    if (!supportsNoteWindows) return;
    _mainController = controller;
    controller.flushDesktopEditors = flushChildren;
    controller.flushDesktopEditor = flushChild;
    final remembered =
        await controller.store.getSetting<List<dynamic>>('openNoteWindows') ??
        const [];
    _openIds.addAll(remembered.cast<String>());
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    await _window!.setWindowMethodHandler(_handleMainCall);
    const runner = MethodChannel('betternotes/windows');
    runner.setMethodCallHandler((call) async {
      if (call.method == 'newNote') {
        await createAndOpenNote();
      }
    });
    controller.addListener(_broadcast);
    await _restoreWindows();
    // Pay for one native engine before the library becomes interactive. Reuse
    // this bounded spare for the next open and park an editor when it closes.
    try {
      final spare = await _createWindow(null, null);
      _idleWindow = spare;
    } catch (_) {
      // A spare is optional; normal opening remains available if warming fails.
    }
    await runner.invokeMethod<void>('ready');
  }

  Future<dynamic> _handleMainCall(MethodCall call) async {
    final controller = _mainController!;
    final args = call.arguments;
    switch (call.method) {
      case 'ready':
        final id = args as String;
        _readyWindows.add(id);
        _readyWaiters.remove(id)?.complete();
        return null;
      case 'note_state':
        return _state(args as String);
      case 'new_note':
        await createAndOpenNote();
        return null;
      case 'focus_search':
        await windowManager.ensureInitialized();
        await windowManager.show();
        await windowManager.focus();
        _searchRequests.value++;
        return null;
      case 'save_note':
        final changes = Map<String, dynamic>.from(args as Map);
        final id = changes['noteId'] as String;
        final current = controller.noteById(id);
        if (current != null) {
          await controller.save(
            current.copyWith(
              delta: changes['delta'] as List<dynamic>?,
              plainText: changes['plainText'] as String?,
              images: (changes['images'] as List<dynamic>?)?.cast<String>(),
              colorIndex: changes['colorIndex'] as int?,
              title: changes['title'] as String?,
              favorite: changes['favorite'] as bool?,
              tags: (changes['tags'] as List<dynamic>?)?.cast<String>(),
              strokes: (changes['strokes'] as List<dynamic>?)
                  ?.map(
                    (value) => InkStroke.fromJson(
                      Map<String, dynamic>.from(value as Map),
                    ),
                  )
                  .toList(),
            ),
          );
        }
        return _state(id);
      case 'delete_note':
        final current = controller.noteById(args as String);
        if (current != null) await controller.delete(current);
        return _state(args);
      case 'restore_note':
        await controller.restore(args as String);
        return _state(args);
      case 'archive_note':
        await controller.archive(args as String);
        return _state(args);
      case 'add_image':
        final values = Map<dynamic, dynamic>.from(args as Map);
        final id = values['noteId'] as String;
        final current = controller.noteById(id);
        if (current != null) {
          await controller.addImage(current, values['bytes'] as Uint8List);
        }
        return _state(id);
      case 'remove_image':
        final values = Map<dynamic, dynamic>.from(args as Map);
        final id = values['noteId'] as String;
        final current = controller.noteById(id);
        if (current != null) {
          await controller.removeImage(current, values['imageId'] as String);
        }
        return _state(id);
      case 'image':
        final values = Map<dynamic, dynamic>.from(args as Map);
        return controller.image(
          values['noteId'] as String,
          values['imageId'] as String,
        );
      case 'cache_image':
        return controller.cacheImage(args as Uint8List);
      case 'bounds':
        final values = Map<dynamic, dynamic>.from(args as Map);
        await controller.store.setSetting(
          'windowBounds:${values['noteId']}',
          values['bounds'] as List<dynamic>,
        );
        return null;
      case 'closed':
        final values = Map<String, dynamic>.from(args as Map);
        final id = values['windowId'] as String;
        if (!_shuttingDown) {
          _openIds.remove(values['noteId'] as String);
          await _rememberOpenWindows();
          _assignments[id] = null;
          _deliveredStates.remove(id);
          if (_idleWindow == null) {
            _idleWindow = WindowController.fromWindowId(id);
            return true;
          }
        }
        // Keep a null assignment until native destruction completes; stale
        // launch arguments must not make this closing window look editable.
        _assignments[id] = null;
        _readyWindows.remove(id);
        _broadcast();
        return false;
      default:
        throw MissingPluginException('Unknown desktop call: ${call.method}');
    }
  }

  Map<String, dynamic> _state(String id) {
    final controller = _mainController!;
    return {
      'note': controller.noteById(id)?.toJson(),
      'confirmDelete': controller.confirmDelete,
      'signedIn': controller.signedIn,
      'syncing': controller.syncing,
      'theme': controller.themeMode.name,
      'customWindowButtons': controller.customWindowButtons,
      'inlineImages': controller.inlineImages,
      'alwaysShowNoteHeader': controller.alwaysShowNoteHeader,
    };
  }

  Future<void> _restoreWindows() async {
    for (final id in _openIds.toList()) {
      if (_shuttingDown) return;
      if (_mainController?.noteById(id) == null ||
          _mainController?.noteById(id)?.archivedAt != null) {
        _openIds.remove(id);
        continue;
      }
      await openNote(id);
    }
    await _rememberOpenWindows();
  }

  Future<void> _rememberOpenWindows() async =>
      _mainController!.store.setSetting('openNoteWindows', _openIds.toList());

  String? _windowNoteId(WindowController child) {
    if (_assignments.containsKey(child.windowId)) {
      return _assignments[child.windowId];
    }
    if (child.arguments.isEmpty) return null;
    final args = jsonDecode(child.arguments) as Map;
    return args['type'] == 'note' ? args['noteId'] as String? : null;
  }

  Future<WindowController> _createWindow(
    String? id,
    List<dynamic>? bounds,
  ) async {
    final child = await WindowController.create(
      WindowConfiguration(
        arguments: jsonEncode({
          'type': 'note',
          'noteId': id,
          'parentId': _window!.windowId,
          'bounds': bounds,
        }),
        hiddenAtLaunch: true,
      ),
    );
    _assignments[child.windowId] = id;
    if (!_readyWindows.contains(child.windowId)) {
      final waiter = _readyWaiters.putIfAbsent(
        child.windowId,
        () => Completer<void>(),
      );
      try {
        await waiter.future.timeout(const Duration(seconds: 15));
      } finally {
        _readyWaiters.remove(child.windowId);
      }
    }
    return child;
  }

  Future<void> createAndOpenNote() async {
    if (isNoteWindow) {
      await WindowController.fromWindowId(_parentId!)
          .invokeMethod<void>('new_note');
      return;
    }
    if (!supportsNoteWindows || _shuttingDown) return;
    final note = await _mainController!.create();
    await openNote(note.id);
  }

  Future<void> focusSearch() async {
    if (isNoteWindow) {
      await WindowController.fromWindowId(_parentId!)
          .invokeMethod<void>('focus_search');
    }
  }

  Future<void> openNote(String id) {
    if (!supportsNoteWindows || _shuttingDown) return Future<void>.value();
    // Coalesce repeated clicks and serialize native engine startup. Different
    // notes still open, but cannot race enumeration or each other's creation.
    return _openingNotes.putIfAbsent(id, () {
      final operation = _openTail.then((_) => _openNote(id));
      _openTail = operation.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      );
      return operation.whenComplete(() {
        _openingNotes.remove(id);
      });
    });
  }

  Future<void> _openNote(String id) async {
    if (!supportsNoteWindows || _shuttingDown) return;
    if (_mainController!.noteById(id) == null ||
        _mainController!.noteById(id)?.archivedAt != null) {
      return;
    }
    for (final existing in await WindowController.getAll()) {
      String? existingNoteId;
      try {
        existingNoteId = _windowNoteId(existing);
      } catch (_) {
        // Another window might use different arguments.
        continue;
      }
      if (existingNoteId != id) continue;
      try {
        await existing.invokeMethod<void>('focus');
        return;
      } catch (_) {
        // A new engine can exist before its Dart focus handler is registered.
        // Reuse that native window rather than starting a duplicate engine.
        final live = await WindowController.getAll();
        if (live.any((window) => window.windowId == existing.windowId)) {
          await existing.show();
          return;
        }
        // It really closed between enumeration and focus; create a replacement.
        break;
      }
    }
    _openIds.add(id);
    await _rememberOpenWindows();
    final bounds = await _mainController!.store.getSetting<List<dynamic>>(
      'windowBounds:$id',
    );
    WindowController? reused;
    try {
      final spare = _idleWindow;
      if (spare != null) {
        reused = spare;
        _idleWindow = null;
        _assignments[spare.windowId] = id;
        await spare.invokeMethod<void>('activate', {
          'noteId': id,
          'state': _state(id),
          'bounds': bounds,
        });
      } else {
        final child = await _createWindow(id, bounds);
        await child.show();
      }
    } catch (_) {
      if (reused != null) {
        _assignments[reused.windowId] = null;
        _deliveredStates.remove(reused.windowId);
        try {
          await reused
              .invokeMethod<void>('reset')
              .timeout(const Duration(seconds: 2));
          _idleWindow ??= reused;
        } catch (_) {
          // If the engine died, a retry can use the normal cold-opening path.
        }
      }
      _openIds.remove(id);
      await _rememberOpenWindows();
      rethrow;
    }
  }

  void _broadcast() {
    if (_mainController == null) return;
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer(
      const Duration(milliseconds: 30),
      () => unawaited(_pushAll()),
    );
  }

  Future<void> _pushAll() async {
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushAgain = false;
        final children = await WindowController.getAll();
        final liveIds = children.map((child) => child.windowId).toSet();
        _deliveredStates.removeWhere((id, _) => !liveIds.contains(id));
        _assignments.removeWhere((id, _) => !liveIds.contains(id));
        _readyWindows.removeWhere((id) => !liveIds.contains(id));
        for (final child in children) {
          try {
            final id = _windowNoteId(child);
            if (id == null) continue;
            final state = _state(id);
            final encoded = jsonEncode(state);
            if (_deliveredStates[child.windowId] == encoded) continue;
            await child.invokeMethod<void>('state', state);
            _deliveredStates[child.windowId] = encoded;
          } catch (_) {
            // A window may have closed between the list and the notification.
          }
        }
      } while (_pushAgain);
    } catch (_) {
      // Enumeration may race engine shutdown; a later notification retries.
    } finally {
      _pushing = false;
    }
  }

  Future<void> _prepareChild() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    await _window!.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'reset':
          await windowManager.hide();
          noteId = null;
          _remote!.park();
          return null;
        case 'activate':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          noteId = args['noteId'] as String;
          _closing = false;
          _remote!.activate(
            noteId!,
            Map<String, dynamic>.from(args['state'] as Map),
          );
          await _applyBounds(args['bounds'] as List<dynamic>?);
          await windowManager.setTitle(
            '${_remote!.noteById(noteId!)!.displayTitle} — BetterNotes',
          );
          // Wait for the new keyed editor, so no old note flashes on reuse.
          await WidgetsBinding.instance.endOfFrame;
          await windowManager.show();
          await windowManager.focus();
          return null;
        case 'focus':
          await windowManager.show();
          await windowManager.focus();
          return null;
        case 'state':
          if (noteId == null) return null;
          _remote?.applyState(Map<String, dynamic>.from(call.arguments as Map));
          final note = _remote?.noteById(noteId!);
          if (note != null) {
            await windowManager.setTitle('${note.displayTitle} — BetterNotes');
          }
          if (note == null || note.archivedAt != null) {
            _closeRequests.value++;
          }
          return null;
        case 'close':
          if (noteId == null) {
            // Reply before destroying the engine that carries this channel.
            // Otherwise the main window waits forever for a lost response.
            Timer.run(() => unawaited(_destroySelf()));
            return null;
          }
          _closeRequests.value++;
          return null;
        case 'flush':
          if (_remote == null) {
            throw StateError('The note editor is still opening. Retry.');
          }
          await _remote!.flushEditors();
          return true;
        default:
          throw MissingPluginException('Unknown window call: ${call.method}');
      }
    });
    await _applyBounds(_initialBounds);
    await windowManager.setTitle('BetterNotes');
  }

  Future<void> _applyBounds(List<dynamic>? bounds) async {
    if (bounds != null && bounds.length == 4) {
      final values = bounds.cast<num>();
      await windowManager.setBounds(
        Rect.fromLTWH(
          values[0].toDouble(),
          values[1].toDouble(),
          values[2].toDouble(),
          values[3].toDouble(),
        ),
      );
    } else {
      await windowManager.setSize(const Size(470, 520));
      await windowManager.center();
    }
  }

  Future<void> notifyReady() async {
    if (!isNoteWindow) return;
    await WindowController.fromWindowId(_parentId!)
        .invokeMethod<void>('ready', _window!.windowId);
    if (noteId != null) {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  Future<NoteEditorStore> createRemote() async {
    final remote = RemoteNoteEditorStore(
      WindowController.fromWindowId(_parentId!),
      noteId,
    );
    await remote.load();
    _remote = remote;
    final note = noteId == null ? null : remote.noteById(noteId!);
    if (note != null) {
      await windowManager.setTitle('${note.displayTitle} — BetterNotes');
    }
    return remote;
  }

  Future<void> _saveBounds() async {
    if (_parentId == null || noteId == null) return;
    final bounds = await windowManager.getBounds();
    await WindowController.fromWindowId(_parentId)
        .invokeMethod<void>('bounds', {
          'noteId': noteId,
          'bounds': [bounds.left, bounds.top, bounds.width, bounds.height],
        });
  }

  @override
  void onWindowMoved() => _scheduleBoundsSave();

  @override
  void onWindowResized() => _scheduleBoundsSave();

  void _scheduleBoundsSave() {
    if (noteId == null) return;
    _boundsTimer?.cancel();
    _boundsTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_saveBounds());
    });
  }

  @override
  void onWindowClose() {
    if (!isNoteWindow) {
      unawaited(_closeMain());
    } else if (noteId == null) {
      unawaited(_destroySelf());
    } else {
      _closeRequests.value++;
    }
  }

  Future<void> _closeMain() async {
    if (_closing) return;
    _closing = true;
    _shuttingDown = true;
    try {
      await _openTail;
      // First save every editor. If one fails, keep all windows available.
      await _mainController!.flushEditors();
      await flushChildren();
      await _mainController!.waitForWrites();
      final children = await WindowController.getAll();
      for (final child in children) {
        if (child.arguments.isEmpty) continue;
        try {
          final args = Map<String, dynamic>.from(
            jsonDecode(child.arguments) as Map,
          );
          if (args['type'] == 'note') {
            await child.invokeMethod<void>('close');
          }
        } catch (_) {
          // A note window may already be closing.
        }
      }
      for (var attempt = 0; attempt < 30; attempt++) {
        final active = await WindowController.getAll();
        if (active.every((window) => window.arguments.isEmpty)) {
          windowManager.removeListener(this);
          await windowManager.setPreventClose(false);
          await windowManager.close();
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      throw StateError('A note is still closing. Retry closing the app.');
    } catch (error) {
      _closing = false;
      _shuttingDown = false;
      _mainController!.reportSaveFailure(
        'App kept open because notes could not finish saving: $error',
      );
      await windowManager.show();
      await windowManager.focus();
    }
  }

  Future<void> flushChildren() async {
    for (final child in await WindowController.getAll()) {
      if (_windowNoteId(child) == null) continue;
      final acknowledged = await child.invokeMethod<bool>('flush');
      if (acknowledged != true) {
        throw StateError('A note did not acknowledge its save. Retry.');
      }
    }
  }

  Future<void> flushChild(String id) async {
    for (final child in await WindowController.getAll()) {
      if (_windowNoteId(child) != id) continue;
      if (await child.invokeMethod<bool>('flush') != true) {
        throw StateError('The note could not finish saving. Retry.');
      }
    }
  }

  Future<void> closeSelf() async {
    if (_closing) return;
    _closing = true;
    _boundsTimer?.cancel();
    final closedId = noteId!;
    try {
      await _saveBounds();
      await windowManager.hide();
      await windowManager.setAlwaysOnTop(false);
      noteId = null;
      _remote!.park();
      _closing = false;
      final keep = await WindowController.fromWindowId(_parentId!)
          .invokeMethod<bool>('closed', {
            'noteId': closedId,
            'windowId': _window!.windowId,
          });
      if (keep != true) await _destroySelf();
    } catch (_) {
      _closing = false;
      noteId = closedId;
      _remote!.unpark(closedId);
      await windowManager.show();
      await windowManager.focus();
      rethrow;
    }
  }

  Future<void> _destroySelf() async {
    _boundsTimer?.cancel();
    windowManager.removeListener(this);
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}

class RemoteNoteEditorStore extends NoteEditorStore {
  RemoteNoteEditorStore(this._parent, this._noteId);

  final WindowController _parent;
  String? _noteId;
  Note? _note;
  @override
  bool confirmDelete = true;
  @override
  bool syncing = false;
  @override
  bool signedIn = false;
  @override
  ThemeMode themeMode = ThemeMode.system;
  @override
  bool customWindowButtons = false;
  @override
  bool inlineImages = false;
  @override
  bool alwaysShowNoteHeader = false;

  Future<void> load() async {
    if (_noteId == null) return;
    final state = await _parent.invokeMethod<Map<dynamic, dynamic>>(
      'note_state',
      _noteId,
    );
    if (state == null) throw StateError('Could not load the note window.');
    applyState(Map<String, dynamic>.from(state));
  }

  void activate(String id, Map<String, dynamic> state) {
    _note = null;
    _noteId = id;
    applyState(state);
  }

  void park() {
    _noteId = null;
    notifyListeners();
  }

  void unpark(String id) {
    _noteId = id;
    notifyListeners();
  }

  void applyState(Map<String, dynamic> state) {
    final raw = state['note'];
    final incoming = raw == null
        ? null
        : Note.fromJson(Map<String, dynamic>.from(raw));
    // A broadcast/save response from the previous assignment may arrive after
    // this engine is parked or switched to another note.
    if (incoming != null && incoming.id != _noteId) return;
    if (incoming == null ||
        _note == null ||
        !incoming.updatedAt.isBefore(_note!.updatedAt)) {
      _note = incoming;
    }
    confirmDelete = state['confirmDelete'] as bool? ?? true;
    syncing = state['syncing'] as bool? ?? false;
    signedIn = state['signedIn'] as bool? ?? false;
    customWindowButtons = state['customWindowButtons'] as bool? ?? false;
    inlineImages = state['inlineImages'] as bool? ?? false;
    alwaysShowNoteHeader = state['alwaysShowNoteHeader'] as bool? ?? false;
    themeMode = switch (state['theme']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  @override
  Note? noteById(String id) => id == _noteId ? _note : null;

  Future<void> _applyResponse(Future<Map<dynamic, dynamic>?> request) async {
    final response = await request;
    if (response == null) {
      throw StateError('The main window did not acknowledge storage.');
    }
    applyState(Map<String, dynamic>.from(response));
  }

  @override
  Future<void> save(Note note) async {
    final previous = _note;
    final changes = <String, dynamic>{'noteId': note.id};
    if (previous == null || previous.title != note.title) {
      changes['title'] = note.title;
    }
    if (previous == null || previous.favorite != note.favorite) {
      changes['favorite'] = note.favorite;
    }
    if (previous == null || !listEquals(previous.tags, note.tags)) {
      changes['tags'] = note.tags;
    }
    if (previous == null ||
        jsonEncode(previous.delta) != jsonEncode(note.delta)) {
      changes['delta'] = note.delta;
      changes['plainText'] = note.plainText;
    }
    if (previous == null || previous.colorIndex != note.colorIndex) {
      changes['colorIndex'] = note.colorIndex;
    }
    if (previous == null || !listEquals(previous.images, note.images)) {
      changes['images'] = note.images;
    }
    if (previous == null ||
        jsonEncode(previous.strokes.map((s) => s.toJson()).toList()) !=
            jsonEncode(note.strokes.map((s) => s.toJson()).toList())) {
      changes['strokes'] = note.strokes.map((s) => s.toJson()).toList();
    }
    if (changes.length == 1) return;
    await _applyResponse(
      _parent.invokeMethod<Map<dynamic, dynamic>>('save_note', changes),
    );
  }

  @override
  Future<void> delete(Note note) => _applyResponse(
    _parent.invokeMethod<Map<dynamic, dynamic>>('delete_note', note.id),
  );

  @override
  Future<void> restore(String id) => _applyResponse(
    _parent.invokeMethod<Map<dynamic, dynamic>>('restore_note', id),
  );

  @override
  Future<void> archive(String id, {bool archived = true}) {
    if (!archived) throw UnsupportedError('Restore from the Archive view.');
    return _applyResponse(
      _parent.invokeMethod<Map<dynamic, dynamic>>('archive_note', id),
    );
  }

  @override
  Future<void> addImage(Note note, Uint8List bytes) => _applyResponse(
    _parent.invokeMethod<Map<dynamic, dynamic>>('add_image', {
      'noteId': note.id,
      'bytes': bytes,
    }),
  );

  @override
  Future<String> cacheImage(Uint8List bytes) async {
    final id = await _parent.invokeMethod<String>('cache_image', bytes);
    if (id == null) throw StateError('Could not cache the image.');
    return id;
  }

  @override
  Future<void> removeImage(Note note, String imageId) => _applyResponse(
    _parent.invokeMethod<Map<dynamic, dynamic>>('remove_image', {
      'noteId': note.id,
      'imageId': imageId,
    }),
  );

  @override
  Future<Uint8List?> image(String noteId, String imageId) => _parent
      .invokeMethod<Uint8List>('image', {'noteId': noteId, 'imageId': imageId});
}
