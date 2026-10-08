# BetterNotes — implementation plan

**Status:** Implementation started. See [STATUS.md](STATUS.md) for verified work and remaining release steps. The architecture below records the original plan; the working app uses Sembast local storage on every platform and 20-second polling while signed in.

## Goal

Build a personal sticky-notes app that works on Windows, Android, iPhone/iPad, and the web, with the same notes available after signing in with a Google account. A shared codebase can later target macOS and Linux. The first release should match the everyday behavior of the classic Microsoft Sticky Notes experience shown in the supplied screenshot; custom features come after that baseline is working.

“Connected with a Google account” means Google handles sign-in. The notes themselves live in the app's private database and image storage, associated with that account. They do **not** automatically appear in Google Keep, Google Drive, or Microsoft Sticky Notes.

## Reference and parity boundary

The supplied screenshot shows the classic dark notes list: a `+` action, “Sticky Notes” heading, search field, newest notes first, colored top edges, a date/time label, clipped text previews, and image previews. Its contents are sample data only; they should not be copied into the app.

Microsoft's current help describes the baseline behavior below: creating and reopening notes, auto-saving edits, searching note text, colors and light/dark mode, rich-text controls, images, desktop positioning and resizing, closing without deleting, deletion confirmation, sharing on mobile, pen input where available, and keyboard shortcuts. Some features vary by platform. This plan reproduces those behaviors in BetterNotes without copying Microsoft's branding or integrating with OneNote/Outlook. [Getting started](https://support.microsoft.com/en-us/windows/apps/stickynotes/get-started-with-sticky-notes) · [Creating and formatting](https://support.microsoft.com/en-us/windows/apps/stickynotes/create-a-sticky-note) · [Deleting](https://support.microsoft.com/en-gb/windows/apps/stickynotes/delete-a-sticky-note) · [Shortcuts](https://support.microsoft.com/en-us/accessibility/windows/stickynotes/keyboard-shortcuts-for-sticky-notes)

## Release 1 features

| Area | Required behavior |
| --- | --- |
| Notes list | Create a note; show previews, image thumbnails, color, and local last-edited time; sort most recently edited first; open existing notes; search all note text; clear search. |
| Editor | Edit text with immediate local save and background sync; bold, italic, underline, strikethrough, and bulleted lists; undo/redo; preserve formatting across devices. No font-family or font-size control in the parity release. |
| Images | Add from files/gallery, paste from clipboard on desktop/web, capture from camera where available, preview full size, and remove an image without deleting the note. |
| Ink | Draw or write with touch/stylus where supported; keep strokes attached to the note and synced. A mouse can draw on desktop. |
| Colors and theme | Change each note's color; app-wide light, dark, and system modes; readable note surfaces in either mode. |
| Windows desktop | Separate movable and resizable note windows plus a notes-list window; remember which notes are open and restore their window bounds locally; close a note window without deleting its note; taskbar access and a quick “new note” action. |
| Mobile and web | Responsive notes list and full-screen editor; touch-friendly controls and OS share sheet where available. Floating desktop-style windows are not expected on phones. |
| Delete | Delete from list or open note; optional “confirm before deleting” setting, on by default. Closing a note must never delete it. Deleted notes disappear from every signed-in device. |
| Accounts and sync | Google sign-in/out; initial download; near-real-time changes between devices; offline editing and automatic retry; visible sync/error state. Sign-out clears the local account cache after pending work is handled. |
| Accessibility | Keyboard navigation, semantic labels, screen-reader announcements, visible focus, scalable UI text, sufficient contrast, and reduced-motion support. |

The screenshot's yellow line is a visual cue, not a fixed brand color. The first release should make the list feel equally quick to scan while using the new visual system below.

### Keyboard behavior on Windows

Match the documented shortcuts where they apply: `Ctrl+N` new, `Ctrl+F` search, `Ctrl+W` close the note window, `Ctrl+D` delete, `Ctrl+B/I/U/T` formatting, `Ctrl+Shift+L` bullets, `Ctrl+Z/Y` undo/redo, and standard copy/paste/select-all. The shortcut layer must avoid intercepting normal text editing in search and dialogs. [Microsoft shortcut reference](https://support.microsoft.com/en-us/accessibility/windows/stickynotes/keyboard-shortcuts-for-sticky-notes)

## Design direction

Use Material 3's rounded shapes, tonal surfaces, clear spacing, expressive color roles, and responsive layouts. Do not make blue the primary accent. Use a **warm plum and citrus** identity: plum for main actions and focus, coral/orange for energy, mint for positive status, and a range of soft note colors including lemon, peach, lilac, mint, and rose. Generate light and dark tonal palettes from these seeds rather than applying raw bright colors behind body text. Material 3 color roles are intended to pair surfaces and text at accessible contrast. [Material 3 color roles](https://m3.material.io/styles/color/the-color-system/key-colors-tones)

Screen sketches to implement before polishing:

1. **Notes list:** prominent “New note” action, heading, search, and vertically stacked note cards like the reference image. On wide screens, optionally use a grid while keeping newest-first order clear.
2. **Note editor:** colored header, overflow menu for color/share/delete, large text area, image/ink actions, and a compact formatting bar.
3. **Settings:** Google account, theme, deletion confirmation, sync status, help, and later export/import.
4. **Desktop note window:** minimal chrome, draggable/resizable frame, clear close control, and direct return to the notes list.

## Recommended technical approach

- **Client:** Flutter for Windows, Android, iOS, web, and later macOS/Linux. Flutter officially supports those targets, although iOS builds require a Mac. [Flutter supported platforms](https://docs.flutter.dev/resources/faq) · [Platform setup](https://docs.flutter.dev/platform-integration)
- **Authentication and cloud data:** Supabase Auth with Google OAuth, Postgres for notes/settings, Realtime or change polling for updates, and private Supabase Storage for images. Supabase documents Flutter compatibility with web, iOS, Android, macOS, and Windows, plus a Google sign-in path for Flutter desktop and web. [Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter) · [Google sign-in](https://supabase.com/docs/guides/auth/social-login/auth-google)
- **Offline data:** a local SQLite store on native devices and an equivalent local store for web. Every edit commits locally first; a sync queue sends changes when online. One repository interface hides the platform-specific storage details.
- **Desktop windows:** implement a small native Windows window-management bridge if available Flutter packages do not reliably support multiple independent note windows, geometry restoration, and taskbar actions. Validate this in an early prototype before building the full editor.
- **Structured note content:** store rich text and ink in a versioned document format; store image files separately with references from the document. Keep plain-text extraction for search and previews.

The backend choice avoids relying on Firebase Flutter's Windows SDK for production: Firebase currently labels Windows support as beta and says it is intended for local development workflows. [Firebase Flutter setup and platform matrix](https://firebase.google.com/docs/flutter/setup)

## Data and sync design

Minimum cloud entities:

- `notes`: note ID, owner ID, content document, plain-text preview/search text, color, created/updated timestamps, revision, and deletion timestamp.
- `note_assets`: image/ink asset ID, owner ID, note ID, private storage path, type, and metadata.
- `user_preferences`: owner ID, theme, delete confirmation, and future settings.
- Local-only `window_state`: device ID, note ID, window position/size/open status. A phone should not inherit a Windows screen coordinate.

Use random stable IDs generated on the client so offline notes can be created immediately. Send updates with a revision check; if two devices edit the same note at once, keep a recoverable conflict copy and show a clear resolution message instead of silently overwriting either edit. A deletion tombstone prevents an offline device from recreating a deleted note during sync. Image uploads and removals must be queued together with the note changes. Search uses the local text index and remains available offline.

Enable row-level security on every exposed table so users can access only their own rows. Use a private storage bucket with matching ownership policies. Never put a service-role key in the app, log note content, or expose images via public URLs. [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security) · [Storage access control](https://supabase.com/docs/guides/storage/security/access-control)

## Build sequence

1. **Foundation and feasibility:** create Flutter project; verify Windows, Android, and web builds; prototype Google OAuth return flow, local storage, rich-text editing, and independent Windows note windows. Record any platform limitation before committing to the full build.
2. **Visual shell:** Material 3 theme, notes list, empty state, search, note cards, editor, and settings using disposable sample notes.
3. **Core notes:** create/edit/close/delete, formatting, colors, images, ink, shortcuts, and desktop window placement.
4. **Accounts and sync:** Google sign-in, database policies, private image storage, offline queue, conflict handling, and sync feedback.
5. **Platform finish:** Android/iOS camera and share integration, web installability, accessibility, startup behavior, and release packaging.
6. **Verification:** device and browser checks, cross-account isolation checks, offline/online tests, two-device simultaneous edits, image sync, deletion propagation, and Windows window restoration.

## Acceptance checks

- A note typed on Windows appears with the same formatting, color, and images on Android, iOS, and web after signing into the same account.
- Creating/editing notes offline works; queued changes sync when connectivity returns, and errors are visible and recoverable.
- Closing a desktop note hides its window while retaining it in the list; reopening restores its content. Moving/resizing a window survives an app restart on that Windows device.
- Search finds words in note text, including formatted text, and shows newest modified notes first when search is cleared.
- Two accounts cannot read or alter each other's notes or images, including by guessing IDs or storage paths.
- Deletion confirmation obeys the setting; deleted notes stay deleted after an offline device reconnects.
- Keyboard, touch, screen reader, light theme, and dark theme paths remain usable.

## Practical dependencies and decisions

- The owner will need a Google Cloud OAuth configuration and a Supabase project when implementation reaches account sync. App IDs, redirect URLs, and secrets will be configured per platform; secrets stay out of source control.
- A Mac with Xcode is required to compile and sign the iOS app. Windows and Android can be developed from the current Windows machine. [Flutter platform setup](https://docs.flutter.dev/platform-integration)
- If the iOS app is distributed through the App Store and Google login is used as the primary account method, Apple's login-services guideline requires an equivalent privacy-preserving login option. Plan for Sign in with Apple and account linking before public iOS release. [Apple App Review Guideline 4.8](https://developer.apple.com/app-store/review/guidelines/)
- This plan assumes a personal notes app, not shared collaborative notes. The existing Microsoft Sticky Notes database and OneNote/Outlook integrations are outside the first release; import/export can be designed later.
- No paid hosting, store accounts, or public releases should be created during the planning stage.

## Later feature space

After the parity release: labels, folders, pinning, reminders, checklists, templates, attachments beyond images, better sorting, end-to-end encryption, and import/export. These are intentionally deferred so the first version remains a fast sticky-note app.
