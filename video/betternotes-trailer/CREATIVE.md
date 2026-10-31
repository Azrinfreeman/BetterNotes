# BetterNotes — 60-second product trailer

Mode: autonomous custom creation, authorized 2026-10-31. Delivery: 1920 × 1080, 30 fps, exactly 1,800 frames. English. Audience: people who want richer desktop notes for work and everyday ideas. Deliver music and no-music versions, retaining narration and sound effects.

## Product and execution decisions

Evidence: README.md, DESIGN.md, lib/ui/theme/notes_theme.dart, lib/ui/review_notebook.dart, and STATUS.md. BetterNotes is an offline-first rich-text notes app with separate Windows note windows. This trailer uses real Flutter captures from an isolated, in-memory synthetic notebook. No personal notebook, account, credentials, or cloud connection may appear. Cloud sync is optional and requires configuration; do not present a live or verified sync session.

| Requirement | Execution |
| --- | --- |
| Explain purpose and benefits first | Opening identifies notes, plans, and ideas; offline writing and richer sticky notes. |
| Explain UI language and layout | Paper/graphite, blue actions, note tints; sidebar for collections, toolbar for tools, canvas for writing. |
| Show how it works | Open a note, format writing, add visual material, search and filter. Keep cause and result visible. |
| Explain why it works | A clearly labeled conceptual local-first flow: write → save locally → optional configured sync. |
| Mention remaining capabilities | Reminders, cleanup, templates, history, backup, export, Sticky Notes import, accessibility. |
| Full minute | Fixed 1,800-frame composition, no padding or repeated demo shots. |
| Sound | English narration if a usable local voice exists; licensed House Vibez plus real switch/sweep SFX. |

## Visual direction

Considered: a high-energy kinetic montage; an editorial paper/graphite walkthrough; a dark cinematic showcase. Selected the editorial walkthrough for readable explanations and faithfulness to the redesigned app. Dark surfaces appear only where they represent the actual theme or provide a restrained chapter break.

Tokens: Segoe UI; light canvas #F5F5F7, white paper, ink #1C1C1E, secondary #5C6068, action #005FCC; dark canvas #141416, dark surface #1C1C1E, dark action #66A8FF. Corners 8/12/20, spacing multiples of 8. Video headlines 68–100 px, supporting explanations 44 px, main captions 60 px. Use a 96 px safe inset. No decorative gradients, neon, jitter, flashing, or elastic UI. Motion: deliberate 26–42-frame eased reveals, legible holds, camera movement with a clear target.

The strict product design contract already locks typography, palette, and material; static reference frames are generated from this contract before motion. Video titles are scaled for 1080p reading. Product UI is always captured, never reconstructed in HTML.

## Feature-to-shot mapping and storyboard

| Time | Frames | Content and visual | Motion / source / sound |
| --- | --- | --- | --- |
| 0–6s | 0–179 | BetterNotes; rich notes for everyday ideas; offline-first benefit | Brand lockup and real note cutouts; slow settle, ≥1s hold. |
| 6–14s | 180–419 | Paper and Graphite design; sidebar, tools, writing space | Real library screenshot; custom restrained layout tour using PageCam. |
| 14–22s | 420–659 | Shape a plan with headings, checklists, and rich text | Real editor before/after captures; pointer checks the first task at frame 536, with an immediate visible result and click. |
| 22–29s | 660–869 | Images and drawing; keep visual context with text | Actual image/ink interface and note capture; close-up and hold. |
| 29–36s | 870–1079 | Search, tags, favorites; find a useful note | type-and-filter / type-and-filter; real screenshots and cutouts. Query at 3f/character, ≥11f pause, return result to actual slot; click. |
| 36–43s | 1080–1289 | Write → local save → optional cloud | Custom explanatory diagram explicitly labeled as concept; no imitation of cloud UI. |
| 43–50s | 1290–1499 | Reminders, text cleanup, version history | Actual dialogs in a three-part editorial arrangement with readable labels. |
| 50–56s | 1500–1679 | Templates, backups, Markdown/PDF export, Sticky Notes import, accessibility | Actual settings capture alongside concise feature list; no false device or sync claims. |
| 56–60s | 1680–1799 | BetterNotes; Make room for your next idea | Brand close with note imagery, ≥1s settled hold. |

The opening follows the promo-energy-arc skeleton but reserves 14 seconds to satisfy the requested introduction. Most shots use original explanatory staging, since generic dashboard cards do not match this Flutter app. The search interaction adapts the exact TypeAndFilter.tsx demo and its 3f typing, pause, real-slot, and pointer rules. No claim of pixel matching a Gallery demo. Reference: references/shots/interaction/type-and-filter.md; demos/interaction/type-and-filter/TypeAndFilter.tsx; gallery style-key type-and-filter. Layout tour is custom (not a cursor-flyover reproduction) so it can explain the actual sidebar without suggesting four nonexistent interactive modules.

## Assets and licensing

- App imagery: actual current BetterNotes Flutter review build and fictional notebook. Logo: assets/icon.png.
- Music: House Vibez — Lily J, https://assets.mixkit.co/music/745/745.mp3; skill's recorded Mixkit Stock Music Free License, https://mixkit.co/license/#music.
- Sweep: Fast small sweep transition, https://assets.mixkit.co/active_storage/sfx/166/166-preview.mp3.
- Click: Quick switch click, recorded in the skill's assets/audio/ATTRIBUTION.md under Mixkit Sound Effects Free License.
- Typing: Typewriter soft hit, https://assets.mixkit.co/active_storage/sfx/1366/1366-preview.mp3, Mixkit Sound Effects Free License. One bounded stroke per visible search character.
- All copies live in public/. Preserve source and license information when sharing project sources.

## Acceptance

Check real app captures, readable titles and captions, feature accuracy, 60s duration, 1080p H.264 output, audible unclipped audio, matching visuals between both exports, and no private data. Render and inspect two frames per scene, extract final-video contact sheets, and request an independent clean-context review as required by video-shotcraft. Record limitations honestly. No application source edits, version bump, or Git commit are required for video production.
