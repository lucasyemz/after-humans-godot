// Lote 4: a HUD da luta montada só com o kit da Awesomic (art/ui/kit/station), nas medidas e na estrutura do alvo
// aprovado (docs/design/reference/hud-target-2026-10-25.webp e docs/design/hud-target.md).
// Fundo: a captura limpa do jogo (loop-screens/before/combat_clean.webp); unidades, vida, ordem e habilidades: os DTOs
// dessa captura (combat.json) e as cotações da sessão (hud-c/session_quotes.json).
// Uso (da raiz do repositório, com python3 -m http.server 8765 servindo a raiz):
//   node docs/design/hud-luta/render.mjs http://127.0.0.1:8765
import fs from "node:fs";
import { pathToFileURL } from "node:url";
import { setBase, BASE, KIT, nine, over, img, glyph, divider, run } from "../hud-kit/lib.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-luta/.render";
// A captura de base (os DTOs de loop-screens/before/<nome>.json): a luta do alvo é "combat"; o lote 6 (hud-laco) usa as
// dos laços. useCapture troca a captura; as partes da tela leem META, UNITS, ACTOR e ORDER daqui.
let META, QUOTES, UNITS, ACTOR, ORDER;
// O centro de cada unidade na captura: o meio da plaquinha do nome que o jogo desenha sob ela (como no render.py do alvo).
const center = (u) => {
  const t = META.texts.find((t) => t.text === u.name && t.rect[1] > 650 && t.rect[1] < 800);
  return Math.round(t.rect[0] + t.rect[2] / 2);
};
// Um nome com "/" é o caminho do DTO sem o .json (o lote do tutorial: docs/design/tutorial/before/fight_two_hud).
export function useCapture(name = "combat") {
  META = JSON.parse(fs.readFileSync(name.includes("/") ? `${name}.json` : `docs/design/loop-screens/before/${name}.json`, "utf8"));
  QUOTES = name === "combat" ? JSON.parse(fs.readFileSync("docs/design/hud-c/session_quotes.json", "utf8")).combat : quotesFrom(META);
  UNITS = META.units.map((u) => ({ ...u, cx: center(u) }));
  ACTOR = UNITS.find((u) => u.id === META.actor);
  // A ordem da rodada como a captura mostra (RODADA 1, Nick · agora, Íris, Emissor, Bento, Véspera, Recreador).
  ORDER = (() => {
    const ts = META.texts.map((t) => t.text);
    const i = ts.findIndex((t) => t.startsWith("RODADA"));
    const left = [...UNITS];
    // Até seis nomes depois de "RODADA"; com menos unidades (o tutorial tem quatro), para no primeiro texto que não é
    // de ninguém.
    const out = [];
    for (const n of ts.slice(i + 1, i + 7)) {
      const u = left.find((u) => u.name.includes(n.split(" · ")[0]));
      if (!u) break;
      left.splice(left.indexOf(u), 1);
      out.push(u);
    }
    return out;
  })();
}
// Sem as cotações da sessão (as capturas dos laços), as habilidades de quem age saem de data/abilities.json, na ordem da
// classe: dá para usar quando a posição de agora está entre as de origem, e o alcance é o texto que a captura mostra.
function quotesFrom(meta) {
  const actor = meta.units.find((u) => u.id === meta.actor);
  const ts = meta.texts.map((t) => t.text);
  const rows = JSON.parse(fs.readFileSync("data/abilities.json", "utf8")).filter((a) => a.ClassId === actor.class_id);
  return { options: rows.map((a) => ({ id: a.Name, name: a.DisplayName, usable: a.OriginRanks.includes(actor.rank),
    range: /^\d+–\d+$/.test(ts[ts.indexOf(a.DisplayName) + 1] || "") ? ts[ts.indexOf(a.DisplayName) + 1] : "", description: a.Description })) };
}
useCapture();
const FACE = { Bento: "bento", Nick: "nick", "Íris": "iris", "Véspera": "vespera" };
// Os rostos: o retrato dos heróis e, nas máquinas, o recorte do sprite (coordenadas do canvas 1178 convertidas para a
// textura de 589, como no render.py do alvo).
const SPRITE = { recreador: [360, 20, 800, 460], sussurrador: [360, 160, 850, 650] };
function face(u, size, bg) {
  let file, box, tex;
  if (u.player) { file = `art/ui/portraits/${FACE[u.name]}.png`; box = [40, 0, 230, 190]; tex = 256; }
  else { file = `art/combat/enemies/${u.enemy_id}/idle.webp`; box = SPRITE[u.enemy_id].map((n) => n * 0.5); tex = 589; }
  const k = size / (box[2] - box[0]);
  return `<div style="position:absolute;inset:3px;background:${bg} url(${BASE}/${file}) no-repeat;background-size:${tex * k}px auto;background-position:${-box[0] * k + 3}px ${-box[1] * k + 3}px;` +
    `background-origin:border-box;clip-path:polygon(5px 0,calc(100% - 5px) 0,100% 5px,100% calc(100% - 5px),calc(100% - 5px) 100%,5px 100%,0 calc(100% - 5px),0 5px)"></div>`;
}
// No daltonismo, o X (enemy_badge) no canto das máquinas: o fundo vermelho sozinho some no cinza.
const cell = (u, size, now, cb) => `<div style="position:relative;width:${size}px;height:${size}px;flex:none">${face(u, size - 6, u.player ? "#192026" : "#421b1b")}` +
  nine("square_portrait", { extra: "position:absolute;inset:0" }) + (now ? over("selected_frame") : "") +
  (cb && !u.player ? img(KIT.enemy_badge.file, "position:absolute;right:1px;bottom:1px;width:22px;height:22px") : "") + `</div>`;

