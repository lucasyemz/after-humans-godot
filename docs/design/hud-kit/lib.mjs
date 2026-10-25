// Base comum das maquetes da HUD (as telas além da luta): as peças de art/ui/kit/station/ e do kit da luta como 9-slice
// (border-image com as mesmas margens do assets.json que a Godot usa no StyleBoxTexture), o CSS dos quatro perfis, a
// moldura das telas da Estação (barra do alto, abas de baixo, painel do cômodo) e a captura com as conferências.
// Texto pela Barlow Condensed, nunca dentro das imagens. As maquetes servem só para comparar e aprovar.
import { chromium } from "playwright";
import fs from "node:fs";
import path from "node:path";

export const KIT = JSON.parse(fs.readFileSync("art/ui/kit/station/assets.json", "utf8")).assets;
export const COMBAT = JSON.parse(fs.readFileSync("art/ui/kit/combat/assets.json", "utf8")).assets;
export let BASE = "http://127.0.0.1:8765";
export const setBase = (b) => { BASE = b; };

export const PROFILES = {
  normal: { k: 1, cb: false },
  large: { k: 1.3, cb: false },
  colorblind: { k: 1, cb: true },
  large_colorblind: { k: 1.3, cb: true },
};

// ------------------------------------------------------------------ peças
export function nine(key, { repeat = "stretch", extra = "", cls = "", attrs = "", pad = null } = {}, inner = "") {
  const row = KIT[key] || COMBAT[key];
  const [l, t, r, b] = row.nine_slice_ltrb;
  const [sw, sh] = row.size;
  // A borda desenhada (texture_margin) e o recuo do conteúdo (content_margin) são separados, como no StyleBoxTexture.
  const c = row.content_xywh;
  const [pt, pr, pb, pl] = pad || (c ? [c[1], sw - c[0] - c[2], sh - c[1] - c[3], c[0]] : [0, 0, 0, 0]);
  return `<div class="nine ${cls}" ${attrs} style="border-width:${pt}px ${pr}px ${pb}px ${pl}px;border-image:url(${BASE}/${row.file}) ${t} ${r} ${b} ${l} fill / ${t}px ${r}px ${b}px ${l}px ${repeat};${extra}">${inner}</div>`;
}
export const over = (key, extra = "") => nine(key, { cls: "over", extra });
export const img = (file, style = "") => `<img src="${BASE}/${file}" style="${style}">`;
// Glifo branco de um tom, tingido pela cor (como o modulate da Godot). ".svg" são os ícones que o jogo já tem.
export const glyph = (name, size, color = "var(--text)", style = "") => {
  const file = name.endsWith(".svg") ? `art/ui/icons/${name}` : `art/ui/kit/station/icons/${name}.webp`;
  return `<i class="glyph" style="width:${size}px;height:${size}px;background:${color};-webkit-mask-image:url(${BASE}/${file});${style}"></i>`;
};
export const key = (label) => `<span class="key">${img(COMBAT.key_tab.file, "position:absolute;inset:0;width:100%;height:100%")}<b>${label}</b></span>`;
export const bar = (w, h, ratio, color) =>
  `<div class="bar" style="width:${typeof w === "number" ? w + "px" : w};height:${h}px">${nine("main_bar", { extra: "position:absolute;inset:0" })}` +
  `<div class="fill" style="left:7px;top:${Math.max(3, Math.round(h * 0.23))}px;bottom:${Math.max(3, Math.round(h * 0.23))}px;width:calc((100% - 14px) * ${ratio});background:${color};-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div></div>`;
export const portrait = (hero, size) =>
  `<div class="portrait" style="width:${size}px;height:${size}px">${img(`art/ui/portraits/${hero}.png`, `position:absolute;left:4px;top:4px;width:${size - 8}px;height:${size - 8}px;object-fit:cover`)}` +
  nine("square_portrait", { extra: "position:absolute;inset:0" }) + `</div>`;
