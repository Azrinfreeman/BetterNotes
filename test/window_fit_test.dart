import 'dart:ui';

import 'package:better_notes/desktop/window_fit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const main = Rect.fromLTWH(0, 0, 1920, 1040);
  const right = Rect.fromLTWH(1920, 0, 1280, 984);

  test('a window fully on a display is unchanged', () {
    const saved = Rect.fromLTWH(300, 200, 470, 520);
    expect(fitToDisplays(saved, [main, right]), saved);
    const onRight = Rect.fromLTWH(2000, 50, 470, 520);
    expect(fitToDisplays(onRight, [main, right]), onRight);
  });

  test('a window from an unplugged monitor moves onto the remaining one', () {
    const saved = Rect.fromLTWH(2400, 300, 470, 520);
    expect(
      fitToDisplays(saved, [main]),
      const Rect.fromLTWH(1450, 300, 470, 520),
    );
    const far = Rect.fromLTWH(-3000, -500, 470, 520);
    expect(fitToDisplays(far, [main]), const Rect.fromLTWH(0, 0, 470, 520));
  });

  test(
    'a window straddling the edge is pulled inside and oversize shrinks',
    () {
      const edge = Rect.fromLTWH(1800, 900, 470, 520);
      final fitted = fitToDisplays(edge, [main]);
      expect(fitted.right, 1920);
      expect(fitted.bottom, 1040);
      const huge = Rect.fromLTWH(100, 100, 5000, 4000);
      expect(fitToDisplays(huge, [main]), main);
      expect(fitToDisplays(edge, const []), edge);
    },
  );
}
