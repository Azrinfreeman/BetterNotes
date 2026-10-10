import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'cloud_sync.dart';
import 'image_shrink.dart';

/// Tests run image work inline: widget tests cannot wait for real isolates.
bool runImageWorkInline = false;

const maxNoteImageBytes = 8 * 1024 * 1024;
const maxSourceImageBytes = 64 * 1024 * 1024;
const downscaleThresholdBytes = 1536 * 1024;
const maxNoteImageSide = 2048;

/// Paint and screenshots arrive as BMP on Windows. Convert them to the PNG
/// format accepted by note storage before applying the upload size limit.
Future<Uint8List> prepareClipboardImage(
  Uint8List bytes, {
  ImageQuality quality = ImageQuality.balanced,
}) async {
  if (bytes.length > 64 * 1024 * 1024) {
    throw StateError('The clipboard image is too large.');
  }
  final normalized = bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d
      ? await compute(_bmpToPng, bytes)
      : bytes;
  return prepareNoteImage(normalized, quality: quality);
}

/// Validates an attached image and shrinks large photos so stored notes and
/// complete backups stay within the 8 MB per-image limit.
Future<Uint8List> prepareNoteImage(
  Uint8List bytes, {
  ImageQuality quality = ImageQuality.balanced,
}) async {
  if (bytes.length > maxSourceImageBytes) {
    throw StateError('Choose an image under 64 MB.');
  }
  final mime = imageMime(bytes);
  var result = bytes;
  if (mime != 'image/gif') {
    if (quality == ImageQuality.original) {
      if (bytes.length > downscaleThresholdBytes) {
        final smaller = await compute(_downscale, bytes);
        if (smaller != null && smaller.length < bytes.length) result = smaller;
      }
    } else {
      final request = (bytes, quality.index);
      final smaller = runImageWorkInline
          ? _shrink(request)
          : await compute(_shrink, request);
      if (smaller.length < bytes.length) result = smaller;
    }
  }
  if (result.length > maxNoteImageBytes) {
    throw StateError('The image is still over 8 MB after resizing.');
  }
  return result;
}

Uint8List _shrink((Uint8List, int) request) =>
    shrinkImage(request.$1, ImageQuality.values[request.$2]);

Uint8List? _downscale(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  final resized = longest > maxNoteImageSide
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxNoteImageSide : null,
          height: decoded.height > decoded.width ? maxNoteImageSide : null,
          interpolation: img.Interpolation.average,
        )
      : decoded;
  return resized.hasAlpha
      ? img.encodePng(resized)
      : img.encodeJpg(resized, quality: 85);
}

Uint8List _bmpToPng(Uint8List bytes) {
  final decoded = img.decodeBmp(bytes);
  if (decoded == null) throw StateError('Could not decode clipboard image.');
  return img.encodePng(decoded);
}
