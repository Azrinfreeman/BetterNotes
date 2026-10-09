#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <shobjidl.h>
#include <windows.h>

#include <algorithm>
#include "app_commands.h"
#include "flutter_window.h"
#include "jump_list.h"
#include "utils.h"

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
  HWND existing =
      FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"better_notes");
  if (existing != nullptr) {
    DWORD_PTR ignored = 0;
    const LRESULT delivered =
        SendMessageTimeoutW(existing, kBetterNotesActivateMessage,
                            new_note ? 1 : 0, 0, SMTO_ABORTIFHUNG, 3000,
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

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
