# BetterNotes UI revamp — implementation proposal

Prepared: 2026-10-31. Status: proposal only; implementation has not started.

## Recommendation

Revamp BetterNotes as a calm, content-first notes app: an attached library sidebar, a clear note collection, a generous writing surface, and restrained translucent chrome. Use Apple's hierarchy, typography, materials, and responsive interaction principles while retaining familiar Windows window controls and BetterNotes' separate note windows.

The premium quality should come from alignment, readable text, carefully grouped controls, reliable focus, and immediate response. Notes should remain the most visually important part of the app.

This proposal covers the whole visible application. It preserves rich text, clipboard behavior, pictures, drawing, reminders, search, tags, favorites, archive, Trash, templates, bulk actions, history, backup/import/export, account settings, tray actions, and existing shortcuts. Storage formats and cloud behavior remain outside the redesign.

Only this proposal and a short project-status entry are authorized at this stage. The existing `IMPLEMENTATION.md` records the completed clipboard/resize work and remains intact.

## Skill application and conflict decisions

| Skill | Application |
| --- | --- |
| `avoid-ai-design` | Source audit first; one shared design contract; remove decorative defaults and verify the eventual rendered UI. |
| `color-system` | Tonal palettes, semantic roles, light/dark mappings, and measured contrast. |
| `no-slop-ui` | Attached navigation, restrained containment, concise labels, useful density, no decorative gradients or hover movement. |
| `emil-design-eng` | Immediate feedback, complete interaction states, anchored menus, and very little motion on frequent actions. |
| `apple-design` | Content hierarchy, platform familiarity, agency, accessibility, typography, and spatial continuity. |
| `apple-design-materials` | Selective translucent chrome, opaque content, consistent icon weight, and solid fallbacks. |
| `apple-design-motion` | Interruptible springs for occasional spatial transitions; velocity-aware gestures where useful. |

The requested Apple direction takes precedence where the skills conflict. Specifically, permit limited functional translucency and occasional spring transitions despite `no-slop-ui`'s blanket bans. Keep its restraint everywhere else: no floating glass dashboard, glass cards, hover scaling, universal pill controls, or decorative motion. Native platform typography also takes precedence over font bans; do not redistribute Apple's fonts or SF Symbols for Windows. Use available Cupertino icons and Material icons through a consistent semantic mapping, rather than mixing styles arbitrarily.

These are Flutter interfaces. Translate the design principles into Flutter widgets and physics; CSS, DOM, Framer Motion, and SwiftUI recipes are reference material, not implementation dependencies.

## Current implementation and audit

Profile: productivity application and shared app components, not a marketing page. Findings below come from source inspection. No current app screenshots or rendered visual audit were produced for this planning task; visual impact remains inferred until the first implementation review.

The `avoid-ai-design` scanner ran on `lib` and reported **0 files scanned** because it does not inspect Dart. Its zero findings do not establish a clean audit. No P0 finding is established by this review.

| Priority / catalog | Before | Proposed after | Why / evidence |
| --- | --- | --- | --- |
| P1, SD1/C3, adapted | `lib/main.dart`: plum seed `#795082`, terracotta secondary `#BD644B`, warm canvas `#FFFAF6`, plum-dark canvas `#1E1A21`. | Neutral paper/graphite surfaces; blue action color; independent status colors. | Values are code-certain. Their resemblance to a common warm/plum template is a visual judgment, not proof of authorship. |
| P1, K2 | Shared cards use radius 24; filled inputs use radius 18. | Role-based corners: compact controls 8, cards 12, dialogs/sheets 16–20. | Code-certain global values flatten the distinction between content, controls, and overlays. |
| P2, K12/S1, adapted | `lib/ui/notes_home.dart`: library views are horizontal chips above search, sort, saved filters, and tag controls; collection capped at 1050. | Persistent navigation at wide widths; one collection toolbar; active filters disclosed only when applied. | Structure is code-certain; crowding and excessive top-of-page emphasis are inferred. Existing chips contain real functionality and must remain accessible. |
| P2, K4, contextual | `CompactNoteTile` uses an 8-pixel color strip; note cards and headers directly use the 12 note colors. | Consistent, restrained note tint and named color choice; neutral application chrome. | Code-certain. User-selected note colors are meaningful identity, so retain them; do not classify every colored note as decoration. |
| P2, shared-system risk | Settings use a long list; note windows use a dedicated colored, auto-hiding header; most other surfaces use Material defaults. | A common toolbar, row, form, menu, dialog, and feedback vocabulary across all screens. | Structures are code-certain; cross-screen visual inconsistency requires rendered confirmation. |

