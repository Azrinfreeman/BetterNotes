# Automatic text cleanup in notes

Status: implemented in source, 2026-10-31. Automated verification is recorded in `STATUS.md`; native Windows interaction remains unverified.

The user requested an implementation document first and clarified that “formatter” means automatic text cleanup. This file is the authoritative plan for that feature. The user subsequently authorized implementation with `proceed`.

## Intended result

Add **Clean up text…** to each note's existing actions menu. It prepares a cleaned version of the selected text, or the entire note body when nothing is selected. The user reviews the result and chooses **Apply cleanup** or **Cancel**.

Cleanup is a local, deterministic operation. It does not need an AI service, account, network connection, or new dependency. It runs only when requested; typing, opening a note, saving, and pasting continue to behave normally.

## Existing implementation

The following findings come from source inspection, not a new runtime test:

- `lib/ui/note_page.dart` owns the Quill editor, selection, note actions, autosave, caret reveal, and color dialogs. Both routed notes and desktop note windows use this editor page.
- `lib/ui/note_quill_controller.dart` extends Quill and already guards asynchronous paste against intervening document or selection changes.
- Notes store rich-text Delta operations and a plain-text projection in `lib/data/note.dart`. Image embeds refer to note-owned assets. Rebuilding a document from plain text would lose formatting and image placement.
- `lib/ui/text_style_panel.dart` already provides manual styling. This feature complements those controls.
- `test/text_style_test.dart` covers formatting, undo, save/reopen, backup, and small-window behavior. `test/large_content_test.dart` includes a 100,000-character document.
- Formatted paste already exists in `lib/data/html_paste.dart`; cleanup must not replace or rerun the HTML importer.

## Cleanup rules

These are proposed defaults, rather than additional requirements supplied by the user.

| Rule | Default | Exact behavior |
| --- | --- | --- |
| Remove trailing spaces | On | Remove ordinary ASCII spaces immediately before a paragraph-ending newline in eligible body paragraphs. |
| Reduce excess blank lines | On | Reduce two or more consecutive eligible empty paragraphs to one empty paragraph. Preserve one blank line between text paragraphs. |
| Reduce repeated spaces between words | Off | When explicitly enabled, reduce runs of ASCII spaces between non-whitespace characters on the same eligible line to one space. Preserve leading indentation. |

Every option is available in the preview and recomputes the proposed result from the original snapshot. The repeated-space option starts off each time because repeated spaces may express intentional alignment. Do not persist preferences in the first version.

An eligible paragraph has no block attributes and contains no image or other embed. Skip headings, lists, checklists, quotes, code blocks, and paragraphs with unknown block attributes. Protect inline-code spans and whitespace adjacent to them. Do not delete styled empty paragraphs; an empty paragraph carrying attributes is intentional for this purpose. Do not merge paragraphs across a protected paragraph.

Preserve ordinary leading spaces, tabs, nonbreaking spaces, Unicode whitespace, punctuation, wording, capitalization, links, inline styles, and the mandatory final Quill newline. Do not strip leading or trailing blank paragraphs at the document boundaries as a separate rule. A spaces-only paragraph may become empty after trailing-space cleanup, then participate in blank-line reduction under the same eligibility rules.

Selection limits every deletion: nothing outside the captured range may change. Use whole-paragraph context to determine eligibility, even for a partial selection. A trailing-space deletion requires the complete trailing-space run and its terminating newline to be inside the selection; blank-paragraph removal requires its complete contents and newline inside the range. Internal-space cleanup requires the full run and both neighboring characters inside the selection. Otherwise leave that candidate unchanged. With no selection, use the complete body, excluding deletion of its mandatory final newline.

This first version does not infer headings or lists, join wrapped lines, correct grammar, reindent source code, remove all styling, or clean up multiple notes at once. Those transformations need separate rules because they can change meaning or structure.

## Note workflow

1. Open **Clean up text…** from the note actions menu. Capture the note ID, document Delta, selection, and a content revision token or equivalent snapshot comparison.
2. Show **Clean up selection** or **Clean up note**, the three options, a brief count of removed spaces and blank lines, and a scrollable read-only preview using the resulting rich-text document. The original remains unchanged behind the dialog.
3. Recompute the preview when options change. Use the existing theme and image renderer so formatting and images remain recognizable. Keep preview resources separate from the live editor and dispose them on close.
4. Enable **Apply cleanup** only when a valid preview contains changes. Show **No cleanup needed** for an unchanged result. **Cancel** and Escape make no document or save changes.
5. Before applying, verify that the note still exists, remains editable, and its content and selection still match the captured state. If it changed elsewhere, disable Apply and show **The note changed. Close this preview and try again.** Never apply offsets computed from stale content.
6. Apply the prepared edits as one isolated undoable operation, map the captured selection through the deletions, restore editor focus, and let the existing autosave path persist the result. One Undo restores the exact original document; Redo restores the cleanup without absorbing surrounding typing.

Use the existing responsive dialog conventions with `LayoutBuilder`, a bounded scrollable preview, visible keyboard focus, accessible labels, and text that scales. At 320 logical pixels and 200% text size, options and actions must remain reachable. Preserve light, dark, high-contrast, and reduced-motion behavior. Do not add a new shortcut in this version.

## Implementation tasks

