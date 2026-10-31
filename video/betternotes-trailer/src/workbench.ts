import { COMPONENTS, Main, Caption, Music } from "./Main";
import { SHOTS, CAPTIONS, SFX, TOTAL } from "./timeline";
import { defaults } from "./Scenes";
export const WORKBENCH = {
  name: "BetterNotes · 60-second trailer",
  fps: 30,
  width: 1920,
  height: 1080,
  total: TOTAL,
  background: "#F5F5F7",
  shots: SHOTS.map((s, i) => ({
    id: s.id,
    label: s.id,
    from: s.from,
    duration: s.duration,
    component: COMPONENTS[i],
    props: { ...defaults[s.id as keyof typeof defaults], duration: s.duration },
    durationProp: "duration",
    schema: [
      { type: "text", key: "title", label: "Title", default: "" },
      { type: "textarea", key: "subtitle", label: "Subtitle", default: "" },
    ],
  })),
  transitions: [],
  captions: CAPTIONS.map((c, i) => ({
    id: `caption-${i}`,
    label: c.text,
    from: c.from,
    duration: c.duration,
    component: Caption,
    props: { text: c.text },
    schema: [{ type: "text", key: "text", label: "Caption", default: "" }],
  })),
  overlays: [
    { id: "music", label: "Music", from: 0, duration: TOTAL, component: Music },
  ],
  sfx: SFX,
  bgm: [],
  // Keep the exact frame-dependent music envelope as an overlay for parity.
  order: ["captions", "overlays", "transitions"],
  original: Main,
};