Preserve existing good foundations: cached light/dark/high-contrast themes, reduced-motion handling in the note header, accessible header preferences, localization, multi-window coordination, and the corrected expanding editor with one body scroll view. Do not reintroduce a fixed writing height or width cap.

## Visual direction

Recommended direction: **Paper and Graphite**. Quiet neutral surfaces, crisp dark text, blue actionable controls, subtle user-selected note tints, and occasional frosted toolbar material. This comes from the product's purpose: finding a note quickly and writing without visual interference.

The signature detail is continuity of note identity: the same restrained tint, title treatment, and color name connects a library note to its standalone window. Avoid a decorative stripe system or a fabricated paper texture.

Two alternatives remain available for review: a fully opaque version with the same layout and palette, or a warmer paper version retaining a small amount of the existing warmth. Neither requires changing the architecture. The recommendation avoids the current plum/terracotta combination, near-black/neon defaults, all-caps labels, and ornamental glass.

### Layout and navigation

Use available logical width, not device names. These are initial breakpoints to validate with real controls and large text.

| Width | Library layout | Behavior |
| --- | --- | --- |
| 1000 and above | Attached 248-wide sidebar plus flexible collection. | Sidebar holds Notes, All active, Favorites, Reminders, Archive, Trash, saved searches, and tags. Settings/account at the bottom. Sidebar scrolls independently if needed. |
| 720–999 | Collapsible 216-wide attached sidebar plus collection. | Keep navigation explicitly reachable from the toolbar; collapse when content or text scaling requires it. |
| Below 720 | Single collection with a labeled navigation button. | Navigation opens a sheet/drawer; search and New note stay directly available. No miniature desktop sidebar. |

Keep the existing standalone note-window workflow as the desktop default. Do not add a three-pane embedded editor during this redesign; it would introduce a second editing/navigation lifecycle. On platforms using route-based editing, preserve that route behavior and back navigation.

Collection toolbar: view title, search, New note, and a compact group for sort, filters, and grid/list choice. Show templates beside New note through an adjacent menu. Use actual counts only when useful; do not add decorative badges. Preserve compact/list preference and grid access; do not silently reset the user's saved choice.

Grid cards show title, a short preview, and the most useful metadata. List rows use the same hierarchy at higher density. Tags and reminder information must remain discoverable without turning every row into a group of chips. Use an icon plus date for reminders and an accessible favorite control. Selected items have a clear fill, checkmark, and focus treatment independent of note color.

Keep multi-selection actions near the collection toolbar. Preserve the existing keyboard and pointer selection behavior, context menus, undo, and Trash retention rules. Changing the layout must not change what a saved filter searches.

### Type, spacing, and shape

- Use platform-appropriate UI typography, including the native Windows system face where available. On Apple platforms allow the system face; do not bundle SF fonts. Verify actual Flutter font resolution instead of assuming a CSS-style `system-ui` value works.
- Initial type roles in logical pixels: window/view title 22/28 semibold, note title 24/30 semibold, row/card title 15/20 semibold, controls/body 14/20 regular, metadata 12/16 medium. Large-text layouts may grow and wrap; these are not fixed-height constraints.
- Preserve user-selected editor font, size, color, and rich-text attributes. UI typography must not rewrite document formatting or exports.
- Spacing scale: 4, 8, 12, 16, 24, 32. Use 16–24 for collection margins, 12–16 within cards, and smaller gaps within a control group. Avoid empty space added just to appear expensive.
- Corners: 8 for controls, 12 for note cards, 16–20 for substantial overlays. Attached panes have square outer edges. Use Flutter continuous-corner shapes where suitable; describe them as approximations rather than exact Apple geometry.
- Use flat rows and tonal separation for structure. Reserve shadows for real overlays. Avoid borders around every nested group.
- Icons generally 18–20; consistent visual weight and optical alignment. Standard Windows caption controls keep their platform placement and behavior.

