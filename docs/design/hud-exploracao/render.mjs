// Lote 2: a HUD da exploração (a rua, os interiores, os cenários) no idioma do kit da Estação.
// Fundos: as capturas limpas do jogo em docs/design/hud-v2/before/; textos e números: os dessas capturas (os .json), de
// scripts/ui/exploration_hud.gd, scripts/street/street_corridor.gd, scripts/ui/inventory_panel.gd e data/events.json.
// Uso (da raiz do repositório, com python3 -m http.server 8765 servindo a raiz):
//   node docs/design/hud-exploracao/render.mjs http://127.0.0.1:8765
import {
  setBase, KIT, nine, over, img, glyph, key, bar, portrait, divider, cost, chip, secondary, primary, section, run,
} from "../hud-kit/lib.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-exploracao/.render";
const BG = (name) => img(`docs/design/hud-v2/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const TEAM = [["bento", "Bento", 34, 34], ["nick", "Nick", 24, 24], ["iris", "Íris", 23, 23], ["vespera", "Véspera", 30, 30]];
const WALK = [["A|D", "Andar"], ["Shift", "Correr"], ["E", "Interagir"]];
const MODAL = [["Setas", "Navegar"], ["E", "Escolher"], ["Esc", "Fechar"]];
const ICON = { start: "node-start.svg", combat: "node-combat.svg", loot: "node-loot.svg", rest: "node-rest.svg", passage: "node-event.svg", boss: "node-boss.svg", inside: "room_depot" };
// O corredor de exemplo (exploration_hud.gd): [tipo, estado]. "done" resolvido, "now" o de agora, "known" conhecido,
// "unknown" ainda não alcançado; o guardião é sempre conhecido.
// Um corredor só para a jornada inteira: os tipos dos dez trechos e, para cada tela, até onde a equipe chegou.
const JOURNEY = ["start", "loot", "combat", "rest", "loot", "combat", "passage", "loot", "rest", "boss"];
const at = (now, known = [], inside = false) => JOURNEY.map((type, i) => i < now ? [type, "done"] : i === now ? [inside ? "inside" : type, "now"]
  : type === "boss" || known.includes(i) ? [type, "known"] : ["", "unknown"]);
const START = at(0), INSIDE = at(1, [], true), MIDWAY = at(2, [3]);

// ------------------------------------------------------------------ a moldura da exploração
function frame({ place = "Rua das Vitrines", sub = "Jornada 1 · Fim de tarde", title = "Trecho 1 de 10 · Partida", route = START, food = "4/8",
  found = ["0", "0", "0"], hope = "80", keys = WALK, touch = false, goal = null, team = TEAM } = {}) {
  const g = goal || { kicker: "Objetivo da rota", title: "Vencer o guardião (trecho 10)", text: "Rota básica: o achado das buscas volta com a equipe.", done: false };
  const plaque = `<div class="abs col" style="left:28px;top:14px;gap:10px">` +
    nine("room_plaque", { cls: "row", extra: "min-width:440px;min-height:96px;gap:16px" },
      `${glyph("route", 48)}<div class="col"><span class="tx f40 semi up">${place}</span><span class="tx f24 muted">${sub}</span></div>`) +
    nine("panel_large", { repeat: "round", cls: "col", extra: "width:440px;gap:4px" },
      `<div class="row" style="gap:10px">${glyph(g.done ? "state_active" : "objective_done", 26, g.done ? "var(--good)" : "var(--amber)")}<span class="tx f20 semi up kicker ${g.done ? "good" : "amber"}">${g.kicker}</span></div>` +
      `<span class="tx f28 semi">${g.title}</span><span class="wrap f20 muted">${g.text}</span>`) + `</div>`;
  // O corredor: o elo verde liga os trechos resolvidos; o resolvido tem o check no canto (forma, além da cor).
  const cells = route.map(([type, state], i) => {
    const link = i === 0 ? "" : `<i style="width:10px;height:4px;flex:none;background:${route[i - 1][1] === "done" ? "var(--good)" : "#3a3e44"}"></i>`;
    const color = type === "boss" ? "var(--danger)" : state === "now" ? "var(--amber)" : state === "done" ? "var(--good)" : "var(--text)";
    const inner = state === "unknown" ? `<span class="tx f24 semi muted">?</span>` : glyph(ICON[type], 26, color);
    return link + `<div style="position:relative;width:48px;height:48px;flex:none">${nine("square_portrait", { extra: "position:absolute;inset:0" })}` +
      `<div class="row" style="position:absolute;inset:0;justify-content:center">${inner}</div>` +
      (state === "done" ? `<div style="position:absolute;right:-3px;bottom:2px;width:18px;height:18px;border-radius:2px;background:#101214">${glyph("state_active", 18, "var(--good)")}</div>` : "") +
      (state === "now" ? over("selected_frame") : "") + `</div>`;
  }).join("");
  const strip = `<div class="abs" style="left:50%;transform:translateX(-50%);top:14px">` + nine("round_strip", { repeat: "round", cls: "col", extra: "gap:6px;align-items:center" },
    `<span class="tx f22 semi up">${title}</span><div class="row" style="gap:0">${cells}</div>`) + `</div>`;
  const supplies = `<div class="abs col" style="right:28px;top:14px;gap:8px;align-items:flex-end">` +
    nine("resource_chip", { cls: "row", extra: "gap:18px;min-height:72px" },
      [["lobby-food.svg", "Comida", food], ["res-bandages.svg", "Curativos", "2"], ["res-hope.svg", "Esperança", hope]]
        .map(([i, l, v]) => `<div class="row" style="gap:8px">${glyph(i, 30)}<div class="col"><span class="tx f20 up muted">${l}</span><span class="tx f26 semi amber">${v}</span></div></div>`).join("")) +
    nine("cost_chip", { cls: "row", extra: "gap:14px;min-height:44px" },
      `<span class="tx f20 up muted">Achado</span>` + [["lobby-seed.svg", found[0]], ["lobby-scrap.svg", found[1]], ["lobby-fragment.svg", found[2]]]
        .map(([i, v]) => `<div class="row" style="gap:6px">${glyph(i, 24)}<span class="tx f22 semi">${v}</span></div>`).join("")) + `</div>`;
  const plates = `<div class="abs row" style="left:28px;bottom:14px;gap:8px">` + team.map(([hero, name, hp, max]) =>
    `<div data-hit="hero">` + nine("panel", { cls: "row", extra: "min-width:226px;min-height:80px;gap:10px" },
      `${portrait(hero, 56)}<div class="col" style="gap:3px;flex:1;min-width:0"><div class="row" style="justify-content:space-between;gap:10px"><span class="tx f22 semi">${name}</span><span class="tx f20">${hp}/${max}</span></div>${bar("100%", 18, hp / max, "var(--ally)")}</div>`) + `</div>`).join("") + `</div>`;
  // A barra das teclas: andar, correr e interagir na rua; com um painel aberto, as teclas do painel. No toque, nenhuma.
  const keyBar = touch ? "" : `<div class="abs" data-hit="keys" style="right:28px;bottom:calc(14px + 64px*var(--k) + 10px)">` + nine("keys_bar", { cls: "row", extra: "gap:18px;height:calc(56px*var(--k));justify-content:center" },
    keys.map(([k, t]) => `<div class="row" style="gap:6px">${k.split("|").map((x) => key(x)).join("")}<span class="tx f22">${t}</span></div>`).join("")) + `</div>`;
  const buttons = `<div class="abs row" style="right:28px;bottom:14px;gap:10px">${secondary("Mochila", { icon: "expeditions", keyLabel: touch ? "" : "I", hit: "bag", height: 64 })}${secondary("Menu", { icon: "lobby-settings.svg", keyLabel: touch ? "" : "Esc", hit: "menu", height: 64 })}</div>`;
  return plaque + strip + supplies + plates + keyBar + buttons;
}

