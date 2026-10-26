// Lote 8: os ajustes da #134, depois de jogar, no kit da Awesomic (art/ui/kit/station):
// - a inspeção da luta (#128): INSPECIONAR na grade de ações, os detalhes na HUD de baixo (herói e máquina), a intenção
//   da máquina sem o alvo e o popup de fim de luta com o X e a barra do tempo;
// - a barra de Admin (#130): as sete abas, simples e densas;
// - os marcadores dos cômodos na Estação (#131), como no XCOM 2;
// - a noite e o amanhecer (#132): o cartão "Noite N" e o painel "Amanhecer · Dia N", com e sem evento;
// - a troca de formação na exploração (#129).
// Fundos: as capturas limpas do jogo (loop-screens, hud-v2, hud-ajustes) e as montagens de before/ (build_bg.py) e do
// lote 7 (hud-casa/before). Os números seguem a história do lote 7 (a volta no Dia 4, a noite 4, o Dia 5).
// Uso (da raiz do repositório, com python3 -m http.server 8765 --bind 127.0.0.1 servindo a raiz):
//   node docs/design/hud-ajustes2/render.mjs http://127.0.0.1:8765
import fs from "node:fs";
import {
  setBase, BASE, KIT, nine, over, img, glyph, key, bar, divider, cost, chip, secondary, primary, train, medal, toggle, slider, arrow,
  bottom, roomPanel, roomTag, section, pill, run,
} from "../hud-kit/lib.mjs";
import { combat } from "../hud-luta/render.mjs";
import { frame, BG as EXPLORE_BG } from "../hud-exploracao/render.mjs";
import { topBar, next, TO_MAP, MINE, inset, line, face, bodies, recovering } from "../hud-casa/render.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-ajustes2/.render";
const OWN = (name) => img(`docs/design/hud-ajustes2/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const V2 = (name) => img(`docs/design/hud-v2/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const veil = (a = 0.5) => `<div class="abs" style="inset:0;background:rgba(5,6,7,${a})"></div>`;
const closeX = (hit = "close") => `<div data-hit="${hit}">${nine("icon_button", { pad: [6, 6, 6, 6], extra: "width:56px;height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, `<span class="tx f28 semi">X</span>`)}</div>`;

// ------------------------------------------------------------------ 1. a luta (#128)
// O centro de cada unidade na captura da luta (loop-screens/before/combat.json): o meio da plaquinha do nome.
const META = JSON.parse(fs.readFileSync("docs/design/loop-screens/before/combat.json", "utf8"));
const CX = Object.fromEntries(META.units.map((u) => {
  const t = META.texts.find((t) => t.text === u.name && t.rect[1] > 650 && t.rect[1] < 800);
  return [u.name, Math.round(t.rect[0] + t.rect[2] / 2)];
}));
// A tecla numa aba (key_tab), como nas outras ações.
const keyTab = (label, x, y) => `<div class="abs" style="left:${x}px;top:${y}px;width:42px;height:42px">` +
  nine("key_tab", { pad: [2, 2, 2, 2], cls: "row", extra: "width:42px;height:42px;justify-content:center" }, `<span class="tx l1 f26 semi">${label}</span>`) + `</div>`;
// INSPECIONAR: um botão alto à esquerda da grade 2x2 (Mover, Defender, Mochila, Fugir), na altura das duas linhas; a
// tecla é a do Examinar de hoje (combat_examine, X / L3). Ligado, a moldura âmbar e o rótulo em âmbar.
const inspectButton = (on) => `<div class="abs" data-hit="action" style="left:1408px;top:836px;width:160px;height:212px">` +
  nine("icon_button", { pad: [14, 12, 14, 12], cls: "col", extra: "width:160px;height:212px;justify-content:center;gap:10px" },
    `${glyph("inspect", 56, on ? "var(--amber)" : "var(--text)")}<span class="tx f20 semi up ${on ? "amber" : ""}">Inspecionar</span>`) +
  (on ? over("selected_frame") : "") + `</div>` + keyTab("X", 1408 + 112, 836 + 6);
// A intenção sobre a cabeça da máquina: o tipo (o ícone de hoje) e o nome da ação, sem o alvo (sai o "→ Nick").
const intentPlate = (cx, top, icon, text, w) => `<div class="abs col" style="left:${cx - w / 2}px;top:${top}px;width:${w}px">` +
  nine("target_tab", { cls: "row", extra: `width:${w}px;min-height:calc(48px*var(--k));gap:10px;justify-content:center` }, `${glyph(icon, 26)}<span class="tx l1 f24">${text}</span>`) +
  `<div style="height:5px;background:var(--enemy);box-shadow:0 0 6px rgba(0,0,0,.6)"></div></div>`;
const INTENTS = () => intentPlate(CX["Recreador"], 290, "intent-attack", "Pega-Pega", 220) + intentPlate(CX["Emissor de Comando"], 476, "intent-attack", "Ordem Contraditória", 300);
// Quem o mouse aponta: só o nome e a vida (a moldura de foco na barra da vida), sem abrir a ficha.
const pointed = (name, large) => `<div class="abs" style="left:${CX[name] - 100}px;top:760px;width:200px;height:${large ? 46 : 44}px">${over("focus_frame")}</div>`;
// O retrato da máquina: o recorte do sprite (como o painel do herói da vez faz com o retrato), em 184.
const machineFace = (size) => {
  const box = [180, 10, 400, 230], tex = 589, k = size / (box[2] - box[0]);
  return `<div style="position:absolute;inset:4px;background:#421b1b url(${BASE}/art/combat/enemies/recreador/idle.webp) no-repeat;background-size:${tex * k}px auto;background-position:${-box[0] * k}px ${-box[1] * k}px"></div>`;
};
// A barra cheia do painel (main_bar com o preenchimento e o valor dentro), como a do herói da vez.
const fillBar = (w, h, ratio, color, text) => nine("main_bar", { pad: [2, 8, 2, 8], cls: "row", extra: `width:${w}px;height:${h}px;justify-content:center;position:relative;flex:none` },
  `<div style="position:absolute;left:0;top:0;bottom:0;width:${ratio * 100}%;background:${color};-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div>` +
  `<span class="tx l1 f26 semi" style="position:relative">${text}</span>`);
// Uma linha de passivo ou de estado: o nome (verde se ajuda, vermelho se atrapalha) e o que faz.
const effect = (name, what, good) => `<div class="col" style="gap:0"><span class="wrap f22 semi ${good ? "good" : "danger"}">${name}</span><span class="wrap f20">${what}</span></div>`;
// A inspeção ligada: os detalhes de quem foi apontado ou escolhido na HUD de baixo, no lugar do painel do herói da vez e
// das habilidades (a vez continua de quem age; ao desligar, o painel volta). A aba de cima diz como trocar e sair.
function inspectPanel(p, who) {
  const large = p.k > 1;
  const hero = who === "bento";
  const portrait = `<div style="position:relative;width:184px;height:184px;flex:none">` + (hero
    ? `<div style="position:absolute;inset:4px;background:#1b1d20 url(${BASE}/art/ui/portraits/bento.png) no-repeat;background-size:${256 * 176 / 168}px auto;background-position:${-40 * 176 / 168}px ${-14 * 176 / 168}px"></div>`
    : machineFace(176)) + nine("hero_tab", { extra: "position:absolute;inset:0" }) + `</div>`;
  const barH = 40;
  const id = hero
    ? `<div class="row" style="gap:12px"><span class="tx l1 f40 semi up">Bento</span>${medal(2, 48)}</div><span class="tx f22 amber">Cão · Tanque e Proteção</span>` +
      fillBar(360, barH, 1, "var(--ally)", "34/34") + fillBar(360, barH, 0, "var(--instinct)", "Instinto 0/200")
    : `<div class="row" style="gap:12px"><span class="tx l1 f40 semi up" style="color:var(--enemy-text)">Recreador</span></div><span class="tx f22 amber">Máquina · Pressão de Instinto</span>` +
      fillBar(360, barH, 1, "var(--enemy)", "8/8");
  const mid = hero
    ? `<span class="tx f26 semi up">Velocidade 2</span><span class="wrap f20 muted">Quem é mais rápido age antes na rodada.</span>` +
      `<span class="tx f22">Posição 1 · frente</span>`
    : `<span class="tx f26 semi up">Velocidade 3</span><span class="wrap f20 muted">Quem é mais rápido age antes na rodada.</span>` +
      `<div class="row" style="gap:8px">${glyph("intent-attack", 24)}<span class="wrap f22">Intenção: Pega-Pega, 3–4 de dano</span></div>`;
  const right = hero
    ? `<span class="tx f20 semi up amber kicker">Efeitos passivos</span>` +
      effect("Corajoso", "+5 pontos percentuais na chance de Superação.", true) +
      effect("Laço com Nick", "Amizade +2 · em +3, quando um cai, o outro ergue a guarda (+1 bloqueio).", true) +
      `<span class="tx f20 semi up amber kicker" style="margin-top:4px">Estados</span><span class="tx f20 muted">Nenhum agora</span>`
    : `<span class="wrap f20 muted">Robô de festas do cinema. Repete a rotina de animar crianças que não vêm há gerações.</span>` +
      `<span class="tx f20 semi up amber kicker" style="margin-top:4px">Efeitos passivos</span>` +
      effect("Resiste a dano por turno", "20% de chance de não sangrar nem contaminar.", true) +
      effect("Resiste a deslocamento", "20% de chance de não ser empurrado nem puxado.", true) +
      `<span class="tx f20 semi up amber kicker" style="margin-top:4px">Estados</span>` +
      effect("Marcado (1 vez)", "Alvo das habilidades que pegam Marca (Caçada Precisa).", false);
  // A aba de cima (no lugar de ESCOLHA UM ALVO, em y 816, sobre a borda do painel): como trocar e sair. Painel e aba
  // numa peça só, na altura do painel do herói da vez (212), também no Maior: o que não cabe à direita rola.
  const tab = `<div style="position:absolute;left:620px;top:-20px;z-index:2">` +
    nine("target_tab", { cls: "row", extra: `min-width:520px;height:${large ? 44 : 40}px;gap:10px;padding-left:6px` },
      `${glyph("inspect", 24, "var(--amber)")}<span class="tx l1 f22 up">Inspecionar · Setas trocam · X ou Esc sai</span>`) + `</div>`;
  return `<div class="abs" data-hit="panel" style="left:64px;top:836px">` + tab +
    nine("panel_large", { pad: [14, 22, 14, 14], cls: "row", extra: `width:1328px;height:212px;gap:22px;align-items:center` },
      portrait + `<div class="col" style="gap:${large ? 4 : 8}px;width:370px;flex:none">${id}</div>` +
      `<div class="col" style="gap:6px;width:250px;flex:none;align-self:stretch;justify-content:center">${mid}</div>` +
      `<div class="col" data-scroll="1" style="gap:4px;flex:1;min-width:0;align-self:stretch;overflow:hidden;padding-right:14px">${right}</div>`) + `</div>`;
}
const ENEMY_TEXT = `<style>:root{--enemy-text:#f0a49a}</style>`;
// A intenção sem o alvo, e o mouse apontando o Recreador (só o nome e a vida; a ficha não abre).
const fightIntent = (p) => ENEMY_TEXT + combat(p, { target: true, extra: INTENTS() + pointed("Recreador", p.k > 1) + inspectButton(false) });
const fightInspect = (who) => (p) => ENEMY_TEXT + combat(p, { target: who !== "bento", extra: INTENTS() + pointed(who === "bento" ? "Bento" : "Recreador", p.k > 1) + inspectButton(true), bottom: inspectPanel(p, who) });

// O popup de fim de luta do lote 5 (hud-ajustes.md) sobre a luta do guardião, com o X no canto e a barra do tempo:
// fica pelo menos 5 s, não fecha com o mouse em cima (a barra para) e fecha no X ou com qualquer tecla.
const BOSS = JSON.parse(fs.readFileSync("docs/design/hud-ajustes/before/fight_boss.json", "utf8"));
function fightPopup(p, { hold = false } = {}) {
  // A barra encolhe até caber entre os pés (a câmera do guardião é mais aberta), como no lote 5.
  const xs = BOSS.units.map((u) => u.feet[0]).sort((a, b) => a - b);
  const w = Math.min(200, Math.floor(Math.min(...xs.slice(1).map((x, i) => x - xs[i])) - 12)), h = p.k > 1 ? 46 : 44, left = p.cb ? 30 : 8;
  const teamBar = (u) => `<div class="abs" style="left:${Math.round(u.feet[0] - w / 2)}px;top:${Math.round(u.feet[1]) + 4}px;width:${w}px;height:${h}px">` +
    nine("main_bar", { pad: p.k > 1 ? [13, 8, 0, left] : [15, 8, 2, left], cls: "col", extra: `width:${w}px;height:${h}px` },
      `<div style="position:absolute;left:0;right:0;top:-10px;height:10px"><div style="height:100%;background:var(--ally);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%;width:${(u.hp / u.max_hp) * 100}%"></div></div>` +
      `<span class="tx f24 semi" style="text-align:center;line-height:1.05">${u.hp}/${u.max_hp}</span>`) +
    (p.cb ? img(KIT.ally_mark.file, `position:absolute;left:0;top:${-12 * h / 44}px;width:${28 * h / 44}px;height:${56 * h / 44}px`) : "") + `</div>`;
  const stars = `<div class="row" style="gap:4px">${[0, 1, 2].map((i) => glyph(i < BOSS.rewards.stars ? "star" : "star_empty", 28, i < BOSS.rewards.stars ? "var(--amber)" : "var(--muted)")).join("")}</div>`;
  const loot = `<div class="row" style="gap:10px;justify-content:center;flex-wrap:wrap">${cost("lobby-seed.svg", "+16 sementes")}${cost("lobby-scrap.svg", "+3 sucata")}${cost("lobby-fragment.svg", "+1 fragmento")}</div>`;
  const xp = `<span class="tx f22 semi" style="color:var(--xp)">XP: ${[...BOSS.units].sort((a, b) => a.feet[0] - b.feet[0]).map((u) => `${u.name} +${u.xp_gained}`).join(" · ")}</span>`;
  const after = `<div class="row" style="gap:8px">${glyph("next_step", 22, "var(--amber)")}<span class="tx f22">A carga do guardião abre em seguida</span></div>`;
  // A barra do tempo: 5 s (a #128 pede pelo menos 5); com o mouse em cima ou o foco no popup, ela para e diz por quê.
  const foot = `<div class="col" style="gap:6px;align-items:center;width:100%"><div style="position:relative;width:360px;height:12px">${nine("slider_track", { extra: "position:absolute;inset:0" })}` +
    `<div class="fill" style="left:4px;top:3px;height:6px;width:calc((100% - 8px) * ${hold ? 0.56 : 0.72});background:${hold ? "var(--muted)" : "var(--amber)"};-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div></div>` +
    (hold
      ? `<div class="row" style="gap:8px">${glyph("alert", 20, "var(--amber)")}<span class="tx f20">Parado: o mouse está em cima · qualquer tecla fecha</span></div>`
      : `<span class="tx f20 muted">Fecha em 4 s · qualquer tecla fecha antes</span>`) + `</div>`;
  const head = `<div class="row" style="width:100%;justify-content:space-between;align-items:flex-start"><i style="width:56px;flex:none"></i>` +
    `<span class="tx f40 semi up">Batalha finalizada</span>${closeX()}</div>`;
  const pop = `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:40px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:680px;gap:8px;align-items:center" },
    `${head}<div class="row" style="gap:14px;justify-content:center"><span class="tx f26 semi up amber">Vitória</span>${stars}</div>${divider()}` +
    `${loot}${xp}${after}${divider()}${foot}`) + (hold ? over("focus_frame") : "") + `</div>`;
  return img("docs/design/hud-ajustes/before/fight_boss_clean.webp", "position:absolute;inset:0;width:1920px;height:1080px") +
    bodies(BOSS.units.map((u) => u.body.map(Math.round))) + BOSS.units.map(teamBar).join("") + pop;
}

// ------------------------------------------------------------------ 2. a barra de Admin (#130)
// O F1 abre por cima de qualquer tela (título, Estação, rua, luta): a tela de baixo escurece e fica parada. No alto, a
// faixa com ADMIN, as sete abas e o X; embaixo, o conteúdo da aba, denso, em linhas de rótulo e botões pequenos (os
// chips do kit). O que muda o save diz antes ("Isso altera o save"); cada ação diz o que fez num aviso curto embaixo.
const TABS = [["route", "Mapas"], ["weather", "Clima"], ["opt_graphics", "Ajustes"], ["lobby-seed.svg", "Recursos"], ["nav_characters", "Heróis"],
  ["intent-attack", "Testes de combate"], ["plan", "Cenas e Jornada"]];
function adminBar(active) {
  const tabs = TABS.map(([icon, label]) => `<div data-hit="admin-tab" style="position:relative;flex:none">` +
    nine("nav_tab", { cls: "row", extra: `height:calc(60px*var(--k));gap:8px;justify-content:center;padding:0 6px` },
      `${glyph(icon, 24, label === active ? "var(--amber)" : "var(--text)")}<span class="tx f22 semi up ${label === active ? "amber" : ""}">${label}</span>`) +
    (label === active ? over("nav_tab_active") : "") + `</div>`).join("");
  return `<div class="abs" style="left:28px;right:28px;top:14px">` + nine("panel_large", { repeat: "round", cls: "row", extra: "gap:12px;align-items:center" },
    `<div class="row" style="gap:10px;flex:none">${glyph("admin", 36, "var(--amber)")}<div class="col"><span class="tx f30 semi up">Admin</span><span class="tx f20 muted">Testes · F1 fecha</span></div></div>` +
    `<div class="row" style="gap:6px;flex:1;min-width:0;flex-wrap:wrap">${tabs}</div>${closeX("admin-close")}`) + `</div>`;
}
// Uma linha do conteúdo: o rótulo à esquerda, os controles à direita (quebram a linha no Maior).
const row = (label, controls, note = "") => `<div class="row" style="gap:16px;align-items:center;min-height:calc(56px*var(--k))">` +
  `<div class="col" style="width:260px;flex:none"><span class="wrap f22 semi">${label}</span>${note ? `<span class="wrap f20 muted">${note}</span>` : ""}</div>` +
  `<div class="row" style="gap:8px;flex-wrap:wrap;flex:1;min-width:0">${controls}</div></div>`;
const small = (label, opts = {}) => chip(label, { hit: "admin-action", ...opts });
const saveNote = `<div class="row" style="gap:10px">${glyph("alert", 24, "var(--danger)")}<span class="wrap f20 danger">Isso altera o save: cada ação pede para confirmar antes.</span></div>`;
const testNote = `<div class="row" style="gap:10px">${glyph("state_active", 24, "var(--good)")}<span class="wrap f20 good">Não altera o save: o teste sai sem mexer na campanha.</span></div>`;
const toast = (text) => `<div class="abs" style="left:50%;transform:translateX(-50%);bottom:28px">` +
  nine("cost_chip", { cls: "row", extra: "gap:10px;min-height:calc(56px*var(--k));padding:0 10px" }, `${glyph("state_active", 26, "var(--good)")}<span class="tx f24">${text}</span>`) + `</div>`;
const adminPanel = (title, body, width = 1300) => `<div class="abs" data-hit="panel" style="left:28px;top:calc(136px + 40px*(var(--k) - 1)/0.3)">` +
  nine("panel_large", { repeat: "round", cls: "col", extra: `width:${width}px;gap:8px;max-height:calc(1080px - 136px - 40px*(var(--k) - 1)/0.3 - 100px)` },
    `<span class="tx f26 semi up amber kicker">${title}</span>${divider()}<div class="col" data-scroll="1" style="gap:6px;overflow:hidden;min-height:0;padding-right:14px">${body}</div>`) + `</div>`;
const admin = (bg, tab, body, extra = "") => bg + veil(0.55) + adminBar(tab) + adminPanel(tab, body) + extra;
// As fases e os mapas de cada uma (journey_rules.gd: PHASES, com o mapa da travessia e o do trecho).
const PHASES = [["Fase 1 · Rua das Vitrines", ["Rua das Vitrines"]], ["Fase 2 · Ponte das Raízes", ["Cais (travessia)", "Ponte"]],
  ["Fase 3 · Sala Esquecida", ["Abrigo lacrado"]], ["Fase 4 · Laboratório Silencioso", ["Portão da triagem"]], ["Fase 5 · Túneis do Eco", ["Depósito alagado (travessia)", "Dutos"]]];
const adminMaps = () => admin(OWN("station_markers"), "Mapas",
  row("Telas", small("Título") + small("Estação Raiz", { selected: true }) + small("Mapa da Rede")) +
  PHASES.map(([phase, maps]) => row(phase, maps.map((m) => small(m)).join("") + small("Trecho 1") + small("Guardião"))).join("") +
  row("Ir com", small("A equipe de agora", { selected: true }) + small("A equipe inicial"), "Na rua, a campanha não muda"));
const adminWeather = () => admin(EXPLORE_BG("explore"), "Clima",
  row("Hora", small("Fim de tarde", { selected: true }) + small("Noite")) +
  row("Chuva", `<div class="row" style="gap:10px">${toggle(false)}<span class="tx f22">Desligada</span></div>`, "O antigo R da rua") +
  row("Onde vale", small("Só agora", { selected: true }) + small("A jornada inteira"), "O antigo T da rua era só agora"),
  toast("Hora: fim de tarde"));
const adminSettings = () => admin(EXPLORE_BG("explore"), "Ajustes",
  row("Câmera da exploração", `${slider(0.5, 300)}<span class="tx f22 amber">100%</span>`) +
  row("Câmera da Estação", `${slider(0.5, 300)}<span class="tx f22 amber">100%</span>`) +
  row("Câmera da luta", `${slider(0.5, 300)}<span class="tx f22 amber">100%</span>`) +
  row("Velocidade da luta", small("1x", { selected: true }) + small("2x")) +
  row("Pós-processamento", `<div class="row" style="gap:10px">${toggle(true)}<span class="tx f22">Ligado</span></div>`, "O antigo P da rua") +
  row("Colisões", `<div class="row" style="gap:10px">${toggle(false)}<span class="tx f22">Desligado</span></div>`, "O antigo C da rua") +
  row("Qualidade", small("Baixa") + small("Média") + small("Alta", { selected: true })));
const RES = [["lobby-seed.svg", "Sementes", "30"], ["lobby-scrap.svg", "Sucata", "9"], ["lobby-fragment.svg", "Fragmentos", "3"],
  ["lobby-food.svg", "Comida", "8 / 12"], ["lobby-water.svg", "Água", "6"], ["res-bandages.svg", "Curativos", "2"]];
const adminResources = () => admin(OWN("station_markers"), "Recursos",
  saveNote + RES.map(([icon, name, value]) => row(`<span class="row" style="gap:10px">${glyph(icon, 30)}${name} · <span class="amber">${value}</span></span>`,
    small("−1") + small("+1") + small("+5") + small("+10"))).join(""),
  toast("+10 sementes: agora 40"));
const HEROES = [["bento", "Bento", "active"], ["nick", "Nick", "light_wound"], ["iris", "Íris", "recovering"], ["vespera", "Véspera", "active"], ["lupa", "Lupa", "active"], ["brasa", "Brasa", "active"]];
const adminHeroes = (p) => admin(V2("station-characters"), "Heróis",
  saveNote + HEROES.map(([h, n, st]) => `<div class="row" style="gap:12px;min-height:calc(56px*var(--k))">${face(h, 52)}<span class="tx f24 semi" style="width:110px;flex:none">${n}</span>` +
    `<div style="width:230px;flex:none">${st === "recovering" ? recovering() : pill(st, p.cb)}</div>` +
    `<div class="row" style="gap:8px;flex-wrap:wrap;flex:1;min-width:0">${small("Curar")}${st === "recovering" ? small("Tirar da recuperação") : small("Cair")}${small("+50 XP")}${small("+1 nível")}</div></div>`).join("") +
  row("Recrutar agora", small("Gato") + small("Cão") + small("Sapo") + small("Coruja")) +
  row("No próximo trem", small("Alguém chega", { selected: true }) + small("Ninguém"), "A chegada da #122"));
const ENEMIES = ["Recreador", "Emissor de Comando", "Pipoco", "Enraizado", "Coletor de Sucata", "O Porteiro"];
const adminCombat = (p) => admin(img("docs/design/loop-screens/before/combat_clean.webp", "position:absolute;inset:0;width:1920px;height:1080px"), "Testes de combate",
  testNote + row("Rua", small("Próxima patrulha"), "O antigo K da rua") +
  row("Luta contra", ENEMIES.map((e, i) => small(e, { selected: i === 0 })).join("")) +
  row("Na luta de agora", small("Forçar Superação") + small("Forçar Colapso") + small("+50 de Instinto") + small("Curar a equipe")) +
  row("Terminar", small("Vencer") + small("Perder") + small("Fugir")),
  toast("Superação na próxima crise do Nick"));
const EVENTS = ["A Porta que Ainda Espera", "Voz no Interfone", "Sobrevivente dos Túneis", "Caixa Lacrada", "Cano Rompido"];
function adminJourney() {
  const body = saveNote + row("Fase de agora", small("Finalizar") + small("Resetar")) + row("Todas as fases", small("Liberar todas")) +
    row("A noite", small("Pular a noite") + small("Pular o amanhecer")) +
    row("Abrir um evento", EVENTS.map((e) => small(e)).join("") + small("Mais 5…")) + row("Briefing", small("Abrir o briefing")) +
    row("Estação", small("Recuperar todos os cômodos"));
  // A confirmação do que muda o save, por cima do painel.
  const confirm = `<div class="abs" style="inset:0;background:rgba(5,6,7,.45)"></div><div class="abs" data-hit="dialog" style="left:50%;top:50%;transform:translate(-50%,-50%)">` +
    nine("panel_large", { repeat: "round", cls: "col", extra: "width:640px;gap:12px" },
      `<div class="row" style="gap:12px">${glyph("alert", 36, "var(--danger)")}<span class="tx f36 semi up">Liberar todas as fases?</span></div>` +
      `<span class="wrap f22">Isso altera o save: as cinco fases ficam abertas no Mapa da Rede, e não dá para desfazer.</span>` +
      `<div class="row" style="gap:16px;justify-content:flex-end">${secondary("Cancelar", { keyLabel: "Esc / B", hit: "cancel", height: 64 })}` +
      `<div style="min-width:300px">${primary("Liberar", { keyLabel: "E / A", hit: "confirm", height: 64, size: "f26" })}</div></div>`) + `</div>`;
  // Com a confirmação aberta, a tela de baixo fica sem alvos (o véu bloqueia o clique) e fora das conferências de texto
  // (as classes tx e wrap viram tx-u e wrap-u, com o mesmo estilo), como na confirmação da plataforma (hud-casa).
  const under = admin(OWN("station_markers"), "Cenas e Jornada", body).replace(/ data-hit="[^"]*"/g, "").replace(/class="(tx|wrap)( |")/g, 'class="$1-u$2');
  return `<style>.tx-u{white-space:nowrap;line-height:1.14}.wrap-u{white-space:normal;line-height:1.18}</style>` + under + confirm;
}

// ------------------------------------------------------------------ 3. os marcadores dos cômodos (#131)
// Como no XCOM 2: sobre cada cômodo não recuperado, uma placa com o cadeado e o que falta. O que já dá para recuperar
// fica aceso (âmbar, com o custo e o que se tem); o que ainda não dá fica apagado, com o motivo. Os recuperados ficam sem
// placa. Um Dia 2 (antes da volta do lote 7): a Forja e a Enfermaria vazias; o Bar chega numa próxima fase.
const MARKERS = [
  { cx: 1310, top: 662, name: "Forja", icon: "room_forge", avail: true, text: "4 sucatas · tem 9" },
  { cx: 530, top: 662, name: "Enfermaria", icon: "room_infirmary", avail: false, text: "Faltam 2 fragmentos" },
  { cx: 1162, top: 532, name: "Bar", icon: "room_bar", avail: false, text: "Numa próxima fase" },
];
const marker = ({ cx, top, name, icon, avail, text }, focus) => `<div class="abs" data-hit="room-marker" style="left:${cx}px;top:${top}px;transform:translateX(-50%)">` +
  nine("room_tag", { cls: "col", extra: `gap:2px;align-items:center;min-height:56px;padding:0 4px;${avail ? "" : "opacity:.9"}` },
    `<div class="row" style="gap:6px">${glyph(avail ? icon : "lock", 22, avail ? "var(--amber)" : "var(--muted)")}<span class="tx f22 semi ${avail ? "" : "muted"}">${name}</span></div>` +
    (avail ? `<div class="row" style="gap:6px">${glyph("lobby-scrap.svg", 20)}<span class="tx f20 amber">${text}</span></div>` : `<span class="tx f20 muted">${text}</span>`)) +
  (avail ? over("selected_frame") : "") + (focus ? over("focus_frame") : "") + `</div>`;
const STOCK = { subtitle: "Dia 2 · Visão geral", heroes: "5 de 8", helpers: "2 de 4", stock: ["14", "9", "0", "2"], food: ["6 / 12 suprimentos", "Abastecida · demanda 4", false] };
function stationMarkers({ focus = false } = {}) {
  const body = `<span class="tx f36 semi">Recuperar a Forja</span><span class="wrap f22">Com a Forja, a Estação fabrica relíquias e conserta o que precisa.</span>` +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-scrap.svg", "4 sucatas · tem 9")}</div>` + secondary("Ver a Forja", { icon: "room_forge", hit: "next", height: 60, extra: "width:100%" });
  // Com o foco na placa da Enfermaria, o cartão do cômodo embaixo mostra o que falta e o que ela destrava.
  const card = focus ? `<div class="abs" style="left:28px;bottom:calc(14px + 72px*var(--k) + 14px)">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:500px;gap:8px" },
    `<div class="row" style="gap:12px">${glyph("room_infirmary", 36, "var(--amber)")}<span class="tx f32 semi up">Enfermaria</span>${roomTag("Vazio")}</div>` +
    `<span class="wrap f22">Recuperada, os leitos de quem caiu: volta em 3 dias, e não em 4 no Dormitório.</span>` +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-scrap.svg", "4 sucatas · tem 9")}${cost("lobby-fragment.svg", "2 fragmentos · tem 0", true)}</div>` +
    train("Recuperar", "faltam 2 fragmentos", { hit: "recover", locked: true, icon: "lock" })) + `</div>` : "";
  return OWN("station_markers") + topBar(STOCK) + MARKERS.map((m) => marker(m, focus && m.name === "Enfermaria")).join("") +
    `<div class="abs col" style="left:28px;top:132px;gap:12px">${next(body)}</div>` + card +
    bottom({ active: 0, back: false, keysAt: 840, keys: [["Setas", "Cômodos"], ["E", "Abrir"], ["Esc", "Menu"], ["F2", "Ocultar"]], main: TO_MAP });
}

