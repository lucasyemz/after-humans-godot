// O tutorial (#146): os cartões da abertura, as dicas na exploração e na luta, a visita guiada da Estação e a campanha
// nova com Pular tutorial, no kit da Awesomic (art/ui/kit/station).
// Fundos: as capturas limpas do jogo com a equipe da fuga (o Bento, a Íris e a Véspera; o Nick chega no aperto, na sala
// das celas) no mapa do tutorial, o Corredor de
// Contenção montado na Godot (capture_map.gd: a zona 1 e a primeira luta, nela), e as de hud-v2/before (a Estação e o
// título).
// Uso (da raiz do repositório, com python3 -m http.server 8765 --bind 127.0.0.1 servindo a raiz):
//   node docs/design/tutorial/render.mjs http://127.0.0.1:8765
import {
  setBase, BASE, nine, over, img, glyph, key, square, divider, secondary, primary, chip, run,
} from "../hud-kit/lib.mjs";
import { useCapture, combat } from "../hud-luta/render.mjs";
import { frame, BG as V2 } from "../hud-exploracao/render.mjs";
import { overview } from "../hud-estacao/render.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/tutorial/.render";
const OWN = (name) => img(`docs/design/tutorial/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const STEPS = 6;

// ------------------------------------------------------------------ peças do tutorial
// O destaque: a moldura de foco do kit em volta do que se deve apertar, e o resto da tela escurecido (a sombra larga do
// próprio recorte faz o fundo escuro, sem cobrir o que está em destaque).
const spot = (x, y, w, h, dim = 0.55) => `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px;box-shadow:0 0 0 4000px rgba(5,6,7,${dim})">${over("focus_frame")}</div>`;
// A dica do tutorial: curta, com o passo ("3 de 6"), o que fazer, a tecla e a seta para o destaque. Fica fora do que
// está em destaque; a seta aponta para ele.
function tip({ x, y, width = 560, step, title, text, keys, arrow = null, arrowAt = 0.5 }) {
  const rot = { down: 90, up: -90, left: 180, right: 0 }[arrow];
  const pointer = arrow === null ? "" : `<div class="abs row" style="${arrow === "down" ? `left:calc(${arrowAt * 100}% - 22px);bottom:-46px` : arrow === "up" ? `left:calc(${arrowAt * 100}% - 22px);top:-46px` : arrow === "left" ? "left:-46px;top:calc(50% - 22px)" : "right:-46px;top:calc(50% - 22px)"};width:44px;height:44px;justify-content:center">` +
    glyph("ui-arrow-right.svg", 40, "var(--amber)", `transform:rotate(${rot}deg)`) + `</div>`;
  return `<div class="abs" data-hit="panel" style="left:${x}px;top:${y}px">` + nine("panel_large", { repeat: "round", cls: "col", extra: `width:${width}px;gap:8px` },
    `<div class="row" style="gap:10px;justify-content:space-between"><div class="row" style="gap:10px">${glyph("next_step", 26, "var(--amber)")}<span class="tx f20 semi up amber kicker">Tutorial</span></div>` +
    `<span class="tx f22 semi">${step} de ${STEPS}</span></div>` +
    `<span class="wrap f30 semi">${title}</span><span class="wrap f22">${text}</span>` +
    `<div class="row" style="gap:16px;flex-wrap:wrap">${keys.map(([k, t]) => `<div class="row" style="gap:6px">${k.split("|").map((x) => key(x)).join("")}<span class="tx f22">${t}</span></div>`).join("")}</div>`) +
    pointer + `</div>`;
}

// ------------------------------------------------------------------ 1. a abertura
// Um cartão só (a decisão do Lucas de 26/10): "Você precisa escapar.", no idioma do cartão de passagem
// (passage_card.gd, hud-fluxo): o aço escuro, a chapa do kit com a frase grande e a divisa com o losango âmbar; o aviso
// de pular no canto. O fade continua o de hoje, e a tirinha entra depois.
const STEEL = `<div class="abs" style="inset:0;background:#1b1d20 url(${BASE}/art/ui/kit/combat/steel_material.webp);background-blend-mode:multiply"></div>`;
const CARD = "Você precisa escapar.";
const cardDivider = `<div class="row" style="gap:12px">${img("art/ui/kit/station/divider.webp", "width:180px;height:8px")}<i style="width:10px;height:10px;background:var(--amber);transform:rotate(45deg)"></i>${img("art/ui/kit/station/divider.webp", "width:180px;height:8px")}</div>`;
const plate = () => `<div class="abs" data-hit="panel" style="left:50%;top:50%;transform:translate(-50%,-50%)">` + nine("panel_large", { repeat: "round", cls: "col", extra: "min-width:820px;max-width:1000px;gap:16px;align-items:center;padding:18px 0" },
  `<span class="tx semi" style="font-size:calc(56px*var(--k));line-height:1.12">${CARD}</span>` + cardDivider) + `</div>`;
const skip = `<div class="abs" data-hit="skip" style="right:40px;bottom:28px">` + nine("keys_bar", { cls: "row", extra: "gap:14px;height:calc(56px*var(--k));justify-content:center" },
  `<div class="row" style="gap:6px">${key("E")}<span class="tx f22">Avançar</span></div><div class="row" style="gap:6px">${key("Esc")}<span class="tx f22">Pular abertura</span></div>`) + `</div>`;
const openingCard = () => STEEL + plate() + skip;
// O lugar da tirinha, depois do cartão: o quadro 16:9 no meio (1440 × 810, na moldura do kit), sem texto por cima (a
// tirinha conta sozinha). Até ela existir, o quadro mostra a zona 1 do corredor de contenção, capturada na Godot.
const openingFrame = () => STEEL +
  `<div class="abs" style="left:240px;top:110px;width:1440px;height:810px">${img("docs/design/tutorial/zone_corridor.webp", "position:absolute;left:8px;top:8px;width:1424px;height:794px;object-fit:cover")}${nine("square_portrait", { extra: "position:absolute;inset:0" })}</div>` +
  skip;

// ------------------------------------------------------------------ 2. as dicas na exploração e na luta
// A equipe da fuga (a decisão do Lucas de 27/10: a Véspera no lugar da Amora, que ainda não existe no jogo).
const TRIO = [["bento", "Bento", 34, 34], ["iris", "Íris", 23, 23], ["vespera", "Véspera", 30, 30]];
// O corredor de contenção (a zona 1 do mapa do tutorial): o passo 1, andar. O destaque é o trio.
const tutorialExplore = () => OWN("explore_two") +
  // O nome do lugar é o decidido pelo Lucas em 26/10 (Corredor de Contenção); o corredor curto da abertura tem cinco trechos (a
  // partida, as três lutas e a busca entre a primeira e a segunda), todos à vista. O mapa é um subsolo: sem clima.
  frame({ place: "Corredor de Contenção", sub: "Abertura", title: "Trecho 1 de 5 · Partida", team: TRIO,
    route: [["start", "now"], ["combat", "known"], ["loot", "known"], ["combat", "known"], ["combat", "known"]],
    goal: { kicker: "Objetivo", title: "Chegar à plataforma", text: "O trem no fim do corredor é a saída.", done: false } }) +
  spot(410, 510, 680, 370, 0.5) +
  tip({ x: 470, y: 200, width: 560, step: 1, title: "Ande até o fim do corredor", text: "A equipe anda junta. As portas fecham atrás de vocês: a saída é para a frente.", keys: [["A|D", "Andar"], ["Shift", "Correr"]], arrow: "down" });
// Os passos da luta: a dica fica no alto à direita, acima das máquinas (a câmera da luta no corredor põe as cabeças da
// equipe logo abaixo do REGISTRO), sem seta: o destaque mostra onde apertar. No alvo, ela fica à direita do destaque.
// A luta da abertura: o passo 3, escolher a habilidade, e o passo 4, escolher o alvo.
useCapture("docs/design/tutorial/before/fight_two_hud");
const tutorialCombat = (p) => combat(p, { bg: "docs/design/tutorial/before/fight_two", withRing: false, target: false, aim: false,
  extra: spot(678, 806, 636, 248, 0.5) + tip({ x: 1292, y: 96, width: 600, step: 2, title: "Escolha uma habilidade", text: "É a vez do Bento. Cada herói tem quatro; o número no canto é a tecla.", keys: [["1|2|3|4", "Habilidade"]] }) });
const tutorialTarget = (p) => combat(p, { bg: "docs/design/tutorial/before/fight_two", withRing: false, target: false,
  extra: spot(1170, 350, 310, 466, 0.5) + tip({ x: 1416, y: 96, width: 476, step: 3, title: "Escolha o alvo", text: "Punho de Sucata alcança o Rastreador. Aperte E, ou clique nele, para atacar.", keys: [["Setas", "Trocar o alvo"], ["E", "Atacar"]] }) });

// ------------------------------------------------------------------ 3. a visita guiada da Estação
// A primeira vez na Estação: a tela escurecida, a moldura no que se mostra, a fala do Bento com o retrato e o passo,
// PRÓXIMO e PULAR VISITA. Quem guia é o Bento: o Nick chega à Estação pela primeira vez.
function speech({ step, total, text, x = 560, y = 760, last = false }) {
  // No Maior a fala sobe 24 px, para não encostar na barra de baixo.
  return `<div class="abs" data-hit="panel" style="left:${x}px;top:calc(${y}px - 24px*(var(--k) - 1)/0.3)">` + nine("panel_large", { repeat: "round", cls: "row", extra: "width:860px;gap:18px;align-items:flex-start" },
    `${square("art/ui/portraits/bento.png", 120)}<div class="col" style="flex:1;min-width:0;gap:8px">` +
    // O passo como no briefing aprovado: os losangos (o de agora em âmbar) e "2/5".
    `<div class="row" style="gap:10px;justify-content:space-between"><span class="tx f30 semi amber">Bento</span><div class="row" style="gap:8px">` +
    Array.from({ length: total }, (_, j) => `<i style="width:10px;height:10px;transform:rotate(45deg);background:${j + 1 === step ? "var(--amber)" : "#4a4e55"}"></i>`).join("") +
    `<span class="tx f22 semi" style="margin-left:4px">${step}/${total}</span></div></div>` +
    `<span class="wrap f24">${text}</span>` +
    `<div class="row" style="gap:12px;justify-content:flex-end;flex-wrap:wrap">${secondary("Pular visita", { keyLabel: "Esc", hit: "skip", height: 60 })}` +
    `<div style="min-width:240px">${primary(last ? "Começar" : "Próximo", { keyLabel: "E / A", hit: "next", height: 60, size: "f26" })}</div></div></div>`) + `</div>`;
}
// Na visita, a Estação de baixo fica parada: sem alvos (a fala é que avança) e fora das conferências de texto (as classes
// tx e wrap viram tx-u e wrap-u, com o mesmo estilo), como a confirmação da plataforma do lote 7.
const UNDER_CSS = `<style>.tx-u{white-space:nowrap;line-height:1.14}.wrap-u{white-space:normal;line-height:1.18}.pill .tx-u{position:relative;font-size:calc(22px*var(--k));font-weight:600}</style>`;
const still = (html) => UNDER_CSS + html.replace(/ data-hit="[^"]*"/g, "").replace(/ data-avoid="1"/g, "").replace(/class="(tx|wrap)( |")/g, 'class="$1-u$2');
const tourRoom = () => still(overview({ subtitle: "Ciclo 0 · 4 no elenco", bare: true })) + spot(440, 522, 364, 110, 0.62) +
  speech({ step: 2, total: 5, y: 700, text: "Aqui é o Dormitório. Depois de cada volta, a equipe dorme: quem dorme come e recupera vida e instinto. Alguém pode vigiar." });
// No último passo, o destaque é o próprio PREPARAR EXPEDIÇÃO (uma cópia parada por cima, com a moldura do tamanho dele
// em cada perfil).
const lit = (inner, style) => `<div class="abs" style="${style}">${still(inner)}<div style="position:absolute;inset:-6px;box-shadow:0 0 0 4000px rgba(5,6,7,.62)">${over("focus_frame")}</div></div>`;
const tourEnd = () => still(overview({ subtitle: "Ciclo 0 · 4 no elenco", bare: true })) +
  lit(primary("Preparar expedição", { icon: "expeditions", keyLabel: "G / X" }), "right:28px;bottom:14px;min-width:480px") +
  speech({ step: 5, total: 5, x: 980, y: 640, last: true, text: "Quando estiver pronto, prepare a próxima expedição. A equipe sai de trem daqui, como a gente chegou." });

// ------------------------------------------------------------------ 4. a campanha nova com Pular tutorial
// Depois de escolher o espaço (e confirmar, se ele já tem campanha): começar com a abertura ou pular. O padrão é a
// abertura; pular começa na Estação com a equipe de hoje (os quatro fundadores), sem a fuga.
const option = (title, text, selected, hit) => `<div data-hit="${hit}" style="position:relative">` + nine("list_row", { cls: "col", extra: "gap:4px;min-height:calc(76px*var(--k));padding:8px 6px" },
  `<div class="row" style="gap:10px">${glyph(selected ? "state_active" : "relic_empty", 26, selected ? "var(--amber)" : "var(--muted)")}<span class="tx f28 semi ${selected ? "amber" : ""}">${title}</span></div><span class="wrap f22">${text}</span>`) +
  (selected ? over("selected_frame") : "") + `</div>`;
const newCampaign = () => V2("title-slots") + `<div class="abs" style="inset:0;background:rgba(5,6,7,.45)"></div>` +
  `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:200px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:820px;gap:14px" },
    `<div class="row" style="gap:14px">${glyph("recruit", 40, "var(--amber)")}<span class="tx f40 semi up">Nova campanha</span></div>${divider()}` +
    option("Começar pela abertura (recomendado)", "A fuga do Bento, da Íris e da Véspera, com o Nick no caminho: três lutas curtas, as dicas de cada passo e o trem até a Estação.", true, "with-tutorial") +
    option("Pular tutorial", "Começa direto na Estação Raiz, com os quatro fundadores e sem as dicas.", false, "skip-tutorial") +
    `<div class="row" style="gap:12px;justify-content:flex-end;flex-wrap:wrap">${secondary("Voltar", { icon: "ui-arrow-right.svg", iconStyle: "transform:scaleX(-1)", keyLabel: "Esc / B", hit: "back", height: 64 })}` +
    `<div style="min-width:300px">${primary("Começar", { keyLabel: "E / A", hit: "start", height: 64, size: "f26" })}</div></div>`) + `</div>`;

await run({
  opening_card: () => openingCard(),
  opening_frame: () => openingFrame(),
  tutorial_explore: () => tutorialExplore(),
  tutorial_combat: (p) => tutorialCombat(p),
  tutorial_target: (p) => tutorialTarget(p),
  tour_room: () => tourRoom(),
  tour_end: () => tourEnd(),
  new_campaign: () => newCampaign(),
}, OUT);
