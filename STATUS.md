# BetterNotes project state

Saved: **2026-10-08** · App version: **1.0.2+3**

## Resume here

- State saved for the requested initial local Git commit (2026-10-08): repository initialized on `main`; source, tests, platform projects, and project documentation are included. Generated builds, `dist` packages, SDK/cache files, and local cloud configuration remain outside version control and are preserved on disk. Updated `AGENTS.md` to reflect the repository. Reviewed the state text and confirmed the current executable and dated ZIP exist; source is unchanged, so recorded analysis, 23 passing tests, Windows build, and archive verification are reused. Live desktop interaction and configured cloud sync remain pending.
- New portable ZIP (2026-10-08): `dist/BetterNotes-Windows-1.0.2-20261008-portable.zip` packages the latest successful Windows release build, including image placement, clipboard/Backspace fixes, and the combined main header. Version remains 1.0.2+3; older packages are preserved. Updated bundled instructions and README. All 24 release files matched the new package by SHA-256; all 25 archived files matched the package by SHA-256. Archive size: 13,786,126 bytes. Reused the recorded build, clean analysis, and 23 passing tests for unchanged source; no rebuild or new desktop/cloud check. Historical references below to an unchanged ZIP describe the older undated archive.
- Requested build (2026-10-08): `flutter build windows --release` passed again using the established Flutter installation with toolchain escalation. Confirmed the release executable, Flutter DLL, and runtime data are present. Reused the recorded clean analysis and 23 passing tests for unchanged source; no code or version changes, and no portable ZIP update. Live desktop interaction and configured cloud sync remain unverified.
- Image placement (2026-10-08): Settings now offers **Above text (current)** (default) and **Within note**, saved locally and propagated to open Windows note windows. New clipboard, picker, and camera images follow the preference; existing images keep their positions. Inline images split paragraphs at the cursor, put the cursor below the image, fit the note width with proportions preserved, and support preview, removal, undo/redo, and reopening. Document image references use the existing asset cache and image list; conflict copies remap those references to their copied IDs. Removed image bytes remain cached so an open editor can undo/redo after sync. Existing clipboard, Backspace, and header edits are preserved; no version bump or portable ZIP update.
- Image-placement verification: changed Dart files formatted; static analysis passed; all 23 tests passed. Coverage includes Settings selection and restart persistence, remote preference state, both image-placement modes for Ctrl+V/button paste and ordinary text fallback, paragraph splitting, multiple images, undo/redo, saved/reopened documents, existing above-text images, conflict-reference remapping, and preview/removal at 470 px window width. Tests caught and resolved typed conflict-map and tiny-image button-layout issues; the removal test now waits for the existing auto-save delay. Windows release build succeeded, updating `build/windows/x64/runner/Release/better_notes.exe` at version 1.0.2+3. The portable ZIP is unchanged and predates this feature. Actual desktop interaction and configured cloud sync remain unverified. Flutter checks require escalation in this environment because sandbox restrictions block its toolchain discovery; direct cached Dart is sufficient for formatting.
- Backspace handling (2026-10-08): Windows note editors now bind Backspace, Shift+Backspace, and Ctrl+Backspace in Quill's own shortcut scope, using its existing character/word deletion actions for presses and repeats. Existing clipboard and main-header edits are preserved. No version bump or portable ZIP update.
- Verification: changed Dart files formatted; static analysis passed; all twelve note-flow tests passed, including repeated Backspace through an empty document, selection removal, intact emoji/combining characters, undo/redo, and saving. Windows release build succeeded and updated `build/windows/x64/runner/Release/better_notes.exe` at version 1.0.2+3. The initial ordinary repeat test also passed before the change, so the reported native desktop failure has not been reproduced; live held-key verification remains pending.
- Clipboard shortcut fix (2026-10-08): the focused Quill editor now awaits the same image-paste path used by the bottom button before falling back to ordinary text/rich-text paste. A persistent editor focus node prevents the global Ctrl+V handler from starting a second paste; the global handler still supports image paste when focus is elsewhere in the note. Existing main-header edits are preserved.
- Verification for the clipboard fix: changed Dart files formatted; final static analysis passed; all eleven tests in `test/note_flow_test.dart` passed, including Windows Ctrl+V with and without editor focus, button paste, exactly one image read/attachment per action, and text-paste fallback. Test setup simulates the clipboard and native bridge; actual Windows desktop clipboard interaction remains unverified. Windows release build succeeded, updating `build/windows/x64/runner/Release/better_notes.exe` at version 1.0.2+3 with this fix and the combined main header. The existing portable ZIP is unchanged and predates both changes.
- Combined main header (2026-10-08): with BetterNotes window buttons, the main notes list has one app header; minimize, maximize/restore, and close sit directly after Settings. The title and its empty space support dragging and double-click maximize/restore. Settings also uses its own app header for window controls, preserving route navigation and live preference changes. Native Windows controls and note-window headers keep their existing behavior.
- Verification for the combined main header: changed Dart files formatted; static analysis passed; all four focused tests in `test/window_buttons_test.dart` passed, including the main header at 470 px width, no duplicate title/caption, controls beside Settings, dragging, button calls, Settings navigation, and preference switching. The first drag test exposed a missing fullscreen response in the platform mock; it was corrected and the focused suite passed. No Windows build, packaging, or desktop interaction check was performed during that header change. The later clipboard-fix build includes it; the existing 1.0.2 portable archive still predates it.
- Windows portable release 1.0.2+3 includes the window-button setting and new note header controls. The Windows release build passed, executable product version is 1.0.2+3, and all 25 archived files passed SHA-256 comparison against the package folder. README and bundled instructions reflect this release. Only version metadata and documentation changed; previous analysis and twelve passing tests were reused for unchanged Dart source. No new desktop interaction check was performed; the pending checks below remain.
- Latest note-window change: one coloured header with New note, twelve-colour palette, always-on-top toggle, More actions (minimize/share/delete), and Close note. With BetterNotes controls this replaces the separate caption. The header fades after 700 ms away and reappears on top-edge hover or keyboard focus; menus/pickers keep it visible. Closing saves and keeps the note. Pinning lasts for the open window, and resets on reopening.
- Verification for this change: Dart formatting and analysis passed; all twelve tests passed. The new header regression also passed at the default 470×520 note-window size, covering hide/reveal, picker retention, colour selection, pin/unpin platform calls, new note, close, and absence of a duplicate caption. Windows release build succeeded. Actual desktop interaction with the new header remains to be checked; older desktop checks below predate this change. The controls are now included in the 1.0.2 portable ZIP.

