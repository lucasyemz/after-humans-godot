// Lote 6: o resto das telas do laço (#96), no kit da Awesomic (art/ui/kit/station):
// - a carga recuperada do guardião (#91, já no jogo): os seis compartimentos lacrados, a escolha e a revelação;
// - o painel do lugar no Mapa da Rede (#92): a travessia, as três missões curtas, o chefe e as estrelas;
// - a árvore da Pesquisa (#94) e o aviso "Pesquisa concluída" no Próximo passo;
// - os laços à vista (#93): na Preparação e o destaque curto na luta;
// - os desafios dos chefes (#95), com os modificadores e as estrelas.
// Fundos: a captura nova da carga (before/, capture.gd), as da Estação (hud-v2/before), as dos laços (loop-screens/before,
// com os laços disparados pelo motor) e o Mapa da Rede do hud-fluxo. Cada tela é montada pelas funções das telas já
// aprovadas (a moldura da exploração, a Visão geral, a Preparação, o Mapa e a luta), sem refazer as outras.
// Uso (da raiz do repositório, com python3 -m http.server 8765 servindo a raiz):
//   node docs/design/hud-laco/render.mjs http://127.0.0.1:8765
import fs from "node:fs";
import {
  setBase, BASE, KIT, nine, over, img, glyph, bar, portrait, divider, cost, secondary, primary, topBar, bottom, section, run,
} from "../hud-kit/lib.mjs";
import { frame, modal, at } from "../hud-exploracao/render.mjs";
import { overview, preparation, BG as STATION_BG } from "../hud-estacao/render.mjs";
import { networkMap, civilFace } from "../hud-fluxo/render.mjs";
import { useCapture, combat } from "../hud-luta/render.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-laco/.render";
const DIR = "docs/design/hud-laco/before";
const BG = (name) => img(`${DIR}/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const data = (name) => JSON.parse(fs.readFileSync(`${DIR}/${name}.json`, "utf8"));
const stars = (n, size = 24, of = 3) => `<div class="row" style="gap:2px;flex:none">${Array.from({ length: of }, (_, i) => glyph(i < n ? "star" : "star_empty", size, i < n ? "var(--amber)" : "var(--muted)")).join("")}</div>`;
const lock = (size = 22) => `<i class="glyph" style="width:${size}px;height:${size}px;background:#b3a993;-webkit-mask-image:url(${BASE}/art/ui/map/network/lock_32.webp)"></i>`;
const face = (file, size, ring = "#8a8478") => `<div style="position:relative;width:${size}px;height:${size}px;flex:none"><i style="position:absolute;inset:0;border-radius:50%;background:${ring}"></i>` +
  img(file, `position:absolute;left:3px;top:3px;width:${size - 6}px;height:${size - 6}px;border-radius:50%`) + `</div>`;
const line = (icon, color, text, cls = "f22") => `<div class="row" style="gap:8px;align-items:flex-start">${glyph(icon, 22, color, "margin-top:2px")}<span class="wrap ${cls}" style="flex:1;min-width:0">${text}</span></div>`;

// ------------------------------------------------------------------ 1. a carga recuperada (#91)
// Os seis compartimentos (cargo_hatch, 200x168, aqui a 168x141) numa grade 3x2, no painel à direita, longe da equipe. Fechados: "Compartimento N" embaixo e o foco do teclado;
// depois da escolha, todos abrem: o escolhido com selected_frame, o ícone e o texto em âmbar e "(sua)"; os outros
// apagados, no tom cheio, para ler pelas frestas.
const CARGO = data("cargo");
// O sorteio com relíquia (o texto mais longo), de outra semente da mesma fase: a rua e a equipe são as da foto.
const CARGO_RELIC = data("cargo_relic");
const RES_ICON = { "lobby-seed": "lobby-seed.svg", "lobby-scrap": "lobby-scrap.svg", "lobby-fragment": "lobby-fragment.svg", "lobby-food": "lobby-food.svg", "res-bandages": "res-bandages.svg" };
function hatch(box, i, { open = false, focus = -1, set = CARGO } = {}) {
  const mine = open && i === set.chosen;
  const inner = open ? `<div class="row" style="position:absolute;left:18px;top:40px;width:132px;height:84px;justify-content:center">${glyph(RES_ICON[box.icon] || `${box.icon}.svg`, 48, mine ? "var(--amber)" : "#8a8478")}</div>` : "";
  return `<div class="col" data-hit="hatch" style="gap:4px;align-items:center;width:168px">` +
    `<div style="position:relative;width:168px;height:141px">${img(KIT[open ? "cargo_hatch_open" : "cargo_hatch"].file, "position:absolute;inset:0;width:168px;height:141px")}${inner}` +
    (mine ? over("selected_frame") : i === focus ? over("focus_frame") : "") + `</div>` +
    // O rótulo quebra dentro dos 168 px da coluna; "(sua)" vai na linha de baixo.
    `<span class="wrap f20 ${open ? (mine ? "semi amber" : "muted") : ""}" style="width:168px;text-align:center;line-height:1.12">${open ? box.text + (mine ? "<br>(sua)" : "") : `Compartimento ${i + 1}`}</span>` + `</div>`;
}
function cargo({ open = false, set = CARGO, found = ["16", "3", "1"] } = {}) {
  const grid = `<div class="col" style="gap:10px;align-items:center">${[0, 1].map((r) => `<div class="row" style="gap:16px;align-items:flex-start">${set.boxes.slice(r * 3, r * 3 + 3).map((b, j) => hatch(b, r * 3 + j, { open, focus: open ? -1 : 1, set })).join("")}</div>`).join("")}</div>`;
  // Depois da escolha, o texto da história sai: o painel fica só com o que se abriu.
  const body = `<div class="row" style="gap:14px">${glyph("guardian_defeated", 40, "var(--amber)")}<span class="tx f40 semi up">Carga recuperada</span></div>` +
    (open ? "" : `<span class="wrap f22">O guardião guardava compartimentos lacrados. Só dá tempo de abrir um antes de a carcaça ceder; o resto, a equipe vê pelas frestas.</span>`) +
    divider() + grid + (open
      ? primary("Continuar", { keyLabel: "E / A", hit: "continue", height: 64, size: "f26" })
      : line("next_step", "var(--amber)", "Escolha um. Os outros cinco se revelam depois, sem segunda escolha.", "f20 muted"));
  const bodies = CARGO.bodies.map((b) => `<div class="abs" data-hit="hero-body" style="left:${Math.round(b[0])}px;top:${Math.round(b[1])}px;width:${Math.round(b[2])}px;height:${Math.round(b[3])}px"></div>`).join("");
  return BG("cargo") + bodies + frame({ title: "Trecho 10 de 10 · Guardião", route: at(9), found,
    keys: open ? [["E", "Continuar"]] : [["Setas", "Navegar"], ["E", "Abrir"]],
    // O cartão do objetivo como no jogo: com a carga pendente, o pedido de abrir um compartimento.
    goal: { kicker: "Objetivo cumprido", title: "Guardião vencido", done: true,
      text: open ? "Fase concluída: volte à Estação com todo o achado (botão ou Esc)." : "Abra um compartimento da carga do guardião antes de voltar." } }) +
    modal(640, 170, body, 1920 - 28 - 640);
}

// ------------------------------------------------------------------ 2. o painel do lugar no Mapa da Rede (#92)
// A travessia (a missão de história de hoje), as três missões curtas e o chefe, cada uma com as estrelas; a liberação pelas
// estrelas somadas do lugar (valores de exemplo, em data/ na integração). A escolhida abre o detalhe embaixo.
const MISSION_ICON = { crossing: "route", patrol: "node-combat.svg", rescue: "recruit", collect: "room_canteen", boss: "node-boss.svg" };
function missionRow(m, selected) {
  const off = m.state === "locked";
  const right = off ? `<div class="row" style="gap:6px;flex:none">${lock(20)}<span class="tx f20 muted">${m.need}</span></div>`
    : `<div class="col" style="align-items:flex-end;gap:2px;flex:none">${stars(m.stars, 22)}${m.state === "done"
      ? `<div class="row" style="gap:4px">${glyph("state_active", 18, "var(--good)")}<span class="tx f20 good">Concluída</span></div>`
      : `<div class="row" style="gap:4px">${glyph("node-start.svg", 18, "var(--ally)")}<span class="tx f20" style="color:var(--ally)">Disponível</span></div>`}</div>`;
  return `<div data-hit="mission" style="position:relative;flex:none">` + nine("list_row", { cls: "row", extra: "gap:12px;min-height:calc(64px*var(--k))" },
    (m.unknown ? `<div class="row" style="width:30px;height:30px;justify-content:center;flex:none;border:2px solid #6d6a62;border-radius:50%"><span class="tx f22 semi muted">?</span></div>`
      : glyph(MISSION_ICON[m.kind], 30, off ? "#8a8478" : m.kind === "boss" ? "var(--danger)" : "var(--amber)")) + `<div class="col" style="flex:1;min-width:0">` +
    `<span class="tx f24 semi ${off ? "muted" : ""}">${m.title}</span><span class="wrap f20 muted">${m.sub}</span></div>${right}`) +
    (selected ? over("list_row_selected") : "") + `</div>`;
}
function place({ name, total, of, missions, selected, detail, footer }) {
  const body = `<div class="row" style="gap:10px;justify-content:space-between"><span class="tx f20 up muted kicker">Missões do lugar</span>` +
    `<div class="row" style="gap:6px">${glyph("star", 24, "var(--amber)")}<span class="tx f24 semi amber">${total} / ${of}</span><span class="tx f20 muted">estrelas</span></div></div>` +
    missions.map((m, i) => missionRow(m, i === selected)).join("") + divider() + detail;
  return { icon: "route", title: name, body, footer };
}
const RUA = {
  name: "Rua das Vitrines", total: 5, of: 15, selected: 3,
  missions: [
    { kind: "crossing", title: "Travessia", sub: "A jornada de 10 trechos até o guardião", stars: 2, state: "done" },
    { kind: "patrol", title: "Patrulha", sub: "Limpar a esquina da mercearia · 3 a 5 min", stars: 3, state: "done" },
    { kind: "rescue", title: "Resgate", sub: "Levar alguém até a Estação · 3 a 5 min", stars: 0, state: "open" },
    { kind: "collect", title: "Coleta", sub: "O caderno de receitas da Dora · 3 a 5 min", stars: 0, state: "open" },
    { kind: "boss", title: "Chefe do lugar", sub: "O radar mostra quem é ao liberar", stars: 0, state: "locked", need: "6 estrelas · falta 1", unknown: true },
  ],
};
const ruaDetail = () => `<div class="row" style="gap:14px;align-items:flex-start">${civilFace("civil_dora", 64)}<div class="col" style="flex:1;min-width:0;gap:4px">` +
  `<span class="tx f20 up amber kicker">Pedido da Dora · Coleta</span><span class="wrap f22">Quer recuperar um caderno de receitas esquecido numa mercearia abandonada.</span></div></div>` +
  line("marker-available.svg", "var(--ally)", "No radar: uma zona da rua, 1 patrulha e 3 buscas.", "f20") +
  `<div class="row" style="gap:8px;flex-wrap:wrap">${cost("room_canteen", "Prêmio: a Cantina rende mais 1 suprimento por volta")}</div>`;
const BRIDGE = {
  name: "Ponte das Raízes", total: 0, of: 15, selected: 1,
  missions: [
    { kind: "crossing", title: "Travessia", sub: "A jornada de 10 trechos até o guardião", stars: 0, state: "open" },
    { kind: "patrol", title: "Patrulha", sub: "Abrir caminho até o cais · 3 a 5 min", stars: 0, state: "open" },
    { kind: "rescue", title: "Resgate", sub: "Levar alguém até a Estação · 3 a 5 min", stars: 0, state: "locked", need: "3 estrelas" },
    { kind: "collect", title: "Coleta", sub: "Achar uma peça para a Estação · 3 a 5 min", stars: 0, state: "locked", need: "3 estrelas" },
    { kind: "boss", title: "Chefe do lugar", sub: "O radar mostra quem é ao liberar", stars: 0, state: "locked", need: "6 estrelas", unknown: true },
  ],
};
const bridgeDetail = () => `<div class="row" style="gap:14px;align-items:flex-start">${face("art/ui/map/network/portrait_enraizado.webp", 64)}<div class="col" style="flex:1;min-width:0;gap:4px">` +
  `<span class="tx f20 up amber kicker">Mapa da Rede · Patrulha</span><span class="wrap f22">Da torre, Véspera contou as patrulhas da ponte: antes eram duas, agora são quatro. No radar, Enraizados.</span></div></div>` +
  `<div class="row" style="gap:8px;flex-wrap:wrap">${cost("lobby-scrap.svg", "Prêmio: 4 sucatas · na repetição, 2")}</div>` +
  line("star", "var(--amber)", "3 estrelas no lugar liberam o Resgate e a Coleta; 6, o Chefe do lugar.", "f20");

// ------------------------------------------------------------------ 3. a árvore da Pesquisa (#94)
// Três ramos (Classe, Estação, Radar), cada nó com o custo em fragmentos e sucata e a duração em expedições. Uma
// pesquisa por vez: a de agora mostra o andamento. Os estados: concluída (o check verde), em andamento (âmbar e a
// barra), disponível, bloqueada (o cadeado e o pré-requisito). Os ids de hoje (res_*) ficam; os outros são exemplos.
// Classe: os quatro treinos de hoje (data/research.json, ids preservados) e o próximo de cada classe, ligado só ao
// pré-requisito real (o treino anterior da mesma classe). Estação e Radar: cadeias curtas, cada nó pedindo o de cima.
const T1 = { frag: 3, scrap: 0, exp: 1 }, T2 = { frag: 4, scrap: 2, exp: 2 };
const effect = (skill) => `+1 nos limites de dano ou cura de ${skill}.`;
const CLASSES = [
  { hero: "bento", a: { id: "res_cao_punho_sucata", name: "Treino: Punho de Sucata", ...T1, state: "done" },
    b: { id: "res_cao_impacto_hidraulico", name: "Treino: Impacto Hidráulico", ...T2, state: "open", needs: "Treino: Punho de Sucata", selected: true, effect: effect("Impacto Hidráulico") } },
  { hero: "nick", a: { id: "res_gato_corte_fase", name: "Treino: Corte de Fase", ...T1, state: "open" },
    b: { id: "res_gato_salto_entre_ruinas", name: "Treino: Salto Entre Ruínas", ...T2, state: "locked", needs: "Corte de Fase" } },
  { hero: "iris", a: { id: "res_sapo_carga_voltaica", name: "Treino: Carga Voltaica", ...T1, state: "open" },
    b: { id: "res_sapo_coquetel_corrosivo", name: "Treino: Coquetel Corrosivo", ...T2, state: "locked", needs: "Carga Voltaica" } },
  { hero: "vespera", a: { id: "res_coruja_recurso_emergencia", name: "Treino: Recurso de Emergência", ...T1, state: "open" },
    b: { id: "res_coruja_disparo_perfurante", name: "Treino: Disparo Perfurante", ...T2, state: "locked", needs: "Recurso de Emergência" } },
];
const CHAINS = [
  { icon: "station", name: "Estação", nodes: [
    { id: "res_canteiro", name: "Canteiro irrigado", frag: 2, scrap: 3, exp: 1, state: "done" },
    { id: "res_filtro", name: "Filtro de água", frag: 2, scrap: 4, exp: 2, state: "open", needs: "Canteiro irrigado" },
    { id: "res_gerador", name: "Gerador remendado", frag: 3, scrap: 5, exp: 3, state: "locked", needs: "Filtro de água" },
  ] },
  { icon: "route", name: "Radar", nodes: [
    { id: "res_radar_parcial", name: "Leitura parcial", frag: 2, scrap: 0, exp: 1, state: "done" },
    { id: "res_radar_completo", name: "Leitura completa", frag: 3, scrap: 1, exp: 2, state: "running", done: 1, needs: "Leitura parcial" },
    { id: "res_radar_missoes", name: "Leitura das missões", frag: 4, scrap: 1, exp: 2, state: "locked", needs: "Leitura completa" },
  ] },
];
const STOCK = { frag: 3, scrap: 9 };
const expText = (n) => `${n} ${n === 1 ? "expedição" : "expedições"}`;
// Os estados: concluída (o check verde), em andamento (a faixa âmbar na esquerda, a barra e o texto âmbar, sem moldura),
// disponível (o custo), bloqueada (o cadeado e o pré-requisito) e a escolhida (selected_frame).
function node(n) {
  const badge = n.state === "done" ? glyph("state_active", 24, "var(--good)") : n.state === "locked" ? lock(22) : n.state === "running" ? glyph("next_step", 24, "var(--amber)") : "";
  const costs = [n.frag ? cost("lobby-fragment.svg", String(n.frag)) : "", n.scrap ? cost("lobby-scrap.svg", String(n.scrap)) : "", cost("expeditions", expText(n.exp))].join("");
  const foot = n.state === "running" ? `<div class="col" style="gap:4px">${bar("100%", 16, n.done / n.exp, "var(--amber)")}<span class="wrap f20 amber">Em andamento · ${n.done} de ${expText(n.exp)}</span></div>`
    : n.state === "done" ? `<span class="tx f20 good">Concluída</span>`
    : n.state === "locked" ? `<span class="wrap f20 muted">Requer ${n.needs}</span>`
    : `<div class="row" style="gap:6px;flex-wrap:wrap">${costs}</div>`;
  return `<div data-hit="node" style="position:relative;flex:1 1 0;min-width:0">` + nine("panel_inset", { cls: "col", extra: "gap:6px;width:100%" },
    (n.state === "running" ? `<i style="position:absolute;left:-10px;top:-6px;bottom:0;width:6px;background:var(--amber)"></i>` : "") +
    `<div class="row" style="gap:10px;align-items:flex-start"><span class="wrap f22 semi" style="flex:1;min-width:0;color:${n.state === "locked" ? "var(--muted)" : "var(--text)"}">${n.name}</span>${badge}</div>${foot}`) +
    (n.selected ? over("selected_frame") : "") + `</div>`;
}
const vlink = (on) => `<div style="width:6px;height:16px;margin-left:28px;flex:none;background:${on ? "var(--good)" : "#3a3e44"};box-shadow:0 0 0 1px #0a0b0c"></div>`;
const hlink = (on) => `<div style="width:16px;height:6px;flex:none;align-self:center;background:${on ? "var(--good)" : "#3a3e44"};box-shadow:0 0 0 1px #0a0b0c"></div>`;
const head = (icon, name, done, of) => `<div class="row" style="gap:10px;margin-bottom:10px">${glyph(icon, 30, "var(--amber)")}<span class="tx f28 semi up">${name}</span><span class="tx f20 muted" style="margin-left:auto">${done} de ${of}</span></div>`;
function research() {
  const classNodes = CLASSES.flatMap((c) => [c.a, c.b]);
  const classCol = `<div class="col" style="flex:2 1 0;min-width:0;gap:10px">` + head("nav_characters", "Classe", classNodes.filter((n) => n.state === "done").length, classNodes.length).replace("margin-bottom:10px", "margin-bottom:0") +
    CLASSES.map((c) => `<div class="row" style="gap:10px;align-items:stretch"><div style="align-self:center;flex:none">${portrait(c.hero, 44)}</div>${node(c.a)}${hlink(c.a.state === "done")}${node(c.b)}</div>`).join("") + `</div>`;
  const chainCols = CHAINS.map((b) => `<div class="col" style="flex:1 1 0;min-width:0;gap:0">` + head(b.icon, b.name, b.nodes.filter((n) => n.state === "done").length, b.nodes.length) +
    b.nodes.map((n, i) => (i ? vlink(b.nodes[i - 1].state === "done") : "") + `<div class="row">${node(n)}</div>`).join("") + `</div>`).join("");
  const sel = CLASSES.map((c) => c.b).find((n) => n.selected);
  const running = CHAINS.flatMap((b) => b.nodes).find((n) => n.state === "running");
  const detail = nine("panel_large", { repeat: "round", cls: "col", extra: "width:520px;gap:12px" },
    `<span class="tx f20 up amber kicker">Ramo Classe · Cão</span><span class="wrap f36 semi">${sel.name}</span><span class="wrap f22">${sel.effect}</span>` + divider() +
    line("state_active", "var(--good)", `Requer ${sel.needs.replace("Treino: ", "")} (concluída).`) +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-fragment.svg", `${sel.frag} fragmentos · tem ${STOCK.frag}`, STOCK.frag < sel.frag)}${cost("lobby-scrap.svg", `${sel.scrap} sucatas · tem ${STOCK.scrap}`)}${cost("expeditions", expText(sel.exp))}</div>` +
    line("alert", "var(--danger)", `Falta 1 fragmento. E uma pesquisa por vez: ${running.name} termina na próxima volta.`, "f22 danger") +
    primary("Iniciar pesquisa", { icon: "room_research", hit: "start", height: 64, locked: true, reason: "Uma pesquisa por vez" }));
  const tree = nine("panel_large", { repeat: "round", cls: "col", extra: "width:1318px;gap:12px;max-height:100%" },
    `<div class="row" style="gap:14px;justify-content:space-between"><div class="row" style="gap:14px">${glyph("room_research", 40, "var(--amber)")}<span class="tx f40 semi up">Pesquisa</span></div>` +
    `<span class="tx f22 muted">Medida em expedições · uma por vez · custo em fragmentos e sucata</span></div>${divider()}` +
    // A calha da barra de rolagem fica reservada à direita (padding-right), para ela não passar por cima do Radar.
    `<div class="row" data-scroll="1" style="gap:22px;align-items:flex-start;overflow:hidden;min-height:0;flex:1 1 auto;padding-right:18px">${classCol}${chainCols}</div>`);
  return STATION_BG("station-research") + topBar({ subtitle: "Centro de Pesquisa", stock: ["30", "9", "3", "2"] }) +
    `<div class="abs" style="left:28px;top:132px;bottom:calc(14px + 72px*var(--k) + 10px + 64px + 12px);display:flex">${tree}</div>` +
    `<div class="abs" style="right:28px;top:132px">${detail}</div>` + bottom({ active: 3, keys: [["Setas", "Navegar"], ["E", "Escolher"], ["Esc", "Voltar"]] });
}
// O aviso na volta: o Próximo passo da Visão geral vira "Pesquisa concluída", e um aviso curto no alto, ao chegar.
function researchDone() {
  const next = `<span class="tx f36 semi">Pesquisa concluída</span><span class="wrap f22">Leitura completa: o Mapa da Rede mostra também os suprimentos, a história e o clima de cada lugar.</span>` +
    `<div class="row" style="gap:10px">${cost("expeditions", "2 de 2 expedições")}</div>` + primary("Ver a Pesquisa", { icon: "room_research", hit: "next", height: 60, size: "f26" });
  const toast = `<div class="abs" style="left:50%;transform:translateX(-50%);top:132px">` + nine("panel_large", { repeat: "round", cls: "row", extra: "gap:14px" },
    `${glyph("room_research", 36, "var(--amber)")}<div class="col"><span class="tx f20 up amber kicker">Pesquisa concluída</span><span class="tx f28 semi">Leitura completa do radar</span></div>`) + `</div>`;
  return overview({ next, extra: toast, subtitle: "Ciclo 2 · 4 no elenco" });
}

// ------------------------------------------------------------------ 4. os laços (#93)
// Na Preparação: a marca do laço em cada carta e, embaixo das cartas, os pares com o nível (−3 a +3), o que o laço faz
// (as regras de hoje, combat_engine.gd) e o que o muda. O nível de exemplo é o de uma expedição; ver hud-laco.md.
const BONDS = [
  { a: "bento", b: "nick", an: "Bento", bn: "Nick", value: 3, kind: "friend", effect: "Quando um cai no Último Fôlego, o outro ergue a guarda: +1 bloqueio." },
  { a: "iris", b: "vespera", an: "Íris", bn: "Véspera", value: -3, kind: "rival", effect: "Um crítico inimigo num deles abala o outro: +5 de instinto." },
];
const scale = (v) => `<div class="row" style="gap:3px;flex:none">${[-3, -2, -1, 0, 1, 2, 3].map((x) => {
  const on = v > 0 ? x > 0 && x <= v : v < 0 ? x < 0 && x >= v : false;
  return `<i style="width:16px;height:${x === 0 ? 16 : 12}px;flex:none;border:1px solid #0a0b0c;background:${on ? (v > 0 ? "var(--good)" : "var(--danger-fill)") : x === 0 ? "#6d6a62" : "#2a2d31"}"></i>`;
}).join("")}</div>`;
function bondRow(bd) {
  const friend = bd.kind === "friend";
  return nine("panel_inset", { cls: "row", extra: "gap:16px;align-items:center" },
    `<div class="row" style="gap:6px;flex:none">${portrait(bd.a, 56)}${glyph(friend ? "bond_friend" : "bond_rival", 30, friend ? "var(--good)" : "var(--danger)")}${portrait(bd.b, 56)}</div>` +
    `<div class="col" style="flex:1;min-width:0;gap:4px"><div class="row" style="gap:12px;flex-wrap:wrap"><span class="tx f24 semi">${bd.an} e ${bd.bn}</span>` +
    `<span class="tx f22 semi ${friend ? "good" : "danger"}">${friend ? "Amizade" : "Rivalidade"} ${bd.value > 0 ? "+" : "−"}${Math.abs(bd.value)}</span>${scale(bd.value)}</div>` +
    `<span class="wrap f20">${bd.effect}</span></div>`);
}
function bondsPreparation() {
  const mark = (hero) => {
    const bd = BONDS.find((x) => x.a === hero || x.b === hero);
    if (!bd) return "";
    const other = bd.a === hero ? bd.bn : bd.an, friend = bd.kind === "friend";
    return `<div class="row" style="gap:8px">${glyph(friend ? "bond_friend" : "bond_rival", 22, friend ? "var(--good)" : "var(--danger)")}<span class="tx f20 ${friend ? "good" : "danger"}">${friend ? "Amizade" : "Rivalidade"} com ${other}</span></div>`;
  };
  // Na largura das quatro cartas (4 x 300 + 3 x 14), um par por linha.
  const below = `<div class="col" style="gap:10px;margin-top:16px;width:1242px"><div class="row" style="gap:12px;flex-wrap:wrap"><span class="tx f24 semi up amber kicker">Laços da equipe</span>` +
    `<span class="wrap f20 muted" style="flex:1;min-width:0">Superação aproxima (+1), colapso afasta (−1), de −3 a +3. O efeito vale em +3 e em −3.</span></div>` +
    BONDS.map(bondRow).join("") + `</div>`;
  return preparation({ cardExtra: mark, below });
}
// Na luta: o destaque curto no alto, embaixo da ordem da rodada (some sozinho, sem parar o turno), e a marca sobre quem
// recebeu o efeito, acima da cabeça, como os números da luta. As capturas são as do motor (loop-screens/before), com o laço disparado de verdade.
function bondCombat(p, kind) {
  const friend = kind === "friend";
  const cap = friend ? "combat-bond-friend" : "combat-bond-rival";
  useCapture(cap);
  const meta = JSON.parse(fs.readFileSync(`docs/design/loop-screens/before/${cap}.json`, "utf8"));
  const nick = meta.texts.find((t) => t.text === "Nick" && t.rect[1] > 650 && t.rect[1] < 800);
  const cx = Math.round(nick.rect[0] + nick.rect[2] / 2);
  const color = friend ? "var(--good)" : "var(--danger)";
  const toast = `<div class="abs" style="left:50%;transform:translateX(-50%);top:110px">` + nine("panel_large", { repeat: "round", cls: "row", extra: "gap:14px" },
    `${glyph(friend ? "bond_friend" : "bond_rival", 36, color)}<div class="col"><span class="tx f20 up kicker semi ${friend ? "good" : "danger"}">${friend ? "Amizade · Bento e Nick" : "Rivalidade · Bento e Nick"}</span>` +
    `<span class="tx f28 semi">${friend ? "Nick ergueu a guarda para proteger Bento" : "Nick estremeceu ao ver a falha do rival"}</span></div>` +
    nine("cost_chip", { cls: "row", extra: "gap:6px;min-height:40px;flex:none" }, friend ? `${glyph("intent-block.svg", 22)}<span class="tx f22 semi">+1 bloqueio</span>` : `<span class="tx f22 semi danger">+5 de instinto</span>`)) + `</div>`;
  const chipOver = `<div class="abs" style="left:${cx}px;top:430px;transform:translateX(-50%)">` +
    nine("cost_chip", { cls: "row", extra: "gap:6px;min-height:40px" }, `${glyph(friend ? "bond_friend" : "bond_rival", 22, color)}<span class="tx f22 semi ${friend ? "good" : "danger"}">${friend ? "+1 bloqueio" : "+5 de instinto"}</span>`) + `</div>`;
  const out = combat(p, { bg: cap, withRing: false, target: false, extra: toast + chipOver });
  useCapture();
  return out;
}

// ------------------------------------------------------------------ 5. os desafios dos chefes (#95)
// Depois de vencer um chefe, o desafio dele: a mesma luta com modificadores e de 1 a 3 estrelas (os critérios da luta,
// data/fight-stars.json), com prêmios de prestígio que não mexem na campanha.
const BOSSES = [
  { id: "robot", name: "Robô", phase: "Fase 1 · Rua das Vitrines", mods: ["Sem curativos", "Sem fugir"], stars: 1, open: true },
  // Os guardiões ainda não vencidos ficam sem nome e sem rosto, como no radar ("Não lido"): só a fase.
  { phase: "Fase 2", open: false }, { phase: "Fase 3", open: false }, { phase: "Fase 4", open: false }, { phase: "Fase 5", open: false },
];
const MOD_ICON = { "Sem curativos": "res-bandages.svg", "Sem fugir": "ui-arrow-right.svg", "Inimigos mais fortes": "node-combat.svg", "Equipe de dois": "nav_characters" };
const mod = (m, off) => nine("cost_chip", { cls: "row", extra: "gap:6px;min-height:40px;flex:none" }, `${glyph(MOD_ICON[m], 20, off ? "#8a8478" : "var(--danger)")}<span class="tx f20 ${off ? "muted" : ""}">${m}</span>`);
function challenges() {
  const row = (b, i) => `<div data-hit="challenge" style="position:relative;flex:none">` + nine("list_row", { cls: "row", extra: "gap:12px;min-height:calc(64px*var(--k));align-items:flex-start" },
    (b.open ? face(`art/ui/map/network/portrait_${b.id}.webp`, 52, "var(--amber)")
      : `<div class="row" style="width:44px;height:44px;justify-content:center;flex:none;border:2px solid #6d6a62;border-radius:50%"><span class="tx f24 semi muted">?</span></div>`) +
    `<div class="col" style="flex:1;min-width:0;gap:${b.open ? 4 : 0}px">` +
    `<div class="row" style="gap:10px;justify-content:space-between"><span class="tx f24 semi ${b.open ? "" : "muted"}">${b.open ? b.name : `Guardião desconhecido<span class="f20" style="font-weight:500"> · ${b.phase} · vença para ler</span>`}</span>${b.open ? stars(b.stars, 22) : lock(22)}</div>` +
    (b.open ? `<div class="row" style="gap:6px;flex-wrap:wrap"><span class="tx f20 muted" style="margin-right:6px">${b.phase}</span>${b.mods.map((m) => mod(m, false)).join("")}</div>` : "") + `</div>`) +
    (i === 0 ? over("list_row_selected") : "") + `</div>`;
  const body = `<span class="wrap f22">Depois de vencer um chefe, a mesma luta com modificadores.</span>` +
    BOSSES.map(row).join("") + divider() +
    `<span class="tx f20 up amber kicker">Robô · as estrelas</span>` +
    line("star", "var(--amber)", "Até 3 estrelas pelos critérios da luta: ninguém caiu, até 5 rodadas, o golpe final de um herói, o instinto controlado. Prêmios de prestígio: a campanha não muda.", "f20") +
    `<div class="row" style="gap:8px;flex-wrap:wrap">${cost("relic-generic.svg", "3 estrelas: uma relíquia rara")}${cost("nav_characters", "Moldura de retrato do Robô")}</div>`;
  const footer = primary("Preparar desafio · Robô", { icon: "node-boss.svg", keyLabel: "G / X", hit: "prepare", height: 64, size: "f26" });
  return networkMap({ selected: "shop", panel: { icon: "node-boss.svg", title: "Desafios dos chefes", body, footer } });
}

await run({
  cargo_choose: () => cargo(),
  // Os suprimentos escolhidos entram no Achado (o chip ganha a comida, como no jogo); a relíquia vai para o Depósito.
  cargo_reveal: () => cargo({ open: true, found: ["16", "3", "1", String(CARGO.boxes[CARGO.chosen].amount)] }),
  cargo_relic: () => cargo({ open: true, set: CARGO_RELIC }),
  map_place: () => networkMap({ selected: "shop", panel: place({ ...RUA, detail: ruaDetail(),
    footer: primary("Preparar missão · Coleta", { icon: "expeditions", keyLabel: "G / X", hit: "prepare", height: 64, size: "f26" }) }) }),
  map_place_locked: () => networkMap({ selected: "bridge", panel: place({ ...BRIDGE, detail: bridgeDetail(),
    footer: primary("Preparar missão · Patrulha", { icon: "expeditions", keyLabel: "G / X", hit: "prepare", height: 64, size: "f26" }) }) }),
  research: () => research(),
  research_done: () => researchDone(),
  bond_preparation: () => bondsPreparation(),
  bond_combat_friend: (p) => bondCombat(p, "friend"),
  bond_combat_rival: (p) => bondCombat(p, "rival"),
  challenges: () => challenges(),
}, OUT);
