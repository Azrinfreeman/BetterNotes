import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'backup_limits.dart';

bool get canImportBackup => true;

Future<Uint8List?> pickBackup() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.zip,application/zip';
  input.style.display = 'none';
  final result = Completer<Uint8List?>();
  Future<void> readSelection() async {
    try {
      final file = input.files?.item(0);
      if (file == null) {
        result.complete(null);
        return;
      }
      if (file.size > maxBackupBytes) {
        throw const FormatException('Backup exceeds 128 MB.');
      }
      final buffer = await file.arrayBuffer().toDart;
      if (!result.isCompleted) result.complete(buffer.toDart.asUint8List());
    } catch (error, stack) {
      if (!result.isCompleted) result.completeError(error, stack);
    }
  }

  input.addEventListener(
    'change',
    ((web.Event event) {
      unawaited(readSelection());
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event event) {
      if (!result.isCompleted) result.complete(null);
    }).toJS,
  );
  web.document.body!.append(input);
  input.click();
  try {
    return await result.future;
  } finally {
    input.remove();
  }
}

Future<bool> saveBackupFile(
  Uint8List bytes,
  String name, {
  String mimeType = 'application/zip',
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body!.append(link);
  link.click();
  link.remove();
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
