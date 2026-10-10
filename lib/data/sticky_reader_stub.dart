import 'dart:typed_data';
import 'dart:io' show Directory;

import 'sticky_import.dart';

/// Windows Sticky Notes only exists on Windows.
Directory? stickyNotesFolder() => null;

class StickyNotesReader implements StickySource {
  static Future<StickyNotesReader> open([Object? folder]) async =>
      throw UnsupportedError('Sticky Notes import needs Windows.');
  @override
  Future<List<StickyNote>> notes() async => const [];
  @override
  Future<Uint8List?> media(String fileName) async => null;
  Future<void> close() async {}
}
