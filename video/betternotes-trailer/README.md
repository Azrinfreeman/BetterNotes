# BetterNotes trailer

A 60-second English product trailer made with video-shotcraft and Remotion Marketing Video. The editable project uses real Flutter interface captures and fictional notes from an isolated, in-memory notebook.

## Outputs

- `out/BetterNotes-Trailer-60s-NoVoice-Colorful.mp4`: colorful-card revision, with music and SFX and no narration. Library, search, and closing cards share the enhanced palette.

- `out/BetterNotes-Trailer-60s-NoVoice.mp4`: current delivery; music and sound effects, with narration removed. Original video stream and on-screen captions preserved. Source and workbench now omit narration.

- `out/BetterNotes-Trailer-60s.mp4`: narration, music, and sound effects.
- `out/BetterNotes-Trailer-60s-NoMusic.mp4`: identical pictures, narration, and sound effects; music removed.
- `out/BetterNotes-Trailer-60s.srt`: optional full narration subtitles.
- `out/qa/`: stills, encoded-video contact sheet, audio alignment measurements, and review reports.

Both MP4s are H.264/AAC, 1920 × 1080, 30 fps, exactly 1,800 video frames and 60 seconds. The audio is 48 kHz. The no-music version reuses the video stream and renders its audio from the same timeline with `bgm:false`.

## Edit

Run `npm ci`, then `npm run dev`. Open http://localhost:3000/BetterNotes. Scene text and movement are in `src/Scenes.tsx` and `src/SearchScene.tsx`; `src/narration.json` is the timing source. Caption and SFX positions derive from `src/timeline.ts`. Colors and typography are in `src/theme.ts`.

The video-shotcraft workbench can import `src/workbench.ts` into separate scene, caption, narration, SFX, and music layers:

```powershell
node C:/Users/Melon/.agents/skills/video-shotcraft/workbench/scripts/open.mjs E:/Projects/2026Projject/Done/BetterNotes/video/betternotes-trailer
```

Open http://localhost:5198/?import=project. Select a scene to change its title or subtitle, or adjust timing and audio in the timeline. Export the modified video from the workbench. Remotion Studio remains available for source-level changes.

## Render

```powershell
npm run check
npm run render
npx remotion render src/index.ts BetterNotes out/nobgm.wav --codec=wav --props=props-nobgm.json
```

The final delivered MP4 received a uniform 43 ms audio advance after three narration correlation probes measured the same AAC pipeline delay. `audio-qa.mjs` records the method and final residuals. When rendering again, measure the new render before copying that compensation; pipeline changes can change the offset. Use FFmpeg to trim/pad the audio to exactly 60 seconds and `-movflags +faststart` for web playback.

## Capture and narration

`demo.dart` seeds a rich reading-club plan into the app's existing synthetic review notebook. It changes no app source or personal storage. From the app root:

```powershell
.tools/flutter/bin/flutter.bat build web --release -t video/betternotes-trailer/demo.dart --no-pub
node tools/serve.mjs
```

Then run `node capture.mjs` and `node capture-fixes.mjs` in this folder. They use the Remotion-installed Chromium and a 1920 × 1080 viewport at 2× pixel density. Screenshot crops and click coordinates assume this viewport and the current app layout. No personal notebook is opened. `public/screens/layout.json` records capture coordinates. The conceptual local-save diagram is an illustration, not a captured cloud session. Windows-only capabilities are identified in the copy; interface captures come from the shared Flutter web build, not a native Windows session.

`narrate.ps1` creates the voice clips using the installed Microsoft Zira Desktop voice. The delivered processed MP3 clips are included, so this voice is not required for playback or rendering. Narration is synthetic. Regenerating narration requires rechecking timing and normalizing its loudness before replacing the MP3s.

## Asset credits

- App logo and interface: BetterNotes project.
- Fictional reading-club illustration: original SVG created for this trailer, captured by `capture.mjs`.
- Music: **House Vibez**, Lily J, [source](https://assets.mixkit.co/music/745/745.mp3), [Mixkit music license](https://mixkit.co/license/#music).
- Sweep: **Fast small sweep transition**, [source](https://assets.mixkit.co/active_storage/sfx/166/166-preview.mp3).
- Click: **Quick switch click**, [source](https://assets.mixkit.co/active_storage/sfx/2582/2582-preview.mp3), supplied under the skill's recorded [Mixkit sound effects license](https://mixkit.co/license/#sfx). Original URL is recorded in the installed skill's `assets/audio/ATTRIBUTION.md`.
- Typing: **Typewriter soft hit**, [source](https://assets.mixkit.co/active_storage/sfx/1366/1366-preview.mp3), [Mixkit sound effects license](https://mixkit.co/license/#sfx), bounded to each visible search character.
- PageCam and search motion reference: video-shotcraft. Search adapted from `demos/interaction/type-and-filter/TypeAndFilter.tsx`, using the `type-and-filter` Gallery variant.

`CREATIVE.md` contains the brief, design decisions, storyboard, and feature mapping. The trailer mentions optional sync with its configuration requirement; it does not claim that cloud sync was live-tested. The closing feature list is a concise mention, not an end-to-end demonstration of every capability.

## Colorful trailer cards

`python color-cards.py` derives `public/screens/library-colorful.png` from the preserved original capture and `layout.json`. It strengthens only the six card fills using BetterNotes palette colors and preserves dark ink. This is trailer artwork; the app theme is unchanged. Layout, search, and closing scenes use the derived asset. The colorful export reuses the preceding NoVoice export's audio stream without re-encoding or retiming it.