## Color contract

Six color families have explicit jobs: Graphite for structure/text, Blue for action/focus, Green for successful completion, Amber for attention, Red for failure/destruction, and Note colors for user organization. Blue is also the information hue, differentiated through an information icon and text. No extra secondary brand accent is needed.

### Raw tonal palettes

These proposed sRGB scales support the semantic contract. Components consume roles, not arbitrary raw shades. The action-specific overrides below are deliberate accessible choices within the blue family.

| Tone | Graphite | Blue | Green | Amber | Red |
| --- | --- | --- | --- | --- | --- |
| 50 | `#F9F9FB` | `#EFF6FF` | `#F0FDF4` | `#FFFBEB` | `#FFF1F2` |
| 100 | `#F5F5F7` | `#DBEAFE` | `#DCFCE7` | `#FEF3C7` | `#FFE4E6` |
| 200 | `#E5E5EA` | `#BFDBFE` | `#BBF7D0` | `#FDE68A` | `#FECDD3` |
| 300 | `#D1D1D6` | `#93C5FD` | `#86EFAC` | `#FCD34D` | `#FDA4AF` |
| 400 | `#AEAEB8` | `#60A5FA` | `#4ADE80` | `#FBBF24` | `#FB7185` |
| 500 | `#858B96` | `#3B82F6` | `#22C55E` | `#F59E0B` | `#F43F5E` |
| 600 | `#5C6068` | `#2563EB` | `#16A34A` | `#D97706` | `#E11D48` |
| 700 | `#45474F` | `#1D4ED8` | `#15803D` | `#B45309` | `#BE123C` |
| 800 | `#2C2C2E` | `#1E40AF` | `#166534` | `#92400E` | `#9F1239` |
| 900 | `#1C1C1E` | `#1E3A8A` | `#14532D` | `#78350F` | `#881337` |
| 950 | `#121214` | `#172554` | `#052E16` | `#451A03` | `#4C0519` |

### Application roles

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| Canvas | `#F5F5F7` | `#141416` | Library background. |
| Surface | `#FFFFFF` | `#1C1C1E` | Note/content surfaces. |
| Raised surface | `#FFFFFF` | `#2C2C2E` | Menus, dialogs, elevated controls. |
| Primary text | `#1C1C1E` | `#F5F5F7` | Main labels and body. |
| Secondary text | `#5C6068` | `#ADB0B8` | Readable metadata, not disabled text. |
| Action / focus | `#005FCC` | `#66A8FF` | Primary action, links, focus ring. |
| Text on action fill | `#FFFFFF` | `#121214` | Filled primary buttons. |
| Selected surface | `#E8F0FC` | `#203750` | Selection plus checkmark/shape. |
| Required control outline | `#858B96` | `#858B96` | Input/control boundaries when needed for identification. |
| Decorative separator | `#E5E5EA` | `#45474F` | Pane/row separation; never the sole control boundary. |

Interaction states need distinct hover, pressed, selected, disabled, focused, loading, and error roles. Define these centrally during foundation work and verify every used pairing. Do not assume lowering opacity preserves readability.

| Status | Light background / text | Dark background / text | Stroke and icon |
| --- | --- | --- | --- |
| Success | `#EAF6EE` / `#1F6F43` | `#193426` / `#6ED69C` | Use the status text color for meaningful borders/icons. |
| Warning | `#FFF4DB` / `#8A5700` | `#382C17` / `#F2C066` | Pair with attention icon and specific action. |
| Error / destructive | `#FDEDEF` / `#B42332` | `#3D2025` / `#FF8A93` | Pair with error icon/text; destructive buttons use separately verified on-fill colors. |
| Information | `#EFF6FF` / `#005FCC` | `#203750` / `#66A8FF` | Pair with information icon and useful message. |

Success is for completed operations, not permanent green decoration. Warnings communicate something actionable such as overdue reminders or backup attention. Red denotes failure or a destructive action, not the ordinary close-window button. Ordinary note colors never imply success, danger, or priority.

