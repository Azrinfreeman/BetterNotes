import { chromium } from "playwright";
import { readFileSync, writeFileSync } from "node:fs";
const frames = JSON.parse(readFileSync("out/qa/frames.json"));
const html = `<html><style>body{margin:0;background:#ddd;font:22px 'Segoe UI';display:grid;grid-template-columns:repeat(3,640px);gap:12px}img{width:640px;display:block}span{display:block;background:#fff;padding:8px}</style>${frames.map((f) => `<div><img src="data:image/png;base64,${readFileSync(`out/qa/f${f}.png`).toString("base64")}"><span>Frame ${f} · ${(f / 30).toFixed(2)}s</span></div>`).join("")}</html>`;
writeFileSync("out/qa/contact.html", html);
const browser = await chromium.launch({
  executablePath:
    "node_modules/.remotion/chrome-headless-shell/win64/chrome-headless-shell-win64/chrome-headless-shell.exe",
  headless: true,
});
const page = await browser.newPage({ viewport: { width: 1944, height: 800 } });
await page.setContent(html);
await page.screenshot({ path: "out/qa/contact.png", fullPage: true });
await browser.close();
