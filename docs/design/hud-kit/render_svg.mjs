// Os SVG antigos de art/ui/icons/ em PNG (o Chromium do Playwright), para a prancha antiga ao lado da nova.
// node docs/design/hud-kit/render_svg.mjs <pasta> <lado> art/ui/icons/a.svg art/ui/icons/b.svg ...
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";
const [out, side, ...files] = process.argv.slice(2);
const b = await chromium.launch();
const p = await b.newPage({ deviceScaleFactor: 1 });
for (const f of files) {
  const svg = fs.readFileSync(f, "utf8");
  await p.setContent(`<html><body style="margin:0;background:transparent"><img id=i src="data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}" style="width:${side}px;height:${side}px;display:block"></body></html>`);
  await p.locator("#i").screenshot({ path: path.join(out, path.basename(f, ".svg") + `_${side}.png`), omitBackground: true });
}
await b.close();
