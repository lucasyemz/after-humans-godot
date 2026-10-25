// Lote 3: o título e o fluxo entre as telas (campanhas, Opções do título, briefing e debriefing, passagem, ficha do
// personagem e Mapa da Rede) no idioma do kit da Estação.
// Fundos: as capturas limpas do jogo em docs/design/hud-v2/before/; o Mapa da Rede usa a pintura e as camadas do Codex
// (#86, art/ui/map/network/, docs/design/phase-map/contract.json). Textos: os do jogo (title_screen.gd, briefings.json).
// Uso (da raiz do repositório, com python3 -m http.server 8765 servindo a raiz):
//   node docs/design/hud-fluxo/render.mjs http://127.0.0.1:8765
import fs from "node:fs";
import {
  setBase, BASE, nine, over, img, glyph, key, bar, portrait, square, badge, divider, cost, chip, secondary, primary, toggle, slider,
  section, roomPanel, topBar, run,
} from "../hud-kit/lib.mjs";

setBase(process.argv[2] || "http://127.0.0.1:8765");
const OUT = process.argv[3] || "docs/design/hud-fluxo/.render";
const BG = (name, extra = "") => img(`docs/design/hud-v2/before/${name}_clean.webp`, `position:absolute;inset:0;width:1920px;height:1080px;${extra}`);
const MAP = JSON.parse(fs.readFileSync("docs/design/phase-map/contract.json", "utf8"));
const keysBar = (keys, style) => `<div class="abs" data-hit="keys" style="${style}">` + nine("keys_bar", { cls: "row", extra: "gap:20px;height:calc(56px*var(--k));justify-content:center" },
  keys.map(([k, t]) => `<div class="row" style="gap:6px">${key(k)}<span class="tx f22">${t}</span></div>`).join("")) + `</div>`;
// Retrato do civil: o recorte do rosto na arte de corpo inteiro (x, y, lado, em pixels da arte), na moldura do kit.
const face = (file, size, [x, y, side], artW) => { const k = size / side;
  return `<div class="portrait" style="width:${size}px;height:${size}px;overflow:hidden;background:#192026">${img(file, `position:absolute;left:${-x * k}px;top:${-y * k}px;width:${artW * k}px`)}` +
    nine("square_portrait", { extra: "position:absolute;inset:0" }) + `</div>`; };
const dim = (a = 0.45) => `<div class="abs" style="inset:0;background:rgba(5,6,7,${a})"></div>`;

// ------------------------------------------------------------------ título
// A logo do jogo já está na arte do título (as capturas limpas a trazem); a HUD do título é só o menu.
const logo = "";
// Telas aprovadas dos lotes anteriores (no mesmo perfil), por baixo dos painéis que abrem sobre elas.
const UNDER = (lot, screen, p) => img(`docs/design/${lot}/${screen}${p.k > 1 ? (p.cb ? "_large_colorblind" : "_large") : p.cb ? "_colorblind" : ""}.webp`, "position:absolute;inset:0;width:1920px;height:1080px");

function title({ campaigns = false } = {}) {
  // A linha do espaço vem de Campaign.slot_summary, numa chapinha para ler sobre a pintura.
  const menu = `<div class="abs col" style="left:96px;top:420px;gap:12px;width:520px">` +
    primary("Continuar", { icon: "route", keyLabel: "E / A", hit: "continue", height: 72 }) +
    nine("cost_chip", { cls: "row", extra: "gap:8px;min-height:40px;align-self:flex-start" }, `${glyph("station", 22, "var(--amber)")}<span class="tx f22">Espaço 1 · Ciclo 0 · 0 fases · 4 de 4 vivos</span>`) +
    secondary("Nova campanha", { icon: "recruit", hit: "new", height: 64, extra: "width:100%" }) +
    (campaigns ? secondary("Campanhas", { icon: "station", hit: "slots", height: 64, extra: "width:100%" }) : "") +
    secondary("Opções", { icon: "lobby-settings.svg", hit: "options", height: 64, extra: "width:100%" }) + `</div>`;
  // O aviso de Campaign.warning_text, quando o save não abriu: chapa com o triângulo, acima do menu.
  const warn = campaigns ? `<div class="abs" style="left:96px;top:calc(420px + 72px*var(--k) + 52px + 3*(64px*var(--k) + 12px) + 24px)">` + nine("panel_inset", { cls: "row", extra: "width:760px;gap:12px;align-items:flex-start" },
    `${glyph("alert", 30, "var(--danger)")}<span class="wrap f22">O save do espaço 2 não pôde ser aberto (o arquivo foi preservado). As outras campanhas estão em Campanhas.</span>`) + `</div>` : "";
  return BG("title-continue") + logo + warn + menu + keysBar([["Setas", "Navegar"], ["E", "Confirmar"]], "left:96px;bottom:28px");
}
const slotRow = (name, detail, sub, sel, empty) => `<div data-hit="slot" style="position:relative">` + nine("list_row", { cls: "row", extra: "gap:14px;min-height:calc(76px*var(--k))" },
  `${glyph(empty ? "relic_empty" : "station", 36, empty ? "var(--muted)" : "var(--amber)")}<div class="col" style="flex:1;min-width:0"><span class="tx f28 semi ${empty ? "muted" : ""}">${name}</span>` +
  (detail ? `<span class="wrap f22">${detail}</span>` : "") + (sub ? `<span class="tx f20 muted">${sub}</span>` : "") + `</div>`) + (sel ? over("selected_frame") : "") + `</div>`;
