// Lote 7: a Estação nova (#120 e #124), no kit da Awesomic (art/ui/kit/station):
// - a Enfermaria (#121): o cômodo na Estação em corte (a captura da Godot, capture_infirmary.gd), o painel e o aviso no
//   Próximo passo;
// - Caído (#118): as cartas do relatório, da Sala e da Preparação, e "Íris caiu" no popup de fim de luta;
// - os limites e o posto (#119): "Heróis 6 de 8", "Ajudantes 3 de 4", o campo Posto, "Quem trabalha aqui" e o rendimento;
// - o recrutamento pelo trem (#122): quem chegou, a casa cheia e a volta sem ninguém;
// - a preparação na plataforma (#123): IR AO MAPA, PREPARAR NESTE LUGAR, a equipe de pé com as cartas e a confirmação.
// Fundos: as capturas limpas da Estação (hud-v2/before e as de capture_infirmary.gd em before/), as montagens da
// plataforma (build_platform.py) e
// a luta de verdade com a Íris caída (capture.gd). Números de exemplo: as propostas das issues, em data/ na integração.
// Uso (da raiz do repositório, com python3 -m http.server 8765 --bind 127.0.0.1 servindo a raiz):
//   node docs/design/hud-casa/render.mjs http://127.0.0.1:8765
import fs from "node:fs";
import {
  setBase, BASE, KIT, nine, over, img, glyph, key, bar, portrait, square, pill, badge, divider, cost, chip, secondary, primary,
  train, medal, bottom, roomPanel, roomTag, section, run,
} from "../hud-kit/lib.mjs";
import { networkMap } from "../hud-fluxo/render.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-casa/.render";
const V2 = (name) => img(`docs/design/hud-v2/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const MINE = (name) => img(`docs/design/hud-casa/before/${name}_clean.webp`, "position:absolute;inset:0;width:1920px;height:1080px");
const inset = (body, extra = "") => nine("panel_inset", { cls: "col", extra: `gap:8px;flex:none;${extra}` }, body);
const line = (icon, color, text, cls = "f22") => `<div class="row" style="gap:10px;align-items:flex-start">${glyph(icon, 24, color, "margin-top:2px")}<span class="wrap ${cls}" style="flex:1;min-width:0">${text}</span></div>`;
const bodies = (list) => list.map(([x, y, w, h]) => `<div class="abs" data-hit="hero-body" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px"></div>`).join("");
const PORTRAIT = { bento: "bento", nick: "nick", iris: "iris", vespera: "vespera", lupa: "frog_recruit_01", brasa: "dog_recruit_01", sereno: "owl_recruit_01" };
const face = (hero, size, style = "") => square(`art/ui/portraits/${PORTRAIT[hero]}.png`, size, style);
// O estado novo nas cartas: a pílula do kit (status_pill), na cor do perigo, com o glifo da recuperação. Neutro de
// gênero, como os outros estados ("Em forma", "Ferimento leve"): os heróis não têm gênero nos dados.
const recovering = () => `<div class="pill">${img(KIT.status_pill.file, "position:absolute;inset:0;width:100%;height:100%")}` +
  `<div class="tint" style="background:var(--danger-fill);-webkit-mask-image:url(${BASE}/${KIT.status_pill.file})"></div>` +
  `${glyph("state_recovering", 22, "#fff6ee", "position:relative")}<span class="tx" style="color:#fff6ee">Caído</span></div>`;
// O véu das cartas de quem não pode sair: o mesmo da habilidade sem uso (riscas escuras), com o texto no tom cheio.
const veil = `<i style="position:absolute;inset:0;background:repeating-linear-gradient(135deg,rgba(6,7,8,.55) 0 10px,rgba(6,7,8,.42) 10px 20px);pointer-events:none"></i>`;
// O botão principal da Estação na saída nova (#123): IR AO MAPA, no lugar de PREPARAR EXPEDIÇÃO.
const TO_MAP = { label: "Ir ao mapa", icon: "route", keyLabel: "G / X" };

// ------------------------------------------------------------------ a barra do alto com os limites (#119)
// O topBar do kit, com a ficha dos limites antes dos materiais: "Heróis 6 de 8" e "Ajudantes 3 de 4" (o Alojamento e o
// Dormitório sobem os dois), com o ícone de cada um.
function topBar({ subtitle = "", heroes = "6 de 8", helpers = "3 de 4", full = false, food = ["8 / 12 suprimentos", "Abastecida · demanda 4", false] } = {}) {
  const res = (icon, label, value, sub, warn) =>
    nine("resource_chip", { cls: "row", extra: "min-width:220px;min-height:96px;gap:12px" },
      `${glyph(warn ? "alert" : icon, 40, warn ? "var(--danger)" : "var(--text)")}<div class="col" style="gap:1px"><span class="tx f20 up muted">${label}</span>` +
      `<span class="tx f26 semi ${warn ? "danger" : "amber"}">${value}</span><span class="tx f20 ${warn ? "danger" : "muted"}">${sub}</span></div>`);
  const limits = nine("resource_chip", { cls: "col", attrs: 'data-hit="limits"', extra: "min-height:96px;gap:2px;justify-content:center" },
    `<div class="row" style="gap:8px">${glyph("nav_characters", 26)}<span class="tx f22">Heróis</span><span class="tx f24 semi ${full ? "danger" : "amber"}">${heroes}</span></div>` +
    `<div class="row" style="gap:8px">${glyph("helpers", 26)}<span class="tx f22">Ajudantes</span><span class="tx f24 semi amber">${helpers}</span></div>`);
  const mats = nine("resource_chip", { cls: "row", extra: "min-height:96px;gap:14px" },
    [["lobby-seed.svg", "30"], ["lobby-scrap.svg", "9"], ["lobby-fragment.svg", "3"], ["res-bandages.svg", "2"]]
      .map(([i, n]) => `<div class="row" style="gap:6px">${glyph(i, 28)}<span class="tx f26 semi">${n}</span></div>`).join(""));
  return `<div class="abs" style="left:28px;top:14px">` +
    nine("room_plaque", { cls: "row", extra: "min-width:400px;min-height:96px;gap:16px" },
      `${glyph("station", 52)}<div class="col"><span class="tx f40 semi up">Estação Raiz</span>${subtitle ? `<span class="tx f24 muted">${subtitle}</span>` : ""}</div>`) + `</div>` +
    `<div class="abs row" style="right:28px;top:14px;gap:10px;align-items:stretch">${limits}${mats}` +
    res("lobby-food.svg", "Comida", food[0], food[1], food[2]) + res("lobby-water.svg", "Água", "6 em estoque", "Próxima volta: 4") + res("lobby-energy.svg", "Energia", "2 / 3 em uso", "1 livre") +
    `<div data-hit="options">` + nine("icon_button", { extra: "width:92px;height:100%;min-height:96px;display:flex;align-items:center;justify-content:center" }, glyph("lobby-settings.svg", 48)) + `</div></div>`;
}

// ------------------------------------------------------------------ 1. a Enfermaria (#121)
// O cômodo escolhido no corte: cantos âmbar e a etiqueta (como o Alojamento na Visão geral). Na câmera do cômodo, a
// Enfermaria de 12 m fica de x 466 a 1178; na Visão geral, de x 596 a 892 (as capturas de capture_infirmary.gd).
const roomMark = (x, y, w, h, icon, label) => `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px;height:${h}px">${nine("selected_slot", { extra: "position:absolute;inset:0" })}</div>` +
  `<div class="abs" style="left:${x + w / 2}px;top:calc(${y}px - 52px*var(--k));transform:translateX(-50%)">` + nine("room_tag", { cls: "row", extra: "min-width:200px;height:calc(52px*var(--k));justify-content:center;gap:8px" }, `${glyph(icon, 22, "var(--amber)")}<span class="tx f22 semi">${label}</span>`) + `</div>`;
const next = (body) => nine("panel_large", { repeat: "round", cls: "col", extra: "width:500px;gap:10px" },
  `<div class="row" style="gap:10px">${glyph("next_step", 28, "var(--amber)")}<span class="tx f22 semi amber kicker">Próximo passo</span></div>${body}`);
// A Visão geral com a Enfermaria no subsolo 2 e o aviso "Íris volta amanhã"; main: o botão principal (o IR AO MAPA da #123).
function overview({ main = TO_MAP, nextBody = null, mark = true, focus = false } = {}) {
  const body = nextBody || (`<div class="row" style="gap:14px">${face("iris", 64)}<div class="col" style="flex:1;min-width:0"><span class="tx f36 semi">Íris volta amanhã</span>` +
    `<span class="wrap f22">Sai da Enfermaria na próxima volta e pode entrar na equipe.</span></div></div>` +
    secondary("Ver a Enfermaria", { icon: "room_infirmary", hit: "next", height: 60, extra: "width:100%" }));
  const card = nine("panel_large", { repeat: "round", cls: "col", extra: "width:500px;gap:8px" },
    `<div class="row" style="gap:12px">${glyph("room_infirmary", 36, "var(--amber)")}<span class="tx f32 semi up">Enfermaria</span>${roomTag("Nível 1", "var(--good)")}</div>` +
    `<span class="wrap f22">Os leitos de quem caiu. Volta mais rápido daqui do que do Dormitório.</span>` + secondary("Gerenciar", { hit: "manage", height: 60, extra: "width:100%" }));
  // O Dia 5, o dia seguinte ao da volta (Dia 4: o relatório, o painel da Enfermaria e a Sala). Os dias de
  // data/recovery.json: 2 no leito, menos 1 do posto da Lupa; um dia é uma volta de expedição, e a noite não conta:
  // no Dia 4 e no Dia 5 falta uma volta, e a Íris volta amanhã. A Comida segue a conta de AHStationRules.forecast: 8, mais 4
  // da Cantina e da Dora, menos 4 que os civis comem e 4 da noite (8 → 4). A Forja de nível 1 acesa, com o Brasa e o
  // Otto (capture_infirmary.gd). Sem cômodo escolhido (a tela do IR AO MAPA), sem o cartão do cômodo.
  return MINE("station_day5") + topBar({ subtitle: "Dia 5 · Visão geral", food: ["4 / 12 suprimentos", "Abastecida · demanda 4", false] }) +
    (mark ? roomMark(596, 628, 296, 86, "room_infirmary", "Enfermaria") : "") +
    `<div class="abs col" style="left:28px;top:132px;gap:12px">${next(body)}</div>` +
    (mark ? `<div class="abs" style="left:28px;bottom:calc(14px + 72px*var(--k) + 14px)">${card}</div>` : "") +
    bottom({ active: 0, back: false, keysAt: 840, keys: [["Setas", "Cômodos"], ["E", "Abrir"], ["Esc", "Menu"], ["F2", "Ocultar"]], main }) +
    // O foco do teclado no botão principal (a tela do IR AO MAPA): a moldura de foco do kit em volta dele.
    (focus ? `<div class="abs" style="right:28px;bottom:14px;width:480px;height:calc(72px*var(--k))">${over("focus_frame")}</div>` : "");
}
// O painel da Enfermaria: os leitos (2 no nível 1, 4 no nível 2), cada um com quem está nele (a vida, o que tem e
// "Volta em N dias"), o curativo que tira um dia e quem cuida (o posto, #119).
function infirmary() {
  const bed = inset(`<div class="row" style="gap:14px;align-items:flex-start">${face("iris", 72)}<div class="col" style="flex:1;min-width:0;gap:4px">` +
    `<div class="row" style="gap:10px;justify-content:space-between"><span class="tx f30 semi">Íris</span><span class="tx f22 muted">Leito 1</span></div>` +
    `<span class="tx f22 muted">Sapo Química</span><div class="row" style="gap:12px;flex-wrap:wrap">${recovering()}<span class="tx f30 semi amber">Volta amanhã</span></div></div></div>` +
    `<div class="row" style="gap:10px"><span class="tx f20 muted up">Vida</span><span class="tx f22">1 / 23</span></div>${bar("100%", 22, 1 / 23, "var(--danger-fill)")}` +
    line("state_fallen", "var(--danger)", "Caiu na Rua das Vitrines, na luta do trecho 4.", "f22") +
    `<div class="row" style="gap:12px;justify-content:space-between;flex-wrap:wrap"><span class="tx f22">Com o curativo, sai hoje.</span>` +
    cost("res-bandages.svg", "Curativo · tem 2") + `</div>` +
    `<div data-hit="bandage">` + nine("train_button", { cls: "row", extra: "height:calc(56px*var(--k));gap:10px" },
      `${glyph("res-bandages.svg", 26, "var(--amber)")}<span class="tx f26 semi up">Usar curativo</span><span class="tx f22 muted">menos 1 dia</span>`) + `</div>`);
  const empty = inset(`<div class="row" style="gap:14px">${glyph("room_infirmary", 40, "var(--muted)")}<div class="col"><span class="tx f24 semi muted">Leito 2 · livre</span><span class="tx f20 muted">Quem cair na próxima expedição vem para cá.</span></div></div>`);
  // Os ajustes do Lucas (26/10): os leitos 3 e 4 estão no cômodo, quebrado e coberto, esperando a melhoria.
  const waiting = inset(`<div class="row" style="gap:14px">${glyph("lobby-scrap.svg", 40, "var(--muted)")}<div class="col" style="flex:1;min-width:0"><span class="tx f24 semi muted">Leitos 3 e 4 · esperam a melhoria</span><span class="wrap f20 muted">Um quebrado e um coberto com a lona. No nível 2, os quatro ficam em uso.</span></div></div>`);
  const carer = inset(`<div class="row" style="gap:14px">${face("lupa", 60)}<div class="col" style="flex:1;min-width:0"><span class="tx f26 semi">Lupa</span>` +
    `<span class="wrap f20 muted">Sapo Química · Química e Suporte</span></div>${chip("Trocar", { hit: "post" })}</div>` +
    line("job_infirmary", "var(--good)", "<b class=\"semi good\">Menos 1 dia</b> para quem está nos leitos. Sapo cuida melhor: mais 1 dia a menos a cada duas voltas.", "f20"));
  const body = `<span class="wrap f22">Leitos de cano e porta velha, no subsolo, embaixo do Dormitório. Quem cai na luta se recupera aqui.</span>` +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${roomTag("Leitos 1 de 2 em uso", "var(--amber)")}${roomTag("Sem a Enfermaria: 3 dias no Dormitório")}</div>` +
    section("Nos leitos", "room_infirmary") + bed + empty + waiting + section("Quem cuida · o posto", "job_infirmary") + carer;
  const footer = `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-scrap.svg", "6 sucatas · tem 9")}${cost("lobby-fragment.svg", "2 fragmentos · tem 3")}</div>` +
    train("Melhorar", "nível 2: 4 leitos", { hit: "upgrade", icon: "room_infirmary" });
  return MINE("station-infirmary") + topBar({ subtitle: "Enfermaria" }) + roomMark(466, 416, 712, 238, "room_infirmary", "Enfermaria") +
    roomPanel({ icon: "room_infirmary", title: "Enfermaria", tag: roomTag("Nível 1", "var(--good)"), body, footer }) + bottom({ active: 1, main: TO_MAP });
}

// ------------------------------------------------------------------ 2. o relatório da volta (#118, #119, #121)
// As cartas do relatório (hud-station.md) sobre a chegada: a Íris caiu e foi direto para a Enfermaria (o lugar dela na
// fila fica vazio, platform_empty), e a carta dela fica apagada, com o motivo e os dias.
const ARRIVAL_BODIES = [[428, 466, 104, 176], [662, 488, 90, 154], [1058, 472, 136, 170]];
const TEAM = [
  { hero: "bento", name: "Bento", cls: "Cão Protetor", hp: 30, max: 34, state: "active", exp: 4, kills: 6 },
  { hero: "nick", name: "Nick", cls: "Gato Batedor", hp: 9, max: 24, state: "wounded", exp: 4, kills: 5 },
  { hero: "iris", name: "Íris", cls: "Sapo Química", hp: 1, max: 23, state: "fallen", exp: 4, kills: 1 },
  { hero: "vespera", name: "Véspera", cls: "Coruja Atiradora", hp: 30, max: 30, state: "active", exp: 4, kills: 7 },
];
function reportCard(h, x, p) {
  const ratio = h.hp / h.max, fallen = h.state === "fallen";
  const color = ratio < 0.5 ? "var(--danger-fill)" : "var(--ally)";
  const large = p.k > 1;
  const life = large
    ? `<div class="row" style="gap:10px"><span class="tx f22 muted up">Vida</span><span class="tx f24">${h.hp} / ${h.max}</span>${bar(196, 20, ratio, color)}</div>`
    : `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f22 muted up">Vida</span><span class="tx f24">${h.hp} / ${h.max}</span></div>${bar(340, 26, ratio, color)}</div>`;
  // A linha de baixo: as expedições e os abates; caído, o motivo e os dias, no lugar da relíquia.
  const foot = fallen
    ? `<div class="row" style="gap:10px">${glyph("room_infirmary", 28, "var(--amber)")}<span class="tx f22 semi amber">Enfermaria · volta amanhã</span></div>`
    : `<div class="row" style="gap:12px">${glyph("relic_empty", 28, "var(--muted)")}<span class="tx f22">Sem relíquia</span></div>`;
  return `<div class="abs" data-hit="card" style="left:${x}px;top:calc(678px - 4px*(var(--k) - 1)/0.3);width:380px">` +
    nine("hero_card", { repeat: "round", cls: "col", extra: `width:380px;gap:${large ? 3 : 8}px;padding:0` },
      `<div class="row" style="gap:16px;align-items:flex-start">${portrait(h.hero, 92)}<div class="col" style="gap:4px;min-width:0">` +
      `<span class="tx f36 semi up">${h.name}</span><span class="tx f22 muted">${h.cls}</span>${fallen ? recovering() : pill(h.state, p.cb)}</div></div>` +
      life + `<div class="row" style="gap:10px">${glyph("expeditions", 28)}<span class="tx f20 muted">Expedições</span><span class="tx f24">${h.exp}</span>` +
      `<i style="width:2px;align-self:stretch;background:#0a0b0c;border-right:1px solid #44484e;margin:0 8px"></i>${glyph("kills", 28)}<span class="tx f20 muted">Abates</span><span class="tx f24">${h.kills}</span></div>` + foot) +
    (fallen ? veil : "") + `</div>`;
}
function resultChip(icon, l1, l2, color) {
  return nine("result_chip", { cls: "row", attrs: 'data-hit="chip"', extra: "gap:12px;padding:0 6px;min-width:232px;min-height:88px;height:auto" },
    `${glyph(icon, 44, color)}<div class="col"><span class="tx f24" style="color:${color}">${l1}</span><span class="tx f24" style="color:${color}">${l2}</span></div>`);
}
const tile = (icon, value, label) => `<div class="col" style="align-items:center;gap:4px">` +
  nine("resource_tile", { extra: "width:104px;height:84px;display:flex;align-items:center;justify-content:center" }, glyph(icon, 46)) +
  `<span class="tx f32 semi amber" style="line-height:1">${value}</span><span class="tx f20" style="line-height:1.1">${label}</span></div>`;
function report(p, details = false) {
  const band = nine("report_band", { repeat: "round", cls: "row", extra: "position:absolute;left:36px;top:24px;width:1848px;min-height:216px;align-items:stretch" },
    `<div class="col" style="flex:none;min-width:560px;gap:6px;justify-content:center;padding-left:6px">` +
    `<div class="row" style="gap:12px">${glyph("station", 30)}<span class="tx f22 up muted" style="letter-spacing:.08em">Estação Raiz · Relatório da expedição</span></div>` +
    `<span class="tx f76 semi up">Rua das Vitrines</span><div class="row" style="gap:12px">${glyph("state_active", 34, "var(--good)")}<span class="tx f32 good">Expedição concluída</span></div></div>` +
    img(KIT.band_divider.file, "width:12px;height:176px;align-self:center;margin:0 20px") +
    `<div class="col" style="flex:1;min-width:0;gap:16px;justify-content:center"><div class="row" style="gap:14px;flex-wrap:wrap">` +
    resultChip("guardian_defeated", "Guardião", "derrotado", "var(--text)") + resultChip("state_fallen", "Íris caiu", "foi para a Enfermaria", "var(--danger)") +
    resultChip("train_arrival", "Chegou alguém", "no trem", "var(--amber)") + `</div>` +
    `<div class="row" style="gap:14px">${glyph("next_step", 32)}<span class="wrap f24">Os postos renderam: veja os detalhes.</span></div></div>` +
    img(KIT.band_divider.file, "width:12px;height:176px;align-self:center;margin:0 20px") +
    `<div class="col" style="flex:none;gap:6px;justify-content:center"><span class="tx f24 up muted" style="letter-spacing:.06em">Recursos recuperados</span>` +
    `<div class="row" style="gap:20px;align-items:flex-start">${tile("lobby-seed.svg", "+16", "Sementes")}${tile("lobby-scrap.svg", "+3", "Sucata")}${tile("lobby-fragment.svg", "+1", "Fragmento")}</div></div>`);
  let lower;
  if (details) {
    const column = (title, body, w) => `<div class="col" style="width:${w}px;flex:none;gap:8px"><span class="tx f24 up amber" style="letter-spacing:.06em">${title}</span>${body}</div>`;
    const dv = img(KIT.band_divider.file, "width:12px;height:176px;margin:0 18px;flex:none;align-self:center");
    // O rendimento de cada posto (#119): quem ficou, onde e o que rendeu; o ajudante soma com o herói.
    const post = (icon, who, where, what) => `<div class="row" style="gap:10px;align-items:flex-start">${glyph(icon, 26, "var(--amber)", "margin-top:2px")}<span class="wrap f22" style="flex:1;min-width:0"><b class="semi">${who} · ${where}:</b> <span class="good">${what}</span></span></div>`;
    lower = `<div class="abs" data-hit="details" style="left:96px;top:668px;width:1728px">` +
      nine("report_band", { repeat: "round", cls: "row", extra: "width:100%;min-height:256px;align-items:flex-start" },
        column("Quem caiu", line("state_fallen", "var(--danger)", "Íris, no trecho 4. Na Enfermaria, com a Lupa no posto: volta amanhã.", "f22"), 360) + dv +
        column("O que chegou", line("lobby-seed.svg", "var(--text)", "+16 sementes") + line("lobby-scrap.svg", "var(--text)", "+3 sucatas") + line("lobby-fragment.svg", "var(--text)", "+1 fragmento"), 220) + dv +
        column("Os postos renderam", post("job_infirmary", "Lupa", "Enfermaria", "a Íris volta 1 dia antes") +
          post("job_forge", "Brasa e Otto", "Forja", "−2 sucatas na próxima obra") + post("job_research", "Cora", "Pesquisa", "+1 fragmento") +
          post("job_canteen", "Dora", "Cantina", "+2 suprimentos"), 540) + dv +
        column("Agora dá para", line("train_arrival", "var(--amber)", "Ver quem chegou na plataforma") + line("job_forge", "var(--amber)", "Melhorar a Forja (4 sucatas com o desconto)"), 380)) + `</div>`;
  } else {
    lower = TEAM.map((h, i) => reportCard(h, [146, 562, 978, 1394][i], p)).join("");
  }
  const toggle = `<div class="abs row" style="left:0;right:0;bottom:14px;justify-content:center;gap:24px;padding-left:274px">` +
    `<div style="min-width:480px">${primary("Entrar no abrigo", { icon: "station", keyLabel: "E / A", hit: "primary" })}</div>` +
    `<div data-hit="details-toggle">` + nine("secondary_button", { cls: "row", extra: "height:calc(64px*var(--k));gap:12px;padding:0 4px" },
      `<span class="tx f24 up">${details ? "Ver a equipe" : "Ver detalhes"}</span>${key("V / LB")}`) + `</div></div>`;
  return MINE("platform_empty") + bodies(ARRIVAL_BODIES) + band + lower + toggle;
}

// ------------------------------------------------------------------ 3. a Sala dos Personagens (#118, #119)
// A Sala de hoje (hud-station.md) com tudo o que ela tem, mais o que é novo: os seis heróis nas abas (a Íris apagada, com
// o glifo da recuperação), os limites embaixo das abas, a aba "Postos da Estação" ao lado de Habilidades na coluna da
// esquerda e, no painel PERSONAGEM, o estado novo e a seção Posto (o painel rola, como hoje no Maior).
const ROSTER = [["bento", "Bento"], ["nick", "Nick"], ["iris", "Íris"], ["vespera", "Véspera"], ["lupa", "Lupa"], ["brasa", "Brasa"]];
const SAPO = [["sapo_carga_voltaica", "Carga Voltaica"], ["sapo_coquetel_corrosivo", "Coquetel Corrosivo"], ["sapo_ampola_reparo_vivo", "Ampola de Reparo Vivo"], ["sapo_antidoto_campo", "Antídoto de Campo"]];
function leftColumn(selected, view) {
  const tabs = ROSTER.map(([h, n]) => `<div class="col" data-hit="hero-tab" style="width:86px;height:calc(96px + 28px*var(--k));position:relative;align-items:center;flex:none">` +
    `<div style="position:absolute;left:5px;top:5px;right:5px;height:84px;overflow:hidden;background:#192026">${img(`art/ui/portraits/${PORTRAIT[h]}.png`, `width:100%;height:100%;object-fit:cover;object-position:50% 15%;${h === "iris" ? "filter:grayscale(.85) brightness(.55)" : ""}`)}` +
    (h === "iris" ? `<div class="row" style="position:absolute;right:2px;top:2px;width:30px;height:30px;justify-content:center;background:var(--danger-fill)">${glyph("state_recovering", 22, "#fff6ee")}</div>` : "") + `</div>` +
    `<div class="row" style="position:absolute;left:5px;right:5px;bottom:5px;top:90px;background:#101214;justify-content:center"><span class="tx f20 ${h === selected ? "amber" : h === "iris" ? "muted" : ""}">${n}</span></div>` +
    nine("hero_tab", { extra: "position:absolute;inset:0" }) + (h === selected ? over("hero_tab_selected") : "") + `</div>`).join("");
  const limits = `<div class="row" style="gap:10px;flex-wrap:wrap;flex:none">${cost("nav_characters", "Heróis 6 de 8")}${cost("helpers", "Ajudantes 3 de 4")}</div>`;
  // As duas vistas da coluna: Habilidades (a de hoje) e Postos da Estação (nova), em chips de opção; a escolhida em âmbar.
  const switcher = `<div class="row" style="gap:8px;flex:none">${chip("Habilidades", { icon: "nav_research", selected: view === "abilities", hit: "view" })}` +
    `${chip("Postos da Estação", { icon: "nav_facilities", selected: view === "posts", hit: "view" })}</div>`;
  let body;
  if (view === "abilities") {
    const rows = SAPO.map(([id, name], i) => `<div data-hit="ability" style="position:relative">` + nine("list_row", { cls: "row", extra: "min-height:60px;gap:14px" },
      `${img(`art/combat/icons/${id}.webp`, "width:44px;height:44px;border:1px solid #3a3e44;flex:none")}<span class="tx f28">${name}</span>`) + (i === 0 ? over("list_row_selected") : "") + `</div>`).join("");
    body = `<div class="col" style="gap:10px">${rows}</div>` + nine("panel_inset", { cls: "col", extra: "gap:6px;flex:none" },
      `<span class="tx f32 semi">Carga Voltaica</span><span class="tx f28 semi amber">Dano 4–7</span>` +
      `<div class="row" style="gap:24px;flex-wrap:wrap"><span class="tx f22 muted">Origem: posições 3 · 4</span><span class="tx f22 muted">Alvo: posições 2 · 3 · 4</span></div>` +
      `<span class="wrap f24">Remove 1 Bloqueio antes do dano; +25% de dano em máquinas.</span><span class="tx f22 danger">Inimigo</span>`);
  } else {
    // Os postos de hoje, um por linha: quem está onde (heróis e ajudantes), o que rende, o que fica livre.
    const row = (icon, room, who, yieldText, free = false) => `<div data-hit="post-row" style="min-width:0">` + nine("list_row", { cls: "row", extra: "gap:12px;min-height:56px;min-width:0" },
      `${glyph(icon, 30, free ? "var(--muted)" : "var(--amber)")}<div class="col" style="flex:1;min-width:0"><span class="wrap f24 semi ${free ? "muted" : ""}">${room} · <span class="${free ? "muted" : "amber"}">${who}</span></span><span class="wrap f20 ${free ? "muted" : "good"}">${yieldText}</span></div>`) + `</div>`;
    body = `<span class="wrap f20 muted">O Alojamento abre mais lugares para heróis; o Dormitório, para ajudantes. Quem está em recuperação conta.</span>` +
      row("job_infirmary", "Enfermaria", "Lupa", "Menos 1 dia nos leitos") + row("job_forge", "Forja", "Brasa · Otto", "−2 sucatas na próxima obra") +
      row("job_research", "Pesquisa", "Cora", "+1 fragmento por volta") + row("job_canteen", "Cantina", "Dora", "+2 suprimentos por volta") +
      row("job_dormitory", "Dormitório", "livre", "Quem está em recuperação melhora mais rápido", true);
  }
  return `<div class="abs" style="left:28px;top:132px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:600px;height:calc(1080px - 132px - 14px - 72px*var(--k) - 10px - 64px - 14px);gap:12px" },
    `<div class="row" style="gap:6px;flex:none">${tabs}</div>${divider()}${limits}${switcher}` +
    `<div class="col" data-scroll="1" style="gap:12px;overflow:hidden;flex:1;min-height:0;padding-right:14px">${body}</div>`) + `</div>`;
}
// Os dois heróis da Sala nesta entrega: a Íris (fundadora, em recuperação) e a Lupa (recruta, no posto da Enfermaria).
// Os números são os de data/: o sapo tem 23 de vida e 4 de velocidade (Ágil +1, Lento −1); os níveis de hero-levels.json.
const SHEET = {
  iris: { name: "Íris", kicker: "Sobrevivente da Estação", lvl: 3, xp: [104, 120], hp: [1, 23], speed: 5, instinct: 40, exp: 4, kills: 1,
    strong: [["agile", "Ágil", "+1 Velocidade"]], weak: [["machine_fear", "Temor das máquinas", "+3 Instinto ao levar dano de máquina"]] },
  lupa: { name: "Lupa", kicker: "Chegou no trem · Dia 2", lvl: 1, xp: [12, 60], hp: [23, 23], speed: 3, instinct: 0, exp: 0, kills: 0,
    strong: [["hopeful", "Esperançoso", "+5 p.p. de Superação"]], weak: [["sluggish", "Lento", "−1 Velocidade"]] },
};
function characterPanel(hero) {
  const fallen = hero === "iris", h = SHEET[hero];
  const head = `<div class="row" style="justify-content:space-between"><span class="tx f40 semi up">Personagem</span>` +
    `<div data-hit="close">${nine("icon_button", { pad: [6, 6, 6, 6], extra: "width:56px;height:calc(56px*var(--k));display:flex;align-items:center;justify-content:center" }, `<span class="tx f28 semi">X</span>`)}</div></div>`;
  const ident = `<span class="tx f22 up amber kicker">${h.kicker}</span>` +
    `<div class="row" style="gap:16px"><span class="tx f52 semi">${h.name}</span>${medal(h.lvl, 64)}` +
    `<div class="col" style="gap:4px"><span class="tx f20 up muted">Nível ${h.lvl} · XP ${h.xp[0]} / ${h.xp[1]}</span>${bar(170, 22, h.xp[0] / h.xp[1], "var(--xp)")}</div></div>` +
    `<span class="tx f26 amber">Sapo Química · Química e Suporte</span>`;
  // Em recuperação, TREINAR sai (não treina no leito) e o lugar dele mostra os dias; com XP de menos, TREINAR apagado.
  const state = fallen
    ? `<div class="row" style="gap:14px;flex-wrap:wrap">${recovering()}<span class="tx f24 semi amber">Volta amanhã</span></div>` +
      line("state_fallen", "var(--danger)", "Caiu na Rua das Vitrines. Está num leito da Enfermaria e não pode sair em expedição.", "f22")
    : `<div class="row" style="gap:14px">${pill("active", false)}<div data-hit="train" style="opacity:.55;filter:saturate(.2)">` +
      nine("train_button", { cls: "row", extra: "height:calc(56px*var(--k));gap:10px" }, `${glyph("train", 26, "var(--muted)")}<span class="tx f26 semi up muted">Treinar</span><span class="tx f22 muted">faltam 48 XP</span>`) + `</div></div>`;
  const stats = `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f26 up">Vida</span><span class="tx f26">${h.hp[0]} / ${h.hp[1]}</span></div>${bar(520, 26, h.hp[0] / h.hp[1], fallen ? "var(--danger-fill)" : "var(--ally)")}</div>` +
    `<div class="col" style="gap:4px"><div class="row" style="gap:30px"><span class="tx f26 up">Velocidade ${h.speed}</span><span class="tx f26 up">Instinto ${h.instinct} / 200</span></div>${bar(520, 22, h.instinct / 200, "var(--instinct)")}</div>`;
  // O Posto: um por herói, nos cômodos recuperados; o rendimento muda com a espécie e os traços (data/ na integração).
  const posts = [["job_research", "Pesquisa"], ["job_forge", "Forja"], ["job_canteen", "Cantina"], ["job_dormitory", "Dormitório"], ["job_infirmary", "Enfermaria"]];
  const post = fallen
    ? section("Posto", "job_infirmary") + inset(`<div class="row" style="gap:12px">${glyph("state_recovering", 30, "var(--muted)")}<span class="wrap f22 muted">Sem posto enquanto se recupera. Volta a escolher quando sair da Enfermaria.</span></div>`)
    : section("Posto", "job_infirmary") + `<div class="row" style="gap:8px;flex-wrap:wrap">${chip("Nenhum", { hit: "post" })}${posts.map(([i, n]) => chip(n, { icon: i, selected: n === "Enfermaria", hit: "post" })).join("")}</div>` +
      inset(`<div class="row" style="gap:10px">${badge("+", "var(--good)")}<span class="tx f22 semi up good">Na Enfermaria</span></div>` +
        `<span class="wrap f22">Menos 1 dia para quem está nos leitos. Sapo cuida melhor: mais 1 dia a menos a cada duas voltas.</span>`) +
      line("expeditions", "var(--amber)", "Se entrar na equipe, sai do posto: a Preparação avisa.", "f20 muted");
  const relic = `<div class="row" style="gap:12px">${glyph("relic_empty", 34, "var(--muted)")}<div class="col"><span class="tx f26">Relíquia: Sem relíquia</span>` +
    `<span class="tx f22 muted">Equipe uma relíquia ao preparar a expedição.</span></div></div>` +
    `<div class="row" style="gap:12px">${glyph("expeditions", 26)}<span class="tx f22">Expedições ${h.exp}</span>${glyph("kills", 26, "var(--text)", "margin-left:16px")}<span class="tx f22">Abates ${h.kills}</span></div>`;
  const col = (sign, color, cls, title, list, good) => `<div class="col" style="gap:8px;width:248px"><div class="row" style="gap:8px">${badge(sign, color)}<span class="tx f22 up ${cls}">${title}</span></div>` +
    list.map(([i, n, e]) => trait(i, n, e, good)).join("") + `</div>`;
  const traits = `<span class="tx f30 semi up">Traços</span><div class="row" style="gap:18px;align-items:flex-start">` +
    col("+", "var(--good)", "good", "Pontos fortes", h.strong, true) + `<i style="width:2px;align-self:stretch;background:#0a0b0c;border-right:1px solid #44484e"></i>` +
    col("−", "var(--danger-fill)", "danger", "Pontos fracos", h.weak, false) + `</div>`;
  return `<div class="abs" style="left:1296px;top:132px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:596px;height:calc(1080px - 132px - 14px - 72px*var(--k) - 14px)" },
    `${head}${divider()}<div class="col" data-scroll="1" style="gap:10px;overflow:hidden;flex:1;position:relative;padding-right:14px">${ident}${state}${stats}${divider()}${post}${divider()}${relic}${divider()}${traits}</div>`) + `</div>`;
}
function characters(hero) {
  const fallen = hero === "iris";
  // O herói de corpo inteiro (a camada da interface, como na Sala de hoje); em recuperação, apagado e curvado na
  // sombra: a pose da Enfermaria fica no cômodo.
  const file = fallen ? "art/combat/heroes/iris/idle.webp" : "art/combat/recruits/frog_recruit_01_idle.webp";
  const art = `<div class="abs" style="left:640px;top:120px;width:640px;height:800px;background:radial-gradient(ellipse 50% 46% at 50% 55%, rgba(6,7,8,.62), rgba(6,7,8,0))"></div>` +
    `<div class="abs" style="left:780px;top:858px;width:360px;height:40px;border-radius:50%;background:radial-gradient(rgba(0,0,0,.7),rgba(0,0,0,0) 70%)"></div>` +
    img(file, `position:absolute;left:calc(960px - 260px);top:300px;width:520px;height:580px;object-fit:contain;object-position:50% 100%;${fallen ? "filter:grayscale(.75) brightness(.5)" : ""}`);
  return V2("station-characters") + art + topBar({ subtitle: "Sala dos Personagens" }) + leftColumn(hero, fallen ? "abilities" : "posts") + characterPanel(hero) +
    bottom({ active: 2, main: TO_MAP });
}

// ------------------------------------------------------------------ 4. "Quem trabalha aqui" no painel do cômodo (#119)
function forgeWorkers() {
  const worker = (hero, name, kind, yieldText, plus) => inset(`<div class="row" style="gap:12px">${hero === "otto" ? square("art/civilians/civil_otto.webp", 60) : face(hero, 60)}` +
    `<div class="col" style="flex:1;min-width:0"><span class="tx f26 semi">${name}</span><span class="tx f20 muted">${kind}</span></div>${chip("Tirar", { hit: "remove" })}</div>` +
    `<div class="row" style="gap:10px;align-items:flex-start">${badge("+", "var(--good)")}<span class="wrap f22" style="flex:1">${yieldText}</span></div>` + (plus ? line("job_forge", "var(--amber)", plus, "f20 muted") : ""));
  const body = `<span class="wrap f22">Fabrica relíquias e conserta o que a Estação precisa. Gasta 1 de energia.</span>` +
    section("Quem trabalha aqui", "job_forge") +
    worker("brasa", "Brasa", "Herói · Cão Protetor", "−1 sucata na próxima obra ou relíquia.", "Cão rende mais na Forja: o desconto dobra a cada duas voltas.") +
    worker("otto", "Otto", "Ajudante · Castor, técnico", "−1 sucata nas obras (o efeito dele, como hoje). Herói e ajudante somam.") +
    `<div data-hit="add">` + nine("secondary_button", { cls: "row", extra: "min-height:calc(60px*var(--k));gap:10px;justify-content:center" }, `${glyph("job_forge", 26, "var(--amber)")}<span class="tx f24 semi up">Pôr alguém</span><span class="tx f20 muted">1 lugar livre</span>`) + `</div>` +
    divider() + section("Na próxima volta") + `<div class="row" style="gap:10px;justify-content:space-between"><span class="wrap f22" style="flex:1;min-width:0">Próxima obra (Forja, nível 2, e 2 fragmentos)</span>${cost("lobby-scrap.svg", "6 → 4 sucatas")}</div>` +
    `<div class="row" style="gap:10px;justify-content:space-between"><span class="tx f22">Relíquia</span>${cost("lobby-scrap.svg", "3 → 2 sucatas")}</div>`;
  return MINE("station-forge-workers") + topBar({ subtitle: "Forja" }) + roomPanel({ icon: "room_forge", title: "Forja", tag: roomTag("Nível 1", "var(--good)"), body }) + bottom({ active: 1, main: TO_MAP });
}

// ------------------------------------------------------------------ 5. o popup de fim de luta com "Íris caiu" (#118)
// O popup do lote 5 (hud-ajustes.md), sobre a luta de verdade em que a Íris caiu (capture.gd): a linha em perigo com o
// glifo, logo abaixo das estrelas.
const FIGHT = JSON.parse(fs.readFileSync("docs/design/hud-casa/before/fight_fallen.json", "utf8"));
function fightFallen(p) {
  // No Último Fôlego, quem caiu fica na arena: a Íris também tem a barra, com "Caído" no lugar da vida.
  const up = FIGHT.units;
  const xs = up.map((u) => u.feet[0]).sort((a, b) => a - b);
  const w = Math.min(200, Math.floor(Math.min(...xs.slice(1).map((x, i) => x - xs[i])) - 12));
  const teamBar = (u) => {
    const h = p.k > 1 ? 46 : 44, left = p.cb ? 30 : 8;
    return `<div class="abs" style="left:${Math.round(u.feet[0] - w / 2)}px;top:${Math.round(u.feet[1]) + 4}px;width:${w}px;height:${h}px">` +
      nine("main_bar", { pad: p.k > 1 ? [13, 8, 0, left] : [15, 8, 2, left], cls: "col", extra: `width:${w}px;height:${h}px` },
        `<div style="position:absolute;left:0;right:0;top:-10px;height:10px"><div style="height:100%;background:var(--ally);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%;width:${(u.hp / u.max_hp) * 100}%"></div></div>` +
        `<span class="tx f24 semi ${u.hp <= 0 ? "muted" : ""}" style="text-align:center;line-height:1.05">${u.hp <= 0 ? "Caído" : `${u.hp}/${u.max_hp}`}</span>`) +
      (p.cb ? img(KIT.ally_mark.file, `position:absolute;left:0;top:${-12 * h / 44}px;width:${28 * h / 44}px;height:${56 * h / 44}px`) : "") + `</div>`;
  };
  const stars = `<div class="row" style="gap:4px">${[0, 1, 2].map((i) => glyph(i < FIGHT.rewards.stars ? "star" : "star_empty", 28, i < FIGHT.rewards.stars ? "var(--amber)" : "var(--muted)")).join("")}</div>`;
  const fallen = `<div class="row" style="gap:10px;justify-content:center">${glyph("state_fallen", 30, "var(--danger)")}<span class="tx f30 semi danger">Íris caiu</span></div>` +
    `<span class="wrap f22" style="text-align:center">Volta à Estação com a equipe e se recupera na Enfermaria.</span>`;
  const xp = `<span class="tx f22 semi" style="color:var(--xp)">XP: ${[...FIGHT.units].sort((a, b) => a.feet[0] - b.feet[0]).map((u) => `${u.name} +${u.xp_gained}`).join(" · ")}</span>`;
  const foot = `<div class="col" style="gap:6px;align-items:center;width:100%"><div style="position:relative;width:320px;height:12px">${nine("slider_track", { extra: "position:absolute;inset:0" })}` +
    `<div class="fill" style="left:4px;top:3px;height:6px;width:calc((100% - 8px) * 0.62);background:var(--amber);-webkit-mask-image:url(${BASE}/${KIT.bar_fill.file});-webkit-mask-size:100% 100%"></div></div>` +
    `<span class="tx f20 muted">Fecha sozinho · qualquer tecla fecha antes</span></div>`;
  const pop = `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:40px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:640px;gap:8px;align-items:center" },
    `<span class="tx f40 semi up">Batalha finalizada</span><div class="row" style="gap:14px;justify-content:center"><span class="tx f26 semi up amber">Vitória</span>${stars}</div>${divider()}` +
    `${fallen}<span class="tx f24 muted">Nenhum recurso nesta luta</span>${xp}${divider()}${foot}`) + `</div>`;
  return MINE("fight_fallen") + bodies(up.map((u) => u.body.map(Math.round))) + up.map(teamBar).join("") + pop;
}

