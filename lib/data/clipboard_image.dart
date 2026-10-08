import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'cloud_sync.dart';

const maxNoteImageBytes = 8 * 1024 * 1024;

/// Paint and screenshots arrive as BMP on Windows. Convert them to the PNG
/// format accepted by note storage before applying the upload size limit.
Future<Uint8List> prepareClipboardImage(Uint8List bytes) async {
  if (bytes.length > 64 * 1024 * 1024) {
    throw StateError('The clipboard image is too large.');
  }
  final normalized = bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d
      ? await compute(_bmpToPng, bytes)
      : bytes;
  imageMime(normalized);
  if (normalized.length > maxNoteImageBytes) {
    throw StateError('Paste an image under 8 MB.');
  }
  return normalized;
}

Uint8List _bmpToPng(Uint8List bytes) {
  final decoded = img.decodeBmp(bytes);
  if (decoded == null) throw StateError('Could not decode clipboard image.');
  return img.encodePng(decoded);
}