export const square = (file, size, style = "") =>
  `<div class="portrait" style="width:${size}px;height:${size}px;${style}">${img(file, `position:absolute;left:4px;top:4px;width:${size - 8}px;height:${size - 8}px;object-fit:cover`)}` +
  nine("square_portrait", { extra: "position:absolute;inset:0" }) + `</div>`;

export const STATES = {
  active: { label: "Em forma", icon: "state_active" },
  light_wound: { label: "Ferimento leve", icon: "state_light_wound" },
  wounded: { label: "Ferimento grave", icon: "state_wounded" },
};
export const pill = (state, cb) => {
  const tint = cb ? KIT.status_pill.tint.colorblind[state] : KIT.status_pill.tint[state];
  const ink = state === "wounded" && !cb ? "#fff6ee" : "#15110b";
  return `<div class="pill">${img(KIT.status_pill.file, "position:absolute;inset:0;width:100%;height:100%")}` +
    `<div class="tint" style="background:${tint};-webkit-mask-image:url(${BASE}/${KIT.status_pill.file})"></div>` +
    `${glyph(STATES[state].icon, 22, ink, "position:relative")}<span class="tx" style="color:${ink}">${STATES[state].label}</span></div>`;
};
// O quadradinho de + e − (pontos fortes e fracos): o sinal separa também no daltonismo.
export const badge = (sign, color) => `<span class="row" style="width:calc(26px*var(--k));height:calc(26px*var(--k));justify-content:center;background:${color};border:1px solid #0a0b0c;box-shadow:inset 0 1px 0 rgba(255,255,255,.35);flex:none"><b class="tx f24 semi" style="color:#101214;line-height:1">${sign}</b></span>`;
export const divider = (w = "100%") => img(KIT.divider.file, `width:${typeof w === "number" ? w + "px" : w};height:8px;flex:none`);
// Custo ou quantidade num chip escuro: ícone do recurso e o número (na cor de alerta quando falta).
// A seta (→) vira glifo: a Barlow Condensed não tem esse caractere.
export const arrow = (color = "var(--amber)") => glyph("ui-arrow-right.svg", 18, color, "margin:0 2px");
export const cost = (icon, text, short = false) => nine("cost_chip", { cls: "row", extra: "gap:8px;flex:none;min-height:40px" },
  `${glyph(icon, 24, short ? "var(--danger)" : "var(--text)")}` + text.split("→").map((t) => `<span class="tx f22 ${short ? "danger" : ""}">${t.trim()}</span>`).join(arrow()));
export const chip = (label, { selected = false, icon = "", hit = "option", width = "" } = {}) =>
  `<div data-hit="${hit}" style="position:relative;flex:none">` + nine("chip_button", { cls: "row", extra: `gap:8px;justify-content:center;min-height:calc(56px*var(--k));min-width:56px;${width ? `min-width:${width}px;` : ""}` },
    `${icon ? glyph(icon, 24, selected ? "var(--amber)" : "var(--text)") : ""}<span class="tx f24 ${selected ? "amber semi" : ""}">${label}</span>`) +
  (selected ? over("selected_frame") : "") + `</div>`;
export const secondary = (label, { icon = "", iconStyle = "", keyLabel = "", hit = "button", height = 60, extra = "" } = {}) =>
  `<div data-hit="${hit}" style="flex:none">` + nine("secondary_button", { cls: "row", extra: `height:calc(${height}px*var(--k));gap:10px;justify-content:center;${extra}` },
    `${icon ? glyph(icon, 26, "var(--text)", iconStyle) : ""}<span class="tx f26 semi up">${label}</span>${keyLabel ? key(keyLabel) : ""}`) + `</div>`;
