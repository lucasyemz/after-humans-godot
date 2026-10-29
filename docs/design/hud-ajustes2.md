# Os ajustes depois de jogar: inspeção, Admin, cômodos, noite e formação (26/10/2026)

O lote 8, a issue #134, com as propostas de tela para as issues do Claude que saíram da última vez que o Lucas jogou:
- **a inspeção da luta (#128):** o botão INSPECIONAR, os detalhes na HUD de baixo (herói e máquina), a intenção da
  máquina sem o alvo e o popup de fim de luta com o X e a barra do tempo;
- **a barra de Admin (#130):** as sete abas, no kit;
- **os marcadores dos cômodos na Estação (#131),** como no XCOM 2;
- **a noite e o amanhecer (#132):** o cartão "Noite N" e o painel "Amanhecer · Dia N", com e sem evento;
- **a troca de formação na exploração (#129):** as plaquinhas em modo de troca;
- **ícones novos** no mesmo método: o cadeado, o clima, o Admin, pular, a noite, o rato e a conversa.

Tudo no kit da Awesomic (`art/ui/kit/station`), sobre as capturas do jogo, nos quatro perfis (Normal, Maior, daltonismo
e Maior com daltonismo). Nada em `scripts/`, `data/` nem `tests/`. Usa o que a Estação nova
([hud-casa.md](hud-casa.md), #139, já na `main`) trouxe (os ícones INSPECIONAR, troca de formação e amanhecer, a
Enfermaria, a barra com os limites e a história do Dia 4 e do Dia 5). As telas servem para comparar e aprovar; a
integração é do Claude, nas issues de cada item. Os números e as regras das telas são os do jogo de hoje (`data/` e
`station_rules.gd`); o que este lote sugere mudar nelas fica em [Para o Lucas decidir](#para-o-lucas-decidir), só como
proposta.

## As telas

| Tela | Normal | Maior | Daltonismo | Maior e daltonismo | Antes e depois |
|---|---|---|---|---|---|
| Luta: a intenção sem o alvo, o mouse no Recreador | [fight_intent](hud-ajustes2/fight_intent.webp) | [large](hud-ajustes2/fight_intent_large.webp) | [colorblind](hud-ajustes2/fight_intent_colorblind.webp) | [large_colorblind](hud-ajustes2/fight_intent_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_fight_intent.webp) |
| Luta: inspecionar um herói | [fight_inspect_hero](hud-ajustes2/fight_inspect_hero.webp) | [large](hud-ajustes2/fight_inspect_hero_large.webp) | [colorblind](hud-ajustes2/fight_inspect_hero_colorblind.webp) | [large_colorblind](hud-ajustes2/fight_inspect_hero_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_fight_inspect_hero.webp) |
| Luta: inspecionar uma máquina | [fight_inspect_machine](hud-ajustes2/fight_inspect_machine.webp) | [large](hud-ajustes2/fight_inspect_machine_large.webp) | [colorblind](hud-ajustes2/fight_inspect_machine_colorblind.webp) | [large_colorblind](hud-ajustes2/fight_inspect_machine_large_colorblind.webp) | (como a anterior) |
| Fim de luta: o X e a barra do tempo | [fight_popup](hud-ajustes2/fight_popup.webp) | [large](hud-ajustes2/fight_popup_large.webp) | [colorblind](hud-ajustes2/fight_popup_colorblind.webp) | [large_colorblind](hud-ajustes2/fight_popup_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_fight_popup.webp) |
| Fim de luta: parado com o mouse em cima | [fight_popup_hold](hud-ajustes2/fight_popup_hold.webp) | [large](hud-ajustes2/fight_popup_hold_large.webp) | [colorblind](hud-ajustes2/fight_popup_hold_colorblind.webp) | [large_colorblind](hud-ajustes2/fight_popup_hold_large_colorblind.webp) | (como a anterior) |
| Admin: Mapas | [admin_maps](hud-ajustes2/admin_maps.webp) | [large](hud-ajustes2/admin_maps_large.webp) | [colorblind](hud-ajustes2/admin_maps_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_maps_large_colorblind.webp) | (tela nova) |
| Admin: Clima | [admin_weather](hud-ajustes2/admin_weather.webp) | [large](hud-ajustes2/admin_weather_large.webp) | [colorblind](hud-ajustes2/admin_weather_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_weather_large_colorblind.webp) | (tela nova) |
| Admin: Ajustes | [admin_settings](hud-ajustes2/admin_settings.webp) | [large](hud-ajustes2/admin_settings_large.webp) | [colorblind](hud-ajustes2/admin_settings_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_settings_large_colorblind.webp) | (tela nova) |
| Admin: Recursos | [admin_resources](hud-ajustes2/admin_resources.webp) | [large](hud-ajustes2/admin_resources_large.webp) | [colorblind](hud-ajustes2/admin_resources_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_resources_large_colorblind.webp) | (tela nova) |
| Admin: Heróis | [admin_heroes](hud-ajustes2/admin_heroes.webp) | [large](hud-ajustes2/admin_heroes_large.webp) | [colorblind](hud-ajustes2/admin_heroes_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_heroes_large_colorblind.webp) | (tela nova) |
| Admin: Testes de combate | [admin_combat](hud-ajustes2/admin_combat.webp) | [large](hud-ajustes2/admin_combat_large.webp) | [colorblind](hud-ajustes2/admin_combat_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_combat_large_colorblind.webp) | (tela nova) |
| Admin: Cenas e Jornada, com a confirmação | [admin_journey](hud-ajustes2/admin_journey.webp) | [large](hud-ajustes2/admin_journey_large.webp) | [colorblind](hud-ajustes2/admin_journey_colorblind.webp) | [large_colorblind](hud-ajustes2/admin_journey_large_colorblind.webp) | (tela nova) |
| Estação: os marcadores dos cômodos | [station_markers](hud-ajustes2/station_markers.webp) | [large](hud-ajustes2/station_markers_large.webp) | [colorblind](hud-ajustes2/station_markers_colorblind.webp) | [large_colorblind](hud-ajustes2/station_markers_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_station_markers.webp) |
| Estação: o foco num cômodo bloqueado | [station_markers_focus](hud-ajustes2/station_markers_focus.webp) | [large](hud-ajustes2/station_markers_focus_large.webp) | [colorblind](hud-ajustes2/station_markers_focus_colorblind.webp) | [large_colorblind](hud-ajustes2/station_markers_focus_large_colorblind.webp) | (como a anterior) |
| A noite: o cartão "Noite 4" | [night_card](hud-ajustes2/night_card.webp) | [large](hud-ajustes2/night_card_large.webp) | [colorblind](hud-ajustes2/night_card_colorblind.webp) | [large_colorblind](hud-ajustes2/night_card_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_night_card.webp) |
| O amanhecer, com um evento | [dawn_event](hud-ajustes2/dawn_event.webp) | [large](hud-ajustes2/dawn_event_large.webp) | [colorblind](hud-ajustes2/dawn_event_colorblind.webp) | [large_colorblind](hud-ajustes2/dawn_event_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_dawn_event.webp) |
| O amanhecer, sem evento | [dawn_quiet](hud-ajustes2/dawn_quiet.webp) | [large](hud-ajustes2/dawn_quiet_large.webp) | [colorblind](hud-ajustes2/dawn_quiet_colorblind.webp) | [large_colorblind](hud-ajustes2/dawn_quiet_large_colorblind.webp) | (como a anterior) |
| Exploração: a formação aberta | [explore_formation](hud-ajustes2/explore_formation.webp) | [large](hud-ajustes2/explore_formation_large.webp) | [colorblind](hud-ajustes2/explore_formation_colorblind.webp) | [large_colorblind](hud-ajustes2/explore_formation_large_colorblind.webp) | [comparar](hud-ajustes2/before_after_explore_formation.webp) |
| Exploração: um escolhido para trocar | [explore_formation_pick](hud-ajustes2/explore_formation_pick.webp) | [large](hud-ajustes2/explore_formation_pick_large.webp) | [colorblind](hud-ajustes2/explore_formation_pick_colorblind.webp) | [large_colorblind](hud-ajustes2/explore_formation_pick_large_colorblind.webp) | (como a anterior) |

Cada tela também tem a redução a 40% (`*_40.webp`), o cinza (`*_gray.webp`) e, quando o painel rola, o painel rolado
até o fim (`*_scrolled.webp`). O "antes" é a tela aprovada que o jogo segue hoje (hud-luta, hud-ajustes, hud-estacao e
hud-exploracao).

[checks.json](hud-ajustes2/checks.json) mede cada texto e cada alvo de toque com as conferências do `lib.mjs`. As 76
telas (19 telas, 4 perfis) passam: nenhum texto cortado, fora da sua peça ou fora da tela; nenhum alvo sobreposto ou
menor que 56 px; nenhuma peça cortada pelo painel; nenhum texto por cima de medalhão ou de painel; o menor texto tem
20 px.

![A inspeção de uma máquina](hud-ajustes2/fight_inspect_machine.webp)
![Os marcadores dos cômodos](hud-ajustes2/station_markers.webp)

## 1. A inspeção da luta (#128)

- **INSPECIONAR** é um botão alto à esquerda da grade das ações (Mover, Defender, Mochila, Fugir), da altura das duas
  linhas (160 × 212 em x 1408, y 836), com o glifo da lupa, o rótulo e a tecla. A tecla é a do Examinar de hoje (`combat_examine`, X e L3 no
  controle): é a mesma ideia, agora como botão. Ligado, ganha a moldura âmbar.
- **O mouse em cima** de um personagem só marca quem ele é: a moldura de foco na barra da vida e, nas máquinas, o nome
  na aba vermelha. A ficha não abre.
- **Com a inspeção ligada,** quem foi apontado ou escolhido aparece na HUD de baixo, no lugar do painel do herói da vez
  **e** das habilidades (a vez continua de quem age; ao desligar, o painel volta):
  - o retrato (nas máquinas, o recorte do sprite), o nome, o nível, a espécie e o papel (nas máquinas, "Máquina" e o
    papel de `enemies.json`), a vida e o instinto;
  - a velocidade (no herói, com o que ela faz); a posição (heróis) ou a intenção, sem o alvo (máquinas);
  - à direita, os passivos e os estados, cada um com o que faz (os textos de `character_sheet.gd` e do glossário de
    `ui_style.gd`). Nas máquinas, a descrição vem primeiro. O que não cabe rola.
  - A aba de cima diz como trocar e sair: "Inspecionar · Setas trocam · X ou Esc sai". Ela fica em y 816, sobre a
    borda do painel (como ESCOLHA UM ALVO hoje), e a coluna da direita começa abaixo dela.
  - As medidas: o painel tem 1328 × 212 em x 64, y 836, também no Maior (o que não cabe à direita rola).
  - Os estados mostrados são exemplo (a captura é a rodada 1, sem estados): o Recreador "Marcado".
- **A intenção da máquina,** sobre a cabeça, mostra o tipo (o ícone de hoje: ataque, área, bloqueio, cura, movimento,
  atordoado) e o nome da ação: "Pega-Pega", "Ordem Contraditória". Sai o "→ um de 4" (o "antes" é a captura do jogo
  com a HUD de hoje). A cor é a de hoje (`_show_intent`, `S.ENEMY`, o laranja #d9893d): o ataque na cor do inimigo; a cura em
  verde e o bloqueio em azul.
- **O popup de fim de luta** (o do lote 5, [hud-ajustes.md](hud-ajustes.md)) ganha o X no canto, e a barra do tempo
  conta 5 s ("Fecha em 4 s · qualquer tecla fecha antes"). Com o mouse em cima ou o foco nele, a barra para, fica
  cinza e diz por quê ("Parado: o mouse está em cima · qualquer tecla fecha"). Na derrota, continua esperando o toque.

## 2. A barra de Admin (#130)

Ferramenta de teste: simples e densa, mas no idioma do kit.
- **O F1 abre por cima de qualquer tela** (título, Estação, rua, luta): a tela de baixo escurece e fica parada. No alto,
  a faixa com ADMIN ("Testes · F1 fecha"), as sete abas (a ativa em âmbar e sublinhada) e o X.
- **O conteúdo** é uma lista de linhas: o rótulo à esquerda (com a origem, quando substitui uma tecla antiga da rua) e
  os controles à direita, em chips do kit. No Maior, os chips quebram a linha.
- **O que muda o save** diz antes ("Isso altera o save: cada ação pede para confirmar antes"), e a confirmação é a
  janela do kit (em "Cenas e Jornada": "Liberar todas as fases?"). Os testes de combate dizem que não alteram o save.
- **Cada ação diz o que fez** num aviso curto embaixo ("+10 sementes: agora 40").
- **As abas:**
  - **Mapas:** o título, a Estação e o Mapa da Rede; cada fase com os mapas dela (a travessia e o trecho), o trecho 1 e
    o guardião; ir com a equipe de agora ou a inicial.
  - **Clima:** a hora (fim de tarde, noite) e o tempo (seco, chuva, tempestade), que eram o T e o R da rua; só agora
    ou a jornada inteira.
  - **Ajustes:** a câmera da exploração, da Estação e da luta; a velocidade da luta; o pós-processamento e as colisões
    (o P e o C da rua); a qualidade.
  - **Recursos:** um por linha, com o que se tem e −1, +1, +5, +10.
  - **Heróis:** cada herói com o estado, curar, cair ou tirar da recuperação (#118), +50 XP e +1 nível (#90); curar a
    equipe; recrutar na hora e quem chega no próximo trem (#122).
- **Os fundos:** a Estação do Dia 5 do lote 7 (os números de Recursos e os estados de Heróis são os desse dia), a rua e
  a luta.
  - **Testes de combate:** a próxima patrulha (o K da rua), a luta contra um inimigo escolhido, forçar Superação e
    Colapso, +50 de Instinto, curar a equipe, vencer, perder e fugir.
  - **Cenas e Jornada:** finalizar e resetar a fase, liberar todas, pular a noite e o amanhecer, abrir cada evento e o
    briefing, recuperar todos os cômodos.

## 3. Os marcadores dos cômodos (#131)

Como no XCOM 2: sobre cada cômodo não recuperado, uma placa (a `room_tag` do kit, com a ponta para baixo) com o que
falta. É a informação do Plano, no lugar.
- **O que já dá para recuperar** fica aceso: o ícone do cômodo em âmbar, a moldura âmbar e o custo com o que se tem
  ("Forja · 4 sucatas · tem 9").
- **O que ainda não dá** fica apagado, com o cadeado e o motivo: "Enfermaria · Falta 1 fragmento", "Bar · Numa
  próxima fase", "Dormitório · Numa próxima fase" (o `upgrade_block` de hoje). O Dormitório começa no nível 0 ("Quarto
  por recuperar"), e a equipe dorme nos beliches assim mesmo.
- **Os recuperados** ficam sem placa.
- **Com o foco numa placa** (setas ou mouse), a moldura de foco e, no lugar do Próximo passo (no alto à esquerda, longe
  das placas), o cartão do cômodo: o que ele destrava, o custo em chips (o que falta em alerta) e RECUPERAR travado com
  o motivo.
- É o Dia 2, dois dias antes da volta do lote 7: a Forja e a Enfermaria ainda vazias, o Próximo passo "Recuperar a
  Forja" com o texto e os chips de `next_step`. Os custos são os de hoje: a Forja, 4 sucatas (`station_rules.gd`); a
  Enfermaria, 4 sucatas e 1 fragmento (`data/recovery.json`, `infirmary_level_1`). Com 0 fragmentos, falta 1. O cartão
  do foco diz os dias de hoje: 2 no leito, 3 no Dormitório.

## 4. A noite e o amanhecer (#132)

- **O cartão "Noite 4"** (600 px de largura, no alto, no meio): ao INICIAR DESCANSO, a Estação escurece (as luzes dos
  cômodos se apagam; a do Dormitório e a da Enfermaria ficam baixas) e o cartão mostra a noite, quem dorme, quem vigia
  e quem está na Enfermaria, a barra do tempo passando e PULAR (Esc / B). Sem a HUD. Com "Reduzir efeitos", só o
  cartão. No corte, o Bento e o Nick deitados nos beliches (a pose de dormir), a Véspera de pé no Depósito, de vigia, e
  a Íris no leito da Enfermaria. O texto do cartão cita só quem aparece (o Bento, o Nick, a Véspera e a Íris). A Lupa e
  o Brasa ficaram na Estação e também dormiriam, mas os recrutas não têm pose de dormir: ficam fora do corte na
  montagem (ver "Para integrar").
- **O painel "Amanhecer · Dia 5",** no lugar e na medida do painel do cômodo (596 de largura, à direita):
  - **o que a noite fez:** a Comida (8 → 6), quem descansou e quanto (o Nick +8 de vida, −15 de instinto), quem vigiou
    e a Enfermaria (a Íris volta amanhã). A conta é a do `resolve_night` de hoje: cada um que voltou e dorme come 1
    suprimento (o Bento e o Nick); quem vigia não come (a Véspera), e quem chegou Caído fica fora da noite (a Íris);
    a produção da Cantina e da Dora e o que os civis comem entram no ciclo da volta, antes da noite;
  - **durante a noite:** o evento, com o ícone, o título e o que mudou;
  - **o Próximo passo;**
  - COMEÇAR O DIA no pé. IR AO MAPA fica bloqueado com o motivo até lá.
- **Com evento:** o `watcher_sees` de `data/night-events.json`, com o texto do jogo: "Véspera viu luzes se mexendo
  longe, no rumo do próximo lugar (Ponte das Raízes). O Mapa da Rede agora lê o guardião e os inimigos de lá." O título
  curto ("Véspera viu luzes ao longe") é a proposta do painel; hoje o jogo mostra "A noite" no alto do quadro.
- **Sem evento:** o `quiet`, com o texto do jogo ("A noite passou tranquila. O abrigo permaneceu seguro."), e a nota do
  vigia como o jogo faz: o sorteio não olha o vigia, mas com alguém de vigia a goteira, as baratas e os ruídos não levam
  nada.
- **Os eventos da noite** são os de `data/night-events.json` (#132, já no jogo: um sorteio por noite pela semente da
  expedição, com os pesos de lá). Os ícones propostos:

| Evento | Ícone | O que muda |
|---|---|---|
| `quiet` | `night` | Noite calma |
| `distant_noise` | `alert` | Quem dorme baixa menos o instinto; com vigia, nada |
| `platform_noise` | `train_arrival` | A chance do próximo trem sobe (#122) |
| `leak` | `resource_water` (pintado) | A água cai; com vigia, nada se perde |
| `pests` (baratas na despensa) | `night_rat` (ver "Para o Lucas decidir") | Os suprimentos caem; o Depósito no nível 2 protege; com vigia, nada |
| `watcher_sees` | `watch` | Só com vigia: o próximo lugar fica lido no Mapa da Rede (#87) |
| `resident_talk` | `night_talk` | Uma fala curta da Dora, do Otto ou da Cora |
| `sleepless` | `alert` | Quem tem trauma e dormiu não baixa o instinto |

A fome e a sede não são eventos: o jogo as guarda à parte (`short_supplies` e `no_water`, nas condições da noite) e o
painel as mostra em "O que a noite fez", junto da comida e da água. As telas usam os textos de
`data/night-events.json`, que passaram pela regra de consistência (`narrative-design.md`, seção 14) na rodada 3
(abaixo).

## 5. A troca de formação na exploração (#129)

- **FORMAÇÃO** entra ao lado de MOCHILA e MENU, com uma tecla nova trocável (proposta: R, que a #129 tira da chuva).
  Ligada, ganha a moldura âmbar. Só fora da luta e dos eventos.
- **As plaquinhas em modo de troca:** o medalhão da posição em cada uma (1 é a frente), a faixa "Formação · da frente
  para trás · escolha dois para trocar", o foco do teclado; o mesmo número sobre a cabeça de cada herói na rua.
- **Um escolhido:** a moldura âmbar e a marca da troca no canto; a faixa diz o que acontece ("E troca Nick e Íris de
  lugar", sem artigo: os heróis não têm gênero nos dados). Clicar no segundo troca os dois; vale para a próxima luta e para a fila na rua.
- A barra das teclas: Setas escolhem, E troca, Esc fecha.

## Ícones novos

Em `art/ui/kit/station/icons/`, glifos brancos de 64 px para tingir (`glyph_white_tintable` nos dois manifestos,
[assets.json](../../art/ui/kit/station/assets.json) e [hud-station/assets.json](hud-station/assets.json)). Gerados no
Nano Banana Pro numa folha 4x2 sobre magenta e recortados por [cut_glyphs.py](hud-ajustes2/cut_glyphs.py), o mesmo
recorte do lote 7.

![Os glifos novos](hud-ajustes2/glyphs.webp)

| Ícone | Uso |
|---|---|
| `lock` | O cômodo bloqueado (os marcadores, RECUPERAR travado) |
| `weather` | A aba Clima do Admin |
| `admin` | A barra de Admin |
| `skip` | PULAR a noite |
| `night` | A noite (o cartão, "O que a noite fez", a noite calma) |
| `night_rat` | O evento do rato na despensa |
| `night_talk` | O evento da conversa de um morador |

A folha tinha uma oitava célula, a goteira, que ficou de fora: o cano fino sumia a 32 px. O evento da goteira usa o
recurso pintado da água. A prancha mostra cada glifo a 64, 32 e 22 px; a [prancha em cinza](hud-ajustes2/glyphs_gray.webp)
confere a leitura sem cor.

## As montagens de before/

A cena 3D da Estação não abre no xvfb sem placa de vídeo. [build_bg.py](hud-ajustes2/build_bg.py) monta, só com as
capturas do jogo:
- `station_markers_clean.webp`: a Visão geral com a Enfermaria vazia (as paredes do Centro de Pesquisa, sem móveis, na
  penumbra, como o cômodo vazio fica no jogo) e o Bar na penumbra;
- `station_markers_clean.webp` também deixa o Dormitório na penumbra (nível 0, com os beliches);
- `station_night_clean.webp`: a Visão geral do lote 7 com a Enfermaria, à noite (a captura a 0,3, puxada para o azul),
  com só o Dormitório e a Enfermaria acesos, baixos; quem estava de pé no Dormitório sai (o trecho do outro beliche), o
  Bento e o Nick deitam nos beliches, e a Preparação fica no escuro (quem estava lá, a Íris e o Bento, não aparece).

As telas da luta usam as capturas limpas de `loop-screens/before/` e `hud-ajustes/before/`; a exploração, a de
`hud-v2/before/`; o amanhecer, a Visão geral do Dia 5 do lote 7 (`hud-casa/before/station_day5_clean.webp`).

## O que mudou fora desta pasta

- `hud-luta/render.mjs`: `combat()` aceita `bottom` (junto do `aim` da `main`), que troca o painel do herói da vez e as habilidades (a inspeção).
  Sem ele, a luta sai como antes.
- `hud-casa/render.mjs`: exporta a barra do alto com os limites e as outras peças que este lote usa, aceita o estoque
  na barra e não gera nada quando é importado; lê o `before/fight_fallen.json` só ao desenhar a tela da luta (a `main`
  tirou esse rascunho do repositório). As telas do lote 7 saem iguais.

## Para integrar (é do Claude)

As telas mostram o jogo de hoje; nada aqui pede mudar regra ou número. O que mudaria regra está em "Para o Lucas
decidir".

- **#128:** a ação de inspecionar reaproveita `combat_examine`; os detalhes vêm de `AHCharacterSheet.from_unit`; a
  plaqueta da intenção perde o "→ alvo" e fica com o ícone e o nome; o popup ganha o X e a pausa com o mouse em cima, e
  `POPUP_HOLD` passa a 5 s.
- **#130:** a ação `admin_toggle` em `tools/define_input.gd`; a barra é uma CanvasLayer por cima de tudo, só na build
  de desenvolvimento ou com `--admin`.
- **#131:** as placas leem `AHStationRules.next_level_cost` e `upgrade_block`; o foco nelas segue as setas, como os
  cômodos.
- **#132:** o painel do amanhecer lê o resultado de `resolve_night` (`night.results`, `supplies_consumed`,
  `night_event_text` e `night_conditions_text`); a comida é a do jogo (aqui, 8 → 6).
- **#132, a cena da noite:** para mostrar a Lupa e o Brasa dormindo, a integração precisa da pose de dormir dos
  recrutas, que é uma tarefa do Codex (poses de personagem). Sem essa pose, a cena fica como a montagem (os recrutas
  fora do corte) e nenhum texto da noite pode dizer que eles dormem.
- **#129:** a ação nova de formação em `tools/define_input.gd` (trocável nas Opções); a troca usa
  `AHStationRules.set_formation` na expedição.

## Para o Lucas decidir

Propostas deste lote que mudariam regra ou número do jogo. Nenhuma está nas telas nem em `data/`; ficam aqui até a
decisão (na #132 ou na #131):
- **A comida da noite:** o lote 7 ([hud-casa.md](hud-casa.md), já na `main`) mostra o Dia 5 com 4/12, pela previsão
  (`AHStationRules.forecast` desconta a noite de todos que voltam); o `resolve_night` desconta só quem dorme, e o
  amanhecer deste lote mostra 6/12. Ou a previsão passa a descontar só quem dorme, ou a noite passa a cobrar de todos.
- **O custo da Enfermaria:** a primeira versão deste lote propunha 4 sucatas e 2 fragmentos; hoje é 4 e 1
  (`data/recovery.json`), e as telas seguem o de hoje.
- **O título do evento no amanhecer:** um título curto por evento (como "Véspera viu luzes ao longe") no lugar de "A
  noite". Pede um campo novo em `data/night-events.json` e textos novos, que passam pela regra de consistência.
- **O vigia e o sorteio:** a primeira versão dizia que o vigia diminuía as chances de uma noite ruim; o jogo de hoje
  não muda o sorteio (o vigia só evita as perdas). Fica como ideia, se o Lucas quiser que vigiar pese no sorteio.
- **O ícone das baratas:** o glifo `night_rat` desenha um rato, e na lore os roedores são povos (o jogo trocou o rato
  da #132 por baratas). Redesenhar o glifo como baratas (e renomear) ou trocar por outro ícone antes de integrar.

## Como refazer

A imagem bruta fica fora do Git, em `images/hud-ajustes2/ajustes-glyphs-sheet.png` do projeto na Awesomic.

Da raiz do repositório, depois das montagens do lote 7 ([hud-casa.md](hud-casa.md)):
1. `python3 -B docs/design/hud-ajustes2/cut_glyphs.py <ajustes-glyphs-sheet.png>` e
   `python3 -B docs/design/hud-ajustes2/glyph_sheet.py`: os glifos e a prancha.
2. `python3 -B docs/design/hud-ajustes2/build_bg.py`: as montagens de `before/`.
3. `python3 -m http.server 8765 --bind 127.0.0.1` e, noutro terminal,
   `node docs/design/hud-ajustes2/render.mjs http://127.0.0.1:8765`.
4. `python3 -B docs/design/hud-ajustes2/compose.py`: as reduções, o cinza, o antes e depois e o `checks.json`.

A pasta `.render/` é temporária e fica fora do Git.

## QA de design

As rodadas seguem [qa.md](qa.md) e ficam registradas abaixo e no PR.

### Rodada 1: REPROVADO

Aprovados na rodada: a cobertura da #134, o escopo, os glifos, a reprodução byte a byte, as telas da hud-luta e da
hud-casa saindo iguais e a coerência com o jogo e com a história do lote 7.

**Alta, corrigido:** no Maior, o cartão do foco cobria a própria placa da Enfermaria. O cartão agora toma o lugar do
Próximo passo, no alto à esquerda, e a coluna da esquerda é `data-hit="panel"` (a conferência passa a valer).

**Média, corrigidos:**
- A aba da inspeção cobria a primeira linha da coluna da direita: a coluna começa abaixo da aba.
- O Dormitório aparecia recuperado no Dia 2: na penumbra, com a placa "Numa próxima fase".
- O fundo da noite contradizia o cartão: o Bento e o Nick deitados nos beliches, a Forja apagada e vazia, a Preparação
  no escuro; o cartão diz quem aparece ("O Bento e o Nick dormem no Dormitório, a Véspera vigia no Depósito…").

**Baixa, corrigidos:**
- O Próximo passo do Dia 2 com o texto de `next_step`.
- A página: o Dia 2 é dois dias antes da volta; as medidas novas.
- A intenção na cor de hoje; o "antes" da intenção é a captura do jogo, com o "→ um de 4".
- A tabela dos eventos diz como ela convive com o `resolve_night` de hoje.
- O Admin: os fundos e os números do Dia 5; a tempestade no Clima; curar a equipe em Heróis.
- A faixa da formação sem artigo.

### Rodada 2: APROVADO

As correções da rodada 1 conferidas nas telas e no código; as telas e as montagens reproduzem byte a byte; 76 de 76.
Observações baixas, aplicadas depois do veredito:
- a intenção no laranja de hoje (`S.ENEMY`), e não no vermelho claro do nome;
- a coluna do meio da inspeção alinhada no alto, abaixo da aba; na máquina, sem a explicação da velocidade (que o
  herói já mostra), para a intenção caber no Maior;
- a conta da comida da noite (8 → 4, do lote 7) fica anotada em "Para integrar", para acertar os dois lotes juntos.

### Rodada 3: a revisão do PR (AJUSTAR ANTES) e a `main` trazida

- A `main` entrou no branch (merge, sem rebase): o #139 já estava lá, e o PR passa a ter só este lote. Os conflitos
  foram em `hud-casa/render.mjs` (as posições novas da Enfermaria, da `main`, com os `export` deste lote) e em
  `hud-luta/render.mjs` (o `aim` da `main` e o `bottom` deste lote, juntos). O `hud-casa/render.mjs` lê o
  `fight_fallen.json` só ao desenhar aquela tela, porque a `main` tirou os rascunhos de `before/`.
- **Média, corrigido:** os números e as regras que não eram de design. As telas mostram o jogo de hoje: a Enfermaria
  custa 4 sucatas e 1 fragmento ("Falta 1 fragmento", 2 dias no leito, 3 no Dormitório); a noite come 1 suprimento por
  quem dorme (8 → 6, também no Admin); os eventos são os de `data/night-events.json`, com os textos do jogo; a fome e a
  sede ficam como condições da noite, como o jogo faz. O que mudaria regra foi para "Para o Lucas decidir".
- **Narrativa:** os textos da noite passaram pela regra de consistência (seção 14). "As lanternas da patrulha" saiu
  (sugeria gente na Ponte, onde só há sensores e máquinas) e o texto passou a ser o do jogo; "Rato na despensa" virou
  as baratas do jogo (os roedores são povos na lore), com o glifo para o Lucas decidir; "as chances de uma noite ruim
  caem pela metade" prometia uma regra que não existe e saiu. As falas da Dora, do Otto e da Cora são as do jogo
  (`talk_*`): cada uma cabe no ofício do morador (as sementes, o gerador, os fragmentos) e não revela nada cedo.
- **Baixa:** as cartas da Enfermaria (`art/station/cards/Infirmary_*`) vieram com o #139 e não estão mais no diff
  deste PR.
- **Baixa:** a cena da noite: "Para integrar" diz que a Lupa e o Brasa dormindo pedem a pose de dormir dos recrutas
  (Codex); sem ela, nenhum texto diz que eles dormem.
- As telas e as provas foram refeitas (`render.mjs` e `compose.py`): 76 de 76 nas conferências, o menor texto com 20 px.
  Mudaram a Estação com os marcadores, o amanhecer e as abas do Admin sobre a Estação do Dia 5 (o fundo e o "Caído" da
  `main`).