// A tecla numa aba (key_tab, 42): 26 no Normal e 34 no Maior, sem mudar o tamanho da aba.
// Sem uso: a aba apaga junto com o quadrado.
const keyTab = (label, x, y, dim = false) => `<div class="abs" style="left:${x}px;top:${y}px;width:42px;height:42px;${dim ? "opacity:.55" : ""}">` +
  nine("key_tab", { pad: [2, 2, 2, 2], cls: "row", extra: "width:42px;height:42px;justify-content:center" }, `<span class="tx l1 f26 semi">${label}</span>`) + `</div>`;
const vida = (u) => `${Math.round(u.hp)}/${Math.round(u.max_hp)}`;

// ------------------------------------------------------------------ as partes da tela
// REGISTRO (L), na plaqueta do kit.
const register = () => `<div class="abs" data-hit="log" style="left:46px;top:32px">` +
  nine("room_plaque", { pad: [10, 14, 10, 24], cls: "row", extra: "width:272px;height:64px;gap:12px;justify-content:space-between" },
    `<span class="tx l1 f30 up">Registro</span>` + nine("key_tab", { pad: [2, 2, 2, 2], cls: "row", extra: "width:42px;height:42px;justify-content:center" }, `<span class="tx l1 f26 semi">L</span>`)) + `</div>`;

// A ordem da rodada: a faixa round_strip, o nome no bolso e os retratos a partir de x 244 da peça.
// Com menos de seis na ordem (o tutorial tem quatro), a faixa encolhe junto, centrada no mesmo lugar.
const order = (p) => `<div class="abs" style="left:${ORDER.length < 6 ? 996 - (226 + ORDER.length * 68 + 30) / 2 : 636}px;top:30px">` +
  nine("round_strip", { cls: "row", extra: `width:${ORDER.length < 6 ? 226 + ORDER.length * 68 + 30 : 720}px;height:64px;gap:0` },
    `<span class="tx l1 f30 up" style="width:178px;text-align:center;flex:none">Rodada 1</span><i style="width:48px;flex:none"></i>` +
    `<div class="row" style="gap:8px">${ORDER.map((u) => cell(u, 60, u.id === META.actor, p.cb)).join("")}</div>`) + `</div>`;

