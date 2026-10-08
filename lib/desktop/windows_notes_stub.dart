import 'package:flutter/foundation.dart';

import '../state/note_editor_store.dart';
import '../state/notes_controller.dart';

Future<DesktopCoordinator> createDesktopCoordinator() async =>
    DesktopCoordinator();

class DesktopCoordinator {
  String? get noteId => null;
  bool get supportsNoteWindows => false;
  ValueListenable<int>? get closeRequests => null;
  ValueListenable<int>? get searchRequests => null;

  Future<void> bindMain(NotesController controller) async {}
  Future<void> openNote(String noteId) async {}
  Future<void> createAndOpenNote() async {}
  Future<void> focusSearch() async {}
  Future<NoteEditorStore> createRemote() async =>
      throw UnsupportedError('Desktop note windows are unavailable.');
  Future<void> closeSelf() async {}
}
