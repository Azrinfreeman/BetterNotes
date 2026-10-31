import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";
const pcm = (file) => {
  const r = spawnSync(
    "ffmpeg",
    [
      "-v",
      "error",
      "-i",
      file,
      "-ac",
      "1",
      "-ar",
      "8000",
      "-f",
      "s16le",
      "pipe:1",
    ],
    { maxBuffer: 20e6 },
  );
  if (r.status !== 0) throw Error(r.stderr.toString());
  const a = new Float32Array(r.stdout.length / 2);
  for (let i = 0; i < a.length; i++) a[i] = r.stdout.readInt16LE(i * 2) / 32768;
  return a;
};
const report = {
  pipeline:
    "Remotion 4.0.484; H.264/AAC MP4; audio 48 kHz; Windows; 2026-10-31",
  measurements: [],
};
const targets = process.argv.slice(2);
for (const target of targets.length
  ? targets
  : [
      "out/BetterNotes-Trailer-60s.mp4",
      "out/BetterNotes-Trailer-60s-NoMusic.mp4",
    ]) {
  const mix = pcm(target);
  for (const [id, start] of [
    ["intro", 5],
    ["write", 425],
    ["extras", 1295],
  ]) {
    const source = pcm(`public/audio/narration-${id}.mp3`);
    const expected = Math.round((start / 30) * 8000);
    let best = { lag: 0, score: -Infinity };
    for (let lag = -800; lag <= 800; lag++) {
      let dot = 0,
        energy = 0,
        srcEnergy = 0;
      for (let j = 1600; j < Math.min(source.length, 16000); j += 3) {
        const v = mix[expected + lag + j] ?? 0;
        dot += source[j] * v;
        energy += v * v;
        srcEnergy += source[j] * source[j];
      }
      const score = dot / Math.sqrt(energy * srcEnergy + 1e-20);
      if (score > best.score) best = { lag, score };
    }
    report.measurements.push({
      target,
      id,
      offsetSeconds: best.lag / 8000,
      offsetFrames: (best.lag / 8000) * 30,
      correlation: best.score,
    });
  }
}
writeFileSync("out/qa/audio-alignment.json", JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
