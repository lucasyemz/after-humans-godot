// Lote 5: os três ajustes do Lucas na #109, no kit da Awesomic (art/ui/kit/station):
// 1. o acampamento na estrutura da Unreal (docs/design/reference/unreal-camp-sitting.jpg e unreal-camp-hud.jpg);
// 2. o Menu da expedição no lugar da "Pausa", e a variante sem menu;
// 3. o popup curto de fim de luta (vitória com e sem recursos, Treino pronto, guardião, fuga e derrota).
// Fundos: as capturas limpas do jogo em before/ (capture.gd, gl_compatibility 1920x1080) e, no menu, as da exploração
// (hud-v2/before). Textos e números: os dessas capturas (before/*.json), de scripts/ui/camp_hud.gd,
// scripts/ui/exploration_hud.gd, scripts/ui/combat_hud.gd e das regras (AHJourneyRules.end_combat e finish_corridor).
// Uso (da raiz do repositório, com python3 -m http.server 8765 servindo a raiz):
//   node docs/design/hud-ajustes/render.mjs http://127.0.0.1:8765
import fs from "node:fs";
import {
  setBase, BASE, KIT, nine, over, img, glyph, key, bar, portrait, divider, cost, secondary, primary, run,
} from "../hud-kit/lib.mjs";
import { frame, modal, MODAL, at, BG as EXPLORE_BG } from "../hud-exploracao/render.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-ajustes/.render";
const DIR = "docs/design/hud-ajustes/before";
const data = (name) => JSON.parse(fs.readFileSync(`${DIR}/${name}.json`, "utf8"));
const BG = (name) => img(`${DIR}/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const FACE = { hero_cao_bento: "bento", hero_gato_nick: "nick", hero_sapo_iris: "iris", hero_coruja_vespera: "vespera" };
// O corpo de cada herói na cena (data-hit="hero-body", medido na captura): a conferência acusa qualquer painel ou botão
// por cima da equipe.
const bodies = (list) => list.map((b) => `<div class="abs" data-hit="hero-body" style="left:${Math.round(b[0])}px;top:${Math.round(b[1])}px;width:${Math.round(b[2])}px;height:${Math.round(b[3])}px"></div>`).join("");
// O texto com a seta (→) vira glifo: a Barlow Condensed não tem esse caractere.
const withArrow = (text, cls) => text.split("→").map((t) => `<span class="wrap ${cls}">${t.trim()}</span>`).join(glyph("ui-arrow-right.svg", 18, "var(--amber)", "margin:0 6px"));

// ------------------------------------------------------------------ 1. o acampamento
const CAMP = data("camp");
const CAMP_NICK = fs.existsSync(`${DIR}/camp_nick.json`) ? data("camp_nick") : CAMP;
// As cartas na ordem da cena, da esquerda para a direita (Véspera e Íris à esquerda do fogo, Nick e Bento à direita).
const SEATED = [...CAMP.members].sort((a, b) => a.feet[0] - b.feet[0]);
const STOCK = { food: CAMP.food, bandages: CAMP.bandages };
const EXTRA = (p) => `<style>:root{--preview:${p.cb ? "#a9d8f5" : "#a6e3ae"}}</style>`;

// A barra da carta: a vida de agora (bar_fill ciano) e, com o foco num cuidado, a vida prevista por cima (bar_preview
// verde claro com riscas, do fim da vida de agora até a prevista, repetida na largura: TILE, como na Godot), sem gastar nada.
function lifeBar(hp, max, preview = 0) {
  const h = 20, inset = Math.max(3, Math.round(h * 0.23));
  return `<div class="bar" style="width:100%;height:${h}px">${nine("main_bar", { extra: "position:absolute;inset:0" })}` +
    `<div class="fill" style="left:7px;top:${inset}px;bottom:${inset}px;width:calc((100% - 14px) * ${hp / max});background:var(--ally);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div>` +
    (preview ? `<div class="fill" style="left:calc(7px + (100% - 14px) * ${hp / max});top:${inset}px;bottom:${inset}px;width:calc((100% - 14px) * ${preview / max});background:var(--preview);-webkit-mask-image:url(${BASE}/${KIT.bar_preview.file});-webkit-mask-size:auto 100%;-webkit-mask-repeat:repeat-x"></div>` : "") + `</div>`;
}
// A carta do herói: as mesmas peças das cartas da Preparação (hero_card, square_portrait, a barra), menor. A escolhida tem
// as cantoneiras âmbar (selected_corners, como quem age na luta); o foco do teclado, a moldura inteira (focus_frame).
const heroCard = (m, { selected = false, focus = false, preview = 0 }) =>
  `<div data-hit="card" style="position:relative;flex:none">` + nine("hero_card", { repeat: "round", cls: "col", extra: "width:252px;gap:8px" },
    `<div class="row" style="gap:12px">${portrait(FACE[m.hero_id], 72)}<div class="col" style="flex:1;min-width:0;gap:2px">` +
    `<span class="tx f26 semi up ${selected ? "amber" : ""}">${m.name}</span>` +
    (preview ? `<div class="row"><span class="tx f22">${m.hp}</span>${glyph("ui-arrow-right.svg", 16, "var(--preview)", "margin:0 4px")}<span class="tx f22 semi" style="color:var(--preview)">${m.hp + preview}</span><span class="tx f22">&nbsp;/ ${m.max_hp}</span></div>`
      : `<span class="tx f22">${m.hp} / ${m.max_hp}</span>`) + `</div></div>` +
    lifeBar(m.hp, m.max_hp, preview)) + (selected ? nine("selected_corners", { cls: "over" }) : "") + (focus ? over("focus_frame") : "") + `</div>`;