// ------------------------------------------------------------------ 6. o recrutamento pelo trem (#122)
// Quem chegou desce do trem e espera na plataforma (platform_train_recruit, com o trem à esquerda): a carta com a classe, os traços, de onde veio e o que pede;
// ACEITAR e RECUSAR. Com a casa cheia, ACEITAR fica travado com o motivo; sem ninguém, o aviso da volta vazia.
const RECRUIT_BODY = [[420, 476, 100, 170]];
const trait = (icon, name, effect, good) => `<div class="row" style="gap:12px;align-items:center">` +
  nine("trait_tile", { extra: "width:72px;height:72px;flex:none;display:flex;align-items:center;justify-content:center" }, img(`art/ui/kit/station/icons/trait_${icon}.webp`, "width:58px;height:58px")) +
  `<div class="col" style="gap:2px;min-width:0;flex:1"><span class="wrap f24 semi ${good ? "good" : "danger"}">${name}</span><span class="wrap f20">${effect}</span></div></div>`;
function recruit({ full = false } = {}) {
  const body = `<div class="row" style="gap:16px;align-items:flex-start">${face("sereno", 116)}` +
    `<div class="col" style="gap:4px;flex:1;min-width:0"><span class="tx f20 semi up amber kicker">Chegou alguém no trem</span><span class="tx f40 semi">Sereno</span>` +
    `<span class="tx f24 amber">Coruja Atiradora · recruta</span><span class="wrap f22 muted">Vivia no alto da torre de rádio da Ponte. Viu a luz da Estação acesa à noite.</span></div></div>` +
    `<div class="row" style="gap:14px;align-items:flex-start"><div class="col" style="gap:8px;flex:1;min-width:0"><div class="row" style="gap:8px">${badge("+", "var(--good)")}<span class="tx f22 up good">Ponto forte</span></div>` +
    trait("brave", "Corajoso", "+5 p.p. de Superação", true) + `</div><div class="col" style="gap:8px;flex:1;min-width:0"><div class="row" style="gap:8px">${badge("−", "var(--danger-fill)")}<span class="tx f22 up danger">Ponto fraco</span></div>` +
    trait("sluggish", "Lento", "−1 de Velocidade no grupo", false) + `</div></div>` +
    inset(`<div class="row" style="gap:10px">${glyph("plan", 24, "var(--amber)")}<span class="tx f22 semi up amber">O que pede</span></div>` +
      `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("lobby-seed.svg", "10 sementes · tem 30")}${cost("lobby-food.svg", "ou 2 suprimentos · tem 8")}</div>`) +
    line("nav_characters", full ? "var(--danger)" : "var(--text)", full ? "<b class=\"semi danger\">Heróis 8 de 8: a casa está cheia.</b> Para aceitar, abra lugar: melhore o Alojamento (10 lugares) ou dispense alguém." : "Heróis 6 de 8: cabe.", "f22") +
    line("train", "var(--muted)", "Se ninguém decidir até a próxima expedição, vai embora no trem. Recusado, não volta.", "f20 muted");
  const footer = (full
    ? primary("Aceitar Sereno", { icon: "recruit", keyLabel: "E / A", hit: "accept", height: 64, locked: true, reason: "Casa cheia: Heróis 8 de 8" })
    : primary("Aceitar Sereno", { icon: "recruit", keyLabel: "E / A", hit: "accept", height: 64, size: "f26" })) +
    secondary("Recusar", { hit: "refuse", height: 60, extra: "width:100%" });
  return MINE("platform_train_recruit") + bodies(RECRUIT_BODY) + topBar({ subtitle: "Plataforma 1", heroes: full ? "8 de 8" : "6 de 8", full }) +
    roomPanel({ icon: "train_arrival", title: "Chegou alguém", body, footer }) +
    bottom({ active: 0, main: { label: "Ir ao mapa", icon: "route", keyLabel: "G / X", locked: true, reason: "Decida quem está na plataforma." }, keysAt: 930 });
}
function nobody() {
  const body = inset(`<div class="row" style="gap:14px">${glyph("train", 48, "var(--muted)")}<div class="col" style="flex:1;min-width:0"><span class="tx f30 semi">O trem voltou vazio</span>` +
    `<span class="wrap f22">Ninguém desceu desta vez.</span></div></div>`) +
    line("next_step", "var(--amber)", "A cada volta sem ninguém, a chance de chegar alguém sobe: 40% nesta, 55% na próxima.", "f22") +
    line("nav_characters", "var(--text)", "Heróis 6 de 8 · Ajudantes 3 de 4: há lugar.", "f22");
  return MINE("platform_train") + topBar({ subtitle: "Plataforma 1" }) +
    roomPanel({ icon: "train_arrival", title: "Plataforma 1", body, footer: secondary("Fechar", { keyLabel: "Esc / B", hit: "close-main", height: 60, extra: "width:100%" }) }) + bottom({ active: 0, main: TO_MAP, keysAt: 930 });
}

