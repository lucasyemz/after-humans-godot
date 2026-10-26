// Monta as telas da Estação (relatório da volta e Sala dos Personagens) sobre capturas reais do jogo, com as peças de
// art/ui/kit/station/ e do kit da luta, nos perfis Normal, Maior (130%), daltonismo e Maior com daltonismo.
// As peças entram como 9-slice (border-image, as mesmas margens do assets.json que a Godot usa no StyleBoxTexture).
// Texto pela Barlow Condensed, nunca dentro das imagens. Grava as telas em PNG temporário (o compose.py faz os WebP) e
// checks.json com cada caixa de texto, se coube, e os alvos de toque.
//
// Uso (da raiz do repositório): node docs/design/hud-station/render.mjs <url-base-do-servidor> <pasta-de-saída>
// O servidor serve a raiz do repositório (python3 -m http.server), porque as máscaras de ícone pedem http.
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

const BASE = process.argv[2] || "http://127.0.0.1:8765";
const OUT = process.argv[3] || "docs/design/hud-station/.render";
fs.mkdirSync(OUT, { recursive: true });
const KIT = JSON.parse(fs.readFileSync("art/ui/kit/station/assets.json", "utf8")).assets;
const COMBAT = JSON.parse(fs.readFileSync("art/ui/kit/combat/assets.json", "utf8")).assets;

const PROFILES = {
  normal: { k: 1, cb: false },
  large: { k: 1.3, cb: false },
  colorblind: { k: 1, cb: true },
  large_colorblind: { k: 1.3, cb: true },
};

// ------------------------------------------------------------------ peças
function nine(key, { repeat = "stretch", extra = "", cls = "", attrs = "", pad = null } = {}, inner = "") {
  const row = KIT[key] || COMBAT[key];
  const [l, t, r, b] = row.nine_slice_ltrb;
  const [sw, sh] = row.size;
  // A borda desenhada (as margens do 9-slice) e o recuo do conteúdo (content_xywh) são coisas separadas, como na Godot:
  // texture_margin_* e content_margin_* do StyleBoxTexture.
  const c = row.content_xywh;
  const [pt, pr, pb, pl] = pad || (c ? [c[1], sw - c[0] - c[2], sh - c[1] - c[3], c[0]] : [0, 0, 0, 0]);
  const src = `${BASE}/${row.file}`;
  return `<div class="nine ${cls}" ${attrs} style="border-width:${pt}px ${pr}px ${pb}px ${pl}px;border-image:url(${src}) ${t} ${r} ${b} ${l} fill / ${t}px ${r}px ${b}px ${l}px ${repeat};${extra}">${inner}</div>`;
}
const over = (key, extra = "") => nine(key, { cls: "over", extra });
const img = (file, style = "") => `<img src="${BASE}/${file}" style="${style}">`;
// Glifo branco de um tom, tingido pela cor (como o modulate da Godot).
const glyph = (name, size, color = "var(--text)", style = "") => {
  const file = name.endsWith(".svg") ? `art/ui/icons/${name}` : `art/ui/kit/station/icons/${name}.webp`;
  return `<i class="glyph" style="width:${size}px;height:${size}px;background:${color};-webkit-mask-image:url(${BASE}/${file});${style}"></i>`;
};
const key = (label) => `<span class="key">${img(COMBAT.key_tab.file, "position:absolute;inset:0;width:100%;height:100%")}<b>${label}</b></span>`;
const bar = (w, h, ratio, color) =>
  `<div class="bar" style="width:${w}px;height:${h}px">${nine("main_bar", { extra: "position:absolute;inset:0" })}` +
  `<div class="fill" style="left:7px;top:6px;bottom:6px;width:calc((100% - 14px) * ${ratio});background:${color};-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div></div>`;
const portrait = (hero, size) =>
  `<div class="portrait" style="width:${size}px;height:${size}px">${img(`art/ui/portraits/${hero}.png`, `position:absolute;left:4px;top:4px;width:${size - 8}px;height:${size - 8}px;object-fit:cover`)}` +
  nine("square_portrait", { extra: "position:absolute;inset:0" }) + `</div>`;

const STATES = {
  // Sem gênero nos dados dos heróis, os rótulos ficam neutros (o alvo dizia "Levemente ferida" para a Íris e a Véspera).
  active: { label: "Em forma", icon: "state_active" },
  light_wound: { label: "Ferimento leve", icon: "state_light_wound" },
  wounded: { label: "Ferimento grave", icon: "state_wounded" },
};
const pill = (state, cb) => {
  const tint = cb ? KIT.status_pill.tint.colorblind[state] : KIT.status_pill.tint[state];
  const ink = state === "wounded" && !cb ? "#fff6ee" : "#15110b";
  return `<div class="pill" data-role="pill">${img(KIT.status_pill.file, "position:absolute;inset:0;width:100%;height:100%")}` +
    `<div class="tint" style="background:${tint};-webkit-mask-image:url(${BASE}/${KIT.status_pill.file})"></div>` +
    `${glyph(STATES[state].icon, 22, ink, "position:relative")}<span class="tx" style="color:${ink}">${STATES[state].label}</span></div>`;
};

