import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/image_shrink.dart';
import '../data/note.dart';
import '../data/revision.dart';
import '../state/note_editor_store.dart';

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
  bool reduceTransparency = true;
  @override
  bool inlineImages = false;
  @override
  bool alwaysShowNoteHeader = false;
  @override
  List<String> availableTags = const [];
  @override
  ImageQuality imageQuality = ImageQuality.balanced;

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
    reduceTransparency = state['reduceTransparency'] as bool? ?? true;
    inlineImages = state['inlineImages'] as bool? ?? false;
    alwaysShowNoteHeader = state['alwaysShowNoteHeader'] as bool? ?? false;
    imageQuality =
        ImageQuality.values
            .where((value) => value.name == state['imageQuality'])
            .firstOrNull ??
        ImageQuality.balanced;
    availableTags =
        (state['availableTags'] as List?)?.cast<String>() ?? const [];
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
  Future<void> setReminder(String id, DateTime? at) => _applyResponse(
    _parent.invokeMethod<Map<dynamic, dynamic>>('set_reminder', {
      'noteId': id,
      'at': at?.toUtc().toIso8601String(),
    }),
  );

  @override
  Future<List<NoteRevision>> revisions(String noteId) async {
    final raw = await _parent.invokeMethod<List<dynamic>>(
      'note_revisions',
      noteId,
    );
    return [
      for (final value in raw ?? const [])
        NoteRevision.fromJson(Map<dynamic, dynamic>.from(value as Map)),
    ];
  }

  @override
  Future<Note?> restoreRevision(String revisionId) async {
    final raw = await _parent.invokeMethod<Map<dynamic, dynamic>>(
      'restore_revision',
      revisionId,
    );
    return raw == null ? null : Note.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<Note?> duplicate(String id) async {
    final raw = await _parent.invokeMethod<Map<dynamic, dynamic>>(
      'duplicate_note',
      id,
    );
    return raw == null ? null : Note.fromJson(Map<String, dynamic>.from(raw));
  }

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