// Os dois cuidados grandes: o nome, o efeito numa linha e o estoque. Sem efeito (vida cheia), apagados no tom cheio.
// Sem efeito: o véu escuro sobre a chapa (como a habilidade sem uso da luta), o ícone e o texto no tom apagado, sem
// transparência no texto.
const care = (icon, label, effect, stock, { focus = false, off = false, hit }) =>
  `<div data-hit="${hit}" style="position:relative;flex:1 1 0;min-width:0">` + nine("secondary_button", { cls: "row", extra: "min-height:calc(76px*var(--k));gap:14px" },
    (off ? `<i style="position:absolute;inset:0;background:repeating-linear-gradient(135deg,rgba(6,7,8,.62) 0 10px,rgba(6,7,8,.48) 10px 20px)"></i>` : "") +
    `${glyph(icon, 40, off ? "#8a8478" : "var(--amber)", "position:relative")}<div class="col" style="flex:1;min-width:0;position:relative"><span class="tx f28 semi up ${off ? "muted" : ""}">${label}</span>` +
    `<span class="tx f22 muted">${effect}</span></div><span class="tx f30 semi ${off ? "muted" : "amber"}" style="position:relative">x${stock}</span>`) + (focus ? over("focus_frame") : "") + `</div>`;

function camp({ chosen = "hero_cao_bento", focus = "card", preview = 0, status, background = "camp" }, p) {
  const hero = CAMP.members.find((m) => m.hero_id === chosen);
  // As regras de hoje (AHJourneyRules.camp_use_food e camp_use_bandage): a Ração só fica sem efeito com a vida cheia e o
  // instinto em 0 (com instinto, ela ainda baixa 5); o Curativo, com a vida cheia.
  const offFood = hero.hp >= hero.max_hp && hero.instinct <= 0, offBandage = hero.hp >= hero.max_hp, full = offFood && offBandage;
  const plaque = `<div class="abs" style="left:28px;top:14px">` + nine("room_plaque", { cls: "row", extra: "min-width:440px;min-height:96px;gap:16px" },
    `${glyph("node-rest.svg", 48, "var(--amber)")}<div class="col"><span class="tx f40 semi up">Acampamento</span><span class="tx f24 muted">Ponto seguro</span></div>`) + `</div>`;
  // A Mochila (a ampola da Íris e os itens da expedição, #98) e o MENU (Esc, o Menu da expedição) continuam, no alto.
  const bag = `<div class="abs row" style="right:28px;top:14px;gap:10px">${secondary("Mochila", { icon: "expeditions", keyLabel: "I", hit: "bag", height: 64 })}` +
    `${secondary("Menu", { icon: "lobby-settings.svg", keyLabel: "Esc", hit: "menu", height: 64 })}</div>`;
  const cards = `<div class="row" style="gap:12px;flex:none;align-items:flex-start">${SEATED.map((m) => heroCard(m, { selected: m.hero_id === chosen,
    focus: focus === "card" && m.hero_id === chosen, preview: m.hero_id === chosen ? preview : 0 })).join("")}</div>`;
  const side = `<div class="col" style="flex:1;min-width:0;gap:8px">` +
    `<div class="row" style="gap:16px;justify-content:space-between"><span class="tx f34 semi up">${hero.name}</span><span class="tx f22 muted">Instinto ${hero.instinct}/200</span></div>` +
    divider() + `<div class="row" style="gap:14px">` +
    care("lobby-food.svg", "Ração", "+10% vida · −5 instinto", STOCK.food, { focus: focus === "food", off: offFood, hit: "eat" }) +
    care("res-bandages.svg", "Curativo", "+8 vida", STOCK.bandages, { focus: focus === "bandage", off: offBandage, hit: "bandage" }) + `</div></div>`;
  const keys = nine("keys_bar", { cls: "row", extra: "gap:18px;height:calc(56px*var(--k));justify-content:center;flex:none" },
    [["Setas", "Herói e cuidados"], ["E", "Escolher"]].map(([k, t]) => `<div class="row" style="gap:6px">${key(k)}<span class="tx f22">${t}</span></div>`).join(""));
  const foot = `<div class="row" style="gap:18px">${glyph(full ? "state_active" : "next_step", 24, full ? "var(--muted)" : "var(--amber)")}` +
    `<div class="row" style="flex:1;min-width:0;flex-wrap:wrap">${withArrow(status, "f22")}</div>${keys}` +
    `<div style="width:340px;flex:none">${primary("Continuar", { icon: "route", hit: "leave", height: 64, size: "f26" })}</div></div>`;
  const panel = `<div class="abs" data-hit="panel" style="left:14px;right:14px;bottom:14px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "gap:10px" },
    `<div class="row" style="gap:28px;align-items:flex-start">${cards}${side}</div>${divider()}${foot}`) + `</div>`;
  const scene = background === "camp" ? CAMP.members : CAMP_NICK.members;
  return EXTRA(p) + BG(background) + bodies(scene.map((m) => m.body)) + plaque + bag + panel;
}
const bento = CAMP.members.find((m) => m.hero_id === "hero_cao_bento");
const FOOD_GAIN = Math.floor(bento.max_hp * 0.1);

// ------------------------------------------------------------------ 2. o Menu da expedição
const MENU_ROUTE = at(2, [3]);
// O corpo dos quatro na captura da rua (hud-v2/before/explore-options_clean.webp), medido na imagem: a captura antiga não
// tem os DTOs do corpo.
const EXPLORE_BODIES = [[395, 738, 150, 220], [572, 772, 130, 195], [728, 758, 142, 207], [888, 732, 145, 233]];
const MENU_FRAME = { title: "Trecho 3 de 10 · Patrulha", route: MENU_ROUTE, found: ["2", "1", "0"] };
function menu() {
  const close = `<div data-hit="close">${nine("icon_button", { pad: [6, 6, 6, 6], extra: "width:56px;height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, `<span class="tx f28 semi">X</span>`)}</div>`;
  const wide = (icon, text, hit, cls = "", color = "var(--text)", sub = "") => `<div data-hit="${hit}">${nine("secondary_button", { cls: "row", extra: "min-height:calc(64px*var(--k));gap:10px;justify-content:center" },
    `${glyph(icon, 26, color)}<div class="col" style="align-items:center"><span class="tx f26 semi up ${cls}">${text}</span>${sub ? `<span class="tx f20 muted">${sub}</span>` : ""}</div>`)}</div>`;
  // O pé do painel fica em y 720, acima das cabeças da equipe (a do Bento em y 732): no Normal o topo cai em 246, perto do
  // da Pausa (230); no Maior, o painel cresce para cima.
  return EXPLORE_BG("explore-options") + bodies(EXPLORE_BODIES) + frame({ ...MENU_FRAME, keys: MODAL }) + modal(660, 0,
    `<div class="row" style="gap:12px;align-items:flex-start"><div class="col" style="flex:1;min-width:0"><span class="tx f20 semi up amber kicker">Menu da expedição</span>` +
    `<span class="wrap f40 semi up">Rua das Vitrines</span><span class="tx f24 muted">Trecho 3 de 10 · Patrulha</span></div>${close}</div>` + divider() +
    wide("train_arrival", "Voltar à Estação", "return", "", "var(--text)", "Retirada: metade do achado") +
    wide("lobby-settings.svg", "Opções", "options") + wide("alert", "Nova campanha", "new-campaign", "danger", "var(--danger)") +
    primary("Fechar", { keyLabel: "Esc / B", hit: "close-main", height: 64, size: "f26" })).replace("top:0px", "bottom:360px");
}
// Sem o menu: o MENU vira OPÇÕES (Esc abre as Opções de hoje, com Nova campanha na seção Campanha) e Voltar à Estação
// ganha botão próprio, com a mesma confirmação de retirada.
function menuDirect() {
  const buttons = secondary("Mochila", { icon: "expeditions", keyLabel: "I", hit: "bag", height: 64 }) +
    secondary("Voltar à Estação", { icon: "train_arrival", hit: "return", height: 64 }) +
    secondary("Opções", { icon: "lobby-settings.svg", keyLabel: "Esc", hit: "options", height: 64 });
  return EXPLORE_BG("explore") + bodies(EXPLORE_BODIES) + frame({ ...MENU_FRAME, buttons });
}

// ------------------------------------------------------------------ 3. o popup de fim de luta
// A vida sob cada herói, como na luta (main_bar com bar_fill ciano e o valor dentro; ally_mark no daltonismo).
// Com a câmera mais aberta (o guardião: a arena enquadra também quem caiu), a barra encolhe até caber entre os pés.
const teamBar = (u, cb, large, w = 200) => {
  const h = large ? 46 : 44, left = cb ? 30 : 8;
  return `<div class="abs" style="left:${Math.round(u.feet[0] - w / 2)}px;top:${Math.round(u.feet[1]) + 4}px;width:${w}px;height:${h}px">` +
    nine("main_bar", { pad: large ? [13, 8, 0, left] : [15, 8, 2, left], cls: "col", extra: `width:${w}px;height:${h}px` },
      `<div style="position:absolute;left:0;right:0;top:-10px;height:10px"><div style="height:100%;background:var(--ally);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%;width:${(u.hp / u.max_hp) * 100}%"></div></div>` +
      `<span class="tx f24 semi ${u.hp <= 0 ? "muted" : ""}" style="text-align:center;line-height:1.05">${u.hp <= 0 ? "Caído" : `${u.hp}/${u.max_hp}`}</span>`) +
    (cb ? img(KIT.ally_mark.file, `position:absolute;left:0;top:${-12 * h / 44}px;width:${28 * h / 44}px;height:${56 * h / 44}px`) : "") + `</div>`;
};
const RESOURCE = { seeds: ["lobby-seed.svg", "semente", "sementes"], scrap: ["lobby-scrap.svg", "sucata", "sucata"], fragments: ["lobby-fragment.svg", "fragmento", "fragmentos"] };
const chips = (loot, sign) => Object.entries(loot).filter(([, n]) => n > 0)
  .map(([k, n]) => cost(RESOURCE[k][0], `${sign}${n} ${n === 1 ? RESOURCE[k][1] : RESOURCE[k][2]}`, sign !== "+")).join("");
const stars = (n) => `<div class="row" style="gap:4px">${[0, 1, 2].map((i) => glyph(i < n ? "star" : "star_empty", 28, i < n ? "var(--amber)" : "var(--muted)")).join("")}</div>`;

// O popup: no alto, longe da equipe, sem botão. Fecha sozinho em cerca de 2,5 s (a linha âmbar embaixo) ou com qualquer
// tecla, clique ou toque; a derrota espera um toque, porque muda a expedição.
function popup(name, { title, tone, starsShown = false, gained = null, lost = null, lostNote = "", note = "", xp = true, extraLine = "", after = "", hold = true }) {
  const d = data(name);
  const head = `<div class="row" style="gap:14px;justify-content:center"><span class="tx f26 semi up ${tone}">${title}</span>${starsShown ? stars(d.rewards.stars) : ""}</div>`;
  let res;
  if (gained) res = Object.values(gained).some((n) => n > 0) ? `<div class="row" style="gap:10px;justify-content:center;flex-wrap:wrap">${chips(gained, "+")}</div>`
    : `<span class="tx f24 muted">Nenhum recurso nesta luta</span>`;
  if (lost) res = `<span class="wrap f22" style="text-align:center">${lostNote}</span><div class="row" style="gap:10px;justify-content:center;flex-wrap:wrap">${chips(lost, "−")}</div>`;
  const lines = [res,
    note ? `<span class="wrap f22" style="text-align:center">${note}</span>` : "",
    xp ? `<span class="tx f22 semi" style="color:var(--xp)">XP: ${[...d.units].sort((a, b) => a.feet[0] - b.feet[0]).map((u) => `${u.name} +${u.xp_gained}`).join(" · ")}</span>` : "",
    extraLine, after].filter(Boolean).join("");
  const foot = hold
    ? `<div class="col" style="gap:6px;align-items:center;width:100%"><div style="position:relative;width:320px;height:12px">${nine("slider_track", { extra: "position:absolute;inset:0" })}` +
      `<div class="fill" style="left:4px;top:3px;height:6px;width:calc((100% - 8px) * 0.62);background:var(--amber);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div></div>` +
      `<span class="tx f20 muted">Fecha sozinho · qualquer tecla fecha antes</span></div>`
    : `<div class="row" style="gap:8px;justify-content:center">${glyph("next_step", 22, "var(--amber)")}<span class="tx f22">Qualquer tecla ou toque para continuar</span></div>`;
  return `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:40px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:640px;gap:8px;align-items:center" },
    `<span class="tx f40 semi up">Batalha finalizada</span>${head}${divider()}${lines}${divider()}${foot}`) + `</div>`;
}
// Os caídos não têm barra (na derrota, a equipe inteira está no chão).
const fight = (name, opts) => (p) => {
  const up = data(name).units.filter((u) => u.hp > 0);
  const xs = up.map((u) => u.feet[0]).sort((a, b) => a - b);
  const gap = Math.min(...xs.slice(1).map((x, i) => x - xs[i]));
  return BG(name) + bodies(up.map((u) => u.body)) + up.map((u) => teamBar(u, p.cb, p.k > 1, Math.min(200, Math.floor(gap - 12)))).join("") + popup(name, opts);
};
const lootOf = (name) => { const l = data(name).loot_before; return { seeds: l.seeds, scrap: l.scrap, fragments: l.fragments }; };
const trained = (name) => data(name).units.filter((u) => u.training_ready).map((u) => u.name);

await run({
  camp: (p) => camp({ status: "Bento: escolha um cuidado. A barra mostra a vida prevista antes de gastar." }, p),
  camp_preview: (p) => camp({ focus: "food", preview: FOOD_GAIN,
    status: `Ração no Bento: vida ${bento.hp} → ${bento.hp + FOOD_GAIN} de ${bento.max_hp}. Nada é gasto até confirmar.` }, p),
  camp_full: (p) => camp({ chosen: "hero_gato_nick", background: "camp_nick", status: "Nick está com a vida cheia e o instinto em 0: nenhum cuidado faz efeito." }, p),
  menu: () => menu(),
  menu_direct: () => menuDirect(),
  // Patrulha vencida: o jogo não dá recurso na patrulha (AHJourneyRules.end_combat).
  fight_none: fight("fight_patrol", { title: "Vitória", tone: "amber", starsShown: true, gained: {} }),
  fight_level: fight("fight_level", { title: "Vitória", tone: "amber", starsShown: true, gained: {},
    extraLine: trained("fight_level").map((n) => `<div class="row" style="gap:8px">${glyph("train", 24, "var(--amber)")}<span class="tx f24 semi amber">${n}: Treino pronto</span></div>`).join("") }),
  // O guardião: +6 sementes e +1 sucata (end_combat) e a fase concluída, +10 sementes, +2 sucata e +1 fragmento
  // (finish_corridor). A carga recuperada abre em seguida.
  fight_loot: fight("fight_boss", { title: "Vitória", tone: "amber", starsShown: true, gained: { seeds: 16, scrap: 3, fragments: 1 },
    after: `<div class="row" style="gap:8px">${glyph("next_step", 22, "var(--amber)")}<span class="tx f22">A carga do guardião abre em seguida</span></div>` }),
  fight_fled: fight("fight_fled", { title: "Fuga", tone: "", xp: false, lost: lootOf("fight_fled"), lostNote: "A equipe recuou pelas sombras e largou o que carregava." }),
  fight_defeat: fight("fight_defeat", { title: "Derrota", tone: "danger", xp: false, hold: false, lost: lootOf("fight_defeat"),
    lostNote: "Todos caíram nas ruínas. O achado ficou para trás." }),
}, OUT);
