import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/note.dart';
import '../data/revision.dart';

/// The editor's view of a note. Desktop note windows use an IPC backed
/// implementation so only the main window writes the local database.
abstract class NoteEditorStore extends ChangeNotifier {
  final Map<String, Future<void> Function()> _editors = {};

  void registerEditor(String id, Future<void> Function() flush) =>
      _editors[id] = flush;
  void unregisterEditor(String id) => _editors.remove(id);
  Future<void> flushEditor(String id) async => await _editors[id]?.call();

  /// Each callback completes only when its latest document is durable.
  Future<void> flushEditors() async {
    for (final flush in _editors.values.toList()) {
      await flush();
    }
  }

  Note? noteById(String id);
  bool get confirmDelete;
  bool get syncing;
  bool get signedIn;
  ThemeMode get themeMode;
  bool get customWindowButtons => false;
  bool get inlineImages => false;
  bool get alwaysShowNoteHeader => false;

  Future<void> save(Note note);
  Future<void> delete(Note note);
  Future<void> archive(String id, {bool archived = true}) async =>
      throw UnsupportedError('Archive unavailable.');
  List<String> get availableTags => const [];
  Future<List<NoteRevision>> revisions(String noteId) async => const [];
  Future<Note?> restoreRevision(String revisionId) async =>
      throw UnsupportedError('Version history unavailable.');
  Future<Note?> duplicate(String id) async =>
      throw UnsupportedError('Duplicate unavailable.');
  Future<void> restore(String id) async =>
      throw UnsupportedError('Restore unavailable.');
  Future<void> addImage(Note note, Uint8List bytes);
  Future<String> cacheImage(Uint8List bytes);
  Future<void> removeImage(Note note, String imageId);
  Future<Uint8List?> image(String noteId, String imageId);
}
