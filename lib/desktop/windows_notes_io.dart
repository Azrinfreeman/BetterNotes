import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../data/reminder_task.dart';
import '../data/startup_timing.dart';
import 'tray.dart';
import 'window_fit.dart';
import '../data/note.dart';
import '../state/note_editor_store.dart';
export 'remote_note_editor_store.dart';
import 'remote_note_editor_store.dart';
import '../state/notes_controller.dart';

class _NoteOpenRequest {
  _NoteOpenRequest(
    this.id, {
    required this.activate,
    required this.retainOnFailure,
  });
  final String id;
  bool activate;
  final bool retainOnFailure;
  final result = Completer<void>();
}

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
  final Map<String, _NoteOpenRequest> _openingNotes = {};
  final List<_NoteOpenRequest> _pendingOpens = [];
  // Native construction is synchronous on the Windows platform thread. Only
  // the wait for the child's first frame overlaps the next native creation.
  Future<void> _nativeCreateTail = Future<void>.value();
  Future<void> _rememberTail = Future<void>.value();
  int _activeOpens = 0;
  // Keep native startup pressure bounded. The two-slot diagnostic experiment
  // did not improve restoration on this engine/plugin combination, so normal
  // launches wait for each first frame before starting another engine.
  int _startupConcurrency = 1;
  int get startupConcurrency => _startupConcurrency;
  set startupConcurrency(int value) => _startupConcurrency = value.clamp(1, 2);
  Duration childReadyTimeout = const Duration(seconds: 15);
  Future<void>? _restoration;
  bool _restoring = false;
  bool _diagnosticMode = false;
  Future<void>? _warming;
  final Set<String> _abandonedWindows = {};
  Timer? _firstReminderTimer;
  final Map<String, String?> _assignments = {};
  final Set<String> _readyWindows = {};
  final Map<String, Completer<void>> _readyWaiters = {};
  WindowController? _idleWindow;
  Timer? _refillTimer;
  Timer? _reminderTimer;
  Future<void> _taskTail = Future<void>.value();
  bool _checkingReminders = false;
  String? _balloonNoteId;

  bool get isNoteWindow => _parentId != null;
  bool get supportsNoteWindows => _window != null && !isNoteWindow;
  ValueListenable<int>? get closeRequests =>
      isNoteWindow ? _closeRequests : null;
  ValueListenable<int>? get searchRequests =>
      supportsNoteWindows ? _searchRequests : null;

  Future<void> bindMain(
    NotesController controller, {
    bool diagnosticMode = false,
  }) async {
    if (!supportsNoteWindows) return;
    _mainController = controller;
    _diagnosticMode = diagnosticMode;
    controller.retryWindowRestore = () {
      if (_restoring) return _restoration ?? Future<void>.value();
      _restoration = null;
      return restoreSession();
    };
    controller.flushDesktopEditors = flushChildren;
    controller.flushDesktopEditor = flushChild;
    controller.applyFastNoteOpening = _applyFastOpening;
    controller.remindersChanged = diagnosticMode ? null : _syncReminderTask;
    controller.applyTray = () =>
        DesktopIntegration.setTray(controller.keepInTray);
    controller.applyQuickCapture = () =>
        DesktopIntegration.setQuickCapture(controller.quickCaptureKey);
    final remembered =
        await controller.store.getSetting<List<dynamic>>('openNoteWindows') ??
        const [];
    _openIds.addAll(remembered.whereType<String>());
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    await _window!.setWindowMethodHandler(_handleMainCall);
    const runner = MethodChannel('betternotes/windows');
    runner.setMethodCallHandler((call) async {
      if (call.method == 'newNote') {
        await createAndOpenNote();
      } else if (call.method == 'quit') {
        await _closeMain();
      } else if (call.method == 'checkReminders') {
        await _checkReminders();
      } else if (call.method == 'balloonClicked') {
        final id = _balloonNoteId;
        if (id != null) {
          await openNote(id);
        } else {
          await _showMainWindow();
        }
      }
    });
    controller.addListener(_broadcast);
    try {
      if (controller.keepInTray) await DesktopIntegration.setTray(true);
    } catch (_) {
      // Without a tray icon the window must still close normally.
      controller.keepInTray = false;
    }
    try {
      if (controller.quickCaptureKey != 'off') {
        await DesktopIntegration.setQuickCapture(controller.quickCaptureKey);
      }
    } catch (_) {
      final label =
          quickCapturePresets[controller.quickCaptureKey]?.label ?? 'shortcut';
      controller.quickCaptureError =
          'The quick note shortcut $label could not be registered; another app may be using it. Choose a different one in Settings.';
      controller.quickCaptureKey = 'off';
    }
    // Reminders: a periodic check also catches ones that came due while the
    // PC slept (the timer fires again on wake) or the app was closed.
    _reminderTimer?.cancel();
    if (!diagnosticMode) {
      _reminderTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_checkReminders()),
      );
    }
    if (!diagnosticMode) {
      _firstReminderTimer = Timer(
        const Duration(seconds: 3),
        () => unawaited(_checkReminders()),
      );
      unawaited(_syncReminderTask().catchError((_) {}));
    }
    StartupTiming.mark('essentialBinding');
  }

  /// Called after the main library's first frame. Repeated calls share the
  /// same restore operation; binding alone never starts a child engine.
  Future<void> restoreSession() {
    if (!supportsNoteWindows) return Future<void>.value();
    return _restoration ??= _startSession();
  }

  Future<void> _startSession() async {
    _restoring = true;
    _mainController!.reportWindowRestoreFailure(null);
    try {
      // Launchers can request a hidden initial window. Show the library before
      // synchronous child engine construction occupies the platform thread.
      await _showMainWindow();
      StartupTiming.mark('libraryShown');
      await const MethodChannel('betternotes/windows')
          .invokeMethod<void>('ready');
      await _restoreWindows();
    } catch (error) {
      _mainController!.reportWindowRestoreFailure(
        'Some note windows could not reopen. Open them from the library to retry. $error',
      );
    } finally {
      _restoring = false;
      StartupTiming.mark('restoreComplete');
      StartupTiming.report();
      _scheduleSpareRefill();
    }
  }

  Future<void> _warmSpare() =>
      _warming ??= _createSpare().whenComplete(() => _warming = null);

  Future<void> _createSpare() async {
    try {
      _idleWindow = await _createWindow(null, null);
      StartupTiming.mark('spareReady');
    } catch (_) {
      // Optional; a normal cold opening remains available.
    }
  }

  /// Creates or releases the idle editor when Fast note opening changes.
  Future<void> _applyFastOpening() async {
    await _warming;
    if (_shuttingDown) return;
    if (_mainController!.fastNoteOpening) {
      if (!_restoring && _openingNotes.isEmpty && _idleWindow == null) {
        await _warmSpare();
      }
      return;
    }
    final spare = _idleWindow;
    if (spare == null) return;
    _idleWindow = null;
    _readyWindows.remove(spare.windowId);
    _assignments[spare.windowId] = null;
    _deliveredStates.remove(spare.windowId);
    try {
      await spare.invokeMethod<void>('close').timeout(childReadyTimeout);
    } catch (_) {
      // The idle engine may already be gone.
    }
  }

  Future<dynamic> _handleMainCall(MethodCall call) async {
    final controller = _mainController!;
    final args = call.arguments;
    switch (call.method) {
      case 'ready':
        final id = args as String;
        if (_abandonedWindows.remove(id)) return null;
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
      case 'set_reminder':
        final values = Map<dynamic, dynamic>.from(args as Map);
        await controller.setReminder(
          values['noteId'] as String,
          DateTime.tryParse(values['at'] as String? ?? ''),
        );
        return _state(values['noteId'] as String);
      case 'note_revisions':
        return [
          for (final revision in await controller.revisions(args as String))
            revision.toJson(light: true),
        ];
      case 'restore_revision':
        return (await controller.restoreRevision(args as String))?.toJson();
      case 'duplicate_note':
        return (await controller.duplicate(args as String))?.toJson();
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
          if (_idleWindow == null && _mainController!.fastNoteOpening) {
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
      'reduceTransparency': controller.reduceTransparency,
      'inlineImages': controller.inlineImages,
      'alwaysShowNoteHeader': controller.alwaysShowNoteHeader,
      'availableTags': controller.availableTags,
      'imageQuality': controller.imageQuality.name,
    };
  }

  Future<void> _restoreWindows() async {
    _openIds.removeWhere((id) => !_canOpen(id));
    await _rememberOpenWindows();
    var failures = 0;
    await Future.wait([
      for (final id in _openIds.toList())
        _queueOpen(id, activate: false).catchError((Object error) {
          failures++;
        }),
    ]);
    if (failures != 0 && !_shuttingDown) {
      _mainController!.reportWindowRestoreFailure(
        '$failures note window(s) could not reopen. Open them from the library to retry.',
      );
    }
  }

  bool _canOpen(String id) {
    final note = _mainController?.noteById(id);
    return note != null && note.archivedAt == null;
  }

  Future<void> _rememberOpenWindows() {
    final snapshot = _openIds.toList();
    final operation = _rememberTail.then(
      (_) => _mainController!.store.setSetting('openNoteWindows', snapshot),
    );
    _rememberTail = operation.catchError((Object error) {});
    return operation;
  }

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
    final creation = _nativeCreateTail.then((_) async {
      final child = await StartupTiming.measure(
        'nativeCreate',
        () => WindowController.create(
          WindowConfiguration(
            arguments: jsonEncode({
              'type': 'note',
              'noteId': id,
              'parentId': _window!.windowId,
              'bounds': bounds,
            }),
            hiddenAtLaunch: true,
          ),
        ),
      );
      _assignments[child.windowId] = id;
      // The runner records child HWNDs during synchronous construction. Claim
      // before starting another create, so a timed-out hidden engine can be
      // destroyed even if its Dart method handler never came up.
      await const MethodChannel('betternotes/windows')
          .invokeMethod<void>('claimStartupWindow', child.windowId);
      return child;
    });
    _nativeCreateTail = creation.then<void>((_) {}, onError: (Object error) {});
    final child = await creation;
    try {
      if (!_readyWindows.contains(child.windowId)) {
        final waiter = _readyWaiters.putIfAbsent(
          child.windowId,
          () => Completer<void>(),
        );
        try {
          await StartupTiming.measure(
            'childReadyWait',
            () => waiter.future.timeout(childReadyTimeout),
          );
        } finally {
          _readyWaiters.remove(child.windowId);
        }
      }
      await const MethodChannel('betternotes/windows')
          .invokeMethod<void>('releaseStartupWindow', child.windowId);
      return child;
    } catch (_) {
      _abandonedWindows.add(child.windowId);
      _assignments[child.windowId] = null;
      _readyWindows.remove(child.windowId);
      _deliveredStates.remove(child.windowId);
      await const MethodChannel('betternotes/windows')
          .invokeMethod<void>('discardStartupWindow', child.windowId);
      rethrow;
    }
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
    return _queueOpen(id, activate: true);
  }

  Future<void> _queueOpen(String id, {required bool activate}) {
    if (!supportsNoteWindows || _shuttingDown) return Future<void>.value();
    final existing = _openingNotes[id];
    if (existing != null) {
      existing.activate |= activate;
      return existing.result.future;
    }
    final request = _NoteOpenRequest(
      id,
      activate: activate,
      retainOnFailure: _openIds.contains(id),
    );
    _openingNotes[id] = request;
    _pendingOpens.add(request);
    _drainOpens();
    return request.result.future;
  }

  void _drainOpens() {
    while (_activeOpens < startupConcurrency && _pendingOpens.isNotEmpty) {
      // User openings take the next available slot ahead of queued restores.
      final priority = _pendingOpens.indexWhere((request) => request.activate);
      final request = _pendingOpens.removeAt(priority < 0 ? 0 : priority);
      _activeOpens++;
      unawaited(_runOpen(request));
    }
  }

  Future<void> _runOpen(_NoteOpenRequest request) async {
    try {
      await _openNote(request);
      request.result.complete();
    } catch (error, stack) {
      request.result.completeError(error, stack);
    } finally {
      _openingNotes.remove(request.id);
      _activeOpens--;
      _drainOpens();
      _scheduleSpareRefill();
    }
  }

  Future<void> _openNote(_NoteOpenRequest request) async {
    final id = request.id;
    if (!supportsNoteWindows || _shuttingDown) return;
    if (!_canOpen(id)) {
      _openIds.remove(id);
      await _rememberOpenWindows();
      return;
    }
    await _warming;
    for (final existing in await WindowController.getAll()) {
      String? existingNoteId;
      try {
        existingNoteId = _windowNoteId(existing);
      } catch (_) {
        // Another window might use different arguments.
        continue;
      }
      if (existingNoteId != id) continue;
      if (!request.activate) {
        if (_readyWindows.contains(existing.windowId)) {
          await existing
              .invokeMethod<void>('present', false)
              .timeout(childReadyTimeout);
        }
        return;
      }
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
    if (_openIds.add(id)) await _rememberOpenWindows();
    final bounds = await _mainController!.store.getSetting<List<dynamic>>(
      'windowBounds:$id',
    );
    if (!_canOpen(id) || _shuttingDown) return;
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
          'activate': request.activate,
        });
      } else {
        final child = await _createWindow(id, bounds);
        if (_shuttingDown) {
          return; // Shutdown will flush/close this ready editor.
        }
        if (!_canOpen(id)) {
          _assignments[child.windowId] = null;
          await child
              .invokeMethod<void>('abort_startup')
              .timeout(childReadyTimeout);
          return;
        }
        final activate = request.activate;
        await child
            .invokeMethod<void>('present', activate)
            .timeout(childReadyTimeout);
        // A user may promote a restore while its presentation call is pending.
        if (!activate && request.activate) {
          await child.invokeMethod<void>('focus').timeout(childReadyTimeout);
        }
      }
      StartupTiming.markOnce('firstNoteVisible');
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
      if (!request.retainOnFailure) _openIds.remove(id);
      await _rememberOpenWindows();
      rethrow;
    }
    _scheduleSpareRefill();
  }

  /// Opening consumes the idle editor; warm a replacement shortly afterwards,
  /// off the opening path, so the next note also opens quickly.
  void _scheduleSpareRefill() {
    if (_shuttingDown ||
        _restoring ||
        _openingNotes.isNotEmpty ||
        _idleWindow != null ||
        !(_mainController?.fastNoteOpening ?? false)) {
      return;
    }
    _refillTimer?.cancel();
    _refillTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!_shuttingDown) unawaited(_applyFastOpening());
    });
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
        if (_openingNotes.isEmpty && _warming == null) {
          _deliveredStates.removeWhere((id, _) => !liveIds.contains(id));
          _assignments.removeWhere((id, _) => !liveIds.contains(id));
          _readyWindows.removeWhere((id) => !liveIds.contains(id));
        }
        for (final child in children) {
          try {
            final id = _windowNoteId(child);
            if (id == null || !_readyWindows.contains(child.windowId)) continue;
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
        case 'abort_startup':
          // A never-presented editor has no user edits to flush. Reply before
          // destroying its engine, just like closing a parked editor.
          Timer.run(() => unawaited(_destroySelf()));
          return null;
        case 'present':
          await _presentChild(call.arguments as bool? ?? true);
          return null;
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
          await _presentChild(args['activate'] as bool? ?? true);
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
      var rect = Rect.fromLTWH(
        values[0].toDouble(),
        values[1].toDouble(),
        values[2].toDouble(),
        values[3].toDouble(),
      );
      try {
        final displays = await screenRetriever.getAllDisplays();
        rect = fitToDisplays(rect, [
          for (final display in displays)
            (display.visiblePosition ?? Offset.zero) &
                (display.visibleSize ?? display.size),
        ]);
      } catch (_) {
        // Keep the remembered position if displays cannot be queried.
      }
      await windowManager.setBounds(rect);
    } else {
      await windowManager.setSize(const Size(470, 520));
      await windowManager.center();
    }
  }

  Future<void> notifyReady() async {
    if (!isNoteWindow) return;
    await WindowController.fromWindowId(_parentId!)
        .invokeMethod<void>('ready', _window!.windowId);
    // Presentation belongs to the parent after readiness is acknowledged.
  }

  Future<void> _presentChild(bool activate) async {
    if (activate) {
      await windowManager.show();
      await windowManager.focus();
    } else {
      // window_manager's Windows implementation ignores its inactive option.
      await const MethodChannel('betternotes/presentation')
          .invokeMethod<void>('showInactive');
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
      if (_mainController?.keepInTray == true && !_shuttingDown) {
        // Tray mode: closing the library hides it; Quit in the tray menu exits.
        unawaited(windowManager.hide());
        return;
      }
      unawaited(_closeMain());
    } else if (noteId == null) {
      unawaited(_destroySelf());
    } else {
      _closeRequests.value++;
    }
  }

  Future<void> _showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> quitIfNoRemindersDue(NotesController controller) async {
    if (controller.dueReminders().isNotEmpty) return;
    await controller.store.database.close();
    exit(0);
  }

  Future<void> _checkReminders() async {
    final controller = _mainController;
    if (controller == null || _shuttingDown || _checkingReminders) return;
    _checkingReminders = true;
    try {
      final due = controller.dueReminders();
      if (due.isEmpty) return;
      for (final note in due) {
        await controller.markReminderFired(note.id);
      }
      if (due.length == 1) {
        final note = due.single;
        final late =
            DateTime.now().difference(note.remindAt!.toLocal()) >
            const Duration(minutes: 2);
        _balloonNoteId = note.id;
        await DesktopIntegration.showBalloon(
          late ? 'Missed reminder' : 'Reminder',
          note.displayTitle,
        );
        await openNote(note.id);
      } else {
        _balloonNoteId = null;
        await DesktopIntegration.showBalloon(
          '${due.length} reminders',
          due.map((note) => note.displayTitle).take(3).join(', '),
        );
        await controller.setLibraryOptions(view: LibraryView.reminders);
        await _showMainWindow();
      }
    } catch (_) {
      // The next check retries anything not yet marked as shown.
    } finally {
      _checkingReminders = false;
    }
  }

  /// Keeps the Windows scheduled task in step with the reminders: it exists
  /// only while the setting is on and a reminder is waiting. Calls are queued
  /// so two changes never run PowerShell at the same time.
  Future<void> _syncReminderTask() {
    final controller = _mainController;
    if (controller == null) return Future<void>.value();
    final run = _taskTail.catchError((_) {}).then((_) async {
      final next = controller.nextReminder;
      if (!controller.reminderTaskEnabled || next == null) {
        await removeReminderTask();
      } else {
        await syncReminderTask(next);
      }
      if (controller.reminderTaskError != null) {
        controller.reminderTaskError = null;
      }
    });
    _taskTail = run;
    return run.catchError((Object error) {
      controller.reminderTaskError = 'Reminder task: $error';
      throw error;
    });
  }

  Future<void> _closeMain() async {
    if (_closing) return;
    _closing = true;
    _shuttingDown = true;
    _refillTimer?.cancel();
    _reminderTimer?.cancel();
    try {
      await Future.wait(
        _openingNotes.values
            .map(
              (request) => request.result.future.catchError((Object error) {}),
            )
            .toList(),
      );
      await _restoration;
      await _warming;
      await _nativeCreateTail;
      await _rememberTail;
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
          await dispose();
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
      // Resume pending startup work after a failed save aborts shutdown.
      if (!_diagnosticMode) {
        _reminderTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => unawaited(_checkReminders()),
        );
      }
      _restoration = null;
      unawaited(restoreSession());
    }
  }

  Future<void> quit() => _closeMain();

  /// Release timers/listeners when the owning main engine is finished.
  Future<void> dispose() async {
    _shuttingDown = true;
    _refillTimer?.cancel();
    _reminderTimer?.cancel();
    _firstReminderTimer?.cancel();
    _broadcastTimer?.cancel();
    _mainController?.removeListener(_broadcast);
    _mainController?.retryWindowRestore = null;
    windowManager.removeListener(this);
    if (supportsNoteWindows) {
      await _window!.setWindowMethodHandler(null);
      const MethodChannel('betternotes/windows').setMethodCallHandler(null);
      await windowManager.setPreventClose(false);
    }
  }

  /// Asks a note window to save. A window whose channel is no longer
  /// registered has already closed or been parked, so it holds nothing unsaved.
  Future<bool> _flushWindow(WindowController child) async {
    try {
      return await child.invokeMethod<bool>('flush') == true;
    } on WindowChannelException catch (error) {
      if (error.code == 'CHANNEL_UNREGISTERED') return true;
      rethrow;
    }
  }

  Future<void> flushChildren() async {
    for (final child in await WindowController.getAll()) {
      if (_windowNoteId(child) == null) continue;
      if (!await _flushWindow(child)) {
        throw StateError('A note did not acknowledge its save. Retry.');
      }
    }
  }

  Future<void> flushChild(String id) async {
    for (final child in await WindowController.getAll()) {
      if (_windowNoteId(child) != id) continue;
      if (!await _flushWindow(child)) {
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
