# BetterNotes design contract

Approved direction: Paper and Graphite, 2026-10-31. Implementation sequence and full palette rationale: `UI_REVAMP_IMPLEMENTATION.md`.

- Content comes first. An attached library sidebar, a flexible collection, and separate Windows note windows. Compact widths use explicit navigation; no embedded-editor lifecycle is added.
- Use semantic colors and shared component themes in `lib/ui/theme/notes_theme.dart`. Blue means action/focus, green completed success, amber attention, red errors/destructive actions. Note tints mean user organization and retain all 12 saved color identities.
- Light canvas `#F5F5F7`, paper `#FFFFFF`, text `#1C1C1E`, secondary `#5C6068`, action `#005FCC`. Dark canvas `#141416`, surface `#1C1C1E`, raised `#2C2C2E`, text `#F5F5F7`, secondary `#ADB0B8`, action `#66A8FF`.
- Platform UI typography; on Windows use Segoe UI. Keep authored document formatting independent. View title 22/28 semibold, note title 24/30, collection title 15/20, UI text 14/20, metadata 12/16. Respect text scaling.
- Spacing: 4/8/12/16/24/32. Corners: controls 8, notes 12, large overlays 16–20; attached panes square. No decorative gradients, giant pills, nested card shells, tinted icon tiles, or hover transforms.
- Text content stays opaque. Translucency is optional and limited to genuinely layered chrome; high contrast and reduced transparency use solid surfaces. Blur is clipped and fixed, never stacked.
- Immediate editing, search, selection, and keyboard actions. Occasional spatial changes may use short, interruptible springs; no bounce without gesture momentum. Reduced motion removes spatial transitions. Feedback never waits for animation.
- Every control needs pressed, focused, disabled, loading and error behavior where relevant. Selection and status need a cue beyond color. Normal text at least 4.5:1; meaningful control boundaries 3:1. Preserve accessible names, shortcuts, undo, safety messages and localization.
- Reuse these tokens across library, editor, drawing, formatting, settings, dialogs, startup recovery and child windows. New one-off colors or timings need a functional reason and a shared role.