export const primary = (label, { icon = "", keyLabel = "", hit = "primary", height = 72, locked = false, reason = "", extra = "", size = "f30" } = {}) => {
  // Mais baixo que a peça (72), o recuo de cima e de baixo diminui, para a tecla caber.
  const pad = height < 72 ? [4, 36, 4, 36] : null;
  const ink = locked ? "#efe6d6" : "#1a1206";
  const text = locked && reason
    ? `<div class="col"><span class="tx f24 semi up" style="color:${ink};line-height:1.05">${label}</span><span class="wrap f20" style="color:#e2d6c2;line-height:1.05;max-width:calc(560px - 140px*(var(--k) - 1)/0.3)">${reason}</span></div>`
    : `<span class="tx ${size} semi up" style="color:${ink}">${label}</span>`;
  return `<div data-hit="${hit}" style="flex:none;${extra}">` + nine(locked ? "primary_button_disabled" : "primary_button", { pad: locked && reason ? [10, 36, 10, 36] : pad, cls: "row", extra: `width:100%;${locked && reason ? "min-" : ""}height:calc(${height}px*var(--k));gap:14px;justify-content:center;padding:0 6px` },
    `${icon ? glyph(icon, 32, ink) : ""}${text}` +
    (keyLabel ? nine("button_key", { cls: "row", extra: "height:calc(40px*var(--k));margin-left:8px;padding:0 4px" }, `<span class="tx f22">${keyLabel}</span>`) : "")) + `</div>`;
};
export const train = (label, costText, { hit = "train", locked = false, icon = "train" } = {}) =>
  `<div data-hit="${hit}" style="flex:none;${locked ? "opacity:.55;filter:saturate(.2)" : ""}">` + nine("train_button", { cls: "row", extra: "height:calc(56px*var(--k));gap:10px" },
    `${glyph(icon, 26, locked ? "var(--muted)" : "var(--amber)")}<span class="tx f26 semi up ${locked ? "muted" : ""}">${label}</span>${costText ? `<span class="tx f22 muted">${costText}</span>` : ""}`) + `</div>`;
export const toggle = (on) => img(KIT[on ? "toggle_on" : "toggle_off"].file, "width:64px;height:32px;flex:none");
export const slider = (ratio, w = 300) =>
  `<div style="position:relative;width:${w}px;height:36px;flex:none">` + nine("slider_track", { extra: "position:absolute;left:0;right:0;top:8px;height:20px" }) +
  `<div class="fill" style="left:4px;top:12px;height:12px;width:calc((100% - 8px) * ${ratio});background:var(--amber);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div>` +
  img(KIT.slider_knob.file, `position:absolute;top:0;left:calc((100% - 8px) * ${ratio} - 10px);width:28px;height:36px`) + `</div>`;
export const medal = (n, size = 56) => `<div style="position:relative;width:${size}px;height:${size}px;flex:none">${img(KIT.level_medal.file, "position:absolute;inset:0;width:100%;height:100%")}` +
  `<span class="tx semi amber" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:calc(${Math.round(size * 0.46)}px*var(--k))">${n}</span></div>`;

// ------------------------------------------------------------------ CSS
export const css = (p) => `
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
.kicker{letter-spacing:.06em;text-transform:uppercase}
`;

// ------------------------------------------------------------------ moldura das telas da Estação
export const NAV = [["nav_overview", "Visão geral"], ["nav_facilities", "Instalações"], ["nav_characters", "Personagens"], ["nav_research", "Pesquisa"], ["nav_hide", "Ocultar HUD"]];

