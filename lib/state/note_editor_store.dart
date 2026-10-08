import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/note.dart';

/// The editor's view of a note. Desktop note windows use an IPC backed
/// implementation so only the main window writes the local database.
abstract class NoteEditorStore extends ChangeNotifier {
  Note? noteById(String id);
  bool get confirmDelete;
  bool get syncing;
  bool get signedIn;
  ThemeMode get themeMode;
  bool get customWindowButtons => false;
  bool get inlineImages => false;

  Future<void> save(Note note);
  Future<void> delete(Note note);
  Future<void> addImage(Note note, Uint8List bytes);
  Future<String> cacheImage(Uint8List bytes);
  Future<void> removeImage(Note note, String imageId);
  Future<Uint8List?> image(String noteId, String imageId);
}