function slots({ fresh = false } = {}) {
  // Campanhas (abrir outro espaço) e "Em qual espaço começar?" (Nova campanha) são a mesma lista com outro título.
  return BG("title-slots") + logo + dim(0.35) + `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:150px">` +
    nine("panel_large", { repeat: "round", cls: "col", extra: "width:760px;gap:12px" },
      `<div class="row" style="gap:14px">${glyph("station", 40, "var(--amber)")}<span class="tx f40 semi up">${fresh ? "Em qual espaço começar?" : "Campanhas"}</span></div>${divider()}` +
      (fresh ? slotRow("Espaço 1", "", "Vazio", true, true) : slotRow("Espaço 1", "Ciclo 0 · 0 fases · 4 de 4 vivos", "24/10/2026 13:55 · 0 min jogados · último usado", true, false)) +
      slotRow("Espaço 2", "", "Vazio", false, true) + slotRow("Espaço 3", "", "Vazio", false, true) +
      secondary("Voltar", { icon: "ui-arrow-right.svg", iconStyle: "transform:scaleX(-1)", keyLabel: "Esc / B", hit: "back", height: 60, extra: "align-self:flex-start" })) + `</div>`;
}
function confirm() {
  return BG("title-confirm") + logo + dim(0.45) + `<div class="abs" data-hit="panel" style="left:50%;transform:translateX(-50%);top:300px">` +
    nine("panel_large", { repeat: "round", cls: "col", extra: "width:780px;gap:14px" },
      `<div class="row" style="gap:14px">${glyph("alert", 40, "var(--danger)")}<span class="wrap f40 semi up">Começar uma campanha nova?</span></div>` +
      `<span class="wrap f24">Todo o progresso salvo no espaço 1 (fases concluídas, cômodos, recursos e heróis) é substituído por uma campanha do zero. Os outros espaços ficam como estão.</span>` +
      `<div class="row" style="gap:12px;flex-wrap:wrap">${primary("Cancelar", { keyLabel: "Esc / B", hit: "cancel", height: 64, size: "f26", extra: "flex:1 1 300px" })}` +
      `<div data-hit="erase" style="flex:1 1 300px">${nine("secondary_button", { cls: "row", extra: "height:calc(64px*var(--k));gap:10px;justify-content:center" }, `${glyph("alert", 26, "var(--danger)")}<span class="tx f26 semi up danger">Começar do zero</span>`)}</div></div>`) + `</div>`;
}
// As Opções do título: o mesmo painel das Opções da Estação (lote 1), à direita, sem a seção Campanha.
function titleOptions() {
  const rowS = (label, ratio) => `<div class="row" data-hit="slider" style="gap:14px;min-height:56px"><span class="tx f24" style="width:150px">${label}</span>${slider(ratio, 300)}<span class="tx f24 amber" style="width:60px;text-align:right">${Math.round(ratio * 100)}%</span></div>`;
  const rowT = (label, on) => `<div class="row" data-hit="toggle" style="gap:14px;justify-content:space-between;min-height:56px"><span class="wrap f24" style="flex:1">${label}</span><span class="tx f20 ${on ? "amber" : "muted"}">${on ? "Ligado" : "Desligado"}</span>${toggle(on)}</div>`;
  const rowC = (label, opts, sel, icon = "") => `<div class="col" style="gap:6px"><div class="row" style="gap:8px">${icon ? glyph(icon, 24) : ""}<span class="tx f24">${label}</span></div><div class="row" style="gap:8px;flex-wrap:wrap">${opts.map((o, i) => chip(o, { selected: i === sel })).join("")}</div></div>`;
  const body = section("Som", "opt_sound") + rowS("Música", 0.6) + rowS("Ambiente", 0.6) + rowS("Efeitos", 0.6) +
    section("Gráficos", "opt_graphics") + rowC("Qualidade", ["Baixo", "Médio", "Alto", "Ultra"], 2) + `<span class="wrap f20 muted">Qualidade: resolução interna, sombras, oclusão, neblina e quantidade de chuva.</span>` +
    rowT("Tela cheia", false) + rowT("Sincronia vertical (vsync)", true) +
    section("Jogo", "nav_characters") + rowC("Velocidade da batalha", ["1x", "2x"], 0) + rowT("Reduzir efeitos (clima, tremor e clarão)", false) + rowT("Dicas da primeira vez", true) +
    rowT("Cores para daltonismo (azul e laranja)", false) + rowC("Tamanho do texto", ["Normal", "Grande", "Maior"], 0) + rowC("Idioma", ["Português", "English (em teste)"], 0, "opt_language") +
    chip("Mostrar as dicas de novo", { hit: "tips" });
  return BG("title-options") + logo + dim(0.35) + roomPanel({ icon: "lobby-settings.svg", title: "Opções", body, left: 1236, width: 640, top: 40 }) +
    keysBar([["Setas", "Navegar"], ["E", "Mudar"], ["Esc", "Fechar"]], "left:96px;bottom:28px");
}

