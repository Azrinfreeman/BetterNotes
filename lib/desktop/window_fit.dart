import 'dart:math' as math;
import 'dart:ui';

/// Keeps a remembered window rectangle on a connected display. A window that
/// already sits fully on a display is returned unchanged; otherwise it moves
/// (and shrinks if needed) onto the display it overlaps most, or the first
/// display when it overlaps none (for example after a monitor was unplugged).
Rect fitToDisplays(Rect saved, List<Rect> displays) {
  if (displays.isEmpty) return saved;
  for (final display in displays) {
    if (_contains(display, saved)) return saved;
  }
  var target = displays.first;
  var best = 0.0;
  for (final display in displays) {
    final overlap = display.intersect(saved);
    final area = overlap.width > 0 && overlap.height > 0
        ? overlap.width * overlap.height
        : 0.0;
    if (area > best) {
      best = area;
      target = display;
    }
  }
  final width = math.min(saved.width, target.width);
  final height = math.min(saved.height, target.height);
  final left = saved.left.clamp(target.left, target.right - width).toDouble();
  final top = saved.top.clamp(target.top, target.bottom - height).toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left - 0.5 &&
    inner.top >= outer.top - 0.5 &&
    inner.right <= outer.right + 0.5 &&
    inner.bottom <= outer.bottom + 0.5;
