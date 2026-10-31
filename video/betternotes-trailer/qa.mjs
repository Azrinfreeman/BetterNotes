import { bundle } from "@remotion/bundler";
import {
  selectComposition,
  renderStill,
  openBrowser,
} from "@remotion/renderer";
import { writeFileSync } from "node:fs";
const serveUrl = await bundle({ entryPoint: "src/index.ts" });
const browser = await openBrowser("chrome");
const composition = await selectComposition({
  serveUrl,
  id: "BetterNotes",
  puppeteerInstance: browser,
});
const frames = [
  70, 155, 240, 385, 485, 620, 720, 825, 924, 1045, 1135, 1245, 1360, 1460,
  1555, 1650, 1730, 1785,
];
for (let i = 0; i < frames.length; i += 3) {
  await Promise.all(
    frames
      .slice(i, i + 3)
      .map((frame) =>
        renderStill({
          serveUrl,
          composition,
          frame,
          output: `out/qa/f${frame}.png`,
          puppeteerInstance: browser,
          imageFormat: "png",
        }),
      ),
  );
  console.log("QA frames", frames.slice(i, i + 3).join(","));
}
writeFileSync("out/qa/frames.json", JSON.stringify(frames));
await browser.close({ silent: true });
