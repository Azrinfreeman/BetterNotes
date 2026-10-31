# Paste with formatting — implementation plan

Status: **proposal only. Nothing has been changed yet.** Prepared 2026-10-31.

## The problem in plain words

When you copy formatted text from somewhere else (a web page, Word, an email) and paste it into BetterNotes, you only get plain text. The bold, italics, headings, lists and links are lost.

**Why it happens.** BetterNotes already keeps formatting when you copy and paste *between its own notes*. It does that by putting a private "BetterNotes" format on the Windows clipboard next to the plain text. Other programs don't write that private format. They write a standard one called **HTML Format** (browsers, Word, Outlook, most apps), and BetterNotes currently never reads it, so it falls back to plain text.

## What you will get

| Action | Result |
| --- | --- |
| Ctrl+V | Pastes **with formatting** (default) |
| Right-click → **Paste** | Pastes **with formatting** |
| Right-click → **Paste as plain text** (new) | Pastes text only, no formatting |
| Ctrl+Shift+V | Still pastes plain text (already works; stays the same) |
| Copy / Cut | Already keep formatting for other BetterNotes notes. Now also keep it for other apps (see below) |

Paste order of preference, first match wins:

1. Picture on the clipboard (unchanged).
2. A URL pasted over selected text becomes a link (unchanged).
3. BetterNotes' own format (unchanged, exact copy between notes).
4. **New:** HTML from another app, converted into note formatting.
5. Plain text (unchanged fallback, also used if the HTML is broken or unreadable).

## What formatting is kept

Kept: bold, italic, underline, strikethrough, headings, bullet and numbered lists, checklists where the source has them, quotes, code, links, text color and highlight, and line breaks.

Not kept on purpose (stays consistent with your note): the source's font family and font size, page backgrounds, tables (their text is kept as lines), and pictures inside the HTML (web images are not downloaded). This avoids pasted text suddenly looking out of place in your note. If you want font sizes kept as well, tell me and I'll add it.

## Copying out of BetterNotes (the other direction)

Right now BetterNotes copies plain text plus its private format. I would also write an **HTML version** to the clipboard. Then copying a bold paragraph from BetterNotes and pasting it into Word, Outlook or Gmail keeps the bold. Small addition, same native code.

## How it will be built

1. **Windows native code** (`windows/runner/note_clipboard.cpp`): add a `read_html` call that reads the standard "HTML Format" clipboard entry and returns just the HTML fragment (Windows wraps it in a small header that must be cut off). Add HTML writing to the existing copy call. Works in the main window and in note windows.
2. **Converter** (new `lib/data/html_paste.dart`): turns HTML into note formatting using the `html` and `flutter_quill_delta_from_html` packages. They are already in the project, so **no new dependency**. Strips scripts and styles, caps very large pastes, and returns nothing on any error so plain text is used instead.
3. **Paste logic** (`lib/ui/note_quill_controller.dart`): add the HTML step after BetterNotes' own format and before plain text. Existing safety checks stay: no change if the note changed while pasting, and the same undo behaviour (one Ctrl+Z undoes the whole paste).
4. **Right-click menu** (`lib/ui/note_page.dart`): the existing Paste item pastes with formatting; add **Paste as plain text** next to it, using the function Ctrl+Shift+V already calls. Add the label to `app_en.arb` and run `flutter gen-l10n`. The touch/mobile toolbar gets the same extra item.
5. **Non-Windows platforms:** keep current behaviour (BetterNotes' own format only) unless the Quill native bridge already supplies HTML there; I'll check and use it when it does.

## Tests and checks

- Unit tests for the converter: bold, italic, link, list, heading, nested tags, junk and script content, and a very large input.
- Widget tests: Ctrl+V keeps formatting from fake HTML; Paste as plain text and Ctrl+Shift+V don't; broken HTML falls back to plain text; undo reverses one paste; a URL over selected text still becomes a link; BetterNotes-to-BetterNotes copy still wins over HTML.
- The existing clipboard tests (`clipboard_resize` etc.) must still pass.
- Native Windows check with real clipboard data: put real HTML on the clipboard through Windows, paste, and confirm the stored formatting (the earlier `tools/clipboard_smoke.dart` approach).
- Manual checks for you after the build: copy from a web page, from Word, and from Outlook, and paste normally and as plain text.

## Risks

- Programs differ in the HTML they produce, especially Word. The converter will be forgiving and fall back to plain text, but the first pass may need tuning against what you really copy.
- Pasted pictures from web pages are not supported (only pictures copied as images, as today).
- Verification here covers automated tests and a native clipboard check. I can't click through Word or your browser, so those need your quick confirmation.

## Order of work

1. Native HTML read/write. 2. Converter and its tests. 3. Paste logic. 4. Right-click item and label. 5. Format, analyze, run the clipboard and note tests, build Windows once. 6. Update `STATUS.md`.

No version bump or packaging until you ask.
