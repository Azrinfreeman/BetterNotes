import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

bool get canAutoBackup =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<String?> chooseBackupFolder() =>
    FileSelectorPlatform.instance.getDirectoryPathWithOptions(
      const FileDialogOptions(
        confirmButtonText: 'Use this folder',
        canCreateDirectories: true,
      ),
    );

final _autoName = RegExp(r'^BetterNotes-auto-\d{8}-\d{6}\.zip$');

String _two(int value) => value.toString().padLeft(2, '0');

/// Writes [bytes] to a new timestamped ZIP in [folder] (through a temporary
/// file, so a failed write never leaves a partial backup) and deletes the
/// oldest automatic backups beyond [keep]. Other files are never touched.
Future<String> writeAutoBackup(
  String folder,
  Uint8List bytes,
  DateTime now,
  int keep,
) async {
  final directory = Directory(folder);
  if (!await directory.exists()) {
    throw FileSystemException('The backup folder is missing', folder);
  }
  final stamp =
      '${now.year}${_two(now.month)}${_two(now.day)}-'
      '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
  final target = File(
    '$folder${Platform.pathSeparator}BetterNotes-auto-$stamp.zip',
  );
  final temporary = File('${target.path}.tmp');
  try {
    await temporary.writeAsBytes(bytes, flush: true);
    await temporary.rename(target.path);
  } catch (_) {
    if (await temporary.exists()) await temporary.delete();
    rethrow;
  }
  final existing = [
    await for (final entry in directory.list())
      if (entry is File && _autoName.hasMatch(entry.uri.pathSegments.last))
        entry,
  ]..sort((a, b) => b.path.compareTo(a.path));
  for (final old in existing.skip(keep < 1 ? 1 : keep)) {
    try {
      await old.delete();
    } catch (_) {
      // A locked old backup is retried on the next run.
    }
  }
  return target.path;
}