- Project folder: `E:\Projects\2026Projject\BetterNotes`.
- User's goal: a personal Sticky Notes app for Windows, Android, iOS, and web, with Google account sync and a fun Material 3 color scheme. Establish the familiar Sticky Notes features before adding larger custom features.
- Current priority: complete features that work locally before connecting online services. The user chose to receive Supabase setup instructions rather than provide credentials now.
- Latest app change: **Settings → Window buttons** switches between Windows controls (default) and themed BetterNotes controls, saved locally and applied live to the main window and note windows. BetterNotes includes minimize, maximize/restore, close, drag, and title double-click. The earlier desktop check saved BetterNotes controls as the selected preference; no BetterNotes process was running at the latest state review.
- **Settings → Start with Windows** remains off. Moving the portable app requires turning this setting off and on from its new location.
- State review (2026-10-08): version matches `pubspec.yaml`; referenced implementation files and build outputs exist; the portable ZIP size matches the recorded 14,059,107 bytes; source contains twelve tests (eight note-flow and four window-button/header tests). This review inspected files only; it did not rerun analysis, tests, builds, or desktop interactions.
- Project working rules: `AGENTS.md` contains efficiency rules to reuse findings and avoid repetitive reads, checks, builds, and packaging unless necessary. Follow it when resuming.
- The requested window-button setting is implemented. Final analysis is clean; all eight existing tests and three new regression tests passed. The Windows release build and focused desktop control checks passed.

## Run and deliverables

- Current Windows package: [BetterNotes-Windows-1.0.2-20261008-portable.zip](dist/BetterNotes-Windows-1.0.2-20261008-portable.zip). Extract all files before running `better_notes.exe`. The extracted package is also available at `dist/BetterNotes-Windows-1.0.2-20261008-portable`. The older undated 1.0.2 package is preserved.
- Earlier Windows package: [BetterNotes-Windows-1.0.1-portable.zip](dist/BetterNotes-Windows-1.0.1-portable.zip), 14,059,107 bytes. This archive predates the window-button setting and was not repackaged.
- Updated Windows executable: `build/windows/x64/runner/Release/better_notes.exe`; keep the adjacent DLLs and `data` folder with it. Version is 1.0.2+3.
- Earlier web release output: `build/web`. The Windows-only startup feature did not require a new web build.
- Flutter installation and working conventions are recorded in [AGENTS.md](AGENTS.md). Setup and usage are in [README.md](README.md); [IMPLEMENTATION.md](IMPLEMENTATION.md) preserves the original plan.

## Working in source

