#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shobjidl.h>
#include <windows.h>

#include <algorithm>
#include "app_commands.h"
#include "flutter_window.h"
#include "jump_list.h"
#include "utils.h"

namespace {

constexpr UINT kTrimCheckMs = 5000;
constexpr int kIdleChecksBeforeTrim = 6;    // About 30 seconds in background.
constexpr int kChecksBetweenRepeats = 60;   // Then at most every five minutes.

// Every note window is its own Flutter engine in this one process. While no
// BetterNotes window has been in the foreground for a while, move the process's
// idle pages to Windows' standby list. They fault back in cheaply on use, and
// the memory is available to other apps meanwhile.
void CALLBACK TrimWhenInBackground(HWND, UINT, UINT_PTR, DWORD) {
  static int background_checks = 0;
  DWORD foreground_process = 0;
  if (HWND foreground = ::GetForegroundWindow()) {
    ::GetWindowThreadProcessId(foreground, &foreground_process);
  }
  if (foreground_process == ::GetCurrentProcessId()) {
    background_checks = 0;
    return;
  }
  ++background_checks;
  if (background_checks == kIdleChecksBeforeTrim ||
      background_checks == kIdleChecksBeforeTrim + kChecksBetweenRepeats) {
    ::SetProcessWorkingSetSize(::GetCurrentProcess(), static_cast<SIZE_T>(-1),
                               static_cast<SIZE_T>(-1));
    if (background_checks > kIdleChecksBeforeTrim) {
      background_checks = kIdleChecksBeforeTrim;
    }
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  SetCurrentProcessExplicitAppUserModelID(kBetterNotesAppId);

  flutter::DartProject project(L"data");
  // Child engine creation runs on the Windows platform thread. Keep the main
  // Flutter UI independent of that work, as we already do for note engines.
  project.set_ui_thread_policy(flutter::UIThreadPolicy::RunOnSeparateThread);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const bool new_note =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--new-note") != command_line_arguments.end();
  const bool reminders_due =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--reminders-due") != command_line_arguments.end();
  // `--quit` (used by the installer): ask a running copy to save and exit,
  // and never start a new one.
  const bool quit_requested =
      std::find(command_line_arguments.begin(), command_line_arguments.end(),
                "--quit") != command_line_arguments.end();
  HWND existing =
      FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"better_notes");
  if (quit_requested) {
    if (existing != nullptr) {
      DWORD_PTR ignored = 0;
      SendMessageTimeoutW(existing, kBetterNotesActivateMessage, 3, 0,
                          SMTO_ABORTIFHUNG, 3000, &ignored);
    }
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }
  if (existing != nullptr) {
    DWORD_PTR ignored = 0;
    const LRESULT delivered =
        SendMessageTimeoutW(existing, kBetterNotesActivateMessage,
                            reminders_due ? 2 : (new_note ? 1 : 0), 0,
                            SMTO_ABORTIFHUNG, 3000,
                            &ignored);
    ::CoUninitialize();
    return delivered != 0 ? EXIT_SUCCESS : EXIT_FAILURE;
  }

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
  RegisterNewNoteTask();

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"better_notes", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);
  ::SetTimer(nullptr, 0, kTrimCheckMs, TrimWhenInBackground);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