The planner, preview, editor integration, and automated checks are implemented. The native manual check below remains pending.

### 1. Prove cleanup and undo on the real document model

- [x] Add `lib/data/text_cleanup.dart` with a pure cleanup planner over a Delta snapshot, selected range, and options. Return a retain/delete change Delta, counts, and the mapped selection. Build the preview by composing this change onto a copy of the snapshot.
- [x] Track offsets using Quill/Dart UTF-16 indexing; count embeds as one document position. Walk complete paragraphs across Delta operation boundaries so text split by bold or link attributes follows the same rules.
- [x] Emit deletions only. Retain all surviving attributes, embeds, paragraph boundaries, and the terminal newline. Empty and protected documents produce a no-op result. Running cleanup twice produces no second change.
- [x] Add focused tests in `test/text_cleanup_test.dart`, then verify the pinned Quill version's public controller/history APIs in `pubspec.lock` and the installed source. Prove one cleanup can be undone and redone independently of typing immediately before and after it. Do this before building the preview UI; do not assume one controller call automatically creates an isolated undo entry.

### 2. Add preview and apply in note windows

- [x] Add `lib/ui/text_cleanup_dialog.dart` for options, counts, preview, no-op state, Cancel, and Apply. Derive each preview from the original snapshot, never from an already-cleaned result.
- [x] Wire the action and guarded apply into `lib/ui/note_page.dart`, reusing its editor, focus, save, error reporting, and existing menu construction. Keep one entry per note surface.
- [x] Add a narrowly scoped helper in `lib/ui/note_quill_controller.dart` only if transaction isolation needs to be shared or cannot be handled cleanly at the call site. Do not change clipboard behavior or native Windows code.
- [x] Put all new labels and messages in `lib/l10n/app_en.arb`; regenerate the existing localization files. Extend `test/text_cleanup_test.dart` with widget coverage.

### 3. Verify and document

- [x] Verify selected-range cleanup and whole-note cleanup, unchanged Cancel, no-op Apply, option toggles, stale-document rejection, focus restoration, and undo/redo isolation.
- [ ] Verify styled runs, links, code, every list/checklist type, unknown attributes, images, emoji, and terminal newlines remain intact. Include a selection spanning protected and eligible paragraphs and candidates split across Delta operations.
- [x] Verify the cleaned Delta survives autosave and reopening, with its plain-text projection updated through the existing save path. Confirm unrelated note metadata and image assets are unchanged.
- [ ] Check the preview at narrow and desktop widths with large text and light/dark themes, plus keyboard and high-contrast behavior. Use a large existing-style document fixture to check for blocking work; move pure planning to an isolate only if measured responsiveness requires it.
- [x] Update `STATUS.md` with actual implementation and verification results. Add a short usage note to the existing README editor instructions if needed. Keep this plan's status accurate; record material deviations in `STATUS.md` rather than creating a duplicate progress document.

## Verification after implementation

Use the SDK recorded in the current `STATUS.md` (`.tools/flutter` in this checkout). Its documented Git safe-directory environment is required on this machine. The commands below describe verification; executed results are recorded in `STATUS.md`.

```powershell
.\.tools\flutter\bin\dart.bat format <changed Dart files>
.\.tools\flutter\bin\flutter.bat gen-l10n
.\.tools\flutter\bin\flutter.bat analyze
.\.tools\flutter\bin\flutter.bat test test/text_cleanup_test.dart test/text_style_test.dart test/note_flow_test.dart test/clipboard_resize_test.dart test/accessibility_test.dart test/large_content_test.dart test/l10n_test.dart
```

Expected results: analysis reports no issues and the selected tests pass. Add regression tests for the actual risks above, rather than reproducing every UI detail.

For the final manual check, use a disposable note containing styled paragraphs, trailing spaces, repeated empty paragraphs, a list, inline code, a code block, and an image. Preview and cancel once; preview and apply once; undo and redo; close and reopen. Repeat in a desktop child note window. The cleanup must match the preview, preserve protected content, and persist through reopening. A Windows build is needed only when producing or running that updated app; an installer rebuild and version bump require a release request.

## Decisions and remaining limits

- **User decision, 2026-10-31:** automatic text cleanup; plan first, then implementation authorized with `proceed`.
- **Proposed approach:** local whitespace cleanup with preview. If “cleanup” should include grammar correction, paragraph restructuring, or AI rewriting, revise these rules before implementation.
- **Verified constraint:** rich text and embeds are already stored as Delta operations. Keep that representation; no schema migration or dependency upgrade is proposed.
- **Verified undo behavior:** the pinned Quill history exposes `lastRecorded`; resetting it before and after cleanup isolates the operation from adjacent typing. Regression tests prove Undo and Redo boundaries. No dependency or storage-format change was needed.
- **Recovery:** Cancel preserves the original; Undo reverses an applied cleanup. Reverting this feature later requires no data conversion because its saved result remains a standard existing note Delta.
- **Export limit:** Markdown and PDF have existing formatting limitations. Cleanup preserves the surviving Delta attributes but does not expand export fidelity or alter paste conversion.

Completion means the action works through the real note editor, the listed regression checks pass, and the native note-window workflow is verified or explicitly reported as unverified. Implementation was authorized separately. No build, packaging, version bump, or commit was performed for this feature.