// ------------------------------------------------------------------ CSS
const css = (p) => `
@font-face{font-family:Barlow;src:url(${BASE}/art/ui/fonts/barlow_condensed_medium.ttf);font-weight:500}
@font-face{font-family:Barlow;src:url(${BASE}/art/ui/fonts/barlow_condensed_semibold.ttf);font-weight:600}
:root{--k:${p.k};--text:#efe6d6;--muted:#b3a993;--amber:#f0a020;--ally:${p.cb ? "#56b4e9" : "#2fb6bd"};
--good:${p.cb ? "#56b4e9" : "#6cc77c"};--danger:${p.cb ? "#e8743a" : "#e2584a"};--danger-fill:${p.cb ? "#d55e00" : "#d23a2e"};--xp:#b7a6f4;--instinct:#c07a3c}
*{box-sizing:border-box;margin:0;padding:0}
body{width:1920px;height:1080px;overflow:hidden;position:relative;font-family:Barlow;font-weight:500;color:var(--text);background:#000}
.bg{position:absolute;inset:0;width:1920px;height:1080px}
.abs{position:absolute}
.nine{border-style:solid;position:relative}
.over{position:absolute;inset:0;pointer-events:none}
.glyph{display:inline-block;flex:none;-webkit-mask-size:contain;-webkit-mask-repeat:no-repeat;-webkit-mask-position:center}
.row{display:flex;align-items:center}
.col{display:flex;flex-direction:column}
.tx{white-space:nowrap;line-height:1.14}
.wrap{white-space:normal;line-height:1.18}
.up{text-transform:uppercase;letter-spacing:.02em}
.semi{font-weight:600}
.f18{font-size:calc(18px*var(--k))}.f20{font-size:calc(20px*var(--k))}.f22{font-size:calc(22px*var(--k))}
.f24{font-size:calc(24px*var(--k))}.f26{font-size:calc(26px*var(--k))}.f28{font-size:calc(28px*var(--k))}
.f30{font-size:calc(30px*var(--k))}.f32{font-size:calc(32px*var(--k))}.f34{font-size:calc(34px*var(--k))}
.f36{font-size:calc(36px*var(--k))}.f40{font-size:calc(40px*var(--k))}.f44{font-size:calc(44px*var(--k))}
.f52{font-size:calc(52px*var(--k))}.f76{font-size:calc(76px*var(--k))}
.muted{color:var(--muted)}.amber{color:var(--amber)}.good{color:var(--good)}.danger{color:var(--danger)}
.key{position:relative;display:inline-flex;align-items:center;justify-content:center;min-width:calc(36px*var(--k));height:calc(36px*var(--k));padding:0 9px;flex:none}
.key b{position:relative;font-weight:600;font-size:calc(20px*var(--k));color:var(--text)}
.bar{position:relative;flex:none}
.fill{position:absolute}
.portrait{position:relative;flex:none}
.pill{position:relative;display:inline-flex;align-items:center;gap:8px;height:calc(34px*var(--k));padding:0 14px 0 10px;flex:none}
.pill .tint{position:absolute;inset:0;-webkit-mask-size:100% 100%;mix-blend-mode:multiply}
.pill .tx{position:relative;font-size:calc(22px*var(--k));font-weight:600}
.shadow{text-shadow:0 2px 3px rgba(0,0,0,.65)}
`;

// ------------------------------------------------------------------ relatório da volta
const TEAM = [
  { hero: "bento", name: "Bento", cls: "Cão Protetor", hp: 34, max: 34, state: "active", exp: 1, kills: 3 },
  { hero: "nick", name: "Nick", cls: "Gato Batedor", hp: 8, max: 24, state: "wounded", exp: 1, kills: 2 },
  { hero: "iris", name: "Íris", cls: "Sapo Química", hp: 17, max: 23, state: "light_wound", exp: 1, kills: 0 },
  { hero: "vespera", name: "Véspera", cls: "Coruja Atiradora", hp: 30, max: 30, state: "active", exp: 1, kills: 4 },
];

