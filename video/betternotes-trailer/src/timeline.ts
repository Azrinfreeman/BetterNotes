import narration from "./narration.json";
export const TOTAL = 1800;
export const SHOTS = narration;
export const SFX = SHOTS.filter((s) => s.from > 0).map((s) => ({
  from: s.from + 12,
  duration: 24,
  src: "audio/swoosh.mp3",
  volume: 0.12,
}));
SFX.push({
  from: SHOTS[4].from + 132,
  duration: 12,
  src: "audio/click.mp3",
  volume: 0.3,
});
SFX.push({
  from: SHOTS[2].from + 116,
  duration: 12,
  src: "audio/click.mp3",
  volume: 0.3,
});
// One bounded mechanical keystroke for each visible search character.
for (let i = 0; i < "Everyday".length; i++) {
  SFX.push({
    from: SHOTS[4].from + 30 + i * 3,
    duration: 3,
    src: "audio/typing.mp3",
    volume: 0.22 - i * 0.01,
  });
}
export const CAPTIONS = [
  { from: 30, duration: 138, text: "Rich desktop notes. Ready offline." },
  { from: 198, duration: 88, text: "Collections on the left." },
  { from: 286, duration: 70, text: "Tools within reach." },
  { from: 356, duration: 54, text: "Space to write." },
  { from: 438, duration: 106, text: "Open a note. Shape your thoughts." },
  {
    from: 544,
    duration: 106,
    text: "Headings, checklists, links, and rich text.",
  },
  { from: 678, duration: 86, text: "Keep pictures beside your words." },
  { from: 764, duration: 96, text: "Sketch the next idea." },
  { from: 888, duration: 96, text: "Search, tag, and favorite." },
  { from: 984, duration: 86, text: "Find the note. Keep moving." },
  { from: 1098, duration: 92, text: "Write. Save locally. Keep working." },
  {
    from: 1190,
    duration: 90,
    text: "Optional cloud sync needs configuration.",
  },
  {
    from: 1308,
    duration: 181,
    text: "Reminders. Text cleanup. Earlier versions.",
  },
  { from: 1518, duration: 151, text: "More ways to keep your notes useful." },
];
