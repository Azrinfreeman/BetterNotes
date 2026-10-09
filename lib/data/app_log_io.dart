import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A small local-only log for crash investigation: nothing is sent anywhere
/// and note text is never written. The file rotates at 512 KB, keeping two
/// older files.
class AppLog {
  /// Rotation size; tests lower it.
  static int maxBytes = 512 * 1024;
  static const _keep = 2;
  static File? _file;

  static String? get path => _file?.path;

  /// Test hook: log into [directory] instead of the app data folder.
  static void useDirectory(Directory directory) {
    _file = File('${directory.path}${Platform.pathSeparator}betternotes.log');
  }

  static Future<void> init() async {
    if (_file != null) return;
    try {
      final base = await getApplicationSupportDirectory();
      final directory = Directory('${base.path}${Platform.pathSeparator}logs');
      await directory.create(recursive: true);
      _file = File('${directory.path}${Platform.pathSeparator}betternotes.log');
    } catch (_) {
      // Logging must never stop the app from starting.
    }
  }

  static void _rotate(File file) {
    for (var i = _keep; i >= 1; i--) {
      final older = File('${file.path}.$i');
      final newer = i == 1 ? file : File('${file.path}.${i - 1}');
      if (!newer.existsSync()) continue;
      if (older.existsSync()) older.deleteSync();
      newer.renameSync(older.path);
    }
  }

  static void write(
    String level,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    final file = _file;
    if (file == null) return;
    try {
      if (file.existsSync() && file.lengthSync() > maxBytes) _rotate(file);
      final buffer = StringBuffer(
        '${DateTime.now().toIso8601String()} [$pid] $level $message',
      );
      if (error != null) buffer.write(' | $error');
      if (stack != null) {
        buffer.write('\n${stack.toString().split('\n').take(12).join('\n')}');
      }
      buffer.writeln();
      file.writeAsStringSync(buffer.toString(), mode: FileMode.append);
    } catch (_) {
      // A full disk or locked file must not crash the app.
    }
  }

  static Future<List<String>> tail([int lines = 80]) async {
    final file = _file;
    if (file == null || !await file.exists()) return const [];
    try {
      final all = await file.readAsLines();
      return all.length <= lines ? all : all.sublist(all.length - lines);
    } catch (_) {
      return const [];
    }
  }
}
