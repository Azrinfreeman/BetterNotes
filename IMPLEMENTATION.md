# BetterNotes — offline usefulness, polish, and performance plan

**Proposed on 2026-10-08. Implementation approved: proceed by phase and build Windows only after all implementation phases are finished.**

## Execution state

- Phase 3 is implemented in source: keyboard/touch-accessible desktop headers, a saved Always show note header preference propagated to note windows, reduced-motion behavior, high-contrast themes, F1/menu/Settings shortcut help, scalable cards and controls, a single scrollable library with lazy cards, and clearer restore/missing-image recovery. Note formatting and image-paste shortcuts respect editor/search/dialog focus. Optional templates, history, tray, reminders, and command palette remain unselected.
- Final Phase 3 formatting and static analysis passed; all 50 VM/widget tests passed, including eight accessibility regressions. Compact layouts at 320/470 px and 200% text passed in light/dark themes. Updated existing tests exercise the new selector layout, settled scrolling to Archive recovery, and actual editor focus for formatting. Native display scaling, screen-reader behavior, file dialogs, shutdown, and multi-window profiling remain pending live verification.

- Phase 2 is implemented in source: optional titles with automatic fallbacks, persistent favorites, normalized tags, Archive/restore, composed library views and filters, saved sorting, structured Quill checklists with derived task counts, and find-in-note (Ctrl+H, next/previous, Escape). Ctrl+F retains library search. Search keeps its input focused and scrolls to the selected document match without changing content or embed offsets.
- New metadata is additive under local schema 2, round-trips through existing schema-1 backups, and stays local until cloud columns are explicitly added. Sync acknowledgements and conflict copies retain it. Archiving awaits local/desktop editor flushes, rejects late saves, closes the note window, retains bounds, and skips startup reopening. Library filtering/order and tag lists remain cached between data/preference changes. Text exports and shares show checklist completion markers; export includes Archive and excludes Trash.

- Phase 1 is implemented in source: serialized/coalesced editor saves with local status and Retry; awaited close/lifecycle/editor flush; a two-step Windows shutdown that keeps the app open on save failure; Trash, Undo, restore, and confirmed permanent deletion of local notes; complete backup/import and text export; cached collection ordering/search text, thumbnail decode sizing, and coalesced changed-state delivery to note windows.
- The main process remains the sole database writer. Sync acknowledgements now compare/write atomically, local Trash timestamps stay outside the cloud schema, and Trash images are retained. Account Trash cannot be purged because its tombstones are required for sync; cached assets are conservatively retained for undo references even after local purge.
- Backup schema 1 uses an uncompressed ZIP with `manifest.json`, `notes.json`, and `assets/<id>`, CRC/SHA-256 integrity checks, strict paths, document/reference validation, and limits of 128 MB overall, 16 MB note JSON, 8 MB per image, 5,000 notes, and 10,000 assets. Imports validate before writes, preview counts, create fresh IDs with remapped embeds, and commit notes/assets/optional preferences in one transaction. Tokens, account ownership, startup registration, and window bounds are excluded. Archive files are readable and unencrypted.
- Desktop uses the existing native file selector; web uses browser upload/download with the same validator. Mobile export uses sharing; **mobile file import is still pending** because the existing selector has no mobile implementation. No new package versions were installed: archive, crypto, file-selector interface, and web were promoted from existing cached transitive dependencies.
- Phase 1 local schema version 1 added nullable Trash timestamps; Phase 2 schema version 2 adds metadata defaults without rewriting existing notes. Old deleted notes with surviving content remain recoverable; missing legacy image bytes cannot be reconstructed.
- Synthetic tests compare the original repeated sort/lowercase search with the cached collection at 100, 1,000, and 5,000 notes. These are debug/test collection timings, not achieved release/UI performance gates. Profile/release startup, frames, memory, one/ten native windows, native file dialogs, and real shutdown checks remain for the final build. Hardware inventory was unavailable in the sandbox.
- **All three approved implementation phases are complete; the final Windows release build passed.** Mobile import and live platform/cloud checks remain pending; optional features remain choices rather than implicit scope.
- Verification and final build outcomes are recorded in `STATUS.md`. Version stays 1.0.2+3 for this build; existing portable ZIPs are preserved and contain the earlier image-placement source. No commit or release packaging is requested.