### Contrast evidence and remaining validation

Calculated during planning using WCAG relative luminance for solid sRGB pairs:

| Pair | Light ratio | Dark ratio |
| --- | --- | --- |
| Primary text / surface | 17.01:1 | 15.63:1 |
| Secondary text / canvas (light), raised surface (dark) | 5.80:1 | 6.42:1 |
| Text on primary action fill | 5.98:1 | 7.67:1 |
| Success text / status background | 5.54:1 | 7.54:1 |
| Warning text / status background | 5.58:1 | 8.12:1 |
| Error text / status background | 5.74:1 | 6.50:1 |
| Control outline / surface (light), raised surface (dark) | 3.43:1 | 4.07:1 |

These calculations validate only the listed pairs. Implementation must verify all interaction states, information/selection pairs, all 12 note tints, high-contrast mappings, and composited translucent surfaces. Target at least 4.5:1 for normal text, 3:1 for large text and meaningful control graphics; aim for 7:1 on primary reading text. Check color-vision simulations and ensure selection/status can be understood without hue.

### Existing note colors

Preserve all 12 `colorIndex` identities, order, names, sorting, imports, and cloud values in `lib/data/note.dart`. Add presentation mappings for light/dark note surfaces in the UI theme instead of changing saved data. Every named color remains selectable and recognizable. Use pale tints in light mode and restrained dark tints in dark mode, with independently validated text/icon colors. A color picker needs a name, selected checkmark, and focus ring. Do not recolor embedded images, ink, or authored rich text.

## Materials and depth

Content stays opaque: writing canvas, note cards, settings groups, and text fields. Start the sidebar opaque too. Translucency is reserved for a toolbar over genuinely scrolling content, an anchored popover, or a sheet where depth clarifies the relationship.

Implement an in-app approximation with clipped `BackdropFilter`, tint, and a restrained highlight/shadow; use fixed blur rather than animating a large blur field. Never stack blur surfaces. Animate the composed layer's opacity/transform if appropriate. Flutter blur does not provide Apple's native Liquid Glass refraction, automatic vibrancy, or desktop wallpaper sampling.

Use solid surfaces in high contrast and when transparency is disabled. Since reduced-transparency support varies across Flutter targets, plan an explicit Appearance preference and default to opaque when platform detection is unavailable. Keep the filter region tight; remove blur wherever profiling shows a performance cost. Native Windows backdrop effects are not required for this phase.

## Motion contract

Motion communicates state or spatial relationships. No launch choreography, staggered note grids, parallax, magnetic controls, hover movement, looping decorations, or scroll hijacking. The editor, search results, rapid note selection, and keyboard-initiated actions update immediately.

| Interaction | Planned behavior | Reduced motion / keyboard |
| --- | --- | --- |
| Button press | Immediate pressed tint; optional 0.98 scale on compact pointer/touch action buttons, with roughly 100–140 ms recovery. | Tint/focus only; keyboard activation remains immediate. |
| Row hover and selection | Subtle color response, at most 80–120 ms for pointer hover; selection commits immediately. | Immediate state and visible focus. |
| Anchored menu/popover | Pointer entry around 140–180 ms, opacity and scale 0.98→1 from the trigger; faster exit. | No spatial animation; keyboard opening immediate. |
| Occasional dialog/sheet | Short opacity/translation or critically damped spring, response about 0.30 s, damping ratio 1.0. | Immediate or short fade; no translation. |
| Touch sheet release, if used | Track the gesture directly, then settle from current position and release velocity; damping about 0.85–1.0. | Explicit dismiss action; no drag required. |
| Toast / undo feedback | One restrained opacity/offset transition, same entry/exit direction, no bounce. | Short fade; preserve existing expiry and accessible announcement. |
| Auto-hiding note header | Preserve hover/focus/pinned-header behavior and immediate reveal on keyboard focus. | Respect existing accessible-navigation preference; do not hide focused controls. |

Response is a spring parameter, not a promised fixed duration. Tune perceptual timing in the first slice; most visible UI transitions should complete their useful motion within about 150–280 ms. No animation may delay editing, saving, dismissal, or a shortcut.