// ------------------------------------------------------------------ briefing e debriefing (#88)
// A fala é papel com o retrato (hud-direction.md): a caixa sobre a tela de baixo escurecida, o retrato do rosto, o nome,
// o papel (só os civis têm), a fala, a contagem (losangos e "1/3") e os botões. No briefing da saída, o Esc volta à
// Preparação (cancel_on_back) e PULAR parte; no debriefing, o Esc pula.
const CIVIL = JSON.parse(fs.readFileSync("data/presentation/civilians.json", "utf8"));
const civilFace = (id, size) => { const c = CIVIL[id], [u0, v0, u1] = c.portrait_uv, [w, h] = c.canvas; return face(c.file.replace("res://", ""), size, [u0 * w, v0 * h, (u1 - u0) * w], w); };
function speech({ who, name, role = "", text, step, total, last, back, keys = null }) {
  const dots = Array.from({ length: total }, (_, i) => `<i style="width:calc(14px*var(--k));height:calc(14px*var(--k));transform:rotate(45deg);background:${i < step ? "var(--amber)" : "#3a3e44"};border:1px solid #0a0b0c;flex:none"></i>`).join("");
  return `<div class="abs col" data-hit="panel" style="left:50%;transform:translateX(-50%);top:calc(1080px - 14px - 72px*var(--k) - 10px - 64px*var(--k) - 40px - 300px*var(--k));gap:10px;align-items:center">` +
    nine("panel_large", { repeat: "round", cls: "row", extra: "width:1240px;gap:22px;align-items:flex-start" },
    `${who}<div class="col" style="gap:8px;flex:1;min-width:0"><div class="row" style="gap:14px"><span class="tx f40 semi up">${name}</span>${role ? `<span class="tx f24 amber">${role}</span>` : ""}</div>` +
    `<span class="wrap f30" style="line-height:1.25">${text}</span><div class="row" style="gap:14px;margin-top:6px"><div class="row" style="gap:10px;flex:1">${dots}<span class="tx f22 muted">${step}/${total}</span></div>` +
    (last ? "" : secondary("Pular", { hit: "skip", height: 60 })) +
    primary(last ? (back ? "Ver o relatório" : "Partir") : "Próximo", { icon: last ? (back ? "plan" : "expeditions") : "", keyLabel: "E / A", hit: "next", height: 64, size: "f26", extra: "min-width:260px" }) + `</div></div>`) +
    (keys ? nine("keys_bar", { cls: "row", extra: "gap:20px;height:calc(56px*var(--k));justify-content:center" }, keys.map(([k, t]) => `<div class="row" style="gap:6px">${key(k)}<span class="tx f22">${t}</span></div>`).join("")) : "") + `</div>`;
}
const BRIEF_KEYS = [["E", "Próximo"], ["Esc", "Voltar à Preparação"]];
function briefing(p) {
  return UNDER("hud-estacao", "preparation", p) + dim(0.55) + speech({ who: civilFace("civil_dora", 180), name: "Dora", role: "Cozinheira", step: 1, total: 3,
    text: "A despensa da Estação dura poucos dias. Na Rua das Vitrines ainda há prateleiras que ninguém esvaziou.", keys: BRIEF_KEYS });
}
// A fala de um herói: sem papel, com o retrato do herói; a última fala troca PRÓXIMO por PARTIR.
function briefingHero(p) {
  return UNDER("hud-estacao", "preparation", p) + dim(0.55) + speech({ who: portrait("nick", 180), name: "Nick", step: 3, total: 3, last: true,
    text: "Então a gente entra pelos fundos. Comida e peças, e volta antes do escuro.", keys: [["E", "Partir"], ["Esc", "Voltar à Preparação"]] });
}
function debriefing() {
  return BG("station-report") + topBar({ subtitle: "Plataforma 1", stock: ["36", "12", "4", "2"], food: ["6 / 12 suprimentos", "Abastecida · demanda 4", false], water: ["4 em estoque", "Próxima volta: 2"] }) + dim(0.35) +
    speech({ who: civilFace("civil_dora", 180), name: "Dora", role: "Cozinheira", step: 1, total: 1, last: true, back: true,
      text: "A despensa volta a ter o que guardar. E do outro lado do rio, dizem que os sensores da Ponte das Raízes voltaram a acender.", keys: [["E", "Ver o relatório"], ["Esc", "Pular"]] });
}

