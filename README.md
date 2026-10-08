# BetterNotes

BetterNotes is a colorful sticky-notes app built with Flutter. It runs locally without an account. Once connected to a Supabase project, Google sign-in associates notes with your account and syncs them through a private database and image bucket.

## Current features

- Searchable newest-first notes list, colorful note cards, light/dark/system appearance
- Rich text: bold, italic, underline, strikethrough, bullets, undo, and redo
- Image selection and full-size preview, mobile camera capture, drawing with touch/stylus/mouse
- Separate movable Windows note windows that remember their position and size; paste clipboard images into notes
- Windows taskbar “New note” action, optional start with Windows, and keyboard shortcuts for note management and formatting
- Auto-save, local offline storage, deletion confirmation, and text sharing
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

A portable Windows archive is available at `dist/BetterNotes-Windows-1.0.2-20261008-portable.zip`. Extract the entire archive to one folder and run `better_notes.exe`; keep the `data` folder and DLL files beside the executable. Notes are saved in your Windows app-data folder, not inside the portable archive. Right-click the running app's taskbar icon for **New note**. In **Settings**, turn on **Start with Windows** to open the app when you sign in. This is off by default and applies only to your Windows account. If you move the extracted folder later, open the app from its new location and turn the setting off and on again to update the startup path.

On Windows, `Ctrl+N` creates a note, `Ctrl+F` focuses the notes search, `Ctrl+W` closes a note window, `Ctrl+D` deletes the open note, and `Ctrl+T` toggles strikethrough. The editor also supports `Ctrl+B/I/U`, `Ctrl+Shift+L` for bullets, and `Ctrl+Z/Y` for undo/redo.

**Settings → Window buttons** lets you choose **Windows** or **BetterNotes** controls. Windows is the default. The choice is saved and applies immediately to the main window and note windows. BetterNotes provides themed minimize, maximize/restore, and close buttons; drag the title bar to move a window or double-click it to maximize/restore. These controls are included in the 1.0.2 portable archive.

The main notes list uses one header with BetterNotes window controls beside Settings. Drag the title or its empty space to move the window; double-click to maximize/restore. The Settings page also puts its window controls in its own header. These changes are included in the dated 20261008 portable ZIP.

On this machine, Flutter is installed at `C:\Users\azrin\develop\flutter` and added to the Windows user PATH. Open a new terminal before using `flutter` or `dart`. The original project-local SDK remains at `.tools/flutter/bin/flutter.bat` and is excluded from version control. Without cloud configuration, the app saves notes only on the current device/browser.

Windows note windows now have a coloured header with **New note**, **Change color** (twelve colours), **Always on top**, **More actions**, and **Close note**. It fades when the pointer leaves; hover over the top edge or focus a header button with the keyboard to reveal it. Menus and the colour picker keep it visible. With BetterNotes window buttons, this is the note's only header; drag its empty space to move the window or double-click to maximize/restore. More actions includes minimize, share, and delete. Close saves and keeps the note; pinning applies until that window closes. These controls are included in the 1.0.2 portable archive.

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