// ------------------------------------------------------------------ 4. a noite e o amanhecer (#132)
// Ao INICIAR DESCANSO, a Estação escurece (as luzes dos cômodos se apagam, a do Dormitório e a da Enfermaria ficam
// baixas) e o cartão "Noite N" mostra o tempo passando; dá para pular. Com "Reduzir efeitos", só o cartão.
function nightCard() {
  const card = `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:150px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:600px;gap:12px;align-items:center" },
    `<div class="row" style="gap:16px">${glyph("night", 60, "var(--amber)")}<div class="col"><span class="tx f52 semi up">Noite 4</span><span class="tx f22 muted">Do Dia 4 para o Dia 5</span></div></div>` +
    `<span class="wrap f22" style="text-align:center">Quatro dormem no Dormitório, a Véspera vigia e a Íris está na Enfermaria.</span>` +
    `<div class="col" style="gap:6px;align-items:center;width:100%"><div style="position:relative;width:420px;height:12px">${nine("slider_track", { extra: "position:absolute;inset:0" })}` +
    `<div class="fill" style="left:4px;top:3px;height:6px;width:calc((100% - 8px) * 0.45);background:var(--amber);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div></div>` +
    `<span class="tx f20 muted">A noite passa</span></div>` + secondary("Pular", { icon: "skip", keyLabel: "Esc / B", hit: "skip", height: 60 })) + `</div>`;
  return OWN("station_night") + card;
}
// O painel "Amanhecer · Dia N" no lugar do painel do cômodo: o que a noite fez (a comida, quem descansou, a
// Enfermaria), o evento da noite e o Próximo passo; COMEÇAR O DIA no pé. PREPARAR fica bloqueado até lá.
function dawn({ event = true } = {}) {
  const who = (hero, name, text, color = "var(--text)") => `<div class="row" style="gap:12px">${face(hero, 44)}<span class="wrap f22" style="flex:1;min-width:0;color:${color}"><b class="semi">${name}</b> ${text}</span></div>`;
  const ev = event
    ? inset(`<div class="row" style="gap:14px;align-items:flex-start">${glyph("watch", 44, "var(--amber)")}<div class="col" style="flex:1;min-width:0"><span class="tx f28 semi">A Véspera viu luzes na Ponte</span>` +
      `<span class="wrap f22">Da vigia, ela viu as lanternas da patrulha na Ponte das Raízes. O Mapa da Rede leu os inimigos de lá: Enraizado.</span></div></div>`)
    : inset(`<div class="row" style="gap:14px;align-items:flex-start">${glyph("night", 44, "var(--muted)")}<div class="col" style="flex:1;min-width:0"><span class="tx f28 semi">Noite calma</span>` +
      `<span class="wrap f22">Nada aconteceu. Com alguém de vigia, as chances de uma noite ruim caem pela metade.</span></div></div>`);
  const body = section("O que a noite fez", "night") +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-food.svg", "Comida 8 → 4")}</div><span class="wrap f20 muted">A Cantina e a Dora renderam 4; os civis comeram 4, e a noite, 4. A água não cai à noite.</span>` +
    who("nick", "Nick", `+8 de vida (9 ${arrow()} 17), −15 de instinto`) + who("bento", "Bento", "−15 de instinto") +
    who("vespera", "Véspera", "vigiou: não descansou") + who("iris", "Íris", "na Enfermaria: volta amanhã", "var(--amber)") +
    section("Durante a noite", event ? "watch" : "night") + ev +
    section("Próximo passo", "next_step") + `<span class="wrap f22">Escolher o lugar da próxima expedição no Mapa da Rede. A Íris volta amanhã.</span>`;
  return MINE("station_day5") + topBar({ subtitle: "Dia 5 · Amanhecer", food: ["4 / 12 suprimentos", "Abastecida · demanda 4", false] }) +
    roomPanel({ icon: "dawn", title: "Amanhecer · Dia 5", body, footer: primary("Começar o dia", { keyLabel: "E / A", hit: "start-day", height: 64, size: "f26" }) }) +
    bottom({ active: 0, back: false, keysAt: 840, keys: [["Setas", "Rolar"], ["E", "Começar"], ["F2", "Ocultar"]], main: { ...TO_MAP, locked: true, reason: "Comece o dia antes de partir." } });
}