// ------------------------------------------------------------------ passagem (#74, #75)
// O cartão de GameFlow.card_for: o nome e "Trecho N de M" (na rua) ou "Estação Raiz" e "Ciclo N" (na volta), na chapa
// do kit, sobre o vagão em movimento (#75) com a faixa escura atrás; embaixo, à direita, o aviso de pular do jogo.
const WAGON = img("docs/qa/departure/teams.jpg", "position:absolute;left:0;top:0;width:3840px;height:2160px");
function passage({ station = false, touch = false } = {}) {
  const card = `<div class="abs" style="left:0;right:0;bottom:120px;height:220px;background:linear-gradient(transparent, rgba(5,6,7,.75) 30%, rgba(5,6,7,.75) 70%, transparent)"></div>` +
    `<div class="abs" style="left:50%;transform:translateX(-50%);bottom:150px">` + nine("panel_large", { repeat: "round", cls: "col", extra: "min-width:820px;gap:10px;align-items:center;padding:6px 0" },
      `<span class="tx semi up" style="font-size:calc(64px*var(--k));line-height:1.12">${station ? "Estação Raiz" : "Rua das Vitrines"}</span>` +
      `<div class="row" style="gap:12px">${img("art/ui/kit/station/divider.webp", "width:180px;height:8px")}<i style="width:10px;height:10px;background:var(--amber);transform:rotate(45deg)"></i>${img("art/ui/kit/station/divider.webp", "width:180px;height:8px")}</div>` +
      `<span class="tx f30 muted">${station ? "Ciclo 1" : "Trecho 1 de 10"}</span>`) + `</div>`;
  const hint = `<div class="abs" style="right:40px;bottom:32px">` + nine("keys_bar", { cls: "row", extra: "gap:14px;height:calc(56px*var(--k));justify-content:center" },
    (touch ? `<span class="tx f22">Toque para pular</span>` : `<div class="row" style="gap:6px">${key("E")}<span class="tx f22">Pular</span></div>`)) + `</div>`;
  return `<div class="abs" style="inset:0;overflow:hidden">${WAGON}</div>` + card + hint;
}

