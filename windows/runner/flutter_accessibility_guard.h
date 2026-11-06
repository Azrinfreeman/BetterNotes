#ifndef RUNNER_FLUTTER_ACCESSIBILITY_GUARD_H_
#define RUNNER_FLUTTER_ACCESSIBILITY_GUARD_H_

#include <windows.h>

// Flutter's FLUTTERVIEW can receive WM_GETOBJECT before its view delegate is
// attached, or while that delegate is being destroyed. Guard only those
// lifecycle gaps; a ready view retains its normal accessibility provider.
// Construct on the platform thread before creating any Flutter controllers.
class FlutterAccessibilityGuard {
 public:
  FlutterAccessibilityGuard();
  ~FlutterAccessibilityGuard();
  FlutterAccessibilityGuard(const FlutterAccessibilityGuard&) = delete;
  FlutterAccessibilityGuard& operator=(const FlutterAccessibilityGuard&) = delete;

  bool installed() const { return hook_ != nullptr; }

 private:
  HHOOK hook_ = nullptr;
};

// Call after FlutterViewController construction, on the same platform thread.
void MarkFlutterViewReady(HWND view);

#endif  // RUNNER_FLUTTER_ACCESSIBILITY_GUARD_H_