function chip(icon, l1, l2, color) {
  return nine("result_chip", { cls: "row", attrs: 'data-hit="chip"', extra: `gap:12px;padding:0 6px;min-width:232px;min-height:88px;height:auto` },
    `${glyph(icon, 44, color)}<div class="col"><span class="tx f24" style="color:${color}">${l1}</span><span class="tx f24" style="color:${color}">${l2}</span></div>`);
}
function resource(icon, value, label) {
  return `<div class="col" style="align-items:center;gap:4px">` +
    nine("resource_tile", { extra: "width:104px;height:84px;display:flex;align-items:center;justify-content:center" }, glyph(icon, 46, "var(--text)")) +
    `<span class="tx f32 semi amber" style="line-height:1">${value}</span><span class="tx f20" style="line-height:1.1">${label}</span></div>`;
}
function card(h, p) {
  const ratio = h.hp / h.max;
  const color = ratio < 0.5 ? "var(--danger-fill)" : "var(--ally)";
  // A carta cresce para baixo (o topo fica abaixo dos pés da fila), para nunca cobrir os heróis, nem no Maior.
  // No Maior, a VIDA fica na mesma linha da barra, para a carta caber entre os pés da fila e o botão.
  const large = p.k > 1;
  const life = large
    ? `<div class="row" style="gap:10px"><span class="tx f22 muted up">Vida</span><span class="tx f24">${h.hp} / ${h.max}</span>${bar(196, 20, ratio, color)}</div>`
    : `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f22 muted up">Vida</span><span class="tx f24">${h.hp} / ${h.max}</span></div>${bar(340, 26, ratio, color)}</div>`;
  return `<div class="abs" data-hit="card" style="left:${h.x}px;top:calc(678px - 4px*(var(--k) - 1)/0.3);width:380px">` +
    `<div data-hit="card-tab" style="position:absolute;left:28px;top:calc(-34px*var(--k) + 12px*(var(--k) - 1)/0.3);width:244px;height:calc(40px*var(--k));z-index:2">` +
    nine("card_tab", { cls: "row", extra: `width:100%;height:100%;gap:8px` },
      `${glyph("train", 22, "var(--amber)")}<span class="tx f22 amber">Melhoria · 3 frag.</span>`) + `</div>` +
    nine("hero_card", { repeat: "round", cls: "col", extra: `width:380px;gap:${large ? 3 : 8}px;padding:0` },
      `<div class="row" style="gap:16px;align-items:flex-start">${portrait(h.hero, 92)}<div class="col" style="gap:4px;min-width:0">` +
      `<span class="tx f36 semi up">${h.name}</span><span class="tx f22 muted">${h.cls}</span>${pill(h.state, p.cb)}</div></div>` +
      life +
      `<div class="row" style="gap:10px">${glyph("expeditions", 28)}<span class="tx f20 muted">Expedições</span><span class="tx f24">${h.exp}</span>` +
      `<i style="width:2px;align-self:stretch;background:#0a0b0c;border-right:1px solid #44484e;margin:0 8px"></i>` +
      `${glyph("kills", 28)}<span class="tx f20 muted">Abates</span><span class="tx f24">${h.kills}</span></div>` +
      `<div class="row" style="gap:12px">${glyph("relic_empty", 28, "var(--muted)")}<span class="tx f22">Sem relíquia</span></div>`) +
    `</div>`;
}
function primary(label, keyLabel, icon, x, y, w, state = "normal", ink = "#1a1206") {
  const keyName = state === "normal" ? "primary_button" : `primary_button_${state}`;
  return `<div class="abs" data-hit="primary" style="left:${x}px;top:${y}px;width:${w}px">` +
    nine(keyName, { cls: "row", extra: `width:100%;height:calc(72px*var(--k));min-height:72px;gap:14px;justify-content:center;padding:0 2px` },
      `${glyph(icon, 34, ink)}<span class="tx f30 semi up" style="color:${ink}">${label}</span>` +
      nine("button_key", { cls: "row", extra: "height:calc(40px*var(--k));margin-left:8px;padding:0 4px" }, `<span class="tx f22">${keyLabel}</span>`)) +
    `</div>`;
}
function reportHTML(p, details) {
  const band = nine("report_band", { repeat: "round", cls: "row", extra: "position:absolute;left:36px;top:24px;width:1848px;min-height:216px;align-items:stretch" },
    `<div class="col" style="flex:none;min-width:600px;gap:6px;justify-content:center;padding-left:6px">` +
    `<div class="row" style="gap:12px">${glyph("station", 30, "var(--text)")}<span class="tx f22 up muted" style="letter-spacing:.08em">Estação Raiz · Relatório da expedição</span></div>` +
    `<span class="tx f76 semi up" style="letter-spacing:.01em">Rua das Vitrines</span>` +
    `<div class="row" style="gap:12px">${glyph("state_active", 34, "var(--good)")}<span class="tx f32 good">Expedição concluída</span></div></div>` +
    img(KIT.band_divider.file, "width:12px;height:176px;align-self:center;margin:0 22px") +
    `<div class="col" style="flex:1;min-width:0;gap:16px;justify-content:center"><div class="row" style="gap:14px;flex-wrap:wrap">` +
    chip("guardian_defeated", "Guardião", "derrotado", "var(--text)") + chip("place_unlocked", "Ponte das Raízes", "liberada", "var(--text)") +
    chip("objective_failed", "Objetivo: água", "não cumprido", "var(--danger)") + `</div>` +
    `<div class="row" style="gap:14px">${glyph("bed", 32, "var(--text)")}<span class="wrap f24">Descanse no Dormitório antes da próxima expedição.</span></div></div>` +
    img(KIT.band_divider.file, "width:12px;height:176px;align-self:center;margin:0 22px") +
    `<div class="col" style="flex:none;gap:6px;justify-content:center"><span class="tx f24 up muted" style="letter-spacing:.06em">Recursos recuperados</span>` +
    `<div class="row" style="gap:22px;align-items:flex-start">${resource("lobby-seed.svg", "+6", "Sementes")}${resource("lobby-scrap.svg", "+3", "Sucata")}${resource("lobby-fragment.svg", "+1", "Fragmento")}</div></div>`);
  // Os detalhes de hoje (o que a equipe viu, o que chegou, a Estação no ciclo, o que dá para fazer agora) trocam de lugar
  // com as cartas: Ver detalhes mostra a segunda faixa embaixo, no lugar da equipe; Ver a equipe volta às cartas.
  let lower;
  if (details) {
    const column = (title, body, w) => `<div class="col" style="width:${w}px;flex:none;gap:8px"><span class="tx f24 up amber" style="letter-spacing:.06em">${title}</span>${body}</div>`;
    const line = (icon, t) => `<div class="row" style="gap:10px;align-items:flex-start">${icon ? glyph(icon, 26, "var(--text)") : `<i style="width:8px;height:8px;margin-top:calc(9px*var(--k));background:var(--amber);transform:rotate(45deg);flex:none"></i>`}<span class="wrap f22">${t}</span></div>`;
    const divider = img(KIT.band_divider.file, "width:12px;height:176px;margin:0 20px;flex:none;align-self:center");
    lower = `<div class="abs" data-hit="details" style="left:96px;top:668px;width:1728px">` +
      nine("report_band", { repeat: "round", cls: "row", extra: "width:100%;min-height:256px;align-items:flex-start" },
        column("O que a equipe viu", `<span class="wrap f24">A Estação aguenta mais alguns dias. O que os Antigos deixaram, ninguém aqui sabe fazer de novo.</span>`, 430) + divider +
        column("O que chegou", line("lobby-seed.svg", "+6 sementes") + line("lobby-scrap.svg", "+3 sucatas") + line("lobby-fragment.svg", "+1 fragmento"), 230) + divider +
        column("A Estação no ciclo 1", `<span class="wrap f22">A Cantina produziu 2 suprimentos; os moradores comeram 0; estragaram 0.</span><span class="wrap f22">Água: 3 bebida, 2 do coletor.</span>`, 380) + divider +
        column("Agora dá para", line("", "Recuperar a Forja (4 sucatas)") + line("", "Recuperar o Centro de Pesquisa (3 sucatas e 2 fragmentos)") + line("", "Melhorar o Depósito (5 sucatas e 1 fragmento)"), 420)) +
      `</div>`;
  } else {
    const xs = [146, 562, 978, 1394];
    lower = TEAM.map((h, i) => card({ ...h, x: xs[i] }, p)).join("");
  }
  // O botão principal e VER DETALHES numa linha só, centrada no pé da tela: no Maior os dois crescem sem se encostar.
  const toggle = `<div class="abs row" style="left:0;right:0;bottom:14px;justify-content:center;gap:24px;padding-left:274px">` +
    `<div data-hit="primary" style="min-width:480px">` +
    nine("primary_button", { cls: "row", extra: `width:100%;height:calc(72px*var(--k));gap:14px;justify-content:center` },
      `${glyph("station", 34, "#1a1206")}<span class="tx f30 semi up" style="color:#1a1206">Entrar no abrigo</span>` +
      nine("button_key", { cls: "row", extra: "height:calc(40px*var(--k));margin-left:8px;padding:0 4px" }, `<span class="tx f22">E / A</span>`)) + `</div>` +
    `<div data-hit="details-toggle">` + nine("secondary_button", { cls: "row", extra: "height:calc(64px*var(--k));gap:12px;padding:0 4px" },
      `<span class="tx f24 up">${details ? "Ver a equipe" : "Ver detalhes"}</span>${key("V / LB")}`) + `</div></div>`;
  // Os corpos da fila na captura (caixas medidas na imagem): nada da interface pode cobri-los.
  const bodies = [[428, 466, 104, 176], [662, 488, 90, 154], [866, 500, 96, 142], [1058, 472, 136, 170]]
    .map(([x, y, w, hh]) => `<div class="abs" data-hit="hero-body" style="left:${x}px;top:${y}px;width:${w}px;height:${hh}px"></div>`).join("");
  return `<img class="bg" src="${BASE}/docs/design/hud-v2/before/station-report_clean.webp">${bodies}${band}${lower}${toggle}` +
    "";
}