// ------------------------------------------------------------------ 5. a troca de formação na exploração (#129)
// Fora da luta e dos eventos, FORMAÇÃO (tecla nova; R, a antiga da chuva, sai na #129) põe as plaquinhas em modo de
// troca: o número da posição em cada uma e sobre cada herói na rua (da frente para trás), o foco do teclado, e quem foi
// escolhido em âmbar. Clicar em dois troca os dois; vale para a próxima luta e para a fila na rua.
const ORDER = [["bento", "Bento", 34, 34, 1], ["nick", "Nick", 24, 24, 2], ["iris", "Íris", 23, 23, 3], ["vespera", "Véspera", 30, 30, 4]];
// A cabeça de cada um na captura (hud-ajustes: EXPLORE_BODIES), de trás (Véspera) para a frente (Bento).
const HEADS = { vespera: [470, 738], iris: [637, 772], nick: [799, 758], bento: [960, 732] };
function formation({ picked = null, focus = "bento" } = {}) {
  const plates = `<div class="abs col" style="left:28px;bottom:14px;gap:8px">` +
    nine("cost_chip", { cls: "row", extra: "gap:10px;min-height:calc(48px*var(--k));align-self:flex-start" },
      `${glyph("formation_swap", 24, "var(--amber)")}<span class="tx f22 semi up amber">Formação</span><span class="tx f22">${picked ? `E troca o ${ORDER.find((o) => o[0] === picked)[1]} com a ${ORDER.find((o) => o[0] === focus)[1]}` : "da frente para trás · escolha dois para trocar"}</span>`) +
    `<div class="row" style="gap:8px">` + ORDER.map(([hero, name, hp, max, pos]) => `<div data-hit="hero" style="position:relative">` +
      nine("panel", { cls: "row", extra: "min-width:226px;min-height:80px;gap:10px" },
        `<div style="position:relative;flex:none">${face(hero, 56)}<div data-avoid="1" style="position:absolute;left:-12px;top:-14px">${medal(pos, 34)}</div></div>` +
        `<div class="col" style="gap:3px;flex:1;min-width:0"><div class="row" style="justify-content:space-between;gap:10px"><span class="tx f22 semi ${hero === picked ? "amber" : ""}">${name}</span><span class="tx f20">${hp}/${max}</span></div>${bar("100%", 18, hp / max, "var(--ally)")}</div>`) +
      (hero === picked ? over("selected_frame") : "") + (hero === focus ? over("focus_frame") : "") +
      // Quem foi escolhido ganha a marca da troca no canto (a moldura âmbar sozinha confunde com o foco).
      (hero === picked ? `<div data-avoid="1" class="row" style="position:absolute;right:10px;top:-30px;width:34px;height:34px;justify-content:center;background:var(--amber);border:1px solid #0a0b0c">${glyph("formation_swap", 24, "#1a1206")}</div>` : "") +
      `</div>`).join("") + `</div></div>`;
  const heads = ORDER.map(([hero, , , , pos]) => `<div class="abs" data-avoid="1" style="left:${HEADS[hero][0] - 22}px;top:${HEADS[hero][1] - 56}px">${medal(pos, 44)}</div>`).join("");
  // FORMAÇÃO ligada: a moldura âmbar no botão, como o INSPECIONAR na luta.
  const buttons = `<div style="position:relative;flex:none">${secondary("Formação", { icon: "formation_swap", keyLabel: "R", hit: "formation", height: 64 })}${over("selected_frame")}</div>` +
    secondary("Mochila", { icon: "expeditions", keyLabel: "I", hit: "bag", height: 64 }) + secondary("Menu", { icon: "lobby-settings.svg", keyLabel: "Esc", hit: "menu", height: 64 });
  return EXPLORE_BG("explore") + bodies([[395, 738, 150, 220], [572, 772, 130, 195], [728, 758, 142, 207], [888, 732, 145, 233]]) +
    frame({ team: [], buttons, keys: [["←|→", "Escolher"], ["E", "Trocar"], ["Esc", "Fechar"]] }) + heads + plates;
}

await run({
  fight_intent: (p) => fightIntent(p),
  fight_inspect_hero: (p) => fightInspect("bento")(p),
  fight_inspect_machine: (p) => fightInspect("recreador")(p),
  fight_popup: (p) => fightPopup(p),
  fight_popup_hold: (p) => fightPopup(p, { hold: true }),
  admin_maps: () => adminMaps(),
  admin_weather: () => adminWeather(),
  admin_settings: () => adminSettings(),
  admin_resources: () => adminResources(),
  admin_heroes: (p) => adminHeroes(p),
  admin_combat: (p) => adminCombat(p),
  admin_journey: () => adminJourney(),
  station_markers: () => stationMarkers(),
  station_markers_focus: () => stationMarkers({ focus: true }),
  night_card: () => nightCard(),
  dawn_event: () => dawn(),
  dawn_quiet: () => dawn({ event: false }),
  explore_formation: () => formation(),
  explore_formation_pick: () => formation({ picked: "nick", focus: "iris" }),
}, OUT);