## Recommendation

Make BetterNotes safer to trust, easier to organize, and faster with a growing collection. My recommended first batch is **reliable save feedback, Trash with restore, complete backup/import, and measured performance improvements**. Then add **titles, favorites, tags, archive, and real checklists**. These improve everyday use without needing an account or internet connection.

Keep the existing sticky-note experience, rich text, colors, image-placement preference, and separate Windows windows. Add commands mainly through note menus, a compact list filter area, and Settings rather than filling the editor with more buttons.

This section is the approved phased roadmap. The original implementation plan is preserved below as historical context; its deferred-feature list does not override these recommendations. The execution state above records what has now changed.

## Planning baseline (before Phase 1)

- `STATUS.md` records version 1.0.2+3, 23 passing tests, a successful Windows release build, and the dated portable ZIP. Those are historical results, not new checks performed for this plan. Latest live desktop interactions and configured cloud sync remain pending.
- Already present: local Sembast storage, plain-text search, rich-text editing and undo/redo, drawing, image attachments and inline images, themes, shortcuts, window restoration, always-on-top for an open window, startup preference, and window-button preferences.
- `Note` has rich-text delta, text, image IDs, ink, dates, and a deletion flag. It has no dedicated title, tags, favorite, archive state, or trash timestamp. Deletion sets `deleted: true`; the normal controller lookup and list hide it, with no restore UI.
- The editor waits 350 ms before saving and awaits persistence on its explicit close path. Save completion and failures need a clear user-facing state, including the desktop main-window shutdown path.
- The controller filters/sorts its collection on each `notes` access, and the list lowercases/searches note text on each rebuild. The grid already uses a lazy builder; keep that behavior.
- Images are base64 records in the local store. `NoteImage` already reuses its loading Future while its IDs stay unchanged, but displays `Image.memory` without a decode-size hint. Avoid proposing redundant Future caching as a new feature.
- Every controller notification currently initiates state delivery to all note windows. Measure serialization, image transfer, and notification frequency before changing the bridge.

These are code observations and candidates for improvement, not proof of a performance fault. No baseline latency or memory measurements have been collected yet.

## Prioritized features

| Priority | Feature | Benefit and proposed behavior | Relative effort |
| --- | --- | --- | --- |
| P0 | Save status and recovery | Show Saving, Saved locally, or Save failed with Retry; flush pending edits before normal close/shutdown; keep unsaved text editable after an error. | Medium |
| P0 | Trash and restore | Delete moves a note to Trash with immediate Undo. Restore rich text, images, ink, and metadata; permanent deletion is explicit. | Medium |
| P0 | Backup and import | Export a complete, versioned local archive and restore into an existing collection without overwriting notes. Offer plain-text/Markdown export separately. | Medium–large |
| P0 | Performance baseline and focused fixes | Test large collections, image-heavy notes, typing, startup, and many open Windows notes; optimize measured bottlenecks. | Medium, measurement dependent |
| P1 | Optional titles and favorites | Better scanning and a Favorites filter. Favorites sort ahead of ordinary notes and persist across restart. | Small–medium |
| P1 | Tags, archive, and filters | Multiple tags per note; archive old notes; filter by tag, color, favorite, archive, and image presence; save sort preference. | Medium |
| P1 | Real checklists | Tappable task boxes, persisted completion state, and a small completed/total summary in cards. | Medium |
| P1 | Search within a note | Find next/previous with visible matches, including long notes; keep library search separately available. | Small–medium |
| P1 | Accessibility and visual finish | Consistent focus, keyboard menus, readable text, clear empty/error states, adaptable toolbars, and screen-reader feedback. | Medium |
| P2 | Templates and duplicate | Built-in meeting, daily tasks, and idea templates; duplicate a note with fresh IDs and valid image references. | Small–medium |
| P2 | Local revision history | Bounded snapshots for recovering earlier text, beyond the open editor's undo history. | Medium–large |
| P2 | Desktop tray and quick capture | Optional tray access to create/show notes and an explicit keep-running preference; later consider a configurable global hotkey. | Medium; native Windows work |
| P2 | Local reminders | Due date, snooze, and reminder list; notifications require platform scheduling and lifecycle verification. | Large across platforms |
| Later | PDF/print and local image text recognition | Useful for sharing and searching screenshots, but introduce rendering or offline model requirements. | Large |