Use Flutter `AnimationController`, `SpringDescription`, and `SpringSimulation` where a real spring is warranted; otherwise use lightweight existing transitions. Map response/damping using mass 1, stiffness `(2*pi/response)^2`, damping `2*dampingRatio*sqrt(stiffness*mass)`. Normalize gesture velocity to controller units, guard zero-distance cases, and re-target from the current position and velocity. Never restart from an old endpoint or await animation completion before accepting input.

Use `MediaQuery` reduced-motion/accessible-navigation signals and the existing high-contrast behavior. Keep preference handling centralized. Pause/dispose offscreen tickers, limit repaints, and avoid rebuilding the Quill document for chrome animation. Do not add an animation dependency unless the existing SDK cannot meet a demonstrated requirement. Haptics are optional only on supported touch platforms; no new sound feedback is proposed.

## Screen-by-screen coverage

| Surface / existing files | Planned work |
| --- | --- |
| Theme and app roots — `lib/main.dart` | Shared semantic themes and component themes applied identically to main and child apps; keep theme caching. |
| Library — `notes_home.dart`, `note_cards.dart`, `bulk_actions.dart` | Responsive sidebar/collection, toolbar, grid/list hierarchy, search/filter disclosure, selected state, archive/Trash, empty/error/loading states. |
| Editor — `note_page.dart`, `note_desktop_header.dart`, `find_bar.dart` | Clear title/actions, restrained note identity, quiet formatting toolbar, stable writing area, find and reminder banners; preserve selection, caret reveal, autosave and clipboard routing. |
| Formatting/media — `text_style_panel.dart`, `text_color_dialog.dart`, `note_image_embed.dart`, `drawing_page.dart` | Shared controls/pickers, clear selected states, responsive sheets, usable image actions and drawing tools; preserve existing document attributes and image placement. |
| Organization — `tag_manager.dart`, `reminder_dialog.dart`, `note_details_dialog.dart`, `version_history.dart` | Consistent row/form/dialog hierarchy, accessible date/time controls, readable revision preview and restore actions. |
| Settings — `settings_page.dart` | Group Account & sync, Appearance, Editing, Windows behavior, Storage & backups, Import/export, and About; wide-layout category navigation and a compact grouped layout. Keep every existing option, progress indicator and safety explanation. |
| Supporting screens — `about_page.dart`, `shortcuts_help.dart`, `startup_error.dart`, auth UI in settings | Same type/color/control system, concise actionable errors, readable diagnostics, safe recovery and sign-in states. |
| Window chrome — `lib/desktop/window_chrome.dart` | Align titlebar, drag regions, caption buttons, focus and inactive-window styling; preserve native/custom-button preference, minimize/maximize/restore/close, snapping and saved bounds. |
| Localization — `lib/l10n/app_en.arb` and generated output | Reuse current strings; add only necessary labels/accessibility names and new appearance preferences through existing localization tooling. |

## Implementation sequence after approval

### 1. Lock the contract and capture the baseline

- Review the current runnable app using an isolated notebook with synthetic notes. Capture only the app window with no private note contents.
- Record main/child window behavior and reference screenshots for library grid/list, editor with pictures and formatting, settings, and important overlays, in light/dark modes.
- Create `DESIGN.md` from the approved decisions here. It becomes the shared contract for every screen. Keep this document as the implementation sequence rather than maintaining two competing specifications.
- Resolve visual judgments from the source audit before deleting or redesigning working controls.

### 2. Implement the shared foundation

- Extract the cached theme builder into a focused `lib/ui/theme/` area. Provide semantic `ThemeExtension` tokens for colors/materials/motion plus spacing/type/shape constants; avoid a generalized theming framework.
- Configure the Material component themes deliberately and reuse Cupertino widgets where behavior genuinely fits. Do not replace the entire app with `CupertinoApp` or remove Material localization required by Quill.
- Add only repeated primitives: toolbar/action button, navigation row, note presentation, grouped settings section, and overlay styling. Extract more only when reuse is concrete.
- Apply tokens to both app roots and startup recovery. Add the transparency preference through the existing settings store and parent-to-child state path, with a backward-compatible default.