// ------------------------------------------------------------------ 7. a preparação: Estação → Mapa → plataforma (#123)
// 7a. A Estação: o botão principal vira IR AO MAPA (o mapa abre o Mapa da Rede).
const goMap = () => overview({ focus: true, mark: false, nextBody: `<span class="tx f36 semi">Escolher o lugar</span><span class="wrap f22">Primeiro o lugar e a missão, no Mapa da Rede; a equipe depois, na plataforma.</span>` +
  `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("nav_characters", "5 prontos · 1 caído")}</div>` });
// 7b. O Mapa: o lugar escolhido e PREPARAR NESTE LUGAR, no pé do painel do lugar.
// A plaqueta do mapa dizia "Equipe: 4 vivos": com ninguém morrendo (#118), conta quem está pronto.
const mapPrepare = () => networkMap({ selected: "bridge", panel: { footer: primary("Preparar neste lugar", { icon: "expeditions", keyLabel: "G / X", hit: "prepare", height: 64, size: "f26" }) } })
  .replace("Equipe: 4 vivos", "Equipe: 5 prontos · 1 caído");
// 7c. A plataforma: a equipe de pé (platform_team: Bento, Nick, Brasa e Véspera), uma carta embaixo de cada um, a faixa
// do lugar e do radar no alto, o Foco e a Comida na faixa, e quem fica na Estação à direita.
const PLATFORM_BODIES = [[428, 466, 104, 176], [662, 488, 90, 154], [862, 474, 110, 172], [1058, 472, 136, 170]];
const PREP = [
  { hero: "bento", name: "Bento", cls: "Tanque e Proteção", hp: 34, max: 34, pos: 1 },
  { hero: "nick", name: "Nick", cls: "Batedor e Mobilidade", hp: 17, max: 24, pos: 2, state: "light_wound" },
  { hero: "brasa", name: "Brasa", cls: "Tanque e Proteção", hp: 34, max: 34, pos: 3, post: "Forja" },
  { hero: "vespera", name: "Véspera", cls: "Atiradora e Controle", hp: 30, max: 30, pos: 4 },
];
function prepCard(h, x, p) {
  const large = p.k > 1;
  return `<div class="abs" data-hit="card" style="left:${x}px;top:calc(678px - 4px*(var(--k) - 1)/0.3);width:380px">` +
    (h.post ? `<div data-hit="card-tab" style="position:absolute;left:28px;top:calc(-34px*var(--k) + 12px*(var(--k) - 1)/0.3);width:300px;height:calc(40px*var(--k));z-index:2">` +
      nine("card_tab", { cls: "row", extra: "width:100%;height:100%;gap:8px" }, `${glyph("job_forge", 22, "var(--amber)")}<span class="tx f22 amber">Sai do posto · ${h.post}</span>`) + `</div>` : "") +
    nine("hero_card", { repeat: "round", cls: "col", extra: `width:380px;gap:${large ? 3 : 8}px;padding:0` },
      `<div class="row" style="gap:16px;align-items:flex-start"><div style="position:relative;flex:none">${face(h.hero, 92)}<div data-avoid="1" style="position:absolute;left:-14px;top:-14px">${medal(h.pos, 44)}</div></div>` +
      `<div class="col" style="gap:4px;min-width:0;flex:1"><span class="tx f36 semi up">${h.name}</span><span class="tx f22 muted">${h.cls}</span>${pill(h.state || "active", p.cb)}</div></div>` +
      `<div class="row" style="gap:10px"><span class="tx f22 muted up">Vida</span><span class="tx f24">${h.hp} / ${h.max}</span>${bar(large ? 170 : 200, 20, h.hp / h.max, "var(--ally)")}</div>` +
      `<div class="row" style="gap:8px">${chip("Trocar", { hit: "swap" })}${chip(h.pos === 1 ? "Frente" : h.pos === 4 ? "Fundo" : "Meio", { hit: "order", icon: "formation_swap" })}</div>`) + `</div>`;
}
function platform(p, { confirm = false } = {}) {
  const radar = (marker, label, value) => `<div class="row" style="gap:10px">${img(`art/ui/map/network/${marker}.webp`, "width:40px;height:40px;flex:none")}<div class="col"><span class="tx f20 up muted">${label}</span><span class="tx f22">${value}</span></div></div>`;
  const band = nine("report_band", { repeat: "round", cls: "row", extra: "position:absolute;left:36px;top:24px;width:1848px;min-height:200px;align-items:stretch" },
    `<div class="col" style="flex:none;min-width:470px;gap:6px;justify-content:center;padding-left:6px">` +
    `<div class="row" style="gap:12px">${glyph("route", 30)}<span class="tx f22 up muted" style="letter-spacing:.08em">Preparação · Plataforma 1</span></div>` +
    `<span class="tx f52 semi up">Ponte das Raízes</span><span class="tx f24 amber">Fase 2 · Patrulha · Moderada</span></div>` +
    img(KIT.band_divider.file, "width:12px;height:160px;align-self:center;margin:0 16px") +
    `<div class="col" style="flex:none;gap:10px;justify-content:center"><span class="tx f20 up muted kicker">O radar leu</span>` +
    `<div class="row" style="gap:20px">${radar("marker_boss_partial", "Chefe", "Coletor de Sucata")}${radar("marker_enemies_partial", "Inimigos", "Enraizado")}</div></div>` +
    img(KIT.band_divider.file, "width:12px;height:160px;align-self:center;margin:0 16px") +
    `<div class="col" style="flex:1;min-width:0;gap:8px;justify-content:center"><span class="tx f20 up muted kicker">Foco da rota</span>` +
    `<div class="row" style="gap:8px;flex-wrap:wrap">${chip("Rota básica")}${chip("Água", { icon: "lobby-water.svg", selected: true })}${chip("Peças", { icon: "lobby-scrap.svg" })}${chip("Provisões", { icon: "lobby-food.svg" })}</div></div>` +
    img(KIT.band_divider.file, "width:12px;height:160px;align-self:center;margin:0 16px") +
    `<div class="col" style="flex:none;gap:8px;justify-content:center"><span class="tx f20 up muted kicker">Comida</span><span class="tx f26 semi">4 grátis + 2 extras</span>` +
    `<div class="row" style="gap:8px">${chip("−", { hit: "minus" })}${chip("+", { hit: "plus" })}<span class="tx f20 muted">4 sementes</span></div></div>`);
  // Quem fica na Estação: os disponíveis (entram com Trocar), quem está em posto (sai dele se entrar) e quem não pode
  // (a Íris em recuperação), apagado com o motivo.
  const benchRow = (hero, name, note, state) => `<div data-hit="bench" style="position:relative">` + nine("list_row", { cls: "row", extra: "gap:12px;min-height:calc(64px*var(--k))" },
    `${face(hero, 52, state === "off" ? "filter:grayscale(.85) brightness(.6)" : "")}<div class="col" style="flex:1;min-width:0"><span class="tx f24 semi ${state === "off" ? "muted" : ""}">${name}</span>` +
    `<span class="wrap f20 ${state === "off" ? "danger" : state === "post" ? "amber" : "muted"}">${note}</span></div>` +
    (state === "off" ? glyph("state_recovering", 28, "var(--danger)") : chip("Trocar", { hit: "swap-in" }))) + `</div>`;
  const bench = `<div class="abs" style="left:1262px;top:262px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "width:622px;gap:8px" },
    `<div class="row" style="gap:10px">${glyph("station", 26, "var(--amber)")}<span class="tx f22 semi up amber kicker">Fica na Estação</span></div>` +
    benchRow("lupa", "Lupa", "Na Enfermaria (posto): se entrar, a Íris volta 1 dia depois", "post") +
    benchRow("iris", "Íris", "Caído · volta amanhã · não pode sair", "off")) + `</div>`;
  const xs = [146, 562, 978, 1394];
  const foot = `<div class="abs" style="left:28px;bottom:14px">` + secondary("Voltar ao mapa", { icon: "ui-arrow-right.svg", iconStyle: "transform:scaleX(-1)", keyLabel: "Esc / B", hit: "back", height: 64 }) + `</div>` +
    `<div class="abs" style="right:28px;bottom:14px;min-width:520px">` + primary("Iniciar expedição", { icon: "expeditions", keyLabel: "G / X", hit: "start" }) + `</div>`;
  let modal = "";
  if (confirm) {
    const sumRow = (icon, label, value) => `<div class="row" style="gap:12px;align-items:flex-start">${glyph(icon, 28, "var(--amber)", "margin-top:2px")}<span class="tx f22 muted up" style="width:110px;flex:none">${label}</span><span class="wrap f24" style="flex:1">${value}</span></div>`;
    modal = `<div class="abs" style="inset:0;background:rgba(5,6,7,.55);z-index:9"></div><div class="abs" data-hit="dialog" style="left:50%;top:50%;transform:translate(-50%,-50%);z-index:10">` +
      nine("panel_large", { repeat: "round", cls: "col", extra: "width:760px;gap:12px" },
        `<div class="row" style="gap:14px">${glyph("expeditions", 40, "var(--amber)")}<span class="tx f40 semi up">Iniciar expedição?</span></div>${divider()}` +
        sumRow("route", "Lugar", "Ponte das Raízes · Patrulha · Fase 2") +
        sumRow("nav_characters", "Equipe", "1 Bento · 2 Nick · 3 Brasa · 4 Véspera") +
        sumRow("lobby-water.svg", "Foco", "Água") + sumRow("lobby-food.svg", "Comida", "6 suprimentos (2 extras por 4 sementes)") +
        line("job_forge", "var(--amber)", "Brasa sai da Forja: com só o Otto, a próxima obra passa de 4 para 5 sucatas.", "f22") + divider() +
        `<div class="row" style="gap:16px;justify-content:flex-end">${secondary("Voltar", { keyLabel: "Esc / B", hit: "cancel", height: 64 })}` +
        `<div style="min-width:420px">${primary("Iniciar expedição", { icon: "expeditions", keyLabel: "E / A", hit: "confirm", height: 64, size: "f26" })}</div></div>`) + `</div>`;
  }
  // Com a confirmação aberta, a tela de baixo fica sem alvos (o véu bloqueia o clique), e as conferências olham só a janela.
  const under = MINE("platform_team") + bodies(PLATFORM_BODIES) + band + bench + PREP.map((h, i) => prepCard(h, xs[i], p)).join("") + foot;
  // O texto de baixo também sai das conferências de texto (fica sob o véu): as classes tx e wrap viram tx-u e wrap-u,
  // com o mesmo estilo.
  const veiled = under.replace(/ data-hit="[^"]*"/g, "").replace(/ data-avoid="1"/g, "").replace(/class="(tx|wrap)( |")/g, 'class="$1-u$2');
  return (confirm ? `<style>.tx-u{white-space:nowrap;line-height:1.14}.wrap-u{white-space:normal;line-height:1.18}.pill .tx-u{position:relative;font-size:calc(22px*var(--k));font-weight:600}</style>` + veiled : under) + modal;
}

await run({
  infirmary_overview: () => overview(),
  infirmary: () => infirmary(),
  report_fallen: (p) => report(p),
  report_posts: (p) => report(p, true),
  characters_fallen: () => characters("iris"),
  characters_post: () => characters("lupa"),
  room_workers: () => forgeWorkers(),
  fight_fallen: (p) => fightFallen(p),
  train_recruit: () => recruit(),
  train_full: () => recruit({ full: true }),
  train_nobody: () => nobody(),
  go_map: () => goMap(),
  map_prepare: () => mapPrepare(),
  platform: (p) => platform(p),
  platform_confirm: (p) => platform(p, { confirm: true }),
}, OUT);
