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
    noteId: args['noteId'] as String,
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
  final String? noteId;
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

  bool get supportsNoteWindows => _window != null && noteId == null;
  ValueListenable<int>? get closeRequests =>
      noteId == null ? null : _closeRequests;
  ValueListenable<int>? get searchRequests =>
      supportsNoteWindows ? _searchRequests : null;

  Future<void> bindMain(NotesController controller) async {
    if (!supportsNoteWindows) return;
    _mainController = controller;
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
    await runner.invokeMethod<void>('ready');
    controller.addListener(_broadcast);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_restoreWindows());
    });
  }

  Future<dynamic> _handleMainCall(MethodCall call) async {
    final controller = _mainController!;
    final args = call.arguments;
    switch (call.method) {
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
        if (!_shuttingDown) {
          _openIds.remove(args as String);
          await _rememberOpenWindows();
        }
        return null;
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
    };
  }

  Future<void> _restoreWindows() async {
    for (final id in _openIds.toList()) {
      if (_shuttingDown) return;
      if (_mainController?.noteById(id) == null) {
        _openIds.remove(id);
        continue;
      }
      await openNote(id);
    }
    await _rememberOpenWindows();
  }

  Future<void> _rememberOpenWindows() async =>
      _mainController!.store.setSetting('openNoteWindows', _openIds.toList());

  Future<void> createAndOpenNote() async {
    if (noteId != null) {
      await WindowController.fromWindowId(_parentId!)
          .invokeMethod<void>('new_note');
      return;
    }
    if (!supportsNoteWindows || _shuttingDown) return;
    final note = await _mainController!.create();
    await openNote(note.id);
  }

  Future<void> focusSearch() async {
    if (noteId != null) {
      await WindowController.fromWindowId(_parentId!)
          .invokeMethod<void>('focus_search');
    }
  }

  Future<void> openNote(String id) async {
    if (!supportsNoteWindows || _shuttingDown) return;
    if (_mainController!.noteById(id) == null) return;
    for (final existing in await WindowController.getAll()) {
      if (existing.arguments.isEmpty) continue;
      try {
        final args = Map<String, dynamic>.from(
          jsonDecode(existing.arguments) as Map,
        );
        if (args['type'] == 'note' && args['noteId'] == id) {
          await existing.invokeMethod<void>('focus');
          return;
        }
      } catch (_) {
        // Another window might use different arguments.
      }
    }
    _openIds.add(id);
    await _rememberOpenWindows();
    final bounds = await _mainController!.store.getSetting<List<dynamic>>(
      'windowBounds:$id',
    );
    try {
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
      await child.show();
    } catch (_) {
      _openIds.remove(id);
      await _rememberOpenWindows();
      rethrow;
    }
  }

  void _broadcast() {
    if (_mainController == null) return;
    unawaited(_pushAll());
  }

  Future<void> _pushAll() async {
    for (final child in await WindowController.getAll()) {
      if (child.arguments.isEmpty) continue;
      try {
        final args = Map<String, dynamic>.from(
          jsonDecode(child.arguments) as Map,
        );
        if (args['type'] != 'note') continue;
        final id = args['noteId'] as String;
        await child.invokeMethod<void>('state', _state(id));
      } catch (_) {
        // A window may have closed between the list and the notification.
      }
    }
  }

  Future<void> _prepareChild() async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    await _window!.setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'focus':
          await windowManager.show();
          await windowManager.focus();
          return null;
        case 'state':
          _remote?.applyState(Map<String, dynamic>.from(call.arguments as Map));
          if (_remote?.noteById(noteId!) == null) {
            _closeRequests.value++;
          }
          return null;
        case 'close':
          _closeRequests.value++;
          return null;
        default:
          throw MissingPluginException('Unknown window call: ${call.method}');
      }
    });
    final bounds = _initialBounds;
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
    await windowManager.setTitle('BetterNotes');
  }

  Future<NoteEditorStore> createRemote() async {
    final remote = RemoteNoteEditorStore(
      WindowController.fromWindowId(_parentId!),
      noteId!,
    );
    await remote.load();
    _remote = remote;
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
    if (noteId == null) {
      unawaited(_closeMain());
    } else {
      _closeRequests.value++;
    }
  }

  Future<void> _closeMain() async {
    if (_closing) return;
    _closing = true;
    _shuttingDown = true;
    try {
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
        if (active.every((window) => window.arguments.isEmpty)) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }

  Future<void> closeSelf() async {
    if (_closing) return;
    _closing = true;
    _boundsTimer?.cancel();
    try {
      await _saveBounds();
      await WindowController.fromWindowId(_parentId!)
          .invokeMethod<void>('closed', noteId);
    } finally {
      windowManager.removeListener(this);
      await windowManager.setPreventClose(false);
      await windowManager.close();
    }
  }
}

class RemoteNoteEditorStore extends NoteEditorStore {
  RemoteNoteEditorStore(this._parent, this._noteId);

  final WindowController _parent;
  final String _noteId;
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

  Future<void> load() async {
    final state = await _parent.invokeMethod<Map<dynamic, dynamic>>(
      'note_state',
      _noteId,
    );
    if (state == null) throw StateError('Could not load the note window.');
    applyState(Map<String, dynamic>.from(state));
  }

  void applyState(Map<String, dynamic> state) {
    final raw = state['note'];
    final incoming = raw == null
        ? null
        : Note.fromJson(Map<String, dynamic>.from(raw));
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
    if (response != null) applyState(Map<String, dynamic>.from(response));
  }

  @override
  Future<void> save(Note note) async {
    final previous = _note;
    final changes = <String, dynamic>{'noteId': note.id};
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