### 3. Deliver one representative implementation slice for review

- Implement library navigation/collection plus one complete standalone note window in light/dark modes.
- Include search, sort, New note/templates, grid/list, note opening, editing, formatting, note color, menus, and save/close behavior. Include keyboard and reduced-motion paths immediately.
- Review the actual Flutter UI at wide, narrow, and large-text sizes. Tune density, tint strength, corners, and timing before propagating the system. An HTML concept cannot validate Flutter rendering or editor behavior.

### 4. Apply the system across all remaining surfaces

- Complete remaining library states and bulk actions, editing/media controls, reminders, organization, history, grouped settings, backup/import/export, supporting screens, and window chrome using the approved tokens.
- Keep the existing data and controller behavior wherever possible. Introduce no storage/schema migration for the visual redesign.
- Reconcile every existing action against the screen inventory; uncommon actions may move into menus, but must not disappear or lose keyboard access.

### 5. Validate, profile, and finish

- Format changed Dart files; regenerate localization only if ARB changes. Run static analysis after related edits settle.
- Run focused behavior tests below. Broaden after shared changes or failures, rather than repeating unchanged checks.
- Review actual rendering and motion; fix contrast, focus, overflow, interruption and repaint problems before calling the redesign complete.
- Build Windows once after code settles for the runnable review. Package and bump versions only when a release is requested. Update `STATUS.md` with actual changes and check outcomes; commit only when requested.

## Verification and completion criteria

Existing tests are useful regression evidence, not a substitute for viewing the redesigned app.

| Area | Required evidence after implementation |
| --- | --- |
| Theme/accessibility | Extend `test/accessibility_test.dart` for used text/control pairings, all note color presentations, focus, high contrast, reduced motion and large text; verify transparent composites separately. |
| Library | Run affected `organization`, `sort`, `saved_filters`, `note_flow`, `round_b`, and `round_b2` tests; preserve filtering, dates, templates, selection, archive and Trash actions. |
| Editor | Run affected `clipboard_resize`, `text_style`, `image_placement`, `large_content`, and `revision_history` tests. Verify real selection/caret, rich clipboard copy/paste, media and resize behavior. |
| Desktop | Run affected `window_buttons`, `window_fit`, `desktop_integration`, and `note_open_performance` tests; manually check drag/snap, maximize/restore, quick-note/tray, multiple windows and settings propagation. |
| Other flows | Run relevant reminders, backup-browser/auto-backup, import/export, startup-error, localization and About tests where shared components or layout changed. Do not trigger real scheduled tasks or modify real user data for a visual check. |
| Responsive review | Check approximately 360, 470, 768, 1024 and 1440 logical widths, short windows, 100–200% text scaling, and Windows display scaling. Include touch hit targets of at least 44×44 where used, usable pointer targets, no clipped focus rings, and logical tab order. |
| Motion/performance | Profile the release/profile build on Windows with a realistic synthetic library and long note with pictures. Compare baseline/new behavior; target sustained refresh-rate frame budgets (about 16.7 ms at 60 Hz), no typing latency, no material-induced scrolling jank. Check interruption and rapid open/close at normal and slowed speed. |
| Visual consistency | Review light/dark/high-contrast screenshots across all surfaces; no unthemed default widgets, unexplained accent colors, nested card shells, decorative gradients, unreadable tints or unnecessary microcopy. |

Complete when every inventoried surface follows the same contract, all current functionality remains reachable, input remains immediate, required checks pass, and material platform limits are recorded. Cross-platform layouts can be checked in Flutter tests on this machine, but real iOS behavior requires a Mac/device and Android packaging requires the Android SDK. Cloud UI states can use fixtures; live authentication/sync verification requires the owner's configuration and is not claimed by this redesign.

## Current verification

Planning only: inspected the existing source and relevant tests, ran the scanner with its unsupported-Dart limitation, calculated the listed solid-color contrast pairs, and reviewed this document. No Dart/native files changed. No Flutter analysis, builds, tests, packaging, or UI implementation ran for this proposal.