// O aviso de interação sobre o objeto: a etiqueta com a ponta para baixo e a tecla (aceita toque).
const prompt = (x, y, k, text, done = false) => `<div class="abs" data-hit="prompt" style="left:${x}px;top:calc(${y}px - 60px*var(--k));transform:translateX(-50%)">` +
  nine("room_tag", { cls: "row", extra: `height:calc(60px*var(--k));gap:10px;justify-content:center;${done ? "opacity:.85" : ""}` },
    `${k ? key(k) : glyph(done ? "state_active" : "next_step", 22, done ? "var(--muted)" : "var(--amber)")}<span class="tx f24 ${done ? "muted" : "semi"}">${text}</span>`) + `</div>`;
// Um painel no meio da tela (evento, Mochila, acampamento, pausa, escolha de risco): começa depois do cartão do objetivo.
const modal = (width, top, body, left = null) => `<div class="abs" style="left:${left !== null ? left + "px" : `calc(28px + 440px + 24px + (1920px - 28px - 440px - 24px - 28px - ${width}px)/2)`};top:${top}px" data-hit="panel">` +
  nine("panel_large", { repeat: "round", cls: "col", extra: `width:${width}px;gap:12px` }, body) + `</div>`;
const heading = (icon, color, text, sub = "") => `<div class="row" style="gap:14px;flex-wrap:wrap">${glyph(icon, 40, color)}<span class="tx f40 semi up">${text}</span>${sub ? `<span class="tx f22 muted">${sub}</span>` : ""}</div>`;