- Flutter app for desktop, mobile, and web from one codebase
- Material 3 plum/citrus theme, light/dark/system settings
- Note list, search, create/edit/close/delete, newest-first sorting
- Rich-text formatting, image selection/camera, drawing, text sharing
- Local offline persistence; Google OAuth and Supabase sync code and schema
- Branded launcher icons for Android, iOS, web, Windows, and macOS
- Separate movable and resizable Windows note windows with local position/size and open-window restoration
- Image paste from the Windows clipboard, including Paint's bitmap format
- Windows taskbar “New note” action and editor shortcuts for creating, finding, closing, deleting, and formatting notes
- Optional per-user Windows auto start in Settings, off by default
- Saved Windows/BetterNotes window-button choice with live propagation to open note windows
- Saved image-placement choice: above-text attachments or images between rich-text paragraphs
- Named note colors for screen readers and a formatting bar that adapts to larger text

## Recorded verification

These results come from completed checks during development on 2026-10-08. Reuse them for unchanged behavior; they are not evidence of checks performed after future edits.

- Dart static analysis passes.
- Eight existing automated checks cover local persistence, image cache, deletion, search, editor save, clipboard conversion, shortcuts, and large-text layout. Three additional checks cover button preference persistence, remote note-window state, and switching controls on Settings without losing the route, including button calls and title double-click.
- After the window-button change, Dart analysis and all eleven tests passed (the existing eight and the focused three). The final Windows release build succeeded. Desktop checks confirmed the Settings selector, custom icon rendering, minimize/maximize/restore/close, and preference restoration after restart. Live note-window propagation is covered by the remote-state test; broader manual multi-window/drag testing remains pending.
- The initial incremental Windows build reused an older reduced Material icon font, leaving new icons blank. Removing only `build/flutter_assets/fonts/MaterialIcons-Regular.otf` and rebuilding regenerated the correct font (8,548 bytes). Reuse this targeted fix if new Material icons are blank in an incremental release build.
- Production web build succeeded before the Windows-only auto-start change.
- Windows debug and release builds succeed with Developer Mode enabled.
- In the native Windows app, a note opened in its own window, kept edits after closing, and restored its moved position when reopened.
- A small image copied from Paint pasted into a note and remained after closing and reopening the window.
- The Windows new-note command created a note in the running app.
- The Windows auto-start switch enabled the sign-in entry, showed the saved state after reopening Settings, and removed it again when turned off.
- Closing the main Windows app with note windows open shut down cleanly; reopening restored the windows and their saved notes.
- A portable Windows ZIP contains the release executable, Flutter assets, required DLLs, and setup instructions.

## Relevant implementation files

- `lib/ui/settings_page.dart`: appearance, deletion confirmation, account controls, and the Windows startup switch.
- `lib/desktop/window_chrome.dart`: native frame switching and shared themed app-header controls, tooltips, drag, and maximize/restore. `lib/ui/notes_home.dart` and `lib/ui/settings_page.dart` embed these controls in their app bars.
- `lib/state/notes_controller.dart`: saved window-button preference; `lib/desktop/windows_notes_io.dart` propagates it to note windows.
- `test/window_buttons_test.dart`: window-button regression checks.
- `lib/ui/note_page.dart` also owns the auto-hiding Windows note header and per-window always-on-top control; `lib/data/note.dart` defines the twelve named note colours, preserving the original six indices.
- `lib/desktop/auto_start.dart`: startup setting calls to the Windows runner.
- `windows/runner/startup_registration.cpp` and `.h`: current-user Windows Run entry, using the quoted path of the running executable.
- `windows/runner/flutter_window.cpp`: Windows command channel, including startup setting reads and writes.
- `lib/desktop/windows_notes_io.dart`: independent note windows, window restoration, and communication with the main app.
- `lib/ui/note_page.dart`: editing, formatting, images, clipboard paste, and note shortcuts.
- `test/note_flow_test.dart`: the eight existing automated checks.

## Still needed for a parity release

- Connect a real Supabase/Google project and verify OAuth and two-device sync end to end.
- Install Android SDK to build Android; use a Mac/Xcode for iOS.
- Verify the taskbar menu visually on installed/pinned Windows shortcuts and complete broader desktop release testing.
- Verify auto start after an actual Windows sign-in; the switch and persisted registration state were checked without restarting Windows.
- Validate mobile camera/share flows on devices and add the equivalent iOS login option before App Store release.
- Complete installer/signing, broader screen-reader and accessibility checks, and release testing.

The app is currently a usable **local Windows and web build** and source project, with a portable Windows archive. It is not a finished all-platform release. The cloud path is wired but unverified until the project owner connects credentials.
