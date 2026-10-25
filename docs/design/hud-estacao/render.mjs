// Lote 1: as outras telas da Estação no idioma do relatório e da Sala dos Personagens (docs/design/hud-station.md).
// Fundos: as capturas limpas do jogo em docs/design/hud-v2/before/; textos e números: os dessas capturas (os .json).
// Uso (da raiz do repositório, com python3 -m http.server 8765 servindo a raiz):
//   node docs/design/hud-estacao/render.mjs http://127.0.0.1:8765
import {
  setBase, nine, over, img, glyph, key, bar, portrait, square, pill, badge, divider, cost, chip, secondary, primary, train,
  toggle, slider, medal, topBar, bottom, roomPanel, roomTag, section, arrow, run,
} from "../hud-kit/lib.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-estacao/.render";
const BG = (name) => img(`docs/design/hud-v2/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const LOCKED = { label: "Preparar expedição", icon: "expeditions", keyLabel: "G / X", locked: true, reason: "Conclua a noite no Dormitório antes de partir." };
const inset = (body, extra = "") => nine("panel_inset", { cls: "col", extra: `gap:8px;flex:none;${extra}` }, body);
const line = (icon, text, cls = "", size = 22) => `<div class="row" style="gap:10px;align-items:flex-start">${icon ? glyph(icon, 26, cls === "danger" ? "var(--danger)" : "var(--text)", "margin-top:2px") : ""}<span class="wrap f${size} ${cls}">${text}</span></div>`;

const VISIT = { label: "Preparar expedição", icon: "expeditions", keyLabel: "G / X", locked: true, reason: "Há alguém esperando na plataforma: decida antes de partir." };
// Botão de aço com o título e a linha de baixo (o Plano da Estação na visão geral).
const twoLine = (icon, title, sub, hit, width) => `<div data-hit="${hit}">` + nine("secondary_button", { cls: "row", extra: `width:${width}px;min-height:calc(64px*var(--k));gap:12px` },
  `${glyph(icon, 30)}<div class="col"><span class="tx f26 semi up">${title}</span><span class="tx f20 muted">${sub}</span></div>`) + `</div>`;
// As pendências da coluna da esquerda (refuge_hud.gd): o que espera decisão antes de partir.
const pending = (rows) => nine("panel_large", { repeat: "round", cls: "col", extra: "width:500px;gap:10px" },
  `<div class="row" style="gap:10px">${glyph("alert", 26, "var(--amber)")}<span class="tx f22 semi amber kicker">Pendências</span></div>` +
  rows.map(([icon, text, hit]) => `<div data-hit="${hit}">` + nine("list_row", { cls: "row", extra: "gap:12px;min-height:56px" }, `${glyph(icon, 28, "var(--amber)")}<span class="wrap f22">${text}</span>`) + `</div>`).join(""));

// ------------------------------------------------------------------ 1. Visão geral
function overview() {
  const next = nine("panel_large", { repeat: "round", cls: "col", extra: "width:500px;gap:10px" },
    `<div class="row" style="gap:10px">${glyph("next_step", 28, "var(--amber)")}<span class="tx f22 semi amber kicker">Próximo passo</span></div>` +
    `<span class="tx f36 semi">Recuperar a Forja</span><span class="wrap f22">Fabrica relíquias por 3 sucatas. Gasta 1 de energia.</span>` +
    `<div class="row" style="gap:10px">${cost("lobby-scrap.svg", "4 sucatas · tem 9")}</div>` +
    primary("Ver a Forja", { icon: "room_forge", hit: "next", height: 60, size: "f26" }));
  const plan = twoLine("plan", "Plano da Estação", "o que cada cômodo destrava", "plan", 500);
  // O cômodo escolhido no corte: cantos âmbar em volta e a etiqueta com a ponta para baixo.
  const room = `<div class="abs" style="left:804px;top:523px;width:246px;height:106px">${nine("selected_slot", { extra: "position:absolute;inset:0" })}</div>` +
    `<div class="abs" style="left:827px;top:calc(523px - 52px*var(--k));width:200px">` + nine("room_tag", { cls: "row", extra: "width:200px;height:calc(52px*var(--k));justify-content:center;gap:8px" }, `${glyph("room_quarters", 22, "var(--amber)")}<span class="tx f22 semi">Alojamento</span>`) + `</div>`;
  // Um só botão âmbar além de PREPARAR: GERENCIAR é de aço, e a tecla de abrir é a da barra (E).
  const card = nine("panel_large", { repeat: "round", cls: "col", extra: "width:500px;gap:8px" },
    `<div class="row" style="gap:12px">${glyph("room_quarters", 36, "var(--amber)")}<span class="tx f32 semi up">Alojamento</span>${roomTag("Aberto", "var(--good)")}</div>` +
    `<span class="wrap f22">Conhecer e acompanhar os moradores do abrigo.</span>` + secondary("Gerenciar", { hit: "manage", height: 60, extra: "width:100%" }));
  return BG("station") + topBar({ subtitle: "Ciclo 0 · 4 no elenco" }) + room +
    `<div class="abs col" style="left:28px;top:132px;gap:12px">${next}${plan}</div>` +
    `<div class="abs" style="left:28px;bottom:calc(14px + 72px*var(--k) + 14px)">${card}</div>` +
    bottom({ active: 0, back: false, keysAt: 840, keys: [["Setas", "Cômodos"], ["E", "Abrir"], ["Esc", "Menu"], ["F2", "Ocultar"]] });
}

// ------------------------------------------------------------------ 2. Preparação
const TEAM = [
  ["vespera", "Véspera", "Atiradora e Controle", 30, 30, 4, ["coruja_disparo_perfurante", "coruja_granada_fumaca", "coruja_olho_nas_ruinas", "coruja_recurso_emergencia"], 3],
  ["iris", "Íris", "Química e Suporte", 23, 23, 3, ["sapo_carga_voltaica", "sapo_coquetel_corrosivo", "sapo_antidoto_campo", "sapo_ampola_reparo_vivo"], 4],
  ["nick", "Nick", "Batedor e Mobilidade", 24, 24, 2, ["gato_corte_fase", "gato_salto_entre_ruinas", "gato_sumir_na_sombra", "gato_cacada_precisa"], 4],
  ["bento", "Bento", "Tanque e Proteção", 34, 34, 1, ["cao_punho_sucata", "cao_impacto_hidraulico", "cao_fique_atras_de_mim", "cao_nao_estamos_sos"], 4],
];
const square56 = (hit, text) => `<div data-hit="${hit}">${nine("icon_button", { pad: [4, 4, 4, 4], extra: "width:calc(56px*var(--k));height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, `<span class="tx f30 semi">${text}</span>`)}</div>`;
function preparation() {
  // O medalhão da posição fica no canto do retrato, e o nome tem a largura toda da carta.
  const card = ([hero, name, role, hp, max, pos, abilities, usable]) =>
    `<div data-hit="slot" style="flex:none">` + nine("hero_card", { repeat: "round", cls: "col", extra: "width:300px;gap:8px" },
      `<div class="row" style="gap:12px;align-items:flex-start"><div style="position:relative;flex:none">${portrait(hero, 76)}<div data-avoid="1" style="position:absolute;left:-14px;top:-14px">${medal(pos, 44)}</div></div>` +
      `<div class="col" style="flex:1;min-width:0"><span class="tx f30 semi up">${name}</span><span class="wrap f20 muted">${role}</span></div></div>` +
      `<div class="row" style="gap:10px"><span class="tx f20 muted up">Vida</span><span class="tx f22">${hp} / ${max}</span></div>${bar("100%", 22, hp / max, "var(--ally)")}` +
      `<div class="row" style="gap:6px">${abilities.map((a, i) => square(`art/combat/icons/${a}.webp`, 54, i >= usable ? "opacity:.35;filter:grayscale(1)" : "")).join("")}</div>` +
      `<div class="row" style="gap:8px">${glyph("state_active", 22, "var(--good)")}<span class="tx f20 good">${usable} de 4 habilidades daqui</span></div>`) + `</div>`;
  const team = `<div class="col" style="gap:10px;flex:none"><div class="row" style="gap:18px"><span class="tx f24 semi up amber kicker">Equipe · 1 a 4 animais</span><span class="tx f20 muted">Clique em dois para trocar</span>` +
    `<div class="row" style="gap:6px;margin-left:auto">${glyph("ui-arrow-right.svg", 18, "var(--muted)", "transform:scaleX(-1)")}<span class="tx f20 muted">fundo · frente</span>${glyph("ui-arrow-right.svg", 18, "var(--muted)")}</div></div><div class="row" style="gap:14px;align-items:flex-start">${TEAM.map(card).join("")}</div></div>`;
  // A escolha (moldura âmbar) e a recomendação (o selo com o pino) são coisas diferentes, como a ★ do jogo.
  const side = `<div class="col" style="gap:12px;width:500px;flex:none">` +
    inset(`<span class="tx f20 semi up amber kicker">Missão</span><div class="row" style="gap:12px">${glyph("route", 40)}<div class="col"><span class="tx f30 semi">Rua das Vitrines</span><span class="tx f20 muted">Fase 1 · Fácil · nível 1+</span></div></div>` +
      chip("Escolher no mapa", { icon: "next_step", hit: "map" })) +
    inset(`<span class="tx f20 semi up amber kicker">Foco da rota</span><div class="row" style="gap:8px;flex-wrap:wrap">${chip("Rota básica", { selected: true })}${chip("Água", { icon: "lobby-water.svg" })}${chip("Peças", { icon: "lobby-scrap.svg" })}${chip("Provisões", { icon: "lobby-food.svg" })}</div>` +
      `<div class="row" style="gap:8px">${glyph("objective_done", 24, "var(--amber)")}<span class="wrap f20"><b class="semi amber">Recomendado: Provisões.</b> Suprimentos: 0 de 12; a noite da volta pede 4.</span></div>`) +
    inset(`<div class="row" style="gap:12px;justify-content:space-between"><div class="col"><span class="tx f20 semi up amber kicker">Comida</span><span class="tx f26 semi">4 grátis + 0 extras</span></div>` +
      `<div class="row" style="gap:8px">${square56("minus", "−")}${square56("plus", "+")}</div></div>` +
      `<span class="wrap f20 muted">0 sementes · cura na Mochila e no acampamento</span>`) + `</div>`;
  // O painel termina acima da linha do VOLTAR, como a coluna da Sala.
  return BG("station-preparation") + topBar({ subtitle: "Preparação" }) +
    `<div class="abs" style="left:28px;bottom:calc(14px + 72px*var(--k) + 10px + 64px + 12px)">` + nine("panel_large", { repeat: "round", cls: "row", extra: "width:1864px;gap:22px;align-items:flex-start" }, team + side) + `</div>` +
    bottom({ active: -1, back: true, main: { label: "Partir · Rua das Vitrines", icon: "expeditions", keyLabel: "G / X" } });
}

// ------------------------------------------------------------------ 3 e 4. Forja e Centro de Pesquisa (recuperar)
// O que o cômodo libera aparece apagado só no ícone; o texto fica no tom cheio, para ler acima de 4,5:1.
function forge() {
  const relic = (icon, name, effect) => inset(`<div class="row" style="gap:12px">${glyph(icon, 34, "#6d6a62")}<div class="col" style="flex:1;min-width:0"><span class="tx f24 semi">${name}</span><span class="wrap f20 muted">${effect}</span></div>${cost("lobby-scrap.svg", "3")}</div>`);
  const body = `<span class="wrap f24">Oficina vazia. Recuperada, fabrica relíquias e gasta 1 de energia.</span>` +
    section("Recuperar", "room_forge") + `<div class="row" style="gap:10px">${cost("lobby-scrap.svg", "4 sucatas · tem 9")}</div>` + train("Recuperar", "", { hit: "recover", icon: "room_forge" }) +
    divider() + section("Depois de recuperar") +
    relic("relic-copper-button.svg", "Botão de Cobre", "+3 de Vida Máxima.") + relic("relic-glass-feather.svg", "Pena de Vidro", "+1 de Velocidade.") +
    relic("relic-memory-collar.svg", "Coleira de Lembrança", "−2 de Instinto causado por eventos misteriosos (mínimo zero).");
  return BG("station-forge") + topBar({ subtitle: "Forja" }) + roomPanel({ icon: "room_forge", title: "Forja", tag: roomTag("Vazio"), body }) + bottom({ active: 1 });
}
function research() {
  const skill = (id, name) => inset(`<div class="row" style="gap:12px">${square(`art/combat/icons/${id}.webp`, 48, "filter:grayscale(.8) brightness(.7)")}<div class="col" style="flex:1;min-width:0"><span class="tx f24 semi">Treino: ${name}</span><span class="wrap f20 muted">+1 nos limites de dano ou cura de ${name}.</span></div>${cost("lobby-fragment.svg", "3")}</div>`);
  const body = `<span class="wrap f24">Laboratório vazio. Recuperado, libera as melhorias de classe e gasta 1 de energia.</span>` +
    section("Recuperar", "room_research") + `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-scrap.svg", "3 sucatas · tem 9")}${cost("lobby-fragment.svg", "2 fragmentos · tem 3")}</div>` +
    train("Recuperar", "", { hit: "recover", icon: "room_research" }) + divider() + section("Depois de recuperar: melhorias de classe") +
    skill("cao_punho_sucata", "Punho de Sucata") + skill("gato_corte_fase", "Corte de Fase") + skill("sapo_carga_voltaica", "Carga Voltaica") + skill("coruja_recurso_emergencia", "Recurso de Emergência");
  return BG("station-research") + topBar({ subtitle: "Centro de Pesquisa" }) + roomPanel({ icon: "room_research", title: "Centro de Pesquisa", tag: roomTag("Vazio"), body }) + bottom({ active: 3 });
}

// ------------------------------------------------------------------ 5 e 6. Dormitório (a noite e vazio)
const NIGHT = [["bento", "Bento", "34/34", "+0 de vida, +0 de instinto"], ["nick", "Nick", "8/24", "+8 de vida, +0 de instinto"],
  ["iris", "Íris", "23/23", "+0 de vida, +0 de instinto"], ["vespera", "Véspera", "30/30", "+0 de vida, +0 de instinto"]];
function night() {
  const row = ([hero, name, life, effect]) => inset(
    `<div class="row" style="gap:12px">${portrait(hero, 52)}<div class="col" style="flex:1;min-width:0"><span class="tx f26 semi">${name}</span><div class="row" style="gap:8px;flex-wrap:wrap"><span class="tx f20 muted">Vida ${life}</span><span class="tx f20 muted">Instinto 0</span></div></div>` +
    `<div class="row" style="gap:6px">${chip("Dormir", { icon: "sleep", selected: true, hit: "sleep" })}${chip("Vigiar", { icon: "watch", hit: "watch" })}</div></div>` +
    `<span class="wrap f20 muted">Alimentado · ${effect}</span>`, "gap:4px");
  const body = `<span class="wrap f22">Quarto por recuperar: só os beliches de ferro. A equipe dorme aqui depois de cada volta.</span>` +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${roomTag("Noite 1", "var(--amber)")}${roomTag("4 dormindo · 0 vigiando")}${cost("lobby-food.svg", "+1 suprimento · 2 sementes")}</div>` + NIGHT.map(row).join("");
  // As ações ficam no pé do painel, fora da parte que rola.
  const footer = line("lobby-food.svg", "Suprimentos: 4 necessários · 6 disponíveis") + `<span class="wrap f20 muted">Quem vigia não descansa, mas protege os outros dos ruídos da noite.</span>` +
    primary("Iniciar descanso", { icon: "sleep", keyLabel: "E / A", hit: "rest", height: 64, size: "f26" });
  return BG("station-night") + topBar({ subtitle: "Ciclo 1 · 4 no elenco", stock: ["36", "12", "4", "2"], food: ["6 / 12 suprimentos", "Abastecida · demanda 4", false], water: ["4 em estoque", "Próxima volta: 2"] }) +
    `<div class="abs" style="left:28px;top:132px">${pending([["sleep", "A noite espera no Dormitório", "pending-night"], ["train_arrival", "O trem chegou: alguém espera na plataforma", "pending-train"]])}</div>` +
    roomPanel({ icon: "bed", title: "Dormitório", tag: roomTag("Vazio"), body, footer }) + bottom({ active: 1, main: LOCKED, keysAt: 930 });
}
function dormitory() {
  const body = `<span class="wrap f24">Quarto por recuperar: só os beliches de ferro. A equipe dorme aqui depois de cada volta.</span>` +
    inset(`<div class="row" style="gap:14px">${glyph("sleep", 48, "var(--muted)")}<span class="wrap f22 muted">Ninguém precisa descansar agora. Depois de cada expedição, a equipe passa a noite aqui.</span></div>`);
  return BG("station-dormitory") + topBar({ subtitle: "Dormitório" }) + roomPanel({ icon: "bed", title: "Dormitório", tag: roomTag("Vazio"), body }) + bottom({ active: 1 });
}

// ------------------------------------------------------------------ 7. O trem chegou
function trainArrival() {
  const body = `<div class="row" style="gap:16px;align-items:flex-start">${square("art/civilians/civil_dora.webp", 116, "")}` +
    `<div class="col" style="gap:4px;flex:1;min-width:0"><span class="tx f20 semi up amber kicker">Dora quer morar na Estação</span><span class="tx f40 semi">Dora</span>` +
    `<span class="tx f24 amber">Cozinheira · Texugo</span><span class="wrap f22 muted">Prática, evita desperdício.</span></div></div>` +
    inset(`<div class="row" style="gap:10px">${badge("+", "var(--good)")}<span class="tx f22 semi up good">Ponto forte</span></div><span class="wrap f22">Na Cantina com energia, produz mais 2 suprimentos por volta.</span>`) +
    inset(`<div class="row" style="gap:10px">${badge("−", "var(--danger-fill)")}<span class="tx f22 semi up danger">Ponto fraco</span></div><span class="wrap f22">Cozinhar gasta água: bebe 2 por volta.</span>`) +
    inset(`<div class="row" style="gap:10px">${glyph("plan", 24, "var(--amber)")}<span class="tx f22 semi up amber">Pedido</span></div><span class="wrap f22">Quer recuperar um caderno de receitas esquecido numa mercearia abandonada.</span>`) +
    section("Na próxima volta") + `<div class="col" style="gap:8px">` +
    [["lobby-food.svg", "Suprimentos depois da noite", "0 → 0", false], ["lobby-water.svg", "Água depois", "4 → 2", true], ["lobby-energy.svg", "Energia", "3 → 3", false]]
      .map(([i, l, v, w]) => `<div class="row" style="gap:10px;justify-content:space-between"><span class="tx f22">${l}</span>${cost(i, v, w)}</div>`).join("") + `</div>`;
  // Recusar não tem tecla: Esc fecha o painel e não pode recusar a Dora sem querer.
  const footer = primary("Acolher Dora", { icon: "recruit", keyLabel: "E / A", hit: "accept", height: 64, size: "f26" }) + secondary("Recusar", { hit: "refuse", height: 60, extra: "width:100%" });
  return BG("station-train") + topBar({ subtitle: "Plataforma 1" }) + roomPanel({ icon: "train_arrival", title: "O trem chegou", body, footer }) + bottom({ active: 0, main: VISIT, keysAt: 930 });
}

// ------------------------------------------------------------------ 8. Plano da Estação
// A ordem dos cômodos é a do jogo (refuge_hud.gd, o Plano).
const ROOMS = [["room_quarters", "Alojamento", "Nível 1 de 1", "Elenco, recrutar, tratar trauma, relíquias e o memorial.", []],
  ["room_canteen", "Cantina", "Nível 1 de 1", "Com energia, produz 2 suprimentos por expedição.", []],
  ["room_bar", "Bar", "Vazio", "Ainda vazio.", []], ["bed", "Dormitório", "Vazio", "Ainda vazio.", []],
  ["room_forge", "Forja", "Vazio", "Recuperar: fabrica relíquias por 3 sucatas. Gasta 1 de energia.", [["lobby-scrap.svg", "4"]]],
  ["room_depot", "Depósito", "Nível 1 de 2", "Guarda até 12 suprimentos; o excesso estraga na volta.", []],
  ["room_research", "Centro de Pesquisa", "Vazio", "Recuperar: libera as melhorias de classe. Gasta 1 de energia.", [["lobby-scrap.svg", "3"], ["lobby-fragment.svg", "2"]]]];
function plan() {
  const row = ([icon, name, level, desc, price]) => inset(`<div class="row" style="gap:12px">${glyph(icon, 36, level === "Vazio" ? "var(--muted)" : "var(--amber)")}<span class="tx f28 semi" style="flex:1">${name}</span>${roomTag(level, level === "Vazio" ? "var(--muted)" : "var(--good)")}</div>` +
    `<div class="row" style="gap:10px;align-items:flex-start"><span class="wrap f20 muted" style="flex:1">${desc}</span>${price.map(([i, v]) => cost(i, v)).join("")}${chip("Ver", { hit: "see" })}</div>`);
  const body = `<span class="wrap f22">A Estação cresce com o que as jornadas trazem. Sucata e fragmentos recuperam e melhoram os cômodos.</span>` + ROOMS.map(row).join("");
  return BG("station-plan") + topBar({ subtitle: "Plano da Estação" }) + roomPanel({ icon: "plan", title: "Plano da Estação", body }) + bottom({ active: 1 });
}

// ------------------------------------------------------------------ 9, 10 e 11. Cantina, Depósito e Bar
// A conta da próxima volta: o que entra em verde, o que sai no tom normal; só o resultado que falta fica em alerta.
function canteen() {
  const flow = (icon, label, parts, result, warn) => inset(`<div class="row" style="gap:10px">${glyph(icon, 30)}<span class="tx f24 semi up">${label}</span></div>` +
    `<div class="row" style="gap:8px;flex-wrap:wrap;align-items:center">${parts.map(([t, c]) => `<span class="tx f22 ${c || ""}">${t}</span>`).join(`<span class="tx f22 muted">·</span>`)}` +
    `<div class="row" style="gap:8px;flex:none">${arrow()}${cost(icon, result, warn)}</div></div>`);
  const body = `<span class="wrap f24">Com energia, produz 2 suprimentos por expedição.</span>` + section("Próxima volta (equipe de 4)") +
    flow("lobby-food.svg", "Suprimentos", [["0 no estoque"], ["+2 da Cantina", "good"], ["0 para os moradores"], ["a noite pede 4"]], "0 depois da noite", true) +
    flow("lobby-water.svg", "Água", [["6 na estação"], ["+2 do coletor", "good"], ["a equipe e os moradores bebem 4"]], "4") +
    flow("lobby-energy.svg", "Energia", [["1 de 3 em uso"]], "2 livres");
  return BG("station-canteen") + topBar({ subtitle: "Cantina" }) + roomPanel({ icon: "room_canteen", title: "Cantina", tag: roomTag("Nível 1", "var(--good)"), body }) + bottom({ active: 1 });
}
function depot() {
  const tile = (icon, n, label) => `<div class="col" style="align-items:center;gap:4px;width:104px">` + nine("resource_tile", { extra: "width:104px;height:84px;display:flex;align-items:center;justify-content:center" }, glyph(icon, 44)) +
    `<span class="tx f30 semi amber" style="line-height:1">${n}</span><span class="tx f20" style="line-height:1.1">${label}</span></div>`;
  const body = `<span class="wrap f24">Guarda até 12 suprimentos; o excesso estraga na volta.</span>` +
    `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f22 up">Suprimentos</span><span class="tx f24 danger">0 / 12</span></div>${bar("100%", 24, 0, "var(--amber)")}</div>` +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-scrap.svg", "5 sucatas · tem 9")}${cost("lobby-fragment.svg", "1 fragmento · tem 3")}</div>` + train("Melhorar", "para o nível 2", { hit: "upgrade", icon: "room_depot" }) +
    divider() + section("Estoque") +
    `<div class="row" style="gap:12px;flex-wrap:wrap">${tile("res-bandages.svg", 2, "Curativos")}${tile("lobby-seed.svg", 30, "Sementes")}${tile("lobby-scrap.svg", 9, "Sucata")}${tile("lobby-fragment.svg", 3, "Fragmentos")}${tile("lobby-water.svg", 6, "Água")}</div>` +
    line("relic-generic.svg", "Relíquias no estoque: nenhuma", "muted") + line("tool-generic.svg", "Ferramentas: nenhuma", "muted");
  return BG("station-depot") + topBar({ subtitle: "Depósito" }) + roomPanel({ icon: "room_depot", title: "Depósito", tag: roomTag("Nível 1 de 2", "var(--good)"), body }) + bottom({ active: 1 });
}
function barRoom() {
  // Só o texto que o jogo já tem: o efeito do Bar está em aberto (#11).
  const body = inset(`<div class="row" style="gap:14px">${glyph("room_bar", 52, "var(--muted)")}<span class="wrap f24">Salão vazio, sem uso por enquanto.</span></div>`);
  return BG("station-bar") + topBar({ subtitle: "Bar" }) + roomPanel({ icon: "room_bar", title: "Bar", tag: roomTag("Vazio"), body }) + bottom({ active: 1 });
}

// ------------------------------------------------------------------ 12. Opções (as seções de options_panel.gd)
function options() {
  const rowS = (label, ratio) => `<div class="row" data-hit="slider" style="gap:14px;min-height:56px"><span class="tx f24" style="width:150px">${label}</span>${slider(ratio, 260)}<span class="tx f24 amber" style="width:60px;text-align:right">${Math.round(ratio * 100)}%</span></div>`;
  const rowT = (label, on) => `<div class="row" data-hit="toggle" style="gap:14px;justify-content:space-between;min-height:56px"><span class="wrap f24" style="flex:1">${label}</span><span class="tx f20 ${on ? "amber" : "muted"}">${on ? "Ligado" : "Desligado"}</span>${toggle(on)}</div>`;
  const rowC = (label, opts, sel, icon = "") => `<div class="col" style="gap:6px"><div class="row" style="gap:8px">${icon ? glyph(icon, 24) : ""}<span class="tx f24">${label}</span></div><div class="row" style="gap:8px;flex-wrap:wrap">${opts.map((o, i) => chip(o, { selected: i === sel })).join("")}</div></div>`;
  const keyRow = (label, keys) => `<div class="row" style="gap:10px;min-height:56px"><span class="wrap f22" style="flex:1">${label}</span>${keys.map((k) => key(k)).join("")}${chip("Trocar", { hit: "rebind" })}</div>`;
  const body = section("Som", "opt_sound") + rowS("Música", 0.6) + rowS("Ambiente", 0.6) + rowS("Efeitos", 0.6) +
    section("Gráficos", "opt_graphics") + rowC("Qualidade", ["Baixo", "Médio", "Alto", "Ultra"], 2) + `<span class="wrap f20 muted">Qualidade: resolução interna, sombras, oclusão, neblina e quantidade de chuva.</span>` +
    rowT("Tela cheia", false) + rowT("Sincronia vertical (vsync)", true) +
    section("Jogo", "nav_characters") + rowC("Velocidade da batalha", ["1x", "2x"], 0) + rowT("Reduzir efeitos (clima, tremor e clarão)", false) + rowT("Dicas da primeira vez", true) +
    rowT("Cores para daltonismo (azul e laranja)", false) + rowC("Tamanho do texto", ["Normal", "Grande", "Maior"], 0) + rowC("Idioma", ["Português", "English (em teste)"], 0, "opt_language") +
    chip("Mostrar as dicas de novo", { hit: "tips" }) +
    section("Controles", "opt_controls") + rowC("Controles de toque", ["Automático", "Sempre", "Desligados"], 0) +
    `<span class="wrap f20 muted">Analógico à esquerda para andar (até a borda corre) e Usar à direita; o aviso de interação também aceita toque.</span>` +
    `<span class="wrap f20 muted">Trocar: clique e aperte a tecla nova (Esc cancela). Se outra ação usava a tecla, as duas trocam.</span>` +
    keyRow("Andar para a esquerda", ["A", "Seta esq."]) + keyRow("Andar para a direita", ["D", "Seta dir."]) + keyRow("Correr", ["Shift", "RB"]) +
    keyRow("Interagir", ["E", "A"]) + keyRow("Mochila", ["I", "Y"]) + keyRow("Voltar", ["Backspace", "B"]) + keyRow("Menu", ["Esc", "Start"]) +
    chip("Restaurar as teclas padrão", { hit: "defaults" }) + `<span class="wrap f20 muted">Mouse: clique nos botões e nos alvos da luta.</span>` +
    section("Campanha", "station") + `<div class="row" style="gap:8px;flex-wrap:wrap">${chip("Voltar ao título", { hit: "title" })}` +
    `<div data-hit="new-campaign">${nine("chip_button", { cls: "row", extra: "gap:8px;min-height:calc(56px*var(--k))" }, `${glyph("alert", 24, "var(--danger)")}<span class="tx f24 danger">Nova campanha…</span>`)}</div></div>`;
  return BG("station-options") + topBar({ subtitle: "Ciclo 0 · 4 no elenco" }) + roomPanel({ icon: "lobby-settings.svg", title: "Opções", body }) + bottom({ active: 0, back: true, keys: [["Setas", "Navegar"], ["E", "Mudar"], ["Esc", "Fechar"]] });
}

await run({
  overview: () => overview(), preparation: () => preparation(), forge: () => forge(), research: () => research(),
  night: () => night(), dormitory: () => dormitory(), train: () => trainArrival(), plan: () => plan(),
  canteen: () => canteen(), depot: () => depot(), bar: () => barRoom(), options: () => options(),
}, OUT);