// ------------------------------------------------------------------ as telas
function explore() { return BG("explore") + frame(); }
function interior() { return BG("explore-interior") + frame({ sub: "Jornada 1 · Noite · chuva", title: "Dentro da mercearia", route: INSIDE }) + prompt(1130, 528, "E / A", "Vasculhar o caixa"); }
function search() {
  const result = `<div class="abs" style="left:50%;transform:translateX(-50%);top:250px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:760px;gap:10px;align-items:center" },
    `<span class="wrap f26" style="text-align:center">Comida e um punhado de sementes enrolados num pano.</span><div class="row" style="gap:10px">${cost("lobby-food.svg", "+1 Comida")}${cost("lobby-seed.svg", "+1 Semente")}</div>`) + `</div>`;
  return BG("explore-search") + frame({ sub: "Jornada 1 · Noite · chuva", title: "Dentro da mercearia", route: INSIDE, food: "5/8", found: ["1", "0", "0"] }) + result + prompt(1130, 528, "", "O Caixa (já vasculhado)", true);
}
function loot() {
  return BG("explore-loot") + frame({ sub: "Jornada 1 · Noite · chuva" }) +
    `<div class="abs" style="left:976px;top:742px;transform:translateX(-50%)">` + nine("cost_chip", { cls: "row", extra: "gap:8px;min-height:44px;box-shadow:0 0 18px rgba(240,160,32,.35)" }, `${glyph("lobby-scrap.svg", 26, "var(--amber)")}<span class="tx f26 semi amber">+1 Sucata</span>`) + `</div>`;
}
// A patrulha à frente (fora da tela): o aviso com a seta, a barra da suspeita e o estado, no lado de onde ela vem.
function patrol() {
  const warn = `<div class="abs" style="right:28px;top:300px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "min-width:340px;gap:8px" },
    `<div class="row" style="gap:10px">${glyph("node-combat.svg", 28, "var(--danger)")}<span class="tx f26 semi up" style="flex:1">Patrulha à frente</span>${glyph("ui-arrow-right.svg", 24, "var(--danger)")}</div>` +
    bar("100%", 20, 0.55, "var(--amber)") + `<div class="row" style="gap:8px">${glyph("alert", 22, "var(--amber)")}<span class="tx f22 amber">desconfiada</span></div>`) + `</div>`;
  return BG("explore-patrol") + frame({ title: "Trecho 3 de 10 · Patrulha", route: MIDWAY, found: ["2", "1", "0"] }) + warn;
}
function eventCard({ art, title, where, text, choices, focus = -1, after = "" }) {
  const row = ([label, kind, need], i) => `<div data-hit="choice" style="position:relative">` + nine("list_row", { cls: "row", extra: "gap:12px;min-height:60px" },
    `${glyph(kind === "locked" ? need[0] : kind === "risk" ? "alert" : "ui-arrow-right.svg", 26, kind === "risk" ? "var(--danger)" : kind === "locked" ? "#8a8478" : "var(--amber)")}` +
    `<span class="wrap f24 ${kind === "locked" ? "muted" : ""}" style="flex:1">${label}</span>` +
    (kind === "locked" ? nine("cost_chip", { cls: "row", extra: "gap:6px;flex:none;min-height:40px" }, `${glyph(need[0], 22, "var(--muted)")}<span class="tx f20 muted">Requer ${need[1]}</span>`) : "") +
    (kind === "risk" ? nine("cost_chip", { cls: "row", extra: "flex:none;min-height:40px" }, `<span class="tx f20 danger up">Arriscado</span>`) : "")) +
    (i === focus ? over("focus_frame") : "") + `</div>`;
  return modal(820, 120,
    `<div style="position:relative;height:230px">${img(art, "position:absolute;left:4px;top:4px;width:calc(100% - 8px);height:222px;object-fit:cover")}${nine("square_portrait", { extra: "position:absolute;inset:0" })}</div>` +
    `<span class="tx f20 up amber kicker">${where}</span><span class="tx f40 semi">${title}</span><span class="wrap f24">${text}</span>` +
    (choices ? `<div class="col" style="gap:8px">${choices.map(row).join("")}</div>` : "") + after);
}
const STREET_EVENT = { art: "art/ui/events/street.webp", title: "Choro Atrás da Porta", where: "Ao vasculhar: armário" };
function eventStreet() {
  // O foco do teclado começa na primeira escolha que dá para fazer (a do pé de cabra está fechada sem ele).
  return BG("explore-event") + frame({ keys: MODAL }) + eventCard({ ...STREET_EVENT, focus: 1,
    text: "Do outro lado de uma porta de aço emperrada, um choro fino. Um filhote de lontra entrou atrás de comida e a porta fechou com ele lá dentro. A fechadura está tomada de ferrugem.",
    choices: [["Forçar a porta com o pé de cabra", "locked", ["tool-crowbar.svg", "Pé de cabra"]], ["Arrombar no ombro", "risk"], ["Passar o que der pela fresta e seguir", ""]] });
}
// O resultado do evento: o texto da resolução (events.json, Failure de "Arrombar no ombro"), o que mudou em chips e CONTINUAR.
function eventResult() {
  return BG("explore-event") + frame({ hope: "75", keys: [["E", "Continuar"]], team: [["bento", "Bento", 30, 34], ...TEAM.slice(1)] }) + eventCard({ ...STREET_EVENT,
    text: "A porta não se mexe e Bento sai com o ombro roxo. O choro continua do outro lado enquanto a equipe procura outra saída para ele.",
    after: `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("state_wounded", "−4 de vida · Bento", true)}${cost("res-hope.svg", "−5 de Esperança", true)}</div>` +
      primary("Continuar", { keyLabel: "E / A", hit: "continue", height: 64, size: "f26" }) });
}
function eventScenario() {
  return BG("scenario-event") + frame({ place: "Abrigo Lacrado", sub: "Jornada 3 · Sala Esquecida · Fim de tarde", keys: MODAL }) + eventCard({ art: "art/ui/events/sealed_shelter.webp", title: "Sala dos Esporos", where: "Ao vasculhar: maca", focus: 1,
    text: "O kit está vazio, mas aponta para a porta de vidro ao lado: uma enfermaria tomada por um fungo cinzento. Lá no fundo, um armário de remédios intacto. O ar lá dentro brilha de esporos.",
    choices: [["Entrar com a máscara com filtro", "locked", ["tool-mask.svg", "Máscara com filtro"]], ["Prender o fôlego e correr", "risk"], ["Deixar a sala fechada", ""]] });
}
function inventory() {
  // O rótulo quebra dentro da largura do quadrado; as ferramentas que não se usam aqui ficam no tom apagado, sem transparência.
  const tile = (icon, label, n, sel = false, dim = false) => `<div data-hit="item" class="col" style="align-items:center;gap:4px;width:116px;position:relative">` +
    `<div style="position:relative">${nine("resource_tile", { extra: "width:116px;height:84px;display:flex;align-items:center;justify-content:center" }, glyph(icon, 42, dim ? "#8a8478" : "var(--text)"))}${sel ? over("selected_frame") : ""}</div>` +
    `<span class="wrap f20 ${dim ? "muted" : ""}" style="line-height:1.1;text-align:center;width:116px">${label}</span>${n ? `<span class="tx f22 semi amber" style="line-height:1">${n}</span>` : ""}</div>`;
  const grid = section("Suprimentos") + `<div class="row" style="gap:10px;align-items:flex-start">${tile("lobby-food.svg", "Comida", "4 / 8", true)}${tile("res-bandages.svg", "Curativo", "2")}${tile("item-ampoule.svg", "Ampola de Reparo", "3 cargas")}</div>` +
    section("Ferramentas") + `<div class="row" style="gap:10px;align-items:flex-start">${tile("tool-crowbar.svg", "Pé de cabra", "", false, true)}${tile("tool-flashlight.svg", "Lanterna", "", false, true)}${tile("tool-mask.svg", "Máscara com filtro", "", false, true)}</div>` +
    section("Recursos e relíquias") + `<div class="row" style="gap:10px;align-items:flex-start">${tile("lobby-seed.svg", "Sementes", "30")}${tile("lobby-scrap.svg", "Sucata", "0")}${tile("lobby-fragment.svg", "Fragmentos", "0")}</div>`;
  const arrowBtn = (flip) => `<div data-hit="ally">${nine("icon_button", { pad: [4, 4, 4, 4], extra: "width:calc(56px*var(--k));height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, glyph("ui-arrow-right.svg", 26, "var(--text)", flip ? "transform:scaleX(-1)" : ""))}</div>`;
  const off = (label, hit) => `<div data-hit="${hit}">${nine("list_row", { cls: "row", extra: "gap:10px;min-height:56px" }, `${glyph("lobby-food.svg", 24, "#8a8478")}<span class="tx f24 muted">${label}</span>`)}</div>`;
  const detail = `<div class="col" style="gap:10px;flex:1;min-width:0">` + `<div class="row" style="gap:12px">${glyph("lobby-food.svg", 40, "var(--amber)")}<span class="tx f40 semi">Comida</span>${nine("cost_chip", { cls: "row", extra: "min-height:40px" }, `<span class="tx f22 amber">4 / 8</span>`)}</div>` +
    `<span class="wrap f22 muted">Da expedição: cura fora e dentro da luta. O que sobrar não volta ao refúgio.</span>` +
    nine("panel_inset", { cls: "row", extra: "gap:12px;justify-content:space-between" }, `${arrowBtn(true)}<div class="row" style="gap:10px">${portrait("bento", 52)}<div class="col"><span class="tx f26 semi">Bento</span><span class="tx f20 muted">Vida 34/34</span></div></div>${arrowBtn(false)}`) +
    off("Comer pouco · 1 comida", "eat-1") + off("Comer bem · 3 comidas", "eat-3") +
    `<div class="row" style="gap:8px">${glyph("state_active", 22, "var(--muted)")}<span class="wrap f20 muted">O aliado já está com a vida cheia.</span></div></div>`;
  return BG("explore-inventory") + frame({ keys: MODAL }) + modal(1060, 112,
    `<div class="row" style="justify-content:space-between;gap:12px"><div class="row" style="gap:14px;flex-wrap:wrap;flex:1;min-width:0">${glyph("expeditions", 40, "var(--amber)")}<span class="tx f40 semi up">Mochila</span><span class="wrap f22 muted">Cuidados fora da luta: escolha o item e o aliado.</span></div>` +
    secondary("Fechar", { keyLabel: "Esc / B", hit: "close", height: 56 }) + `</div>${divider()}<div class="row" style="gap:24px;align-items:flex-start"><div class="col" style="gap:8px;flex:none">${grid}</div>${detail}</div>`, 500);
}
function camp() {
  const row = ([hero, name, hp, max]) => nine("panel_inset", { cls: "row", extra: "gap:14px;flex:none" },
    `${portrait(hero, 48)}<div class="col" style="gap:4px;flex:1;min-width:0"><div class="row" style="gap:12px;flex-wrap:wrap"><span class="tx f26 semi">${name}</span><span class="tx f20 muted">Vida ${hp}/${max} · Instinto 0</span></div>${bar("100%", 18, hp / max, "var(--ally)")}</div>` +
    `<div class="row" style="gap:8px">${["Comer|lobby-food.svg|eat", "Curativo|res-bandages.svg|bandage"].map((x) => { const [t, i, h] = x.split("|");
      return `<div data-hit="${h}">${nine("chip_button", { cls: "row", extra: "gap:8px;min-height:calc(56px*var(--k));justify-content:center" }, `${glyph(i, 24, "#8a8478")}<span class="tx f24 muted">${t}</span>`)}</div>`; }).join("")}</div>`);
  return BG("explore-camp") + frame({ sub: "Jornada 1 · Noite · chuva", keys: MODAL }) + modal(880, 130,
    heading("node-rest.svg", "var(--amber)", "Acampamento", "A porta fechada e a fogueira acesa.") +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-food.svg", "Comer: +10% de vida, −5 de instinto · 4 comidas")}${cost("res-bandages.svg", "Curativo: +8 de vida · 2 curativos")}</div>` +
    TEAM.map(row).join("") + `<div class="row" style="gap:8px">${glyph("state_active", 22, "var(--muted)")}<span class="wrap f20 muted">Todos estão com a vida cheia.</span></div>` +
    primary("Levantar acampamento", { icon: "route", keyLabel: "E / A", hit: "leave", height: 64, size: "f26" }), 500);
}
function risk() {
  return BG("explore-risk") + frame({ sub: "Jornada 1 · Noite · chuva", keys: MODAL }) + modal(760, 280,
    heading("alert", "var(--danger)", "Abandonar a expedição?") +
    `<span class="wrap f24">A equipe volta pelo trem sem enfrentar o guardião: só metade do achado chega à Estação.</span>` +
    `<div class="row" style="gap:12px;flex-wrap:wrap">${primary("Continuar a expedição", { keyLabel: "Esc / B", hit: "stay", height: 64, size: "f26", extra: "flex:1 1 300px" })}${secondary("Voltar à Estação", { icon: "train_arrival", hit: "leave", height: 64, extra: "flex:1 1 260px" })}</div>`);
}
// Diante do guardião (street_corridor.gd, _ask_risk): a equipe como está, os suprimentos e o achado, e as duas saídas.
function bossChoice() {
  const mate = ([hero, name, hp, max]) => nine("panel_inset", { cls: "col", extra: "gap:6px;width:170px;flex:none;align-items:center" },
    `${portrait(hero, 64)}<span class="tx f22 semi">${name}</span><span class="tx f20">${hp}/${max}</span>${bar("100%", 16, hp / max, "var(--ally)")}`);
  return BG("explore-risk") + frame({ title: "Trecho 9 de 10 · Descanso", route: at(8), food: "3/8", found: ["6", "3", "1"], keys: MODAL }) +
    modal(800, 120,
      heading("node-boss.svg", "var(--danger)", "O guardião está à frente") +
      `<span class="wrap f24">Vencer o guardião conclui a fase e leva todo o achado. Se a equipe cair, o achado fica para trás; voltar agora leva metade.</span>` +
      `<div class="row" style="gap:10px;flex-wrap:wrap">${TEAM.map(mate).join("")}</div>` +
      `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-food.svg", "Comida 3/8")}${cost("res-bandages.svg", "Curativos 2")}${cost("lobby-seed.svg", "6 sementes")}${cost("lobby-scrap.svg", "3 sucata")}${cost("lobby-fragment.svg", "1 fragmento")}</div>` +
      `<div class="row" style="gap:12px;flex-wrap:wrap">${primary("Seguir em frente", { keyLabel: "E / A", hit: "go", height: 64, size: "f26", extra: "flex:1 1 300px" })}${secondary("Voltar à Estação (metade do achado)", { icon: "train_arrival", hit: "back", height: 64, extra: "flex:1 1 360px" })}</div>`);
}
// A Pausa do Esc (show_menu): antes do guardião a volta é uma retirada; no meio de uma luta ou evento ela fica fechada com o motivo.
function pause() {
  return BG("explore-options") + frame({ keys: MODAL }) + modal(660, 230,
    heading("lobby-settings.svg", "var(--amber)", "Pausa") +
    primary("Continuar", { keyLabel: "Esc / B", hit: "resume", height: 64, size: "f26" }) +
    `<div data-hit="return">${nine("secondary_button", { cls: "row", extra: "min-height:calc(64px*var(--k));gap:10px;justify-content:center" }, `${glyph("train_arrival", 26)}<span class="wrap f26 semi up" style="text-align:center">Voltar à Estação (retirada: metade do achado)</span>`)}</div>` +
    secondary("Opções", { icon: "lobby-settings.svg", hit: "options", height: 60, extra: "width:100%" }) +
    `<div data-hit="new-campaign">${nine("secondary_button", { cls: "row", extra: "min-height:calc(60px*var(--k));gap:10px;justify-content:center" }, `${glyph("alert", 24, "var(--danger)")}<span class="tx f26 semi up danger">Nova campanha</span>`)}</div>`);
}
// O guardião vencido: o objetivo cumprido no cartão (com o check, não só a cor) e o botão de concluir a jornada.
function bossDone() {
  return BG("explore") + frame({ title: "Trecho 10 de 10 · Guardião", route: at(9), found: ["8", "4", "1"],
    goal: { kicker: "Objetivo cumprido", title: "Guardião vencido", text: "Fase concluída: volte à Estação com todo o achado (botão ou Esc).", done: true } }) +
    `<div class="abs" style="right:28px;bottom:calc(14px + 64px*var(--k) + 10px + 56px*var(--k) + 10px);min-width:480px">` + primary("Concluir jornada · Voltar à Estação", { icon: "train_arrival", hit: "finish", height: 64, size: "f24" }) + `</div>`;
}
function touch(active) {
  // Toque: o analógico que aparece onde o dedo encosta (até a borda corre) e o Usar, apagado sem nada por perto e com o
  // âmbar por cima quando há o que usar.
  const stick = `<div class="abs" style="left:70px;top:640px;width:240px;height:240px">${img(KIT.touch_ring.file, "position:absolute;inset:0;width:100%;height:100%")}` +
    `${img(KIT.touch_knob.file, "position:absolute;left:78px;top:78px;width:84px;height:84px")}<div class="row" style="position:absolute;left:0;right:0;bottom:-50px;justify-content:center">${nine("cost_chip", { cls: "row", extra: "min-height:40px" }, `<span class="tx f22">Andar</span>`)}</div></div>`;
  const use = `<div class="abs" data-hit="use" style="right:70px;top:640px;width:170px;height:170px">${img(KIT.touch_button.file, "position:absolute;inset:0;width:100%;height:100%")}` +
    (active ? img(KIT.touch_button_active.file, "position:absolute;inset:0;width:100%;height:100%") : "") +
    `<div class="col" style="position:absolute;inset:0;justify-content:center;align-items:center;gap:4px">${glyph("next_step", 40, active ? "var(--amber)" : "#8a8478")}<span class="tx f28 semi up ${active ? "" : "muted"}">Usar</span></div></div>`;
  return BG(active ? "explore-interior" : "explore-touch") + frame(active ? { touch: true, sub: "Jornada 1 · Noite · chuva", title: "Dentro da mercearia", route: INSIDE } : { touch: true }) + stick + use +
    (active ? prompt(1130, 528, "", "Vasculhar o caixa") : "");
}

await run({
  explore: () => explore(), patrol: () => patrol(), interior: () => interior(), search: () => search(), loot: () => loot(),
  event: () => eventStreet(), event_result: () => eventResult(), scenario_event: () => eventScenario(), inventory: () => inventory(),
  camp: () => camp(), risk: () => risk(), boss_choice: () => bossChoice(), pause: () => pause(), boss_done: () => bossDone(),
  touch: () => touch(false), touch_active: () => touch(true),
}, OUT);