Relative effort is scope guidance, not a delivery-time promise. Defer folders until tags prove insufficient; defer encryption until storage, recovery, key management, and platform requirements can be designed together.

## Phase 1: trust and responsiveness

### 1. Reliable saves

- Extend `NoteEditorStore` with observable per-note local save state and an awaited flush operation. A desktop child reports Saved locally only after the main process acknowledges durable storage.
- Serialize writes per note and coalesce pending document snapshots so a slow older write cannot replace a newer edit. Keep editor focus/selection stable during status changes.
- Save state must describe local persistence independently of existing cloud indicators. Announce failures accessibly; do not show a success state while work is merely queued.
- Coordinate pending writes for explicit note close, route changes, app lifecycle transitions, and main-window shutdown. A failed normal close offers Retry or continued editing. Forced process termination cannot guarantee the last unsaved keystrokes; any crash-recovery draft design needs a documented persistence boundary.
- **Acceptance:** rapid edit then immediate close/reopen retains the final text; simulated storage failure keeps edits available and allows Retry; delayed writes finish in order; closing the main app with several edited notes awaits their saves.

### 2. Trash with Undo

- Add nullable `deletedAt`; retain the current deletion flag as the tombstone. Introduce explicit active/trash lookups so normal editing cannot accidentally revive a deleted note.
- Add a Trash view with preview, restore, and permanent-delete commands. Restoring keeps the original ID when safe, clears deletion state, and updates the note revision/dirty handling consistently.
- Start with manual permanent deletion, no automatic expiry. Keep assets while notes are in Trash. Old deleted records without a timestamp remain recoverable if their data is present; do not invent an original deletion time.
- Undo and Trash restore refresh the list and open-window state. Late editor writes must not silently undo deletion or restoration.
- Permanent deletion needs confirmation regardless of the normal deletion-confirmation preference. Asset cleanup must account for active notes, Trash, undo history, revision history, and future sync references; an empty Trash is not permission to remove every unused-looking image.
- **Acceptance:** restore text, formatting, ink, both image modes, and metadata after restart; Undo works with an open desktop note; late saves cannot resurrect a deleted note; permanent deletion removes only eligible local content.

### 3. Backup and safe import

- Add Settings → Backup and restore with user-selected export/import locations. Back up the current local owner collection, including Trash, rich-text deltas, image bytes, ink, metadata, and supported preferences. Exclude tokens, credentials, other owners' notes, startup registration, and device window bounds.
- Use a documented versioned archive containing a manifest, note JSON, asset files, and integrity hashes. Evaluate available archive/file-picker capabilities during implementation; add dependencies only when existing tools cannot meet the requirement.
- Validate format version, asset references, hashes, rich-text data, entry paths, counts, and size limits before writing. Reject path traversal and oversized/corrupt input with an actionable message.
- Show a preview of note/asset counts and warnings. Default to importing copies with fresh note/asset IDs, remapped inline embeds, and the current owner ID. Preserve existing notes; repeated imports may create duplicates and should make that clear.
- Commit imported data atomically, or stage it with a rollback strategy before exposing it to the collection. A failed import must leave existing notes and assets intact.
- Text/Markdown export is a convenience format; only the complete archive promises restoration of rich text, images, ink, and metadata. Document that exports contain readable personal data; automatic backups and backup encryption are separate later decisions.
- **Acceptance:** export/import round trip for every supported content type; duplicate IDs and mixed legacy/inline images import safely; a truncated archive or missing asset changes nothing; Windows file cancellation is harmless, and browser download/upload follows the same validation rules.

### 4. Profile, then optimize

