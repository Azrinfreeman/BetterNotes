import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// How hard stored images are compressed. Pictures are compressed once when
/// they are added; the original bytes are not kept.
enum ImageQuality {
  /// Near-lossless: up to 2048 px, very high quality.
  balanced,

  /// Smallest files: up to 1600 px, slightly lower quality.
  smallest,

  /// Only shrink very large pictures, as before.
  original,
}

const _largeBytes = 1536 * 1024;

class _Profile {
  const _Profile(this.maxSide, this.palettePsnr, this.jpegPsnr);
  final int maxSide;
  final double palettePsnr;
  final double jpegPsnr;
}

const _balanced = _Profile(2048, 46, 42);
const _smallest = _Profile(1600, 42, 38);

/// Entry point for `compute`: (bytes, [ImageQuality] index).
Uint8List shrinkRequest((Uint8List, int) request) =>
    shrinkImage(request.$1, ImageQuality.values[request.$2]);

/// What re-encoding every stored picture would change.
class ImageShrinkPlan {
  const ImageShrinkPlan({
    required this.total,
    required this.before,
    required this.after,
    required this.replacements,
  });

  final int total;
  final int before;
  final int after;

  /// Picture ID -> smaller bytes, only for pictures that shrink by 10% or more.
  final Map<String, Uint8List> replacements;

  int get saved => before - after;
}

/// Re-encodes [original] as the smallest of: lossless PNG, a reduced-color PNG
/// (flat graphics and screenshots), and JPEG (photos), keeping only results
/// whose PSNR against the source is above the profile's threshold. Returns
/// [original] when nothing is meaningfully smaller, for animated images, and
/// when decoding fails. Transparency is kept whenever it is really used.
Uint8List shrinkImage(Uint8List original, ImageQuality quality) {
  if (quality == ImageQuality.original) return original;
  try {
    return _shrink(original, quality);
  } catch (_) {
    // Malformed or unusual files must never block adding a picture.
    return original;
  }
}

Uint8List _shrink(Uint8List original, ImageQuality quality) {
  final profile = quality == ImageQuality.smallest ? _smallest : _balanced;
  final decoded = img.decodeImage(original);
  if (decoded == null || decoded.numFrames > 1) return original;

  var source = decoded.convert(format: img.Format.uint8, numChannels: 4);
  final hasAlpha = _usesAlpha(source);
  final longest = math.max(source.width, source.height);
  final resized = longest > profile.maxSide;
  if (resized) {
    source = img.copyResize(
      source,
      width: source.width >= source.height ? profile.maxSide : null,
      height: source.height > source.width ? profile.maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  final reference = hasAlpha ? source : _flatten(source);

  final candidates = <Uint8List>[
    Uint8List.fromList(img.encodePng(reference, level: 9)),
  ];

  if (hasAlpha) {
    final palette = _tryPalette(reference, 256, profile.palettePsnr);
    if (palette != null) candidates.add(palette);
  } else {
    final palette = _smallestPalette(reference, profile.palettePsnr);
    if (palette != null) candidates.add(palette);
    // Photos (no palette passes) and large palette results try JPEG too.
    final best = candidates.map((c) => c.length).reduce(math.min);
    if (palette == null ||
        palette.length < best ||
        palette.length > 60 * 1024) {
      final jpeg = _smallestJpeg(reference, profile.jpegPsnr);
      if (jpeg != null) {
        candidates.add(jpeg);
      } else if (palette == null) {
        // Detailed photos pass no PSNR check; plain JPEG 85 still beats a
        // lossless PNG of a photograph by a wide margin.
        candidates.add(
          Uint8List.fromList(img.encodeJpg(reference, quality: 85)),
        );
      }
    }
  }

  var best = candidates.first;
  for (final candidate in candidates) {
    if (candidate.length < best.length) best = candidate;
  }
  // Not worth re-encoding for under 5%; never return something larger.
  if (best.length < original.length * 0.95) return best;
  // Noisy photos pass no quality check. Large or oversized ones are still
  // brought down (JPEG 85, as before) so they fit the backup limits.
  if (resized || original.length > _largeBytes) {
    final fallback = hasAlpha
        ? candidates.first
        : Uint8List.fromList(img.encodeJpg(reference, quality: 85));
    if (fallback.length < original.length) return fallback;
  }
  return original;
}

bool _usesAlpha(img.Image image) {
  for (final pixel in image) {
    if (pixel.a < 255) return true;
  }
  return false;
}

img.Image _flatten(img.Image image) {
  final out = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  );
  for (final p in image) {
    out.setPixelRgb(p.x, p.y, p.r.toInt(), p.g.toInt(), p.b.toInt());
  }
  return out;
}

double _psnr(img.Image a, img.Image b) {
  if (a.width != b.width || a.height != b.height) return 0;
  final channels = math.min(a.numChannels, b.numChannels).clamp(3, 4);
  final step = math.max(1, math.sqrt(a.width * a.height / 250000).ceil());
  var sum = 0.0;
  var count = 0;
  for (var y = 0; y < a.height; y += step) {
    for (var x = 0; x < a.width; x += step) {
      final p = a.getPixel(x, y);
      final q = b.getPixel(x, y);
      for (var c = 0; c < channels; c++) {
        final d = p[c].toDouble() - q[c].toDouble();
        sum += d * d;
        count++;
      }
    }
  }
  if (count == 0 || sum == 0) return 99;
  return 10 * math.log(255 * 255 / (sum / count)) / math.ln10;
}

Uint8List? _tryPalette(img.Image reference, int colors, double threshold) {
  try {
    final encoded = Uint8List.fromList(
      img.encodePng(img.quantize(reference, numberOfColors: colors), level: 9),
    );
    final back = img.decodeImage(encoded);
    if (back == null) return null;
    final converted = back.convert(
      format: img.Format.uint8,
      numChannels: reference.numChannels,
    );
    return _psnr(reference, converted) >= threshold ? encoded : null;
  } catch (_) {
    return null;
  }
}

/// 64 colors first: if it passes, try 32; if not, try 256.
Uint8List? _smallestPalette(img.Image reference, double threshold) {
  final sixtyFour = _tryPalette(reference, 64, threshold);
  if (sixtyFour != null) {
    final thirtyTwo = _tryPalette(reference, 32, threshold);
    return thirtyTwo != null && thirtyTwo.length < sixtyFour.length
        ? thirtyTwo
        : sixtyFour;
  }
  return _tryPalette(reference, 256, threshold);
}

/// The lowest JPEG quality (smallest file) that still passes the threshold.
Uint8List? _smallestJpeg(img.Image reference, double threshold) {
  for (final quality in const [55, 65, 75, 85]) {
    final encoded = Uint8List.fromList(
      img.encodeJpg(reference, quality: quality),
    );
    final back = img.decodeImage(encoded);
    if (back != null &&
        _psnr(
              reference,
              back.convert(
                format: img.Format.uint8,
                numChannels: reference.numChannels,
              ),
            ) >=
            threshold) {
      return encoded;
    }
  }
  return null;
}
