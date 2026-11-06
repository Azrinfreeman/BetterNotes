#include "flutter_accessibility_guard.h"

#include <commctrl.h>

#include <cwchar>
#include <set>

namespace {
constexpr UINT_PTR kAccessibilitySubclass = 1;
std::set<HWND> ready_views;

LRESULT CALLBACK GuardView(HWND window, UINT message, WPARAM wparam,
                           LPARAM lparam, UINT_PTR, DWORD_PTR) {
  if (message == WM_GETOBJECT && ready_views.count(window) == 0) {
    // Windows can retry a provider query. Never call the engine's delegate
    // during construction/destruction, and never disable semantics globally.
    return 0;
  }
  if (message == WM_NCDESTROY) {
    ready_views.erase(window);
    RemoveWindowSubclass(window, GuardView, kAccessibilitySubclass);
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

BOOL CALLBACK RevokeChildReadiness(HWND window, LPARAM) {
  ready_views.erase(window);
  return TRUE;
}

LRESULT CALLBACK ObserveWindowLifecycle(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HCBT_CREATEWND) {
    const auto window = reinterpret_cast<HWND>(wparam);
    wchar_t class_name[64] = {};
    GetClassNameW(window, class_name, 64);
    if (std::wcscmp(class_name, L"FLUTTERVIEW") == 0) {
      // HCBT_CREATEWND precedes WM_NCCREATE, covering queries issued from
      // inside Flutter's native constructor as well as its first messages.
      if (!SetWindowSubclass(window, GuardView, kAccessibilitySubclass, 0)) {
        return 1;  // Fail creation instead of leaving an unguarded view.
      }
    }
  } else if (code == HCBT_DESTROYWND) {
    const auto window = reinterpret_cast<HWND>(wparam);
    // Parent WM_DESTROY releases the controller before Windows destroys its
    // child HWND. Revoke descendants now, before that teardown starts.
    ready_views.erase(window);
    EnumChildWindows(window, RevokeChildReadiness, 0);
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
}
}  // namespace

FlutterAccessibilityGuard::FlutterAccessibilityGuard() {
  hook_ = SetWindowsHookExW(WH_CBT, ObserveWindowLifecycle, nullptr,
                           GetCurrentThreadId());
}

FlutterAccessibilityGuard::~FlutterAccessibilityGuard() {
  if (hook_) UnhookWindowsHookEx(hook_);
}

void MarkFlutterViewReady(HWND view) {
  DWORD_PTR unused = 0;
  if (GetWindowSubclass(view, GuardView, kAccessibilitySubclass, &unused)) {
    ready_views.insert(view);
  }
}