// O anel no chão, por baixo de Nick: a luz âmbar difusa e o anel (actor_ring 256x80 sem escala, centro nos pés, em y 748), os dois com uma
// máscara que tira o recorte do sprite de Nick (o mesmo sprite da captura, projetado em 659,467 com 264x300), para os pés
// e a cauda taparem o anel. No jogo: decalque com depth test.
const ring = () => {
  const cx = ACTOR.cx;
  const cut = (left, top) => `-webkit-mask-image:linear-gradient(#000,#000),url(${BASE}/art/combat/heroes/nick/idle.webp);` +
    `-webkit-mask-size:100% 100%,264px 300px;-webkit-mask-position:0 0,${659 - left}px ${467 - top}px;-webkit-mask-repeat:no-repeat;-webkit-mask-composite:source-out`;
  return `<div class="abs" style="left:${cx - 160}px;top:708px;width:320px;height:80px;background:radial-gradient(ellipse 142px 34px at 160px 40px,rgba(255,137,25,.30),rgba(255,137,25,0));${cut(cx - 160, 708)}"></div>` +
    `<div class="abs" style="left:${cx - 128}px;top:708px;width:256px;height:80px;background:url(${BASE}/${KIT.actor_ring.file}) 0 0/100% 100%;${cut(cx - 128, 708)}"></div>`;
};

// A vida sob cada unidade: main_bar com bar_fill tingido (ciano nos heróis, vermelho nos inimigos; azul e vermelhão no
// daltonismo), o valor dentro e a forma do lado na ponta esquerda (ally_mark sobe, enemy_mark desce).
// A forma do lado entra no daltonismo (no Normal a barra fica como a do alvo, sem a tampa).
const worldBar = (u, large, cb) => {
  const x = u.cx - 100, h = large ? 46 : 44, color = u.player ? "var(--ally)" : "var(--enemy)";
  const mark = u.player ? "ally_mark" : "enemy_mark", left = cb ? 30 : 8;
  return `<div class="abs" style="left:${x}px;top:760px;width:200px;height:${h}px">` +
    nine("main_bar", { pad: large ? [13, 8, 0, left] : [15, 8, 2, left], cls: "col", extra: `width:200px;height:${h}px` },
      `<div style="position:absolute;left:0;right:0;top:-10px;height:10px"><div style="height:100%;background:${color};-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%;width:${(u.hp / u.max_hp) * 100}%"></div></div>` +
      `<span class="tx f24 semi" style="text-align:center;line-height:1.05">${vida(u)}</span>`) +
    (u.id === META.actor ? nine("selected_corners", { cls: "over" }) : "") +
    // A tampa vai por cima das cantoneiras; no Maior (barra de 46) ela escala por igual, 46/44.
    (cb ? img(KIT[mark].file, `position:absolute;left:0;top:${u.player ? -12 * h / 44 : 0}px;width:${28 * h / 44}px;height:${56 * h / 44}px`) : "") + `</div>`;
};

// O nome do alvo: a aba escura (target_tab) assentada na linha da cor do inimigo.
const targetName = () => `<div class="abs col" style="left:1280px;top:348px;width:176px">` +
  nine("target_tab", { cls: "row", extra: "width:176px;min-height:calc(48px*var(--k));justify-content:center" }, `<span class="tx l1 f26 up">Recreador</span>`) +
  `<div style="height:5px;background:var(--enemy);box-shadow:0 0 6px rgba(0,0,0,.6)"></div></div>`;

// O herói da vez: um painel só (panel_large), o retrato grande na moldura vazada hero_tab, o nome, a vida e o instinto.
const hero = (large) => {
  const barH = large ? 52 : 40;
  const fillBar = (ratio, color, text) => nine("main_bar", { pad: [2, 8, 2, 8], cls: "row", extra: `width:308px;height:${barH}px;justify-content:center;position:relative` },
    `<div style="position:absolute;left:0;top:0;bottom:0;width:${ratio * 100}%;background:${color};-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div>` +
    `<span class="tx l1 f32 semi" style="position:relative">${text}</span>`);
  return `<div class="abs" style="left:64px;top:836px">` +
    nine("panel_large", { pad: [14, 22, 14, 14], cls: "row", extra: "width:564px;height:212px;gap:22px;align-items:center" },
      `<div data-hit="hero-inspect" style="position:relative;width:184px;height:184px;flex:none">` +
      `<div style="position:absolute;inset:4px;background:#1b1d20 url(${BASE}/art/ui/portraits/${FACE[ACTOR.name]}.png) no-repeat;background-size:${256 * 176 / 168}px auto;background-position:${-40 * 176 / 168}px ${-14 * 176 / 168}px"></div>` +
      nine("hero_tab", { extra: "position:absolute;inset:0" }) + `</div>` +
      `<div class="col" style="gap:${large ? 6 : 10}px;flex:1;min-width:0">` +
      `<span class="tx l1 f40 semi up" style="margin-bottom:${large ? 0 : 4}px">${ACTOR.name}</span>` +
      fillBar(ACTOR.hp / ACTOR.max_hp, "var(--ally)", vida(ACTOR)) + fillBar(ACTOR.instinct / 200, "var(--instinct)", `${ACTOR.instinct}/200`) + `</div>`) + `</div>`;
};

