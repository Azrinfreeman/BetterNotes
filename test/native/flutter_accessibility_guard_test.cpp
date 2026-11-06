#include "../../windows/runner/flutter_accessibility_guard.h"

#include <cstdio>

namespace {
int provider_queries = 0;
int construction_queries = 0;
int teardown_queries = 0;
HWND child = nullptr;

LRESULT CALLBACK FakeView(HWND window, UINT message, WPARAM wparam,
                          LPARAM lparam) {
  if (message == WM_CREATE) {
    construction_queries = static_cast<int>(
        SendMessageW(window, WM_GETOBJECT, 0, OBJID_CLIENT));
  }
  if (message == WM_GETOBJECT) {
    ++provider_queries;
    return 42;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

LRESULT CALLBACK FakeParent(HWND window, UINT message, WPARAM wparam,
                            LPARAM lparam) {
  if (message == WM_DESTROY) {
    teardown_queries = static_cast<int>(
        SendMessageW(child, WM_GETOBJECT, 0, OBJID_CLIENT));
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

bool Require(bool condition, const char* message) {
  if (!condition) std::fprintf(stderr, "%s\n", message);
  return condition;
}
}  // namespace

int main() {
  FlutterAccessibilityGuard guard;
  if (!Require(guard.installed(), "Could not install lifecycle hook")) return 1;
  WNDCLASSW view_class = {};
  view_class.lpfnWndProc = FakeView;
  view_class.hInstance = GetModuleHandleW(nullptr);
  view_class.lpszClassName = L"FLUTTERVIEW";
  if (!RegisterClassW(&view_class)) return 1;
  WNDCLASSW parent_class = view_class;
  parent_class.lpfnWndProc = FakeParent;
  parent_class.lpszClassName = L"BetterNotesGuardTest";
  if (!RegisterClassW(&parent_class)) return 1;

  // Repeat to check removal of per-HWND readiness and subclass state.
  for (int iteration = 0; iteration < 100; ++iteration) {
    HWND parent = CreateWindowW(parent_class.lpszClassName, L"", 0, 0, 0,
                                100, 100, nullptr, nullptr,
                                parent_class.hInstance, nullptr);
    provider_queries = 0;
    child = CreateWindowW(view_class.lpszClassName, L"", WS_CHILD, 0, 0,
                           100, 100, parent, nullptr,
                           view_class.hInstance, nullptr);
    if (!Require(parent && child, "Could not create test windows")) return 1;
    if (!Require(construction_queries == 0 && provider_queries == 0,
                 "Construction queried an unattached provider")) return 1;
    MarkFlutterViewReady(child);
    if (!Require(SendMessageW(child, WM_GETOBJECT, 0, OBJID_CLIENT) == 42 &&
                     provider_queries == 1,
                 "A ready provider must remain accessible")) return 1;
    DestroyWindow(parent);
    if (!Require(teardown_queries == 0 && provider_queries == 1,
                 "Teardown queried a destroyed provider")) return 1;
  }
  std::puts("100 construction / accessible-ready / parent-teardown cycles passed.");
  return 0;
}