// ------------------------------------------------------------------ Sala dos Personagens
const ABILITIES = [
  ["cao_punho_sucata", "Punho de Sucata"], ["cao_impacto_hidraulico", "Impacto Hidráulico"],
  ["cao_fique_atras_de_mim", "Fique Atrás de Mim"], ["cao_nao_estamos_sos", "Não Estamos Sós"],
];
function topBar() {
  const res = (icon, label, value, sub, warn) =>
    nine("resource_chip", { cls: "row", extra: "min-width:252px;min-height:96px;gap:12px" },
      `${glyph(icon, 40, warn ? "var(--danger)" : "var(--text)")}<div class="col" style="gap:1px"><span class="tx f20 up muted">${label}</span>` +
      `<span class="tx f26 semi ${warn ? "danger" : "amber"}">${value}</span><span class="tx f20 ${warn ? "danger" : "muted"}">${sub}</span></div>`);
  return `<div class="abs" style="left:28px;top:14px">` +
    nine("room_plaque", { cls: "row", extra: "min-width:520px;min-height:96px;gap:16px" },
      `${glyph("station", 52)}<div class="col"><span class="tx f40 semi up">Estação Raiz</span><span class="tx f24 muted">Sala dos Personagens</span></div>`) + `</div>` +
    `<div class="abs row" style="right:28px;top:14px;gap:10px;align-items:stretch">` +
    res("lobby-food.svg", "Comida", "0 / 12 suprimentos", "Falta na volta", true) +
    res("lobby-water.svg", "Água", "6 em estoque", "Próxima volta: 4", false) +
    res("lobby-energy.svg", "Energia", "1 / 3 em uso", "2 livres", false) +
    `<div data-hit="options">` + nine("icon_button", { extra: "width:92px;height:100%;min-height:96px;display:flex;align-items:center;justify-content:center" }, glyph("lobby-settings.svg", 48)) + `</div></div>`;
}
function leftColumn() {
  const tabs = [["bento", "Bento"], ["nick", "Nick"], ["iris", "Íris"], ["vespera", "Véspera"]].map(([h, n], i) =>
    `<div class="col" data-hit="hero-tab" style="width:116px;height:calc(104px + 28px*var(--k));position:relative;align-items:center">` +
    `<div style="position:absolute;left:6px;top:6px;right:6px;height:92px;overflow:hidden;background:#192026">${img(`art/ui/portraits/${h}.png`, "width:100%;height:100%;object-fit:cover;object-position:50% 15%")}</div>` +
    `<div class="row" style="position:absolute;left:6px;right:6px;bottom:6px;top:98px;background:#101214;justify-content:center"><span class="tx f22 ${i === 0 ? "amber" : ""}">${n}</span></div>` +
    nine("hero_tab", { extra: "position:absolute;inset:0" }) + (i === 0 ? over("hero_tab_selected") : "") + `</div>`).join("");
  const rows = ABILITIES.map(([id, name], i) =>
    `<div data-hit="ability" style="position:relative">` + nine("list_row", { cls: "row", extra: "width:538px;min-height:60px;gap:14px" },
      `${img(`art/combat/icons/${id}.webp`, "width:44px;height:44px;border:1px solid #3a3e44")}<span class="tx f28">${name}</span>`) +
    (i === 0 ? over("list_row_selected") : "") + `</div>`).join("");
  const detail = nine("panel_inset", { cls: "col", extra: "width:538px;gap:6px;flex:none" },
    `<span class="tx f32 semi">Punho de Sucata</span><span class="tx f28 semi amber">Dano 5–8</span>` +
    `<div class="row" style="gap:24px"><span class="tx f22 muted">Origem: posições 1 · 2</span><span class="tx f22 muted">Alvo: posições 1 · 2</span></div>` +
    `<span class="wrap f24">Golpe frontal; remove 1 Bloqueio antes do dano.</span><span class="tx f22 danger">Inimigo</span>`);
  return `<div class="abs" style="left:28px;top:132px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:600px;height:calc(1080px - 132px - 14px - 72px*var(--k) - 10px - 64px - 14px);gap:12px;overflow:hidden" },
    `<div class="row" style="gap:14px;flex:none">${tabs}</div>${img(KIT.divider.file, "width:552px;height:8px;flex:none")}` +
    `<div class="col" data-scroll="1" style="gap:12px;overflow:hidden;flex:1;min-height:0;padding-right:14px"><span class="tx f30 semi up">Habilidades</span><div class="col" style="gap:10px">${rows}</div>${detail}</div>`) + `</div>`;
}
function trait(icon, name, effect, good) {
  return `<div class="row" style="gap:12px;align-items:center">` +
    nine("trait_tile", { extra: "width:80px;height:80px;flex:none;display:flex;align-items:center;justify-content:center" }, img(`art/ui/kit/station/icons/trait_${icon}.webp`, "width:66px;height:66px")) +
    `<div class="col" style="gap:2px;min-width:0"><span class="tx f26 semi ${good ? "good" : "danger"}">${name}</span><span class="wrap f22" style="max-width:150px">${effect}</span></div></div>`;
}
// O quadradinho de + e − dos traços, como no alvo: a forma do sinal também separa as colunas no daltonismo.
const badge = (sign, color) => `<span class="row" style="width:calc(26px*var(--k));height:calc(26px*var(--k));justify-content:center;background:${color};border:1px solid #0a0b0c;box-shadow:inset 0 1px 0 rgba(255,255,255,.35);flex:none"><b class="tx f24 semi" style="color:#101214;line-height:1">${sign}</b></span>`;
function rightPanel(p, locked = false) {
  const head = `<div class="row" style="justify-content:space-between"><span class="tx f40 semi up">Personagem</span>` +
    `<div data-hit="close">${nine("icon_button", { pad: [6, 6, 6, 6], extra: "width:56px;height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, `<span class="tx f28 semi">X</span>`)}</div></div>`;
  const ident = `<span class="tx f22 up amber" style="letter-spacing:.06em">Sobrevivente da Estação</span>` +
    `<div class="row" style="gap:16px"><span class="tx f52 semi">Bento</span>` +
    `<div style="position:relative;width:72px;height:72px;flex:none">${img(KIT.level_medal.file, "position:absolute;inset:0")}<span class="tx f34 semi amber" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">2</span></div>` +
    `<div class="col" style="gap:4px"><span class="tx f20 up muted">Nível 2 · XP ${locked ? 64 : 90} / 90</span>${bar(170, 22, locked ? 64 / 90 : 1, "var(--xp)")}</div></div>` +
    `<span class="tx f26 amber">Cão Protetor · Tanque e Proteção</span><div class="row" style="gap:14px">${pill("active", p.cb)}` +
    (locked
      ? `<div data-hit="train" style="opacity:.55;filter:saturate(.2)">${nine("train_button", { cls: "row", extra: "height:calc(56px*var(--k));gap:10px" }, `${glyph("train", 26, "var(--muted)")}<span class="tx f26 semi up muted">Treinar</span><span class="tx f22 muted">faltam 26 XP</span>`)}</div></div>`
      : `<div data-hit="train">${nine("train_button", { cls: "row", extra: "height:calc(56px*var(--k));gap:10px" }, `${glyph("train", 26, "var(--amber)")}<span class="tx f26 semi up">Treinar</span><span class="tx f22 muted">1 semente</span>`)}</div></div>`);
  const stats = `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f26 up">Vida</span><span class="tx f26">34 / 34</span></div>${bar(520, 26, 1, "var(--ally)")}</div>` +
    `<div class="col" style="gap:4px"><div class="row" style="gap:30px"><span class="tx f26 up">Velocidade 2</span><span class="tx f26 up">Instinto 0 / 200</span></div>${bar(520, 22, 0, "var(--instinct)")}</div>`;
  const relic = `<div class="row" style="gap:12px">${glyph("relic_empty", 34, "var(--muted)")}<div class="col"><span class="tx f26">Relíquia: Sem relíquia</span>` +
    `<span class="tx f22 muted">Equipe uma relíquia ao preparar a expedição.</span></div></div>` +
    `<div class="row" style="gap:12px">${glyph("expeditions", 26)}<span class="tx f22">Expedições 3</span>${glyph("kills", 26, "var(--text)", "margin-left:16px")}<span class="tx f22">Abates 7</span></div>`;
  const traits = `<span class="tx f30 semi up">Traços</span><div class="row" style="gap:18px;align-items:flex-start">` +
    `<div class="col" style="gap:8px;width:248px"><div class="row" style="gap:8px">${badge("+", "var(--good)")}<span class="tx f22 up good">Pontos fortes</span></div>` +
    trait("brave", "Corajoso", "+5 p.p. de Superação", true) + trait("agile", "Ágil", "+1 Velocidade", true) + `</div>` +
    `<i style="width:2px;align-self:stretch;background:#0a0b0c;border-right:1px solid #44484e"></i>` +
    `<div class="col" style="gap:8px;width:248px"><div class="row" style="gap:8px">${badge("−", "var(--danger-fill)")}<span class="tx f22 up danger">Pontos fracos</span></div>` +
    trait("gloomy", "Pessimista", "−5 p.p. de Superação", false) + `</div></div>`;
  return `<div class="abs" style="left:1296px;top:132px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:596px;height:calc(1080px - 132px - 14px - 72px*var(--k) - 14px)" },
    `${head}${img(KIT.divider.file, "width:548px;height:8px;margin:6px 0")}<div class="col scroll" data-scroll="1" style="gap:8px;overflow:hidden;flex:1;position:relative;padding-right:14px">${ident}${stats}${img(KIT.divider.file, "width:520px;height:8px")}${relic}${img(KIT.divider.file, "width:520px;height:8px")}${traits}</div>`) + `</div>`;
}
function bottom(locked = false) {
  const tabs = [["nav_overview", "Visão geral"], ["nav_facilities", "Instalações"], ["nav_characters", "Personagens"], ["nav_research", "Pesquisa"], ["nav_hide", "Ocultar HUD"]]
    .map(([icon, label], i) => `<div data-hit="nav" style="position:relative">` + nine("nav_tab", { cls: "row", extra: `min-width:${i === 4 ? 200 : 216}px;height:calc(72px*var(--k));gap:10px;justify-content:center` },
      `${glyph(icon, 30, i === 2 ? "var(--amber)" : "var(--text)")}<span class="tx f26 semi up ${i === 2 ? "amber" : ""}">${label}</span>`) + (i === 2 ? over("nav_tab_active") : "") + `</div>`).join("");
  const keys = [["Setas", "Navegar"], ["E", "Selecionar"], ["Esc", "Voltar"], ["F2", "Ocultar"]].map(([k, t]) => `<div class="row" style="gap:6px">${key(k)}<span class="tx f22">${t}</span></div>`).join("");
  const above = "bottom:calc(14px + 72px*var(--k) + 10px)";
  return `<div class="abs" data-hit="back" style="left:28px;${above}">` + nine("secondary_button", { cls: "row", extra: "width:220px;height:64px;gap:10px" },
    `${glyph("ui-arrow-right.svg", 26, "var(--text)", "transform:scaleX(-1)")}<span class="tx f28 semi up">Voltar</span>`) + `</div>` +
    `<div class="abs" data-hit="keys" style="left:962px;transform:translateX(-50%);${above}">` + nine("keys_bar", { cls: "row", extra: "min-width:600px;height:calc(56px*var(--k));gap:calc(22px - 8px*(var(--k) - 1)/0.3);justify-content:center" }, keys) + `</div>` +
    `<div class="abs row" style="left:28px;bottom:14px;gap:6px">${tabs}</div>` +
    `<div class="abs" data-hit="primary" style="right:28px;bottom:14px;min-width:480px">` +
    nine(locked ? "primary_button_disabled" : "primary_button", { cls: "row", extra: "width:100%;padding:0 6px;height:calc(72px*var(--k));gap:14px;justify-content:center;padding:0 2px" },
      // Bloqueado: o motivo vem dentro do próprio botão (a regra é de AHStationRules), sem depender de apontar.
      `${glyph("expeditions", 34, locked ? "#efe6d6" : "#1a1206")}` + (locked
        ? `<div class="col" style="gap:0"><span class="tx f26 semi up" style="color:#efe6d6;line-height:1.05">Preparar expedição</span><span class="tx f20" style="color:#e2d6c2;line-height:1.05">Conclua a noite no Dormitório antes de partir.</span></div>`
        : `<span class="tx f30 semi up" style="color:#1a1206">Preparar expedição</span>`) +
      nine("button_key", { cls: "row", extra: "height:calc(40px*var(--k));margin-left:8px;padding:0 4px" }, `<span class="tx f22">G / X</span>`)) + `</div>`;
}
function trainingDialog() {
  const cardUp = (name, effect, has, sel) => `<div data-hit="upgrade" style="position:relative">` +
    nine("upgrade_card", { cls: "col", extra: "width:300px;min-height:200px;gap:8px" },
      `<span class="tx f30 semi ${sel ? "amber" : ""}">${name}</span><span class="wrap f24" style="max-width:256px">${effect}</span><span class="tx f22 muted">${has}</span>`) +
    (sel ? over("upgrade_card_selected") : "") + `</div>`;
  return `<div class="abs" style="inset:0;background:rgba(5,6,7,.45)"></div><div class="abs" style="left:620px;top:250px">` +
    nine("panel_large", { repeat: "round", cls: "col", extra: "width:680px;gap:14px" },
      `<div class="row" style="gap:14px">${glyph("train", 34, "var(--amber)")}<span class="tx f36 semi up">Treino · nível 3</span></div>` +
      `<span class="wrap f24 muted" style="max-width:620px">Escolha uma melhoria. O treino gasta o XP do nível e 1 semente.</span>` +
      `<div class="row" style="gap:24px">${cardUp("Mais fôlego", "+2 de vida máxima.", "Já tem: 1", true)}${cardUp("Sangue frio", "Começa cada luta com 10 de instinto a menos.", "Já tem: 0", false)}</div>` +
      `<div class="row" style="gap:18px;justify-content:flex-end"><div data-hit="cancel">${nine("secondary_button", { cls: "row", extra: "height:calc(60px*var(--k));gap:10px" }, `<span class="tx f26 semi up">Cancelar</span>${key("Esc / B")}`)}</div>` +
      `<div data-hit="confirm">${nine("primary_button", { cls: "row", extra: "height:calc(64px*var(--k));gap:10px;padding:0 2px" }, `<span class="tx f28 semi up" style="color:#1a1206">Treinar</span>${nine("button_key", { cls: "row", extra: "height:calc(38px*var(--k))" }, `<span class="tx f22">E / A</span>`)}`)}</div></div>`) + `</div>`;
}
function charactersHTML(p, mode) {
  const training = mode === "training", locked = mode === "locked";
  // O herói de corpo inteiro é camada da interface (a pose idle do jogo), não o boneco da cena; a sombra o assenta.
  const hero = `<div class="abs" style="left:640px;top:120px;width:640px;height:800px;background:radial-gradient(ellipse 50% 46% at 50% 55%, rgba(6,7,8,.62), rgba(6,7,8,0))"></div>` +
    `<div class="abs" style="left:780px;top:858px;width:360px;height:40px;border-radius:50%;background:radial-gradient(rgba(0,0,0,.7),rgba(0,0,0,0) 70%)"></div>` +
    img("art/combat/heroes/bento/idle.webp", "position:absolute;left:calc(960px - 236.5px*1.02);top:calc(878px - 714.5px*1.02);width:calc(543px*1.02);height:calc(724px*1.02)");
  return `<img class="bg" src="${BASE}/docs/design/hud-v2/before/station-characters_clean.webp">${hero}${topBar()}${leftColumn()}${rightPanel(p, locked)}${bottom(locked)}` + (training ? trainingDialog() : "");
}

// ------------------------------------------------------------------ captura e conferência
const SCREENS = {
  report: (p) => reportHTML(p, false),
  report_details: (p) => reportHTML(p, true),
  characters: (p) => charactersHTML(p, ""),
  characters_training: (p) => charactersHTML(p, "training"),
  characters_locked: (p) => charactersHTML(p, "locked"),
};

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
const checks = {};
for (const [screen, build] of Object.entries(SCREENS)) {
  for (const [profile, p] of Object.entries(PROFILES)) {
    const html = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><style>${css(p)}</style></head><body>${build(p)}</body></html>`;
    fs.writeFileSync(path.join(OUT, `${screen}_${profile}.html`), html);
    await page.goto(`${BASE}/${OUT}/${screen}_${profile}.html`);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    const result = await page.evaluate(() => {
      const texts = [...document.querySelectorAll(".tx,.wrap")].map((el) => {
        const r = el.getBoundingClientRect();
        const clipped = el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 4;
        // Fora da caixa: o texto passa da borda da peça em volta ou de um contêiner que corta (overflow hidden).
        let outside = false;
        let parent = el.parentElement;
        let nearestNine = true;
        while (parent && parent !== document.body) {
          const cs = getComputedStyle(parent);
          const cuts = cs.overflow === "hidden" && !parent.hasAttribute("data-scroll");
          if ((parent.classList.contains("nine") && nearestNine) || cuts) {
            const pr = parent.getBoundingClientRect();
            if (r.left < pr.left - 1 || r.right > pr.right + 1 || r.top < pr.top - 1 || r.bottom > pr.bottom + 1) outside = true;
            if (parent.classList.contains("nine")) nearestNine = false;
          }
          parent = parent.parentElement;
        }
        const offscreen = r.right > 1920 || r.bottom > 1080 || r.left < 0 || r.top < 0;
        // Dentro da caixa que rola, o que está abaixo da dobra é alcançado rolando (a captura _scrolled mostra o fim).
        const box = el.closest("[data-scroll]");
        if (box && box.scrollHeight > box.clientHeight + 2) {
          const br = box.getBoundingClientRect();
          if (r.left >= br.left - 1 && r.right <= br.right + 1) return { text: el.textContent.trim(), size: parseFloat(getComputedStyle(el).fontSize), rect: [r.left, r.top, r.width, r.height].map(Math.round), clipped, outside: false, offscreen: false, in_scroll: r.bottom > br.bottom };
        }
        return { text: el.textContent.trim(), size: parseFloat(getComputedStyle(el).fontSize), rect: [r.left, r.top, r.width, r.height].map(Math.round), clipped, outside, offscreen };
      });
      const els = [...document.querySelectorAll("[data-hit]")];
      const hits = els.map((el) => { const r = el.getBoundingClientRect(); return { kind: el.dataset.hit, rect: [r.left, r.top, r.width, r.height].map(Math.round) }; });
      const overlaps = [];
      for (let i = 0; i < hits.length; i++) for (let j = i + 1; j < hits.length; j++) {
        if (els[i].contains(els[j]) || els[j].contains(els[i])) continue;
        const a = hits[i].rect, b = hits[j].rect;
        if (a[0] < b[0] + b[2] - 1 && b[0] < a[0] + a[2] - 1 && a[1] < b[1] + b[3] - 1 && b[1] < a[1] + a[3] - 1) overlaps.push([hits[i].kind, hits[j].kind]);
      }
      // O conteúdo cabe na área de conteúdo da peça (content_xywh), não só o texto na tela.
      const pieces = [...document.querySelectorAll(".nine:not(.over)")].filter((el) => !el.closest("[data-scroll]") || el.matches("[data-scroll] *"))
        .filter((el) => el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 1)
        .map((el) => ({ piece: (el.style.borderImage.match(/station\/(\w+)\.webp|combat\/(\w+)\.webp/) || []).slice(1).find(Boolean), over: [el.scrollWidth - el.clientWidth, el.scrollHeight - el.clientHeight] }));
      const scroll = [...document.querySelectorAll("[data-scroll]")].map((el) => ({ needs_scroll: el.scrollHeight > el.clientHeight + 2, content: el.scrollHeight, visible: el.clientHeight }));
      return { texts, hits, overlaps, scroll, pieces };
    });
    // A caixa que rola mostra a barra de rolagem do kit (aço com o polegar âmbar), como o painel do alvo.
    if (result.scroll.some((s) => s.needs_scroll)) {
      await page.evaluate(() => {
        for (const el of document.querySelectorAll("[data-scroll]")) {
          if (el.scrollHeight <= el.clientHeight + 2) continue;
          const track = document.createElement("div");
          const r = el.getBoundingClientRect();
          track.style.cssText = `position:absolute;left:${r.right - 8}px;top:${r.top}px;width:8px;height:${r.height}px;background:#0b0c0e;border:1px solid #3a3e44`;
          const thumb = document.createElement("div");
          thumb.style.cssText = `position:absolute;left:1px;top:1px;width:4px;height:${Math.round(r.height * el.clientHeight / el.scrollHeight)}px;background:#f0a020`;
          track.appendChild(thumb);
          document.body.appendChild(track);
          el._track = track;
        }
      });
    }
    await page.screenshot({ path: path.join(OUT, `${screen}_${profile}.png`) });
    if (result.scroll.some((s) => s.needs_scroll)) {
      await page.evaluate(() => {
        for (const el of document.querySelectorAll("[data-scroll]")) {
          const max = el.scrollHeight - el.clientHeight;
          el.scrollTop = max;
          const track = el._track;
          if (track) track.firstChild.style.top = `${Math.round(el.clientHeight - el.clientHeight * el.clientHeight / el.scrollHeight)}px`;
        }
      });
      await page.screenshot({ path: path.join(OUT, `${screen}_${profile}_scrolled.png`) });
    }
    const bad = result.texts.filter((t) => t.clipped || t.outside || t.offscreen);
    checks[`${screen}_${profile}`] = { ...result, problems: bad, ok: bad.length === 0 && result.overlaps.length === 0 && result.pieces.length === 0 };
    console.log(screen, profile, bad.length ? `PROBLEMAS ${bad.length}: ${bad.map((b) => b.text).join(" | ")}` : "ok", result.overlaps.length ? `sobreposições ${JSON.stringify(result.overlaps)}` : "", JSON.stringify(result.scroll), result.pieces.length ? `peças estouradas ${JSON.stringify(result.pieces)}` : "");
  }
}
fs.writeFileSync(path.join(OUT, "checks.json"), JSON.stringify(checks, null, 1));
await browser.close();