// A barra do alto: a plaqueta à esquerda; os materiais, Comida, Água e Energia e a engrenagem à direita.
export function topBar({ title = "Estação Raiz", subtitle = "", materials = true, stock = ["30", "9", "3", "2"], food = ["0 / 12 suprimentos", "Falta na volta", true], water = ["6 em estoque", "Próxima volta: 4"], energy = ["1 / 3 em uso", "2 livres"] } = {}) {
  const res = (icon, label, value, sub, warn) =>
    nine("resource_chip", { cls: "row", extra: "min-width:236px;min-height:96px;gap:12px" },
      `${glyph(warn ? "alert" : icon, 40, warn ? "var(--danger)" : "var(--text)")}<div class="col" style="gap:1px"><span class="tx f20 up muted">${label}</span>` +
      `<span class="tx f26 semi ${warn ? "danger" : "amber"}">${value}</span><span class="tx f20 ${warn ? "danger" : "muted"}">${sub}</span></div>`);
  const mats = materials ? nine("resource_chip", { cls: "row", extra: "min-height:96px;gap:16px" },
    [["lobby-seed.svg", stock[0]], ["lobby-scrap.svg", stock[1]], ["lobby-fragment.svg", stock[2]], ["res-bandages.svg", stock[3]]]
      .map(([i, n]) => `<div class="row" style="gap:6px">${glyph(i, 30)}<span class="tx f26 semi">${n}</span></div>`).join("")) : "";
  return `<div class="abs" style="left:28px;top:14px">` +
    nine("room_plaque", { cls: "row", extra: "min-width:440px;min-height:96px;gap:16px" },
      `${glyph("station", 52)}<div class="col"><span class="tx f40 semi up">${title}</span>${subtitle ? `<span class="tx f24 muted">${subtitle}</span>` : ""}</div>`) + `</div>` +
    `<div class="abs row" style="right:28px;top:14px;gap:10px;align-items:stretch">${mats}` +
    res("lobby-food.svg", "Comida", food[0], food[1], food[2]) + res("lobby-water.svg", "Água", water[0], water[1]) + res("lobby-energy.svg", "Energia", energy[0], energy[1]) +
    `<div data-hit="options">` + nine("icon_button", { extra: "width:92px;height:100%;min-height:96px;display:flex;align-items:center;justify-content:center" }, glyph("lobby-settings.svg", 48)) + `</div></div>`;
}

// O pé da tela: VOLTAR (nos cômodos) e a barra das teclas, as abas e o botão principal.
export function bottom({ active = 0, back = true, keysAt = null, keys = [["Setas", "Navegar"], ["E", "Selecionar"], ["Esc", "Voltar"], ["F2", "Ocultar"]], main = null } = {}) {
  const tabs = NAV.map(([icon, label], i) => `<div data-hit="nav" style="position:relative">` + nine("nav_tab", { cls: "row", extra: `min-width:${i === 4 ? 200 : 216}px;height:calc(72px*var(--k));gap:10px;justify-content:center` },
    `${glyph(icon, 30, i === active ? "var(--amber)" : "var(--text)")}<span class="tx f26 semi up ${i === active ? "amber" : ""}">${label}</span>`) + (i === active ? over("nav_tab_active") : "") + `</div>`).join("");
  const keyRow = keys.map(([k, t]) => `<div class="row" style="gap:6px">${key(k)}<span class="tx f22">${t}</span></div>`).join("");
  const above = "bottom:calc(14px + 72px*var(--k) + 10px)";
  const m = main || { label: "Preparar expedição", icon: "expeditions", keyLabel: "G / X" };
  return (back ? `<div class="abs" style="left:28px;${above}">` + secondary("Voltar", { icon: "ui-arrow-right.svg", iconStyle: "transform:scaleX(-1)", hit: "back", height: 64, extra: "width:220px" }) + `</div>` : "") +
    `<div class="abs" data-hit="keys" style="left:${keysAt || (back ? 962 : 760)}px;transform:translateX(-50%);${above}">` + nine("keys_bar", { cls: "row", extra: "min-width:560px;height:calc(56px*var(--k));gap:calc(22px - 8px*(var(--k) - 1)/0.3);justify-content:center" }, keyRow) + `</div>` +
    `<div class="abs row" style="left:28px;bottom:14px;gap:6px">${tabs}</div>` +
    `<div class="abs" style="right:28px;bottom:14px;min-width:480px">` + primary(m.label, { icon: m.icon, keyLabel: m.keyLabel, locked: m.locked, reason: m.reason, hit: "primary" }) + `</div>`;
}