- Measure Windows using profile mode for frame/rebuild investigation and release mode for startup/user-visible timing. Use the browser's performance tools for web; Flutter DevTools does not connect to web profile mode. Use synthetic notes rather than personal content. [Flutter profiling](https://docs.flutter.dev/perf/ui-performance)
- Compare 100, 1,000, and 5,000 notes; text-only and image-heavy collections; one and ten open note windows; long rich-text notes; repeated window open/close. Record hardware, build mode, data volume, cold/warm startup, input latency, frame times, memory, and bridge traffic.
- Cache the sorted visible collection and normalized search text when affected data changes. Debounce library search only if measurement shows it helps; retain immediate clear-search behavior and avoid stale results.
- Limit UI rebuilds to affected notes/status consumers. Deliver changed-note state to the relevant window and preference updates to all affected windows; coalesce broadcasts and discard stale responses. Preserve the main process as the sole database writer.
- Decode thumbnails near their displayed pixel size, accounting for display scale. Keep full-resolution originals for preview/export, and use bounded caches for decoded bytes and pending reads. Decode-size hints reduce image memory cost; verify behavior on each target. [Flutter Image API](https://api.flutter.dev/flutter/widgets/Image-class.html)
- Retain the existing lazy grid. Avoid expensive work during widget build; use background processing for large archive/image operations only where supported and justified by profiling. [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices)
- Keep Sembast initially. Consider file-backed original assets, thumbnail files, paging, or another storage engine only if measured memory/I/O shows a need; any later migration must be resumable and preserve the existing database until validation succeeds.
- **Provisional targets to validate against baseline:** at 1,000 notes on the recorded reference PC, 95th-percentile search update under 150 ms and warm note opening under 200 ms; ordinary scrolling/typing generally fits the 16.7 ms frame interval at 60 Hz; no sustained memory growth after repeated open/close cycles. Large image decoding is measured separately. These are proposed gates, not achieved results.

## Phase 2: organization and everyday productivity

- Add backward-compatible defaults for `title`, `favorite`, `tags`, and `archivedAt`. Blank title falls back to the first non-empty text line, then Image note/Ink note/Empty note. Titles appear in cards and accessible window labels without adding an obligatory text field to every sticky note.
- Favorites are independent of the existing Always on top window toggle. Favorites persist as note metadata; the window toggle retains its current meaning.
- Default view shows active, unarchived notes with favorites first, then newest edited. Provide All active, Favorites, Archive, and Trash views. Search respects the selected view; offer an explicit wider search rather than silently searching Trash.
- Combine filters with AND semantics; title/body search is case-insensitive, selected tags match all chosen tags, and tag naming is trimmed and case-normalized without changing body text. Save local sort/filter preferences with a clear reset action.
- Archiving first flushes the editor and closes that note window, retaining saved bounds. Archived notes do not automatically reopen at startup. Restore them from Archive when needed.
- Checklists use structured rich-text operations. Verify the installed Quill version's checklist support before deciding on any custom embed. Preserve undo/redo, selection, exports, and coexistence with inline images; derive task counts rather than saving a second source of truth.
- Add find-in-note commands with next/previous and Escape to dismiss. Preserve the existing Ctrl+F library-search shortcut; use a distinct documented shortcut such as Ctrl+H for find-in-note after checking editor conflicts.
- **Acceptance:** old notes load with defaults; metadata survives restart, Trash restore, and backup; filters compose predictably; checklist toggles undo/redo and persist; note search finds formatted text without moving image embeds.

## Phase 3: professional finish

- Audit 470 px note windows and narrower supported layouts, large text, light/dark themes, contrast, Windows display scaling, keyboard-only operation, and screen-reader labels. Give Save failed/Restore/Undo clear announcements without announcing every keystroke.
- Make hover-hidden headers usable with keyboard focus, touch, reduced motion, and assistive technology. Consider a saved Always show note header preference if focused checks show the hiding behavior hurts discoverability.
- Add a shortcuts/help surface and a modest command palette for common actions if menus become crowded. Keep command scope clear and avoid intercepting typing in dialogs or search.
- Improve missing-image, empty-list, no-results, failed-file, and unavailable-platform messages with relevant recovery actions. Show task/tag indicators only when present; preserve readable previews and consistent spacing.
- Add templates and duplicate after metadata and backup remapping are stable. Revision history, if selected, uses bounded checkpoint snapshots, retains referenced images, and restores into a recoverable copy rather than immediately overwriting the current note.
- Treat tray and global hotkey support as Windows-specific, opt-in work. Default Close behavior stays predictable; expose Quit, flush all editors on exit, and verify hotkey conflicts and tray recovery.
- Reminders require an early feasibility check per platform. Never advertise delivery with the app closed until native scheduling is verified. For web, present an in-app reminder list unless supported background delivery is implemented and verified. Address sleep/resume, timezone changes, clock changes, duplicates, cancellation, and snooze before release.
- PDF/print, image text recognition, a full attachment manager, and app locking remain optional later work. A UI lock alone must not be described as encrypted storage.

## Data compatibility and implementation locations

| Area | Existing files and proposed changes |
| --- | --- |
| Note metadata | `lib/data/note.dart`: optional fields/defaults, copy/serialization, document validation boundaries. |
| Persistence/recovery | `lib/data/local_store.dart`: trash queries, migration version, atomic import, referenced-asset retention. Keep platform factory behavior. |
| Save and filtering | `lib/state/notes_controller.dart`, `lib/state/note_editor_store.dart`: save states/flush, ordered writes, restore/archive, cached collections and metadata commands. |
| Editor | `lib/ui/note_page.dart`: save feedback, close handling, checklist/find commands, accessible menus. |
| Collection | `lib/ui/notes_home.dart`: title/favorite previews, filters/Trash/Archive, stable item identity, thumbnail sizing. |
| Preferences | `lib/ui/settings_page.dart`: backup/import, sort/layout/help and any chosen accessibility preference. |
| Desktop bridge | `lib/desktop/windows_notes_io.dart` and relevant native runner files only where necessary: flush acknowledgements, targeted state delivery, deleted/archived window handling, optional tray/hotkey. |
| Regression coverage | Extend `test/note_flow_test.dart`, `test/image_placement_test.dart`, and `test/window_buttons_test.dart`; add focused backup/recovery coverage where existing suites do not fit. |

Add a versioned local migration and backup schema; distinguish them from the existing cloud `revision` conflict counter. Missing fields in old records use safe defaults, and malformed data is reported without erasing the database. Validate on a copy before migrating existing user data.

Although this roadmap excludes online feature work, new fields must not accidentally break the existing cloud serialization. `toRemoteJson()` currently sends local note fields apart from `dirty`; new metadata must be explicitly mapped or kept out until a corresponding cloud schema is ready. Prevent legacy remote records from erasing local-only metadata. Trash purge must retain any tombstones/assets still required by pending sync; disable purge for such records rather than risking resurrection. Configured end-to-end sync remains outside this work and must be reported as unverified.

## Delivery and verification

1. **Phase 1 first:** baseline measurement and save ordering/feedback, then Trash, backup/import, and focused performance fixes. Complete its acceptance checks before adding organizational scope.
2. **Phase 2 next:** metadata, filters/archive, checklists, and find-in-note. Agree the batch scope before implementation; approval of one batch is not approval to implement every optional feature.
3. **Phase 3 selectively:** accessibility/visual finish first, then only the chosen templates, history, desktop, or reminder features.

For each approved batch, preserve existing edits, format changed Dart files, run static analysis once after related edits settle, and run relevant existing plus meaningful regression tests. Failure-injection and round-trip tests are appropriate for saves/imports; manual keyboard, screen-reader, scaling, and desktop lifecycle checks give evidence automated mocks cannot provide. Run web checks when shared behavior changes. Per the user's instruction, defer the Windows build until all implementation phases are finished; package at the end when requested, and bump versions only for an actual release.

Record new outcomes and remaining limitations in `STATUS.md`, keeping older verification distinct. The initial proposal was checked through source/documentation review and whitespace validation; that historical documentation check does not verify the newly implemented source.

---

# Original implementation plan (preserved)

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