// As habilidades: a aba ESCOLHA UM ALVO, a barra com o ícone, o nome e o dano, e os quatro quadrados.
const RANGE = "4–6";
const rangeOf = (o) => o.range === undefined ? RANGE : o.range;
const ICON = (id) => `art/combat/icons/${id}.webp`;
// Do tutorial: aim = false é a vez de quem age, antes de escolher a habilidade (a aba diz "Vez de <nome>", nenhuma
// escolhida; a barra mostra a do foco do teclado, a primeira, como _show_header faz ao começar a vez).
function abilities(large, { selected = 0, focus = -1, pressed = -1, aim = true } = {}) {
  const opt = QUOTES.options;
  const sel = opt[selected < 0 ? 0 : selected];
  const tab = `<div class="abs" style="left:856px;top:816px">` +
    nine("target_tab", { cls: "row", extra: `width:336px;height:${large ? 44 : 40}px;padding-left:6px` }, `<span class="tx l1 f26 up">${aim ? "Escolha um alvo" : `Vez de ${ACTOR.name}`}</span>`) + `</div>`;
  const head = `<div class="abs" style="left:684px;top:852px">` +
    nine("ability_header", { cls: "row", extra: "width:624px;height:56px;gap:0" },
      `<div style="width:42px;height:42px;flex:none;margin-left:2px;background:url(${BASE}/${ICON(sel.id)}) center/cover;clip-path:polygon(5px 0,calc(100% - 5px) 0,100% 5px,100% calc(100% - 5px),calc(100% - 5px) 100%,5px 100%,0 calc(100% - 5px),0 5px)"></div>` +
      `<span class="tx l1 f32 up" style="margin-left:14px;flex:1;min-width:0">${sel.name}</span>` +
      `<span class="tx l1 f28" style="width:104px;text-align:center;flex:none">${rangeOf(sel)}</span>`) + `</div>`;
  const slots = opt.map((o, i) => {
    const x = 688 + i * 160, y = 916;
    const state = !o.usable ? "ability_slot_disabled" : i === pressed ? "ability_slot_pressed" : "ability_slot";
    const shift = i === pressed ? 2 : 0;
    return `<div class="abs" data-hit="ability" style="left:${x}px;top:${y}px;width:132px;height:132px">` +
      `<div style="position:absolute;left:8px;top:${8 + shift}px;width:116px;height:116px;background:url(${BASE}/${ICON(o.id)}) center/cover;${o.usable ? "" : "filter:grayscale(1) brightness(.6)"}"></div>` +
      img(KIT[state].file, `position:absolute;inset:0;width:132px;height:132px`) +
      (i === selected ? nine("selected_corners", { cls: "over" }) : "") + (i === focus ? nine("focus_frame", { cls: "over" }) : "") + `</div>` +
      keyTab(String(i + 1), x + 90, y + 90, !o.usable);
  }).join("");
  return head + tab + slots;
}

// As ações: a grade 2x2 de botões quadrados (icon_button), o ícone branco de linha e a tecla na aba. F é Fugir: a porta.
const ACTIONS = [["intent-move.svg", "Q"], ["intent-block.svg", "W"], ["item-generic.svg", "I"], ["exit", "F"]];
const actions = () => ACTIONS.map(([icon, cap], i) => {
  const x = 1584 + (i % 2) * 136, y = 836 + Math.floor(i / 2) * 112;
  const g = icon === "exit" ? `<i class="glyph" style="width:44px;height:44px;background:var(--text);-webkit-mask-image:url(${BASE}/art/ui/kit/combat/exit.webp)"></i>` : glyph(icon, 44);
  return `<div class="abs" data-hit="action" style="left:${x}px;top:${y}px;width:128px;height:100px">` +
    nine("icon_button", { pad: [14, 14, 14, 14], cls: "row", extra: "width:128px;height:100px;justify-content:center;align-items:flex-start;padding-top:10px" }, g) + `</div>` +
    keyTab(cap, x + 78, y + 54);
}).join("");

