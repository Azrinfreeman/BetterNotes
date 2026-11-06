# Startup and note restoration

BetterNotes displays its library before reopening saved Windows note windows. Production restoration starts one child engine at a time and shows restored editors without moving keyboard focus. Fast note opening still keeps one reusable spare editor, but warms it after restoration instead of delaying the library. Each note has its own Flutter engine, so large sessions still reopen gradually.

Normal use needs no new setting. Close BetterNotes through Quit to save and remember the session. A failed restoration leaves the library available and displays a separate error with Retry. Retry rechecks the remembered session; opening an individual note from the library also retries it. Save errors keep their existing save-specific Retry action.

## Source and responsibilities

- `lib/main.dart`: required local initialization, first library frame, and post-rasterization restoration. The explicit diagnostic entry point uses an in-memory notebook instead of user storage or cloud.
- `lib/desktop/windows_notes_io.dart`: restore queue, per-note coalescing, interactive priority, native creation ordering, readiness deadlines, window assignments, remembered IDs, spare reuse, and shutdown. `windows_notes_stub.dart` preserves the conditional API outside desktop Windows.
- `windows/runner/flutter_window.cpp`: inactive child presentation and temporary native handle tracking. A child that never acknowledges its first frame can be destroyed while still hidden, even if its Dart handler failed to register.
- `windows/runner/flutter_accessibility_guard.cpp` and `.h`: a platform-thread hook protects Flutter view construction and destruction from premature accessibility queries. `main.cpp` installs the guard before creating controllers; `flutter_window.cpp` marks each constructed view ready. Ready views use Flutter's normal accessibility provider.
- `lib/state/notes_controller.dart` and `lib/ui/notes_home.dart`: restoration error state and the library Retry action, separate from save failures.
- `lib/data/startup_timing.dart`: optional monotonic stage timings. Aggregate measurements contain counts and durations, without note contents or account details.
- `lib/ui/review_notebook.dart`: disposable benchmark notes, including bold text, long paragraphs, and a local synthetic image. `lib/desktop/startup_benchmark_io.dart` writes diagnostic JSON only when explicitly requested.
- `test/startup_restore_test.dart` and `test/note_open_performance_test.dart`: queue, failure recovery, reuse, stale-state, and session-lifecycle regressions.
- `test/native/flutter_accessibility_guard_test.cpp`: native Windows regression for early queries, ready-provider forwarding, and parent teardown, repeated for 100 lifecycles.

All paths above are relative to the repository root. Edit these sources, not `build/`, the generated plugin registrant, or files in the package cache.

## How startup works

The main engine opens storage, loads the controller, and binds desktop channels before drawing the library. Once the first frame has rasterized, `restoreSession()` starts one owned future. Repeated calls share that future. Each remembered ID becomes a queued request; repeated requests for the same note share its result. An interactive open promotes that request and takes the next available slot.

Native engine creation runs on the Windows platform thread and is serialized through `_nativeCreateTail`. The production queue waits for that child to become ready before starting the next engine. The diagnostic-only two-slot override supports performance comparisons after engine or plugin changes. Each child reports readiness without showing itself. The parent then requests presentation, with activation only for interactive opens.

Native stress testing exposed a crash in Flutter's `OnUpdateSemanticsEnabled` with both startup limits. The engine's source forwards that callback to a view delegate without a null check. The app-owned accessibility guard intercepts `WM_GETOBJECT` only while a `FLUTTERVIEW` is under construction or teardown. It forwards queries after controller construction, and revokes readiness before a parent destroys the controller. It uses documented Windows hooks and subclassing; neither the Flutter SDK nor the package cache needs this guard copied into it. Keep the guard alive for the platform message loop and retain both main-view and child-view readiness calls when changing controller setup.

The runner claims child window handles in creation order until readiness succeeds. If readiness times out, it discards the hidden native window and the coordinator releases that assignment. Late readiness cannot revive the failed assignment. Native creation itself is synchronous and cannot be cancelled by a Dart timeout; a completely blocked native create remains a platform limitation.

Remembered IDs use an ordered persistence chain. Failed restore IDs and work not attempted before shutdown remain remembered. Missing, deleted, and archived IDs are removed. Shutdown stops new queue work, waits for in-flight startup, flushes editors, and closes windows. A save failure keeps the app open.

## Change a startup limit

To allow more time for a slow child, change `childReadyTimeout` from `Duration(seconds: 15)` to `Duration(seconds: 20)` in `DesktopCoordinator` in `lib/desktop/windows_notes_io.dart`. Rebuild and run the timeout regression with its shorter test override. A child that never acknowledges readiness should now wait up to 20 seconds before cleanup; successful children should behave the same. This cannot interrupt native engine creation, which is synchronous.

`_startupConcurrency` defaults to one. The setter permits an explicit diagnostic override of two; use repeat-launch measurements before changing the default. Native construction is serialized in either mode, so extra slots do not guarantee faster restoration. The spare refill delay remains 1,500 milliseconds in `_scheduleSpareRefill()`, with lifecycle and preference checks before creating an idle engine.

