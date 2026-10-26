// O tutorial (#146): os cartões da abertura, as dicas na exploração e na luta, a visita guiada da Estação e a campanha
// nova com Pular tutorial, no kit da Awesomic (art/ui/kit/station).
// Fundos: as capturas limpas do jogo com a equipe da abertura (só o Bento e o Nick, capture.gd: a Rua das Vitrines, que
// a #144 usa até o mapa do tutorial ficar pronto) e as de hud-v2/before (a Estação e o título).
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

// ------------------------------------------------------------------ 1. os cartões da abertura
// No idioma do cartão de passagem (passage_card.gd, hud-fluxo): o aço escuro, a chapa do kit com o título grande, a
// divisa com o losango âmbar e a linha de baixo; o aviso de pular no canto. Por enquanto só texto, com o fade de hoje.
const STEEL = `<div class="abs" style="inset:0;background:#1b1d20 url(${BASE}/art/ui/kit/combat/steel_material.webp);background-blend-mode:multiply"></div>`;
const CARDS = [
  ["Antes da Estação", "As máquinas dos Antigos ainda cumprem ordens que ninguém cancelou."],
  ["Bento", "Saiu atrás de suprimentos. Uma área antiga entrou em contenção e baixou as portas com ele lá dentro."],
  ["Nick", "Viajava sozinho. Viu uma saída que as máquinas não vigiam, e voltou."],
  ["A plataforma", "No fim do corredor, um trem ainda espera."],
];
function plate(i, bottom) {
  const [title, sub] = CARDS[i];
  return `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);${bottom}">` + nine("panel_large", { repeat: "round", cls: "col", extra: "min-width:820px;max-width:1000px;gap:10px;align-items:center;padding:6px 0" },
    `<span class="tx semi up" style="font-size:calc(56px*var(--k));line-height:1.12">${title}</span>` +
    `<div class="row" style="gap:12px">${img("art/ui/kit/station/divider.webp", "width:180px;height:8px")}<i style="width:10px;height:10px;background:var(--amber);transform:rotate(45deg)"></i>${img("art/ui/kit/station/divider.webp", "width:180px;height:8px")}</div>` +
    `<span class="wrap f30" style="text-align:center;max-width:900px">${sub}</span>`) + `</div>`;
}
// O passo da abertura (quatro pontos, o de agora em âmbar) e o pular, como no cartão de passagem.
const dots = (i) => `<div class="abs row" style="left:50%;transform:translateX(-50%);bottom:40px;gap:12px">` +
  CARDS.map((_, j) => `<i style="width:12px;height:12px;transform:rotate(45deg);background:${j === i ? "var(--amber)" : "#4a4e55"}"></i>`).join("") + `</div>`;
const skip = `<div class="abs" data-hit="skip" style="right:40px;bottom:28px">` + nine("keys_bar", { cls: "row", extra: "gap:14px;height:calc(56px*var(--k));justify-content:center" },
  `<div class="row" style="gap:6px">${key("E")}<span class="tx f22">Avançar</span></div><div class="row" style="gap:6px">${key("Esc")}<span class="tx f22">Pular abertura</span></div>`) + `</div>`;
const openingCard = () => STEEL + plate(1, "top:calc(50% - 150px)") + dots(1) + skip;
// O lugar da tirinha: o quadro 16:9 no alto (1120 × 630), a chapa do texto embaixo. Até a tirinha existir, o quadro
// mostra a prévia do corredor de contenção (zone_corridor.webp), no lugar e na medida dela.
const openingFrame = () => STEEL +
  `<div class="abs" style="left:400px;top:56px;width:1120px;height:630px">${img("docs/design/tutorial/zone_corridor.webp", "position:absolute;left:8px;top:8px;width:1104px;height:614px;object-fit:cover")}${nine("square_portrait", { extra: "position:absolute;inset:0" })}</div>` +
  plate(3, "bottom:calc(110px - 20px*(var(--k) - 1)/0.3)") + dots(3) + skip;

