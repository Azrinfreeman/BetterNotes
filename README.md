# BetterNotes

BetterNotes is a colorful sticky-notes app built with Flutter. It runs locally without an account. Once connected to a Supabase project, Google sign-in associates notes with your account and syncs them through a private database and image bucket.

## Current features

- Searchable newest-first notes list, colorful note cards, light/dark/system appearance
- Rich text: selected-text colors, highlighting, font sizes, headings, bold, italic, underline, strikethrough, lists, quotes, inline code, undo, and redo
- Image selection and full-size preview, mobile camera capture, drawing with touch/stylus/mouse
- Separate movable Windows note windows that remember their position and size; paste clipboard images into notes
- Windows taskbar “New note” action, optional start with Windows, and keyboard shortcuts for note management and formatting
- Auto-save, local offline storage, deletion confirmation, and text sharing
- Local save progress and Retry, Trash with Undo/restore, complete backup/import, and text export
- Optional titles, favorites, tags, Archive, saved filters/sorting, checklists, and find-in-note
- Google sign-in and revision-based cloud sync when configured
- Windows, Android, iOS, web, macOS, and Linux Flutter project scaffolds

See [IMPLEMENTATION.md](IMPLEMENTATION.md) for the original feature plan and [STATUS.md](STATUS.md) for what still needs platform verification.

## Run locally

