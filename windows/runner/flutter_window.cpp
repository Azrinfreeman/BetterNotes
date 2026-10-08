#include "flutter_window.h"

#include <optional>

#include <flutter/standard_method_codec.h>

#include "app_commands.h"
#include "flutter/generated_plugin_registrant.h"
#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "startup_registration.h"

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

void FlutterWindow::OnDestroy() {
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
