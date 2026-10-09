import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<String> _databasePath() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return '${directory.path}${Platform.pathSeparator}better_notes.db';
}

Future<Database> openLocalDatabase() async =>
    databaseFactoryIo.openDatabase(await _databasePath());

const canQuarantineLocalDatabase = true;

/// Renames an unreadable database instead of deleting it, so it can still be
/// inspected or recovered. Returns the new path, or null if none existed.
Future<String?> quarantineLocalDatabase() async {
  final path = await _databasePath();
  final file = File(path);
  if (!await file.exists()) return null;
  final target = '$path.unreadable-${DateTime.now().millisecondsSinceEpoch}';
  await file.rename(target);
  return target;
}