const EXTRA = (p) => `<style>:root{--enemy:${p.cb ? "var(--danger-fill)" : "#d23a2e"}}.l1{line-height:1.1}</style>`;
const BG = (name = "combat") => img(name.includes("/") ? `${name}_clean.webp` : `docs/design/loop-screens/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px") +
  `<div class="abs" style="left:0;top:796px;width:1920px;height:284px;background:linear-gradient(rgba(0,0,0,0),rgba(0,0,0,.24))"></div>`;

// Opções do lote 6 (hud-laco): o fundo da captura, sem o anel (a máscara dele é a do sprite de Nick) e sem o nome do
// alvo, e o que vai por cima (extra).
export const combat = (p, { bg = "combat", withRing = true, target = true, extra = "", aim = true } = {}) => {
  const large = p.k > 1;
  return EXTRA(p) + BG(bg) + (withRing ? ring() : "") + UNITS.map((u) => worldBar(u, large, p.cb)).join("") + (target ? targetName() : "") +
    register() + order(p) + hero(large) + abilities(large, aim ? {} : { selected: -1, aim: false }) + actions() + extra;
};

// ------------------------------------------------------------------ a prancha dos estados
// Cada peça nova nos estados que ela tem, sobre o aço escuro, com o nome do estado embaixo.
const label = (t) => `<span class="tx f20 muted up" style="margin-top:8px">${t}</span>`;
function states(p) {
  const large = p.k > 1;
  const opt = QUOTES.options;
  const slot = (o, kind) => {
    const off = kind.startsWith("disabled");
    const piece = off ? "ability_slot_disabled" : kind === "pressed" ? "ability_slot_pressed" : "ability_slot";
    const shift = kind === "pressed" ? 2 : 0;
    return `<div class="col" style="align-items:center"><div style="position:relative;width:132px;height:132px" data-hit="ability">` +
      `<div style="position:absolute;left:8px;top:${8 + shift}px;width:116px;height:116px;background:url(${BASE}/${ICON(o.id)}) center/cover;${off ? "filter:grayscale(1) brightness(.6)" : ""}"></div>` +
      img(KIT[piece].file, "position:absolute;inset:0;width:132px;height:132px") +
      (kind === "selected" || kind === "both" ? nine("selected_corners", { cls: "over" }) : "") + (kind === "focus" || kind === "both" || kind === "disabled_focus" ? nine("focus_frame", { cls: "over" }) : "") +
      (kind === "uses" ? `<div class="abs" style="left:6px;top:6px">${nine("cost_chip", { cls: "row", extra: "min-height:32px;gap:4px" }, `<span class="tx l1 f20 amber">Recarga 2</span>`)}</div>` : "") +
      `<div class="abs" style="left:90px;top:90px;${off ? "opacity:.55" : ""}">${nine("key_tab", { pad: [2, 2, 2, 2], cls: "row", extra: "width:42px;height:42px;justify-content:center" }, `<span class="tx l1 f26 semi">${opt.indexOf(o) + 1}</span>`)}</div>` +
      `</div>${label({ normal: "Normal", focus: "Foco", pressed: "Pressionado", disabled: "Sem uso", disabled_focus: "Sem uso + foco", selected: "Escolhida", both: "Escolhida + foco", uses: "Recarga" }[kind])}` +
      (kind === "disabled_focus" ? `<div style="margin-top:6px">${nine("panel_inset", { cls: "col", extra: "width:220px" }, `<span class="tx f22 semi danger">Sem alvo válido</span><span class="wrap f20 muted">${opt[3].description.split("\n")[0]}</span>`)}</div>` : "") + `</div>`;
  };
  const row1 = `<div class="row" style="gap:28px;align-items:flex-start">` +
    [[opt[1], "normal"], [opt[1], "focus"], [opt[1], "pressed"], [opt[0], "selected"], [opt[0], "both"], [opt[2], "uses"], [opt[3], "disabled"], [opt[1], "disabled"], [opt[3], "disabled_focus"]].map(([o, k]) => slot(o, k)).join("") + `</div>`;
  const reason = `<div class="col" style="gap:0">` +
    nine("target_tab", { cls: "row", extra: `width:336px;height:${large ? 44 : 40}px;padding-left:6px` }, `<span class="tx l1 f26 up danger">Sem alvo válido</span>`) +
    nine("ability_header", { cls: "row", extra: "width:624px;height:56px;margin-top:-4px" },
      `<div style="width:42px;height:42px;flex:none;margin-left:2px;background:url(${BASE}/${ICON(opt[3].id)}) center/cover;filter:grayscale(1) brightness(.6)"></div>` +
      `<span class="tx l1 f32 up muted" style="margin-left:14px;flex:1;min-width:0">${opt[3].name}</span><span class="tx l1 f28 muted" style="width:104px;text-align:center;flex:none">7–10</span>`) +
    label("Habilidade sem alvo: o motivo na aba, na cor de perigo") + `</div>`;
  const choose = `<div class="col" style="gap:0">` +
    nine("target_tab", { cls: "row", extra: `width:336px;height:${large ? 44 : 40}px;padding-left:6px` }, `<span class="tx l1 f26 up">Escolha um alvo</span>`) +
    nine("ability_header", { cls: "row", extra: "width:624px;height:56px;margin-top:-4px" },
      `<div style="width:42px;height:42px;flex:none;margin-left:2px;background:url(${BASE}/${ICON(opt[0].id)}) center/cover"></div>` +
      `<span class="tx l1 f32 up" style="margin-left:14px;flex:1;min-width:0">${opt[0].name}</span><span class="tx l1 f28" style="width:104px;text-align:center;flex:none">${RANGE}</span>`) +
    label("A aba e a barra da habilidade") + `</div>`;
  const strip = `<div class="col">` + nine("round_strip", { cls: "row", extra: "width:720px;height:64px;gap:0" },
    `<span class="tx l1 f30 up" style="width:178px;text-align:center;flex:none">Rodada 1</span><i style="width:48px;flex:none"></i>` +
    `<div class="row" style="gap:8px">${ORDER.map((u) => cell(u, 60, u.id === META.actor, p.cb)).join("")}</div>`) +
    label("A ordem: quem age com o âmbar; máquinas em fundo vermelho (e o X no daltonismo)") + `</div>`;
  const bars = `<div class="col"><div class="row" style="gap:24px;padding-top:14px">` +
    [UNITS[1], UNITS[0], UNITS[4]].map((u) => `<div style="position:relative;width:200px;height:${large ? 50 : 44}px">${worldBar({ ...u, cx: 100 }, large, true).replace('class="abs" style="left:0px;top:760px;', 'style="position:relative;')}</div>`).join("") +
    `</div>${label("Vida no daltonismo: quem age, herói (a aba sobe) e inimigo (os dentes descem)")}</div>`;
  const ringBox = `<div class="col" style="align-items:center"><div style="position:relative;width:320px;height:96px;background:#2b2a2a">` +
    `<div class="abs" style="inset:0;background:radial-gradient(ellipse 142px 34px at 160px 48px,rgba(255,137,25,.30),rgba(255,137,25,0))"></div>` +
    img(KIT.actor_ring.file, "position:absolute;left:32px;top:8px;width:256px;height:80px") + `</div>${label("O anel no chão (sem pulso ao reduzir efeitos)")}</div>`;
  return EXTRA(p) + `<div class="abs" style="inset:0;background:#151719 url(${BASE}/art/ui/kit/combat/steel_material.webp);background-blend-mode:multiply"></div>` +
    `<div class="abs col" style="left:60px;top:44px;gap:40px">` +
    `<span class="tx f40 semi up">Peças da luta no kit da Awesomic: os estados</span>` + row1 +
    `<div class="row" style="gap:60px;align-items:flex-start">${choose}${reason}</div>` +
    `<div class="row" style="gap:60px;align-items:flex-start">${strip}${ringBox}</div>` + bars + `</div>`;
}

// Importado (o lote 6), este arquivo não gera nada.
if (import.meta.url === pathToFileURL(process.argv[1]).href) await run({ combat: (p) => combat(p), states }, OUT);
