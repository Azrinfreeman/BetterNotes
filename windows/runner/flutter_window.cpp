#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "app_commands.h"
#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include <shellapi.h>

#include "resource.h"
#include "startup_registration.h"

namespace {
constexpr UINT kTrayIconId = 1;
constexpr int kQuickCaptureHotkeyId = 0x4E4E;
enum TrayCommand : UINT {
  kTrayNewNote = 1,
  kTrayShowNotes = 2,
  kTrayQuit = 3,
};
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  command_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "betternotes/windows",
          &flutter::StandardMethodCodec::GetInstance());
  command_channel_->SetMethodCallHandler(
      [this](const auto &call, auto result) {
        if (call.method_name() == "getAutoStart") {
          LSTATUS error = ERROR_SUCCESS;
          const auto enabled = IsAutoStartEnabled(&error);
          if (!enabled) {
            result->Error("windows_registry",
                          "Could not read Windows startup setting (" +
                              std::to_string(error) + ").");
            return;
          }
          result->Success(flutter::EncodableValue(*enabled));
          return;
        }
        if (call.method_name() == "setAutoStart") {
          const auto *enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("invalid_argument", "Expected a boolean value.");
            return;
          }
          const LSTATUS error = SetAutoStartEnabled(*enabled);
          if (error != ERROR_SUCCESS) {
            result->Error("windows_registry",
                          "Could not update Windows startup setting (" +
                              std::to_string(error) + ").");
            return;
          }
          result->Success();
          return;
        }
        if (call.method_name() == "setTray") {
          const auto *enabled = std::get_if<bool>(call.arguments());
          if (enabled == nullptr) {
            result->Error("invalid_argument", "Expected a boolean value.");
            return;
          }
          if (!SetTrayVisible(*enabled)) {
            result->Error("tray", "Windows could not add the tray icon.");
            return;
          }
          result->Success();
          return;
        }
        if (call.method_name() == "setQuickCapture") {
          const auto *values = std::get_if<flutter::EncodableList>(call.arguments());
          if (values == nullptr || values->size() != 3) {
            result->Error("invalid_argument", "Expected [enabled, modifiers, key].");
            return;
          }
          const bool enabled = std::get<bool>((*values)[0]);
          const UINT modifiers = static_cast<UINT>(std::get<int32_t>((*values)[1]));
          const UINT key = static_cast<UINT>(std::get<int32_t>((*values)[2]));
          const DWORD error = SetQuickCaptureHotkey(enabled, modifiers, key);
          if (error != ERROR_SUCCESS) {
            result->Error(error == ERROR_HOTKEY_ALREADY_REGISTERED
                              ? "hotkey_in_use"
                              : "hotkey",
                          "Windows could not register that shortcut (" +
                              std::to_string(error) + ").");
            return;
          }
          result->Success();
          return;
        }
        if (call.method_name() != "ready") {
          result->NotImplemented();
          return;
        }
        commands_ready_ = true;
        result->Success();
        if (pending_new_note_) {
          pending_new_note_ = false;
          command_channel_->InvokeMethod("newNote", nullptr);
        }
      });
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    RegisterPlugins(view_controller->engine());
  });
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::ShowMainWindow() {
  HWND hwnd = GetHandle();
  ShowWindow(hwnd, IsIconic(hwnd) ? SW_RESTORE : SW_SHOW);
  SetForegroundWindow(hwnd);
}

bool FlutterWindow::SetTrayVisible(bool visible) {
  HWND hwnd = GetHandle();
  NOTIFYICONDATAW data = {};
  data.cbSize = sizeof(data);
  data.hWnd = hwnd;
  data.uID = kTrayIconId;
  if (!visible) {
    if (tray_visible_) Shell_NotifyIconW(NIM_DELETE, &data);
    tray_visible_ = false;
    return true;
  }
  data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  data.uCallbackMessage = kBetterNotesTrayMessage;
  data.hIcon = LoadIconW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(IDI_APP_ICON));
  wcscpy_s(data.szTip, L"BetterNotes");
  if (tray_visible_) Shell_NotifyIconW(NIM_DELETE, &data);
  tray_visible_ = Shell_NotifyIconW(NIM_ADD, &data) == TRUE;
  return tray_visible_;
}

void FlutterWindow::ShowTrayMenu() {
  HWND hwnd = GetHandle();
  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) return;
  AppendMenuW(menu, MF_STRING, kTrayNewNote, L"New note");
  AppendMenuW(menu, MF_STRING, kTrayShowNotes, L"Show notes");
  AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenuW(menu, MF_STRING, kTrayQuit, L"Quit BetterNotes");
  POINT cursor;
  GetCursorPos(&cursor);
  // The menu only dismisses on an outside click when its owner is foreground.
  SetForegroundWindow(hwnd);
  const UINT command = TrackPopupMenu(
      menu, TPM_RETURNCMD | TPM_RIGHTBUTTON | TPM_NONOTIFY, cursor.x, cursor.y,
      0, hwnd, nullptr);
  PostMessageW(hwnd, WM_NULL, 0, 0);
  DestroyMenu(menu);
  if (!commands_ready_ || !command_channel_) {
    if (command == kTrayShowNotes) ShowMainWindow();
    return;
  }
  if (command == kTrayNewNote) {
    command_channel_->InvokeMethod("newNote", nullptr);
  } else if (command == kTrayShowNotes) {
    ShowMainWindow();
  } else if (command == kTrayQuit) {
    command_channel_->InvokeMethod("quit", nullptr);
  }
}

DWORD FlutterWindow::SetQuickCaptureHotkey(bool enabled, UINT modifiers,
                                           UINT key) {
  HWND hwnd = GetHandle();
  if (hotkey_registered_) {
    UnregisterHotKey(hwnd, kQuickCaptureHotkeyId);
    hotkey_registered_ = false;
  }
  if (!enabled) return ERROR_SUCCESS;
  if (!RegisterHotKey(hwnd, kQuickCaptureHotkeyId, modifiers | MOD_NOREPEAT,
                      key)) {
    return GetLastError();
  }
  hotkey_registered_ = true;
  return ERROR_SUCCESS;
}

void FlutterWindow::OnDestroy() {
  SetTrayVisible(false);
  SetQuickCaptureHotkey(false, 0, 0);
  command_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kBetterNotesActivateMessage) {
    ShowWindow(hwnd, SW_RESTORE);
    SetForegroundWindow(hwnd);
    if (wparam != 0) {
      if (commands_ready_ && command_channel_) {
        command_channel_->InvokeMethod("newNote", nullptr);
      } else {
        pending_new_note_ = true;
      }
    }
    return 0;
  }
  if (message == kBetterNotesTrayMessage) {
    switch (LOWORD(lparam)) {
      case WM_LBUTTONUP:
      case WM_LBUTTONDBLCLK:
        ShowMainWindow();
        break;
      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        ShowTrayMenu();
        break;
    }
    return 0;
  }
  if (message == WM_HOTKEY && wparam == kQuickCaptureHotkeyId) {
    if (commands_ready_ && command_channel_) {
      command_channel_->InvokeMethod("newNote", nullptr);
    }
    return 0;
  }
  if (taskbar_created_message_ != 0 && message == taskbar_created_message_ &&
      tray_visible_) {
    // Explorer restarted; its tray forgot our icon.
    tray_visible_ = false;
    SetTrayVisible(true);
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
