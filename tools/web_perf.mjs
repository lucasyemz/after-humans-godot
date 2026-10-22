// O roteiro de desempenho (#37) na versão web: serve build/web, abre no Chromium sem janela (WebGL 2 pelo SwiftShader
// quando não há placa), passa --perf ao jogo e devolve as linhas "PERF ..." do console. Também é a prova de que a web
// carrega e roda a Estação e uma luta (#39): sai com 1 se o jogo não terminar o roteiro.
//   "$GODOT" --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_perf.mjs [--only=station,street,combat] [--levels=0] [--timeout=900]
// Precisa do Playwright (npm i -g playwright) e de um Chromium.
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, resolve } from "node:path";
import { chromium } from "playwright";

const args = Object.fromEntries(process.argv.slice(2).map((a) => a.replace(/^--/, "").split("=")));
const root = resolve(args.dir ?? "build/web");
const only = args.only ?? "title,station,street,combat";
const levels = args.levels ?? "0";
const timeout = Number(args.timeout ?? 900) * 1000;
const types = { ".html": "text/html", ".js": "text/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png" };

// O GODOT_CONFIG do index.html exportado recebe os argumentos do roteiro; o resto sai como está.
const server = createServer(async (request, response) => {
	const path = join(root, decodeURIComponent(new URL(request.url, "http://x").pathname).replace(/\/$/, "/index.html"));
	try {
		let body = await readFile(path);
		if (path.endsWith("index.html")) {
			body = body.toString().replace(/"args":\[\]/, `"args":["--perf","--perf-only=${only}","--perf-levels=${levels}"]`);
		}
		response.writeHead(200, { "Content-Type": types[extname(path)] ?? "application/octet-stream" });
		response.end(body);
	} catch {
		response.writeHead(404);
		response.end();
	}
});
await new Promise((ok) => server.listen(0, ok));
const url = `http://127.0.0.1:${server.address().port}/index.html`;

const browser = await chromium.launch({ args: ["--enable-unsafe-swiftshader", "--use-angle=swiftshader", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const lines = [];
let finished = false;
const started = Date.now();
page.on("console", (message) => {
	const text = message.text();
	if (text.startsWith("PERF")) {
		lines.push(text);
		console.log(`${((Date.now() - started) / 1000).toFixed(1)}s ${text}`);
		if (text.startsWith("PERF fim")) finished = true;
	} else if (message.type() === "error") {
		console.log(`console error: ${text}`);
	}
});
page.on("pageerror", (error) => console.log(`page error: ${error.message}`));
await page.goto(url);
while (!finished && Date.now() - started < timeout) {
	await page.waitForTimeout(1000);
}
console.log(finished ? `web: roteiro completo em ${((Date.now() - started) / 1000).toFixed(0)} s` : "web: o roteiro não terminou no tempo");
await browser.close();
server.close();
process.exit(finished ? 0 : 1);
