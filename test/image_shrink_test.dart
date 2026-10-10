import 'dart:math' as math;
import 'dart:typed_data';

import 'package:better_notes/data/image_shrink.dart';
import 'package:better_notes/data/local_store.dart';
import 'package:better_notes/state/notes_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sembast/sembast_memory.dart';

/// A screenshot-like picture: flat colors and some "text" strokes.
Uint8List screenshot({int width = 1200, int height = 800}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(245, 245, 250));
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: width,
    y2: 60,
    color: img.ColorRgb8(121, 80, 130),
  );
  for (var row = 0; row < 14; row++) {
    img.drawLine(
      image,
      x1: 40,
      y1: 100 + row * 40,
      x2: 40 + 300 + (row * 53) % 500,
      y2: 100 + row * 40,
      color: img.ColorRgb8(40, 40, 50),
      thickness: 3,
    );
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List photo({int width = 1600, int height = 1000, bool alpha = false}) {
  final image = img.Image(
    width: width,
    height: height,
    numChannels: alpha ? 4 : 3,
  );
  final random = math.Random(3);
  for (final p in image) {
    final base = (128 + 100 * math.sin(p.x / 90) * math.cos(p.y / 70)).round();
    p
      ..r = (base + random.nextInt(14)).clamp(0, 255)
      ..g = (base ~/ 2 + p.x ~/ 20 + random.nextInt(14)).clamp(0, 255)
      ..b = (255 - base + random.nextInt(14)).clamp(0, 255);
    if (alpha) p.a = p.x < width ~/ 2 ? 255 : 90;
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test('screenshots become small reduced-color PNGs', () {
    final source = screenshot();
    final out = shrinkImage(source, ImageQuality.balanced);
    expect(out.length, lessThan(source.length * 0.8));
    expect(out[0], 0x89); // still PNG
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 1200);
    expect(decoded.height, 800);
  });

  test('photographs become JPEG and large ones are capped in size', () {
    final source = photo();
    final out = shrinkImage(source, ImageQuality.balanced);
    expect(out[0], 0xFF); // JPEG
    expect(out.length, lessThan(source.length * 0.3));
    final big = shrinkImage(
      photo(width: 2300, height: 1300),
      ImageQuality.balanced,
    );
    final decoded = img.decodeImage(big)!;
    expect(math.max(decoded.width, decoded.height), 2048);
  });

  test('the smallest profile is no larger and caps at 1600 px', () {
    final source = photo(width: 1800, height: 1100);
    final balanced = shrinkImage(source, ImageQuality.balanced);
    final smallest = shrinkImage(source, ImageQuality.smallest);
    expect(smallest.length, lessThanOrEqualTo(balanced.length));
    final decoded = img.decodeImage(smallest)!;
    expect(math.max(decoded.width, decoded.height), 1600);
  });

  test('real transparency is preserved and unused alpha is dropped', () {
    final transparent = photo(alpha: true);
    final out = shrinkImage(transparent, ImageQuality.balanced);
    final decoded = img.decodeImage(out)!;
    expect(decoded.hasAlpha, isTrue);
    expect(decoded.getPixel(decoded.width - 5, 10).a, lessThan(255));
    expect(decoded.getPixel(5, 10).a, 255);

    final opaqueRgba = img.Image(width: 300, height: 300, numChannels: 4);
    img.fill(opaqueRgba, color: img.ColorRgba8(200, 30, 30, 255));
    for (var x = 0; x < 300; x += 7) {
      img.drawLine(
        opaqueRgba,
        x1: x,
        y1: 0,
        x2: 300 - x,
        y2: 299,
        color: img.ColorRgba8(10, 10, 200, 255),
      );
    }
    final source = Uint8List.fromList(img.encodePng(opaqueRgba));
    final flatOut = shrinkImage(source, ImageQuality.balanced);
    expect(flatOut.length, lessThan(source.length));
    expect(img.decodeImage(flatOut)!.getPixel(1, 1).a, 255);
  });

  test('animated, tiny and original-quality images are left alone', () {
    final first = img.Image(width: 64, height: 64);
    img.fill(first, color: img.ColorRgb8(255, 0, 0));
    final second = img.Image(width: 64, height: 64);
    img.fill(second, color: img.ColorRgb8(0, 0, 255));
    first.addFrame(second);
    final animated = Uint8List.fromList(img.encodeGif(first));
    expect(shrinkImage(animated, ImageQuality.balanced), same(animated));

    final tiny = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    expect(shrinkImage(tiny, ImageQuality.balanced), same(tiny));

    final source = screenshot();
    expect(shrinkImage(source, ImageQuality.original), same(source));
    expect(
      shrinkImage(Uint8List.fromList([1, 2, 3]), ImageQuality.balanced),
      isNotNull,
    );
  });

  test('results never exceed the original', () {
    for (final source in [
      screenshot(width: 200, height: 150),
      photo(width: 300, height: 200),
    ]) {
      for (final quality in ImageQuality.values) {
        expect(
          shrinkImage(source, quality).length,
          lessThanOrEqualTo(source.length),
        );
      }
    }
  });

  test('stored pictures are planned and replaced in place', () async {
    final db = await databaseFactoryMemory.openDatabase('shrink-plan');
    final store = LocalStore.fromDatabase(db);
    final controller = NotesController(store, null);
    await controller.load();
    final big = screenshot();
    final tiny = Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    await store.putImage('big', big);
    await store.putImage('copy', big);
    await store.putImage('tiny', tiny);
    final progress = <int>[];
    final plan = await controller.planImageShrink(
      onProgress: (done, total) => progress.add(done),
    );
    expect(plan.total, 3);
    expect(plan.replacements.keys.toSet(), {'big', 'copy'});
    expect(plan.after, lessThan(plan.before));
    expect(progress.last, 3);
    // Planning writes nothing.
    expect(await store.getImage('big'), big);

    await controller.applyImageShrink(plan);
    expect((await store.getImage('big'))!.length, lessThan(big.length));
    expect(await store.getImage('tiny'), tiny);
    expect((await controller.planImageShrink()).replacements, isEmpty);

    await controller.setImageQuality(ImageQuality.original);
    await store.putImage('again', big);
    expect((await controller.planImageShrink()).replacements, isEmpty);
    controller.dispose();

    final reopened = NotesController(LocalStore.fromDatabase(db), null);
    await reopened.load();
    expect(reopened.imageQuality, ImageQuality.original);
    reopened.dispose();
    await db.close();
  });
}
