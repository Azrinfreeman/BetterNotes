import 'dart:math';
import 'dart:typed_data';

import 'package:better_notes/data/clipboard_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('small images are stored unchanged', () async {
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    expect(await prepareNoteImage(png), same(png));
  });

  test('oversized photos are shrunk under the backup limit', () async {
    final random = Random(7);
    final photo = img.Image(width: 3200, height: 2400);
    for (final pixel in photo) {
      pixel
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
    }
    final source = Uint8List.fromList(img.encodeJpg(photo, quality: 98));
    expect(source.length, greaterThan(downscaleThresholdBytes));

    final result = await prepareNoteImage(source);
    final decoded = img.decodeImage(result)!;
    expect(result.length, lessThan(source.length));
    expect(result.length, lessThanOrEqualTo(maxNoteImageBytes));
    expect(decoded.width, maxNoteImageSide);
    expect(decoded.height, 1536);
  });

  test('non-image bytes are rejected', () async {
    expect(
      prepareNoteImage(Uint8List.fromList(List.filled(32, 1))),
      throwsA(anything),
    );
  });
}