// O painel do cômodo à direita (o mesmo lugar e a mesma chapa do painel PERSONAGEM): título com ícone, o X e o conteúdo,
// que rola no Maior quando não cabe.
export function roomPanel({ icon, title, tag = "", body, footer = "", left = 1296, width = 596, top = 132 }) {
  // O título encolhe e quebra a linha antes de empurrar o X; o X fica sempre no canto.
  const head = `<div class="row" style="justify-content:space-between;gap:12px;align-items:flex-start"><div class="row" style="gap:14px;flex:1;min-width:0;flex-wrap:wrap">${glyph(icon, 40, "var(--amber)")}<span class="wrap f40 semi up" style="min-width:0">${title}</span>${tag}</div>` +
    `<div data-hit="close">${nine("icon_button", { pad: [6, 6, 6, 6], extra: "width:56px;height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, `<span class="tx f28 semi">X</span>`)}</div></div>`;
  // A altura acompanha o conteúdo até o limite acima das abas; daí em diante o conteúdo rola e as ações do pé ficam fixas.
  return `<div class="abs" style="left:${left}px;top:${top}px">` + nine("panel_large", { repeat: "round", cls: "col", extra: `width:${width}px;max-height:calc(1080px - ${top}px - 14px - 72px*var(--k) - 28px);min-height:320px` },
    `${head}${divider()}<div class="col" data-scroll="1" style="gap:12px;overflow:hidden;flex:1 1 auto;min-height:0;position:relative;padding:8px 14px 0 0">${body}</div>` +
    (footer ? `<div class="col" style="gap:10px;flex:none;padding-top:12px">${divider()}${footer}</div>` : "")) + `</div>`;
}
// Etiqueta de estado do cômodo (Vazio, Nível 1 de 2): chip escuro pequeno.
export const roomTag = (text, color = "var(--muted)") => nine("cost_chip", { cls: "row", extra: "flex:none;min-height:40px" }, `<span class="tx f22 up" style="color:${color}">${text}</span>`);
export const section = (title, icon = "") => `<div class="row" style="gap:10px;margin-top:4px">${icon ? glyph(icon, 26, "var(--amber)") : ""}<span class="wrap f24 semi up amber kicker">${title}</span></div>`;

// ------------------------------------------------------------------ captura e conferência
// Tipos de alvo que não são toque (informação ou caixas de conferência): ficam fora da régua de 56 px.
const NOT_TOUCH = new Set(["keys", "hero-body", "card-tab", "details", "chip", "hero", "slot-info"]);