Install [Flutter](https://docs.flutter.dev/get-started/install) and run:

```powershell
flutter pub get
flutter run -d chrome --web-port 5173
```

For the Windows app, run `flutter run -d windows`. Notes open in their own windows; use the clipboard button in a note or `Ctrl+V` to paste an image. Closing a note window keeps the note in the list. Windows also restores notes that were open when the app last closed.

**Settings → Image placement** offers **Above text (current)**, the default, and **Within note**. Within note inserts new images at the cursor between paragraphs and moves the cursor below the image so you can continue typing. Pasting in the middle of a paragraph splits it, preserving the remaining text. The choice applies to clipboard paste and image selection, is saved locally, and updates open Windows note windows. Existing images stay where they are when you switch preferences. Inline images support preview, removal, undo, and redo. Text wrapping beside images is not included. This feature is included in the dated 20261008 portable ZIP.

A portable Windows archive is available at [dist/BetterNotes-Windows-1.0.2-20261009-portable.zip](dist/BetterNotes-Windows-1.0.2-20261009-portable.zip), with a `.zip.sha256` checksum alongside it. It includes the current organization, backup, accessibility, text styling/right-click color, and note-opening performance changes. Extract the entire archive to one folder and run `better_notes.exe`; keep the `data` folder and DLL files beside the executable. Notes are saved in your Windows app-data folder, not inside the portable archive. Right-click the running app's taskbar icon for **New note**. In **Settings**, turn on **Start with Windows** to open the app when you sign in. This is off by default and applies only to your Windows account. If you move the extracted folder later, open the app from its new location and turn the setting off and on again to update the startup path.

On Windows, `Ctrl+N` creates a note, `Ctrl+F` focuses the notes search, `Ctrl+W` closes a note window, `Ctrl+D` deletes the open note, and `Ctrl+T` toggles strikethrough while editing. The editor also supports `Ctrl+B/I/U`, `Ctrl+Shift+L` for bullets, and `Ctrl+Z/Y` for undo/redo. `Ctrl+H` opens find-in-note, with previous/next controls and `Escape` to dismiss. `F1`, note menus, and **Settings → Keyboard shortcuts** open shortcut help.

**Settings → Window buttons** lets you choose **Windows** or **BetterNotes** controls. Windows is the default. The choice is saved and applies immediately to the main window and note windows. BetterNotes provides themed minimize, maximize/restore, and close buttons; drag the title bar to move a window or double-click it to maximize/restore. These controls are included in the 1.0.2 portable archive.

The main notes list uses one header with BetterNotes window controls beside Settings. Drag the title or its empty space to move the window; double-click to maximize/restore. The Settings page also puts its window controls in its own header. These changes are included in the dated 20261008 portable ZIP.

On this machine, Flutter is installed at `C:\Users\azrin\develop\flutter` and added to the Windows user PATH. Open a new terminal before using `flutter` or `dart`. The original project-local SDK remains at `.tools/flutter/bin/flutter.bat` and is excluded from version control. Without cloud configuration, the app saves notes only on the current device/browser.

Windows note windows now have a coloured header with **New note**, **Change color** (twelve colours), **Always on top**, **More actions**, and **Close note**. It fades when the pointer leaves; hover over the top edge or focus a header button with the keyboard to reveal it. Menus and the colour picker keep it visible. With BetterNotes window buttons, this is the note's only header; drag its empty space to move the window or double-click to maximize/restore. More actions includes minimize, share, and delete. Close saves and keeps the note; pinning applies until that window closes. These controls are included in the 1.0.2 portable archive.

## Install, update, and uninstall (Windows)

**Installer.** Run `BetterNotes-Setup-<version>.exe`. It installs for the current user (no administrator needed; the wizard can switch to all users), adds a Start-menu shortcut (optional desktop shortcut), and keeps the taskbar **New note** entry, which the app registers each time it starts. Build it with Inno Setup 6 after a Windows release build: `ISCC.exe /DAppVersion=<version> installer\BetterNotes.iss` (output in `dist`).

**Updating.** Run the newer installer: it closes a running BetterNotes (which saves its notes), replaces the files in place, and offers to start it again. Settings, notes, and backups live outside the install folder and are untouched. For the portable ZIP: close BetterNotes (including its tray icon: Quit), extract the new ZIP over the old folder, and start `better_notes.exe`; if **Start with Windows** is on and you move the folder, turn it off and on again. There is no automatic update check or silent self-update.

**Uninstalling.** Use Windows Settings -> Apps (or the Start-menu uninstaller). It removes the app files and shortcuts, the **Start with Windows** entry, the **BetterNotes Reminders** scheduled task, and the diagnostic logs. **Your notes database (`%APPDATA%\dev.betternotes`) is kept** so a reinstall finds your notes; delete that folder yourself, after exporting a backup, to remove them.

**Unsigned warning.** Installers and executables here are not code-signed (no certificate has been purchased), so Windows SmartScreen may show "Windows protected your PC" on first run. Choose **More info -> Run anyway** only for a file you built or downloaded from a source you trust; a signing certificate would remove the warning.

**About and diagnostics.** **Settings -> About BetterNotes** shows the version, where the notes data and log file are, and **Copy diagnostics** (versions, counts, and settings states plus the recent error log; never note text). The log stays on the device.

## Offline recovery and backups (current source)

Delete moves notes to **Trash**, with Undo and Restore. Permanent deletion always asks for confirmation and is available for local notes; account Trash keeps the sync records needed to prevent deleted notes from reappearing. Cached images are retained conservatively for undo and recovery.

In **Settings → Backup and restore**, export a complete backup before moving devices. Backups include active notes, Archive and Trash, titles/favorites/tags, formatting, images, drawings, each note's saved version history, and supported preferences. Import validates the archive first and shows counts, then adds copies with fresh IDs. Existing notes are preserved; repeated imports create more copies. Restoring preferences is optional. Text export includes titles and active-note text, including Archive, with `[ ]`/`[x]` checklist markers; Trash is excluded.

## Organization and productivity (current source)

To change selected text color, select the text, right-click it, and choose **Change color**. Pick a swatch or enter a six-digit hex color, then choose **Apply**. The menu keeps the usual clipboard actions.

In a note, select text and open **Text style options** (the text-format icon beside Add image). Choose **Font size**, **Text color**, or **Highlight color**; colors support named swatches and custom six-digit hex values. **Apply** changes the selection, **Cancel** leaves it alone, and **Reset color** removes only that color. With no selection, styles apply to the text you type next. The panel also offers headings, numbered lists, quotes, inline code, and **Clear format**. Paragraph styles apply to the selected paragraphs. The panel scrolls in small windows; toggle the icon again to close it. Formatting is saved in notes and complete backups, and supports undo/redo. Text sharing/export remains plain text.

Use a note's **More actions → Title and tags** to set an optional title and comma-separated tags. Blank titles use the first non-empty text line, then Image note/Ink note/Empty note. Tags are trimmed, deduplicated and lowercase. **Favorite** persists independently of the Windows **Always on top** toggle.

**Notes** shows unarchived notes, with favorites first. **Favorites**, **Archive**, and **Trash** have separate views; **All active** also includes Archive. Search matches titles and body text within the selected view and tag filters. Every selected tag must match. Sorting and filters are saved on this device; **Reset filters** restores Notes/recently edited and clears tags/search. The wider-search action switches to All active while retaining selected tags and excluding Trash.

**Archive note** saves and closes its editor while retaining content and window bounds. Archived windows stay closed on startup; use **Restore from Archive** before editing again. The editor's checklist button creates native rich-text checkboxes, with undo/redo and backup support; cards show completion counts when tasks exist. **Find in note (Ctrl+H)** selects matches across formatted text, with previous/next controls and Escape to return to editing. It preserves images and formatting.

**Duplicate note** (card or editor menu) copies a note, including images, under new IDs. The **New note from template** button offers Daily tasks, Meeting, Idea, and Shopping list. **Manage tags** (in the tag filter) renames, merges, or deletes a tag across all notes, and **Title and tags** suggests existing tags. Paste a web address over selected text to make it a link; `Ctrl+Shift+V` pastes plain text. The editor's More actions menu starts with a word, character, and reading-time count. Long-press (or Ctrl+click) notes to select several for favorite, archive, Trash, color, tags, or **Export as Markdown** (a single text note saves as `.md`; otherwise a ZIP with an `images` folder). **Set reminder** (editor menu) schedules a local reminder (presets or a chosen date and time). When it is due, BetterNotes shows a Windows notification and opens the note, with Snooze and Done; the **Reminders** view lists them. Reminders stay on this device and are best effort: BetterNotes must be running, or **Settings → Remind me when BetterNotes is closed** must be on (it adds a per-user Windows scheduled task, removed when the switch is turned off), and a reminder missed while the PC was off is shown the next time the app starts. **Version history** (editor menu) lists up to 20 earlier versions of a note, saved while you edit at most every 5 minutes; **Restore as a copy** makes a new note and never overwrites the current one. History stays on this device, is included in complete backups, and is removed when the note is permanently deleted. **Save search** (shown once a search, view, sort, or tag filter is active) keeps that setup as a chip under the view tabs. **Export as PDF (to print)** in the editor menu writes an A4 PDF (Latin characters only; drawings are not included). The list icon beside Reset filters switches to a compact list. **Settings → Empty Trash automatically** permanently removes local notes after 7, 30, or 90 days in Trash; signed-in account notes are never removed this way.

Titles, favorites, tags, Archive and library preferences currently remain local. Complete backup/import transfers note metadata; the existing configured cloud schema continues syncing body content without these new organization fields. The 20261009 portable ZIP includes the three implementation phases; older ZIPs predate them. Build and package verification are recorded in `STATUS.md`.

Backups are readable, unencrypted ZIPs. Limits are 128 MB per backup, 5,000 notes, 10,000 images, 8 MB per image, and 16 MB of note JSON. Keep a complete exported ZIP; recompressing its contents is unsupported. Desktop, web, Android, and iOS support file import (mobile import is untested on devices); mobile export uses the share sheet. Tokens, other accounts, startup registration, and window bounds are excluded.

All three approved phases are implemented and included in the 20261009 portable package. Older packages are preserved; see `STATUS.md` for Windows build and package verification.

## Accessibility and recovery (current source)

Note headers reveal on keyboard focus and remain visible for touch, accessibility navigation, or reduced motion. On Windows, **Settings → Always show note header** keeps actions visible and applies to open note windows. The app follows the system high-contrast setting and supports enlarged text in light and dark themes. The library controls and lazy note cards share one scrollable layout so results remain reachable in small windows.

Shortcut help explains common commands and keyboard navigation. Formatting shortcuts apply while editing note text; typing in find inputs and dialogs keeps its normal scope. Restore actions show confirmation, and unavailable images offer **Retry image** or guidance to restore a copy from a complete backup. Live screen-reader and Windows display-scaling checks remain pending.

## Connect Google account sync

1. Create your own [Supabase project](https://supabase.com/dashboard). In its SQL Editor, run [supabase/schema.sql](supabase/schema.sql). The script creates the notes table, private image bucket, and policies that restrict data to its owner.
2. In Supabase Authentication, enable the **Google** provider. In [Google Auth Platform](https://console.cloud.google.com/auth), create the OAuth client and use the Supabase callback URL shown in the provider settings as Google's authorized redirect URI. Put the Google client ID and secret in the Supabase provider settings. Keep the Google client secret out of this app.
3. In Supabase Auth URL configuration, add these app redirect URLs for the platforms you will use:
   - `http://localhost:5173/` for local web development
   - `http://127.0.0.1:48555/auth/callback` for the Windows desktop loopback callback
   - `dev.betternotes://login-callback/` for Android and iOS
   - Your deployed web URL when you publish the web app
4. Find your **Project URL** and **publishable key** in Supabase's Connect panel. Pass them at build or run time:

```powershell
flutter run -d chrome --web-port 5173 `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Alternatively, copy [config.example.json](config.example.json) to `config.local.json`, fill in your values, and use `--dart-define-from-file=config.local.json`. The local file is ignored by Git. A publishable key is designed for client apps; **never** put a Supabase secret/service-role key in the app. The database policies are essential.

The app uses Google for account identity and Supabase for note storage. It does not write to Google Keep or Drive. A signed-out person can still use local notes; signing in moves those local notes into the signed-in account. Sign-out waits for pending sync and then clears that account's local cache.

### Platform notes

- **Windows:** The Google callback uses a local listener on `127.0.0.1:48555`. Allow the app to receive that callback if Windows prompts. Another program using the port will prevent sign-in until the port is free.
- **Android:** Install the Android SDK and accept its licenses before building. The manifest already includes internet access and the sign-in return link.
- **iOS:** Build and sign on a Mac with Xcode. The URL scheme and camera/photo descriptions are already in `Info.plist`. Public App Store distribution with Google as a primary login method will also need an equivalent login option under [Apple's login-services guideline](https://developer.apple.com/app-store/review/guidelines/); that release requirement is not implemented yet.
- **Web:** Serve over HTTPS in production. Add the deployed origin to the appropriate Supabase and Google settings. A web app manifest and branded icons are included; confirm install behavior in each target browser before release.

The included `assets/icon.png` is the source for generated Android, iOS, web, Windows, and macOS launcher icons. Regenerate them after editing it with `dart run flutter_launcher_icons`.

## Verify

```powershell
flutter analyze
flutter test
flutter build web
flutter build windows
```

The Windows build requires Windows Developer Mode because Flutter's native plugins use symbolic links. It is enabled on this machine. iOS and Android builds require their respective platform toolchains.
