import 'dart:typed_data';

bool get canAutoBackup => false;

Future<String?> chooseBackupFolder() async => null;

Future<String> writeAutoBackup(
  String folder,
  Uint8List bytes,
  DateTime now,
  int keep,
) => throw UnsupportedError('Automatic backups need a desktop app.');