export async function run(screens, out) {
  fs.rmSync(out, { recursive: true, force: true });
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  const checks = {};
  for (const [screen, build] of Object.entries(screens)) {
    for (const [profile, p] of Object.entries(PROFILES)) {
      const html = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><style>${css(p)}</style></head><body>${build(p)}</body></html>`;
      fs.writeFileSync(path.join(out, `${screen}_${profile}.html`), html);
      await page.goto(`${BASE}/${out}/${screen}_${profile}.html`);
      await page.evaluate(() => document.fonts.ready);
      await page.waitForTimeout(150);
      const result = await page.evaluate((NOT_TOUCH) => {
        // O número do medalhão (data-avoid) mora de propósito na quina da carta, fora da área de conteúdo.
        const texts = [...document.querySelectorAll(".tx,.wrap")].filter((el) => !el.closest("[data-avoid]")).map((el) => {
          const r = el.getBoundingClientRect();
          const clipped = el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 4;
          const offscreen = r.right > 1920 || r.bottom > 1080 || r.left < 0 || r.top < 0;
          const box = el.closest("[data-scroll]");
          if (box && box.scrollHeight > box.clientHeight + 2) {
            const br = box.getBoundingClientRect();
            if (r.left >= br.left - 1 && r.right <= br.right + 1) return { text: el.textContent.trim(), size: parseFloat(getComputedStyle(el).fontSize), rect: [r.left, r.top, r.width, r.height].map(Math.round), clipped, outside: false, offscreen: false, in_scroll: r.bottom > br.bottom };
          }
          let outside = false, parent = el.parentElement, nearestNine = true;
          while (parent && parent !== document.body) {
            const cuts = getComputedStyle(parent).overflow === "hidden" && !parent.hasAttribute("data-scroll");
            if ((parent.classList.contains("nine") && nearestNine) || cuts) {
              // Na peça mais próxima, a régua é a área de conteúdo (as margens de conteúdo), não a borda desenhada.
              const box = parent.getBoundingClientRect(), cs = getComputedStyle(parent);
              const inner = parent.classList.contains("nine") && nearestNine;
              const pr = inner ? { left: box.left + parseFloat(cs.borderLeftWidth), right: box.right - parseFloat(cs.borderRightWidth), top: box.top + parseFloat(cs.borderTopWidth), bottom: box.bottom - parseFloat(cs.borderBottomWidth) } : box;
              if (r.left < pr.left - 1 || r.right > pr.right + 1 || r.top < pr.top - 1 || r.bottom > pr.bottom + 1) outside = true;
              if (parent.classList.contains("nine")) nearestNine = false;
            }
            parent = parent.parentElement;
          }
          return { text: el.textContent.trim(), size: parseFloat(getComputedStyle(el).fontSize), rect: [r.left, r.top, r.width, r.height].map(Math.round), clipped, outside, offscreen };
        });
        const els = [...document.querySelectorAll("[data-hit]")];
        const hits = els.map((el) => { const r = el.getBoundingClientRect(); return { kind: el.dataset.hit, rect: [r.left, r.top, r.width, r.height].map(Math.round) }; });
        const overlaps = [];
        for (let i = 0; i < hits.length; i++) for (let j = i + 1; j < hits.length; j++) {
          if (els[i].contains(els[j]) || els[j].contains(els[i])) continue;
          const a = hits[i].rect, b = hits[j].rect;
          // Dentro de uma caixa que rola, o que está abaixo da dobra não conta como sobreposto ao que está fora dela.
          const sa = els[i].closest("[data-scroll]"), sb = els[j].closest("[data-scroll]");
          if ((sa && sa.scrollHeight > sa.clientHeight + 2 && a[1] + a[3] > sa.getBoundingClientRect().bottom) || (sb && sb.scrollHeight > sb.clientHeight + 2 && b[1] + b[3] > sb.getBoundingClientRect().bottom)) continue;
          if (a[0] < b[0] + b[2] - 1 && b[0] < a[0] + a[2] - 1 && a[1] < b[1] + b[3] - 1 && b[1] < a[1] + a[3] - 1) overlaps.push([hits[i].kind, hits[j].kind]);
        }
        // O conteúdo cabe na área de conteúdo de cada peça (content_xywh).
        const pieces = [...document.querySelectorAll(".nine:not(.over)")]
          // Na altura, até 3 px é a caixa de linha do texto (ascendentes e descendentes), não conteúdo de verdade.
          .filter((el) => el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 3)
          .filter((el) => !el.hasAttribute("data-scroll") && !el.querySelector(":scope > [data-scroll]"))
          .map((el) => ({ piece: (el.style.borderImage.match(/(?:station|combat)\/(\w+)\.webp/) || [])[1], over: [el.scrollWidth - el.clientWidth, el.scrollHeight - el.clientHeight] }));
        const scroll = [...document.querySelectorAll("[data-scroll]")].map((el) => ({ needs_scroll: el.scrollHeight > el.clientHeight + 2, content: el.scrollHeight, visible: el.clientHeight }));
        // Caracteres que a Barlow Condensed não tem (setas, estrelas, triângulos): viram caixinhas.
        const glyphs = texts.filter((t) => [...t.text].some((c) => c.codePointAt(0) >= 0x2190 && c !== "\u2212")).map((t) => t.text);
        // Alvos fora da tela e menores que 56 px.
        const belowFold = (el) => { const box = el.closest("[data-scroll]"); return box && box.scrollHeight > box.clientHeight + 2; };
        const offscreenHits = hits.filter((h, i) => !belowFold(els[i]) && (h.rect[0] < 0 || h.rect[1] < 0 || h.rect[0] + h.rect[2] > 1920 || h.rect[1] + h.rect[3] > 1080)).map((h) => h.kind);
        const small = hits.filter((h) => !NOT_TOUCH.includes(h.kind) && (h.rect[2] < 56 || h.rect[3] < 56)).map((h) => [h.kind, h.rect[2], h.rect[3]]);
        // Peças cortadas por um contêiner que corta (o painel que rola corta só nos lados; o que corta de verdade, em tudo).
        const cut = [];
        for (const el of document.querySelectorAll(".nine:not(.over)")) {
          const r = el.getBoundingClientRect();
          let parent = el.parentElement;
          while (parent && parent !== document.body) {
            const scrolls = parent.hasAttribute("data-scroll");
            if (getComputedStyle(parent).overflow === "hidden") {
              const pr = parent.getBoundingClientRect();
              const side = r.left < pr.left - 1 || r.right > pr.right + 1;
              const vertical = !scrolls && (r.top < pr.top - 1 || r.bottom > pr.bottom + 1);
              if (side || vertical) cut.push((el.style.borderImage.match(/(?:station|combat)\/(\w+)\.webp/) || [])[1]);
            }
            parent = parent.parentElement;
          }
        }
        // Texto em cima de uma peça que pede espaço (medalhões, retratos marcados com data-avoid).
        const avoid = [...document.querySelectorAll("[data-avoid]")].map((el) => [el, el.getBoundingClientRect()]);
        const covered = [...document.querySelectorAll(".tx,.wrap")].filter((el) => avoid.some(([a, ar]) => {
          if (a.contains(el)) return false;
          const r = el.getBoundingClientRect();
          return r.left < ar.right - 1 && ar.left < r.right - 1 && r.top < ar.bottom - 1 && ar.top < r.bottom - 1;
        })).map((el) => el.textContent.trim());
        return { texts, hits, overlaps, scroll, pieces, glyphs, offscreenHits, small, cut, covered };
      }, [...NOT_TOUCH]);
      if (result.scroll.some((s) => s.needs_scroll)) {
        await page.evaluate(() => {
          for (const el of document.querySelectorAll("[data-scroll]")) {
            if (el.scrollHeight <= el.clientHeight + 2) continue;
            const r = el.getBoundingClientRect();
            const track = document.createElement("div");
            track.style.cssText = `position:absolute;left:${r.right - 8}px;top:${r.top}px;width:8px;height:${r.height}px;background:#0b0c0e;border:1px solid #3a3e44`;
            const thumb = document.createElement("div");
            thumb.style.cssText = `position:absolute;left:1px;top:1px;width:4px;height:${Math.round(r.height * el.clientHeight / el.scrollHeight)}px;background:#f0a020`;
            track.appendChild(thumb);
            document.body.appendChild(track);
            el._track = track;
          }
        });
      }
      await page.screenshot({ path: path.join(out, `${screen}_${profile}.png`) });
      if (result.scroll.some((s) => s.needs_scroll)) {
        await page.evaluate(() => {
          for (const el of document.querySelectorAll("[data-scroll]")) {
            el.scrollTop = el.scrollHeight - el.clientHeight;
            if (el._track) el._track.firstChild.style.top = `${Math.round(el.clientHeight - el.clientHeight * el.clientHeight / el.scrollHeight)}px`;
          }
        });
        await page.screenshot({ path: path.join(out, `${screen}_${profile}_scrolled.png`) });
      }
      const bad = result.texts.filter((t) => t.clipped || t.outside || t.offscreen);
      const extra = ["glyphs", "offscreenHits", "small", "cut", "covered"].filter((k) => result[k].length);
      checks[`${screen}_${profile}`] = { ...result, problems: bad, ok: bad.length === 0 && result.overlaps.length === 0 && result.pieces.length === 0 && extra.length === 0 };
      console.log(screen, profile, bad.length ? `TEXTOS ${bad.length}: ${bad.map((b) => b.text).join(" | ")}` : "ok",
        result.overlaps.length ? `sobreposições ${JSON.stringify(result.overlaps)}` : "", result.pieces.length ? `peças ${JSON.stringify(result.pieces)}` : "",
        result.scroll.some((s) => s.needs_scroll) ? "rola" : "", extra.map((k) => `${k} ${JSON.stringify(result[k])}`).join(" "));
    }
  }
  fs.writeFileSync(path.join(out, "checks.json"), JSON.stringify(checks, null, 1));
  await browser.close();
}
