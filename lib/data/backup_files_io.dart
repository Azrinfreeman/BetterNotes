import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:share_plus/share_plus.dart';

import 'backup.dart';

bool get canImportBackup =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<Uint8List?> pickBackup() async {
  final file = await FileSelectorPlatform.instance.openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'BetterNotes backup', extensions: ['zip']),
    ],
  );
  if (file == null) return null;
  if (await file.length() > maxBackupBytes) {
    throw const FormatException('Backup exceeds 128 MB.');
  }
  return file.readAsBytes();
}

Future<bool> saveBackupFile(
  Uint8List bytes,
  String name, {
  String mimeType = 'application/zip',
}) async {
  final file = XFile.fromData(bytes, name: name, mimeType: mimeType);
  if (Platform.isAndroid || Platform.isIOS) {
    final result = await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [name]),
    );
    return result.status == ShareResultStatus.success;
  }
  final location = await FileSelectorPlatform.instance.getSaveLocation(
    options: SaveDialogOptions(suggestedName: name),
  );
  if (location == null) return false;
  await file.saveTo(location.path);
  return true;
}
