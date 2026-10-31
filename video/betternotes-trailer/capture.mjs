import { chromium } from "playwright";
import { writeFileSync } from "node:fs";
const browser = await chromium.launch({
  executablePath:
    "node_modules/.remotion/chrome-headless-shell/win64/chrome-headless-shell-win64/chrome-headless-shell.exe",
  headless: true,
  args: ["--no-sandbox"],
});
const page = await browser.newPage({
  viewport: { width: 1920, height: 1080 },
  deviceScaleFactor: 2,
});
await page.goto("http://127.0.0.1:8765/?capture=synthetic");
await page.waitForTimeout(2500);
await page
  .locator("flt-semantics-placeholder")
  .evaluateAll((els) => els.forEach((e) => e.click()));
await page.waitForTimeout(800);
await page.screenshot({ path: "public/screens/library.png" });
console.log("LIBRARY", (await page.locator("body").innerText()).slice(0, 3500));
await page.mouse.dblclick(470, 300);
await page.waitForTimeout(1000);
await page.screenshot({ path: "public/screens/editor.png" });
console.log("EDITOR", (await page.locator("body").innerText()).slice(0, 3500));
await page.mouse.click(1800, 500);
await page.waitForTimeout(700);
await page.screenshot({ path: "public/screens/writing.png" });
await page
  .getByRole("button", { name: "Text style options", exact: true })
  .click();
await page.waitForTimeout(400);
await page.screenshot({ path: "public/screens/formatting.png" });
console.log("FORMAT", (await page.locator("body").innerText()).slice(0, 2500));
await page.keyboard.press("Escape");
await page.mouse.click(1300, 600);
await page.getByRole("button", { name: "Draw", exact: true }).click();
await page.waitForTimeout(400);
console.log("DRAW", (await page.locator("body").innerText()).slice(0, 2500));
await page.mouse.move(520, 350);
await page.mouse.down();
for (let i = 0; i <= 40; i++)
  await page.mouse.move(520 + i * 17, 350 + Math.sin(i / 5) * 65);
await page.mouse.up();
await page.screenshot({ path: "public/screens/drawing.png" });
console.log(
  "DRAW BUTTONS",
  await page.locator("[role=button]").allTextContents(),
);
await page.getByRole("button", { name: "Done", exact: true }).click();
await page.waitForTimeout(400);
const art = await browser.newPage({
  viewport: { width: 900, height: 380 },
  deviceScaleFactor: 2,
});
await art.setContent(
  `<html><body style="margin:0"><svg xmlns="http://www.w3.org/2000/svg" width="900" height="380" viewBox="0 0 900 380"><rect width="900" height="380" fill="#e8f0fc"/><path d="M90 260 L90 130 Q200 95 340 140 L340 275 Q205 227 90 260 M340 140 Q480 95 590 130 L590 260 Q475 227 340 275" fill="white" stroke="#005fcc" stroke-width="6" stroke-linejoin="round"/><path d="M340 140 V275 M125 155 Q220 130 300 160 M125 185 Q220 160 300 190 M380 160 Q470 130 550 155 M380 190 Q470 160 550 185" stroke="#005fcc" stroke-width="4" fill="none"/><circle cx="720" cy="155" r="52" fill="#bce8d4"/><path d="M694 156 L714 176 L749 135" stroke="#1f6f43" stroke-width="7" fill="none" stroke-linecap="round"/><text x="644" y="260" font-family="Segoe UI" font-size="28" font-weight="600" fill="#1c1c1e">One good book.</text></svg></body></html>`,
);
await art.screenshot({ path: "public/screens/bookclub.png" });
await art.close();
const chooser = page.waitForEvent("filechooser");
await page.getByRole("button", { name: "Add image", exact: true }).click();
await (await chooser).setFiles("public/screens/bookclub.png");
await page.waitForTimeout(1200);
await page.screenshot({ path: "public/screens/visual-note.png" });
await page.getByRole("button", { name: "More actions", exact: true }).click();
await page.waitForTimeout(600);
console.log("MENU", (await page.locator("body").innerText()).slice(-2200));
await page.screenshot({ path: "public/screens/note-menu.png" });
await page.mouse.click(1750, 232);
await page.waitForTimeout(700);
await page.screenshot({ path: "public/screens/reminder.png" });
await page.keyboard.press("Escape");
await page.waitForTimeout(600);
await page.getByRole("button", { name: "More actions", exact: true }).click();
await page.waitForTimeout(600);
await page.mouse.click(1750, 472);
await page.waitForTimeout(700);
await page.screenshot({ path: "public/screens/cleanup.png" });
await page.keyboard.press("Escape");
await page.waitForTimeout(600);
await page.getByRole("button", { name: "More actions", exact: true }).click();
await page.waitForTimeout(600);
await page.mouse.click(1750, 280);
await page.waitForTimeout(700);
await page.screenshot({ path: "public/screens/history.png" });
await page.keyboard.press("Escape");
await page.waitForTimeout(600);
await page.mouse.click(28, 28);
await page.waitForTimeout(400);
await page.mouse.click(600, 145);
await page.keyboard.type("reading", { delay: 100 });
await page.waitForTimeout(500);
await page.screenshot({ path: "public/screens/search.png" });
console.log("SEARCH", (await page.locator("body").innerText()).slice(0, 1500));
await page.mouse.click(80, 1040);
await page.waitForTimeout(700);
await page.screenshot({ path: "public/screens/settings.png" });
console.log(
  "SETTINGS",
  (await page.locator("body").innerText()).slice(0, 3500),
);
writeFileSync("out/capture-dom.txt", await page.content());
await browser.close();