// ------------------------------------------------------------------ ficha do personagem (#89), na Preparação
// A ficha sai da carta do herói e fica ancorada à direita dela; a carta (data-avoid) não pode ser coberta.
function sheet(p) {
  const card = p.k > 1 ? [994, 237, 300, 282] : [994, 370, 300, 268];
  const passive = (title, text, good = true) => `<div class="col" style="gap:2px"><div class="row" style="gap:8px">${badge(good ? "+" : "−", good ? "var(--good)" : "var(--danger-fill)")}<span class="tx f24 semi ${good ? "good" : "danger"}">${title}</span></div><span class="wrap f20 muted">${text}</span></div>`;
  return UNDER("hud-estacao", "preparation", p) + dim(0.35) +
    `<div class="abs" data-avoid="1" style="left:${card[0]}px;top:${card[1]}px;width:${card[2]}px;height:${card[3]}px;outline:3px solid var(--amber);outline-offset:2px"></div>` +
    `<div class="abs" data-hit="panel" style="left:${card[0] + card[2] + 14}px;top:120px">` +
    nine("panel_large", { repeat: "round", cls: "col", extra: "width:540px;gap:10px" },
      `<div class="row" style="gap:14px">${portrait("bento", 84)}<div class="col" style="gap:2px;flex:1;min-width:0"><span class="tx f40 semi up">Bento</span><span class="tx f24 amber">Cão · Tanque e Proteção</span></div>` +
      `<div class="col" style="align-items:center;gap:2px"><div style="position:relative;width:60px;height:60px;flex:none">${img("art/ui/kit/station/level_medal.webp", "position:absolute;inset:0;width:100%;height:100%")}<span class="tx f28 semi amber" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">1</span></div><span class="tx f20 up muted">Nível</span></div></div>` +
      `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f24 up">Vida</span><span class="tx f24">34 / 34</span></div>${bar("100%", 24, 1, "var(--ally)")}</div>` +
      `<div class="col" style="gap:4px"><div class="row" style="gap:12px"><span class="tx f24 up">Instinto</span><span class="tx f24">0 / 200</span><span class="tx f20 muted">em 200, crise</span></div>${bar("100%", 20, 0, "var(--instinct)")}</div>` +
      `<div class="row" style="gap:10px">${glyph("next_step", 26)}<span class="wrap f22"><b class="semi">Velocidade 3</b> · quem é mais rápido age antes na rodada</span></div>` +
      divider() + section("Efeitos passivos") +
      passive("Ágil", "+1 Velocidade enquanto estiver no grupo.") + passive("Relíquia: Botão de Cobre", "+3 de Vida Máxima. Um talismã sólido do tempo dos Antigos.") +
      divider() + section("Estados") + `<span class="tx f22 muted">Nenhum agora</span>`) + `</div>`;
}