## Build, test, and measure

Use the existing Flutter SDK. On the current machine it is `.tools/flutter`; `STATUS.md` records the machine-specific Git safe-directory workaround. From the repository root in PowerShell:

```powershell
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = '*'
./.tools/flutter/bin/flutter.bat analyze --no-pub lib test
./.tools/flutter/bin/flutter.bat test --no-pub test/startup_restore_test.dart test/note_open_performance_test.dart
./.tools/flutter/bin/flutter.bat test --no-pub
./.tools/flutter/bin/flutter.bat build windows --release --no-pub
```

The native guard test uses the existing Visual Studio CMake installation. On this machine:

```powershell
$cmake = 'C:/Program Files/Microsoft Visual Studio/18/Community/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
& $cmake -S test/native -B build/native-startup-tests -G 'Visual Studio 18 2026' -A x64
& $cmake --build build/native-startup-tests --config Release
./build/native-startup-tests/Release/flutter_accessibility_guard_test.exe
```

Expected output: `100 construction / accessible-ready / parent-teardown cycles passed.` On another machine, use its installed CMake executable and Visual Studio generator. This test checks Win32 lifecycle behavior with a small fake view; it does not substitute for a screen-reader check of the real app.

For a repeatable native benchmark, after building:

```powershell
./scripts/benchmark-startup.ps1 -Notes 10 -Runs 5 -Concurrency 1
```

The script launches visible windows because a hidden Windows startup flag can suppress the first library presentation. It starts the release executable with `--ui-review --startup-benchmark=N --benchmark-output=PATH`. This explicit combination bypasses the native single-instance redirect, uses an in-memory fixture, disables reminder-task integration, and exits through normal save/close after recording a result. It can run alongside an installed copy. Do not remove those isolation flags or benchmark against the real notes database. JSON files and a summary stay under the specified output directory. The script samples process CPU and working-set memory at restore completion, before the diagnostic app exits. This is not a steady-state memory or leak measurement; deferred spare warming can increase memory afterwards.

For interactive checks, launch the executable with the same diagnostic flags plus `--benchmark-stay-open`; close the library normally when finished. The fixture remains in memory, so do not use it for real notes.

Use `-Notes 0`, `1`, `5`, `10`, or `20` to change session size. Timings from `fixtureReady` exclude synthetic fixture construction and real database opening. `observedLaunchToResultMs` includes process launch and fixture setup, with up to roughly 100 ms polling granularity; it is not an exact launch-to-visible timestamp. `mainFirstFrame` measures the library frame callback; `mainRasterized` confirms rasterization before restoration starts, and `libraryShown` records acknowledgement of explicit library presentation. `restoreComplete` follows presentation acknowledgements; it does not prove every image is decoded or every user interaction was checked. Native creation totals are cumulative work, not an additional elapsed phase to add to restore time.

To inspect normal startup stage durations, build with `--dart-define=STARTUP_TIMING=true` and observe diagnostic output. The default build does not emit timing summaries. No note contents are included, and timing events do not synchronously append to the application log.

## Verification and limits

Static analysis, 13 focused startup/performance tests, the native 100-cycle guard regression, and the final Windows release build passed. An earlier complete suite passed 156 tests with one skip before the final cleanup-error boundary. The guarded release completed ten repeated 10-note launches, plus size checks with 0, 1, 5, and 20 notes, and exited normally.

In the five production-limit 10-note runs, the library frame median fell from 20,830 ms to 63 ms after fixture setup. Complete restoration took 20,804 ms versus the baseline's 17,607 ms: the planned 30% reduction was not achieved. The two-slot diagnostic median was slower still. Keep the earlier library and deferred warming benefits separate from full-restoration performance. The fixture excludes real storage/cloud initialization; these are warm/repeated synthetic launches, not cold-disk or owner-notebook results. `IMPLEMENTATION.md` and `STATUS.md` record timings and resource limits.

Native screenshots confirmed the library and restored editors, and their accessibility trees were exposed. Search focus was reached, but synthetic typing and later element references were inconclusive. Native editing/filtering and focus retention during restoration remain manual checks. Automated channel tests support save/session behavior; this fixture does not verify durable real-notebook restart persistence.

Keep native window edits, focus checks, bounds persistence, tray/quick capture, reminder-only launch, and save-failure recovery in the manual regression checklist when changing this code. Mocked channel tests cover scheduling and cleanup decisions but cannot prove Windows focus behavior or native destruction. Each window remains a separate Flutter engine, so restoring many windows still has a CPU and memory cost.

## Maintain this tutorial

This Markdown file is the authoritative editable source. Its HTML companion is generated by the standard-library-only exporter:

```powershell
python scripts/export-startup-tutorial.py
```

The exporter supports the headings, paragraphs, lists, inline code, and fenced code used here. Review the HTML after regeneration. PDF export is optional through the browser Print dialog; no PDF tooling was installed for this change.