// ------------------------------------------------------------------ 2. as dicas na exploração e na luta
const TWO = [["bento", "Bento", 34, 34], ["nick", "Nick", 24, 24]];
// A rua da abertura (a Rua das Vitrines até o mapa do tutorial chegar): o passo 1, andar. O destaque é a dupla.
const tutorialExplore = () => OWN("explore_two") +
  // O nome do lugar é a proposta da #147 (Corredor de Contenção); o corredor curto da abertura tem cinco trechos (a
  // partida, as três lutas e a busca entre a primeira e a segunda), todos à vista. O mapa é um subsolo: sem clima.
  frame({ place: "Corredor de Contenção", sub: "Abertura", title: "Trecho 1 de 5 · Partida", team: TWO,
    route: [["start", "now"], ["combat", "known"], ["loot", "known"], ["combat", "known"], ["combat", "known"]],
    goal: { kicker: "Objetivo", title: "Chegar à plataforma", text: "O trem no fim do corredor é a saída.", done: false } }) +
  spot(740, 700, 320, 290, 0.5) +
  tip({ x: 1110, y: 560, width: 560, step: 1, title: "Ande até o fim do corredor", text: "O Bento e o Nick andam juntos. As portas fecham atrás de vocês: a saída é para a frente.", keys: [["A|D", "Andar"], ["Shift", "Correr"]], arrow: "left" });
// Os passos da luta: a dica fica no alto à esquerda, acima das cabeças (a faixa livre sob o REGISTRO), sem seta: o
// destaque mostra onde apertar.
// A luta da abertura: o passo 3, escolher a habilidade, e o passo 4, escolher o alvo.
useCapture("docs/design/tutorial/before/fight_two_hud");
const tutorialCombat = (p) => combat(p, { bg: "docs/design/tutorial/before/fight_two", withRing: false, target: false, aim: false,
  extra: spot(678, 806, 636, 248, 0.5) + tip({ x: 28, y: 108, width: 600, step: 2, title: "Escolha uma habilidade", text: "É a vez do Nick. Cada herói tem quatro; o número no canto é a tecla.", keys: [["1|2|3|4", "Habilidade"]] }) });
const tutorialTarget = (p) => combat(p, { bg: "docs/design/tutorial/before/fight_two", withRing: false, target: false,
  extra: spot(1040, 320, 258, 492, 0.5) + tip({ x: 28, y: 108, width: 600, step: 3, title: "Escolha o alvo", text: "Corte de Fase alcança o Recreador. Aperte E, ou clique nele, para atacar.", keys: [["Setas", "Trocar o alvo"], ["E", "Atacar"]] }) });

// ------------------------------------------------------------------ 3. a visita guiada da Estação
// A primeira vez na Estação: a tela escurecida, a moldura no que se mostra, a fala do Bento com o retrato e o passo,
// PRÓXIMO e PULAR VISITA. Quem guia é o Bento: o Nick chega à Estação pela primeira vez.
function speech({ step, total, text, x = 560, y = 760, last = false }) {
  return `<div class="abs" data-hit="panel" style="left:${x}px;top:${y}px">` + nine("panel_large", { repeat: "round", cls: "row", extra: "width:860px;gap:18px;align-items:flex-start" },
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
// abertura; pular começa na Estação com a equipe de hoje (os quatro fundadores), sem a fuga do Bento e do Nick.
const option = (title, text, selected, hit) => `<div data-hit="${hit}" style="position:relative">` + nine("list_row", { cls: "col", extra: "gap:4px;min-height:calc(76px*var(--k));padding:8px 6px" },
  `<div class="row" style="gap:10px">${glyph(selected ? "state_active" : "relic_empty", 26, selected ? "var(--amber)" : "var(--muted)")}<span class="tx f28 semi ${selected ? "amber" : ""}">${title}</span></div><span class="wrap f22">${text}</span>`) +
  (selected ? over("selected_frame") : "") + `</div>`;
const newCampaign = () => V2("title-slots") + `<div class="abs" style="inset:0;background:rgba(5,6,7,.45)"></div>` +
  `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:200px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:820px;gap:14px" },
    `<div class="row" style="gap:14px">${glyph("recruit", 40, "var(--amber)")}<span class="tx f40 semi up">Nova campanha</span></div>${divider()}` +
    option("Começar pela abertura (recomendado)", "A fuga do Bento e do Nick: três lutas curtas, as dicas de cada passo e o trem até a Estação.", true, "with-tutorial") +
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