// ------------------------------------------------------------------ Mapa da Rede (#86 do Codex, na chapa do kit)
// A pintura e as camadas são as do Codex; a moldura, a plaqueta, as etiquetas, os marcadores e o painel passam para o aço
// do kit. A pintura fica em 60,196 (no contract.json, 68,248): a integração soma essa origem aos polígonos de clique.
const X0 = 60, Y0 = 196;
const tint = (file, [ox, oy], [w, h], color, extra = "") => `<i style="position:absolute;left:${X0 + ox}px;top:${Y0 + oy}px;width:${w}px;height:${h}px;background:${color};-webkit-mask-image:url(${BASE}/${file});-webkit-mask-size:100% 100%;${extra}"></i>`;
const COLOR = { available: "var(--ally)", completed: "var(--good)", selected: "var(--amber)", locked: "#8a8478" };
const PHASES = {
  // Chefe e inimigo mais comum do radar_snapshot.json do Codex (guardians[0] e a maior contagem de patrulha), como no render.py dele.
  shop: { n: 1, name: "Rua das Vitrines", level: 1, diff: "Fácil", boss: "Robô", portrait: "portrait_robot", enemies: "Relé de Defesa", enemyFace: "portrait_condutor_raiz", supplies: "Visto na última volta", weather: "Noite · chuva",
    text: "Vitrines tomadas por raízes ainda guardam comida e peças que a Estação não sabe mais fabricar. Os sensores das Galerias seguem separando clientes dos Antigos de fauna não autorizada." },
  bridge: { n: 2, name: "Ponte das Raízes", level: 3, diff: "Moderada", boss: "Coletor de Sucata", enemies: "Enraizado", supplies: "Sinal parcial", weather: "Não lido",
    text: "A ponte ligava bairros. Há pouco tempo, seus sensores voltaram a acender e a patrulha dobrou: a passagem livre agora pede permissões que ninguém na Estação possui." },
  shelter: { n: 3, name: "Sala Esquecida", level: 5, diff: "Difícil" },
};
function networkMap({ selected = "bridge" } = {}) {
  const state = { refuge: "available", shop: "completed", bridge: "available", shelter: "locked", lab: "locked", depot: "locked" };
  state[selected] = state[selected] === "locked" ? "locked" : "selected";
  const reading = { shop: "known", bridge: "partial", shelter: "unknown", lab: "unknown", depot: "unknown" };
  const layers = MAP.regions.map((r) => { const st = r.states[state[r.key] === "locked" ? "locked" : state[r.key]]; return tint(st.file, st.origin, st.size, COLOR[state[r.key]], `opacity:${state[r.key] === "locked" ? 0.55 : 0.85}`); }).join("") +
    tint(MAP.routes.shop.traversed, [0, 0], [1120, 630], "var(--amber)") +
    // A rota que falta até a escolhida: clara, com contorno escuro, para ler sobre a pintura.
    // A rota que falta até a escolhida: a camada de build_layers.py (o traço do Codex engrossado, claro com contorno escuro).
    (MAP.routes[selected] && selected !== "shop" ? img(`docs/design/hud-fluxo/layers/route_${selected}_remaining.webp`, `position:absolute;left:${X0}px;top:${Y0}px;width:1120px;height:630px`) : "");
  // Os marcadores do Codex sobre cada fase (chefe, inimigos, suprimentos, história), numa chapinha acima da etiqueta.
  const markers = (r) => {
    if (!r.phase_id) return "";
    const rd = reading[r.key], boss = PHASES[r.key]?.portrait && rd === "known";
    const m = (kind, size) => img(`art/ui/map/network/marker_${kind}_${rd === "known" && kind === "story" ? "none" : rd}.webp`, `width:${size}px;height:${size}px;flex:none`);
    return `<div class="abs" style="left:${X0 + r.anchor[0]}px;top:${Y0 + r.anchor[1] - 66}px;transform:translateX(-50%)">` +
      nine("cost_chip", { cls: "row", extra: "gap:4px;min-height:52px" },
        (boss ? `<div style="position:relative;width:44px;height:44px;flex:none">${img("art/ui/map/network/marker_boss_known.webp", "position:absolute;inset:0;width:44px;height:44px")}${`<i style="position:absolute;left:6px;top:6px;width:32px;height:32px;border-radius:50%;background:#8a8478"></i>` + img(`art/ui/map/network/${PHASES[r.key].portrait}.webp`, "position:absolute;left:6px;top:6px;width:32px;height:32px;border-radius:50%")}</div>` : m("boss", 44)) +
        (rd === "known" && PHASES[r.key]?.enemyFace ? `<div style="position:relative;width:34px;height:34px;flex:none">${img("art/ui/map/network/marker_enemies_known.webp", "position:absolute;inset:0;width:34px;height:34px")}<i style="position:absolute;left:5px;top:5px;width:24px;height:24px;border-radius:50%;background:#8a8478"></i>${img(`art/ui/map/network/${PHASES[r.key].enemyFace}.webp`, "position:absolute;left:5px;top:5px;width:24px;height:24px;border-radius:50%")}</div>` : m("enemies", 34)) +
        m("supplies", 34) + m("story", 34)) + `</div>`;
  };
  const label = (r) => {
    const st = state[r.key];
    const icon = st === "completed" ? glyph("state_active", 24, "var(--good)") : st === "locked" ? `<i class="glyph" style="width:24px;height:24px;background:#b3a993;-webkit-mask-image:url(${BASE}/art/ui/map/network/lock_32.webp)"></i>` : st === "selected" ? glyph("next_step", 24, "var(--amber)") : glyph("node-start.svg", 24, "var(--ally)");
    const name = r.phase_id ? `Fase ${r.phase_id.slice(-1)}` : "Estação Raiz";
    return `<div class="abs" data-hit="place" style="left:${X0 + r.anchor[0]}px;top:calc(${Y0 + r.anchor[1] - 8}px);transform:translateX(-50%)">` +
      `<div style="position:relative">` + nine("chip_button", { cls: "row", extra: "gap:8px;min-height:calc(56px*var(--k));min-width:140px;justify-content:center" }, `${icon}<span class="tx f24 ${st === "selected" ? "amber semi" : st === "locked" ? "muted" : ""}">${name}</span>`) +
      (r.key === selected ? over("selected_frame") : "") + `</div></div>`;
  };
  const frame = `<div class="abs" style="left:${X0 - 24}px;top:${Y0 - 70}px">` + nine("panel_large", { repeat: "round", cls: "col", extra: `width:${1120 + 48}px;height:${630 + 196}px;gap:6px` },
    `<div class="row" style="gap:12px;justify-content:space-between"><span class="tx f26 semi up">Lugares</span><span class="tx f22 muted">Rede antiga · VIGIA</span></div>`) + `</div>`;
  const legend = `<div class="abs col" style="left:${X0}px;top:${Y0 + 640}px;gap:10px"><div class="row" style="gap:24px">` +
    [["state_active", "var(--good)", "Concluída"], ["next_step", "var(--amber)", "Escolhida"], ["node-start.svg", "var(--ally)", "Disponível"]].map(([i, c, t]) => `<div class="row" style="gap:8px">${glyph(i, 22, c)}<span class="tx f20">${t}</span></div>`).join("") +
    `<div class="row" style="gap:8px"><i class="glyph" style="width:22px;height:22px;background:#b3a993;-webkit-mask-image:url(${BASE}/art/ui/map/network/lock_32.webp)"></i><span class="tx f20">Bloqueada</span></div>` +
    `<div class="row" style="gap:8px"><span class="tx f22 semi muted">?</span><span class="tx f20">Não lido</span></div></div>` +
    `<div class="row" style="gap:10px"><span class="tx f20 muted">Estoque da Estação</span>${cost("lobby-seed.svg", "30")}${cost("lobby-scrap.svg", "9")}${cost("lobby-fragment.svg", "3")}</div></div>`;
  const clima = (value) => `<div class="row" style="gap:14px"><div class="row" style="width:48px;height:48px;justify-content:center;flex:none;border:2px solid #6d6a62;border-radius:50%">${value === "Não lido" ? `<span class="tx f28 semi muted">?</span>` : glyph("sleep", 26)}</div><div class="col"><span class="tx f20 up muted">Clima</span><span class="tx f24 ${value === "Não lido" ? "muted" : ""}">${value}</span></div></div>`;
  const read = (marker, labelText, value, dimmed) => `<div class="row" style="gap:14px">${img(`art/ui/map/network/${marker}.webp`, `width:48px;height:48px;flex:none;${dimmed ? "opacity:.6" : ""}`)}<div class="col"><span class="tx f20 up muted">${labelText}</span><span class="tx f24 ${dimmed ? "muted" : ""}">${value}</span></div></div>`;
  const ph = PHASES[selected], st = state[selected];
  const status = st === "locked" ? `<div class="row" style="gap:8px"><i class="glyph" style="width:22px;height:22px;background:#b3a993;-webkit-mask-image:url(${BASE}/art/ui/map/network/lock_32.webp)"></i><span class="tx f22 muted">Bloqueada · vença a fase anterior</span></div>`
    : selected === "shop" ? `<div class="row" style="gap:8px">${glyph("state_active", 22, "var(--good)")}<span class="tx f22 good">Concluída · dá para jogar de novo</span></div>`
    : `<div class="row" style="gap:8px">${glyph("node-start.svg", 22, "var(--ally)")}<span class="tx f22" style="color:var(--ally)">Disponível</span></div>`;
  const rd = reading[selected];
  const body = `<span class="tx f20 up muted kicker">Fase ${ph.n} · Dificuldade: ${ph.diff}</span>${status}` +
    `<span class="wrap f22 ${st === "locked" ? "muted" : ""}">${st === "locked" ? "O que há lá, a equipe só descobre quando chegar." : ph.text}</span>` +
    `<div class="row" style="gap:10px;flex-wrap:wrap">${cost("state_active", `Nível recomendado ${ph.level}`)}</div>` + divider() +
    `<span class="tx f22">Mapa da Rede: ${rd === "known" ? "leitura completa" : rd === "partial" ? "leitura parcial" : "sem leitura"}</span>` +
    (rd === "unknown" ? read("marker_boss_unknown", "Chefe", "Não lido", true) + read("marker_enemies_unknown", "Inimigos", "Não lido", true)
      : (rd === "known" ? `<div class="row" style="gap:14px"><div style="position:relative;width:48px;height:48px;flex:none">${img("art/ui/map/network/marker_boss_known.webp", "position:absolute;inset:0;width:48px;height:48px")}${`<i style="position:absolute;left:7px;top:7px;width:34px;height:34px;border-radius:50%;background:#8a8478"></i>` + img(`art/ui/map/network/${ph.portrait}.webp`, "position:absolute;left:7px;top:7px;width:34px;height:34px;border-radius:50%")}</div><div class="col"><span class="tx f20 up muted">Chefe</span><span class="tx f24">${ph.boss}</span></div></div>`
        : read("marker_boss_partial", "Chefe", ph.boss)) +
        (rd === "known" ? `<div class="row" style="gap:14px"><div style="position:relative;width:48px;height:48px;flex:none">${img("art/ui/map/network/marker_enemies_known.webp", "position:absolute;inset:0;width:48px;height:48px")}<i style="position:absolute;left:7px;top:7px;width:34px;height:34px;border-radius:50%;background:#8a8478"></i>${img(`art/ui/map/network/${ph.enemyFace}.webp`, "position:absolute;left:7px;top:7px;width:34px;height:34px;border-radius:50%")}</div><div class="col"><span class="tx f20 up muted">Inimigos</span><span class="tx f24">${ph.enemies}</span></div></div>`
          : read(`marker_enemies_${rd}`, "Inimigos", ph.enemies)) + read(`marker_supplies_${rd}`, "Suprimentos", ph.supplies) +
        read(rd === "known" ? "marker_story_none" : "marker_story_unknown", "História", rd === "known" ? "Nada a ler" : "Não lido", rd !== "known")) + clima(ph.weather || "Não lido");
  const footer = st === "locked" ? primary("Preparar expedição", { icon: "expeditions", keyLabel: "G / X", hit: "prepare", height: 64, locked: true, reason: "Bloqueada · vença a fase anterior" })
    : primary("Preparar expedição", { icon: "expeditions", keyLabel: "G / X", hit: "prepare", height: 64, size: "f26" });
  // O X do painel tira a escolha (volta a "Lugares"); VOLTAR À ESTAÇÃO fecha o mapa.
  return `<div class="abs" style="inset:0;background:#0c0e10"></div>` +
    `<div class="abs" style="left:28px;top:14px">` + nine("room_plaque", { cls: "row", extra: "min-width:520px;min-height:96px;gap:16px" },
      `${glyph("route", 52)}<div class="col"><span class="tx f40 semi up">Mapa da Rede</span><span class="tx f24 muted">Bairro Submerso · Fases concluídas 1 / 5 · Equipe: 4 vivos</span></div>`) + `</div>` +
    frame + img("art/ui/map/network/network_map.webp", `position:absolute;left:${X0}px;top:${Y0}px;width:1120px;height:630px`) + layers + MAP.regions.map(markers).join("") + MAP.regions.map(label).join("") + legend +
    roomPanel({ icon: st === "locked" ? "alert" : "next_step", title: ph.name, body, footer, left: 1236, width: 656, top: 126 }) +
    `<div class="abs" style="left:28px;bottom:14px">` + secondary("Voltar à Estação", { icon: "ui-arrow-right.svg", iconStyle: "transform:scaleX(-1)", keyLabel: "Esc / B", hit: "back", height: 64 }) + `</div>` +
    keysBar([["Setas", "Lugar"], ["E", "Escolher"]], "left:440px;bottom:18px");
}

await run({
  title: () => title(), title_warning: () => title({ campaigns: true }), slots: () => slots(), slots_new: () => slots({ fresh: true }), confirm: () => confirm(),
  title_options: () => titleOptions(), briefing: (p) => briefing(p), briefing_last: (p) => briefingHero(p), debriefing: () => debriefing(),
  passage: () => passage(), passage_station: () => passage({ station: true, touch: true }), sheet: (p) => sheet(p),
  map: () => networkMap(), map_known: () => networkMap({ selected: "shop" }), map_locked: () => networkMap({ selected: "shelter" }),
}, OUT);
