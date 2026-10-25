# O kit da HUD no jogo (#60)

A biblioteca de componentes (`scripts/ui/kit/`) com as peças do Codex aprovadas pelo Lucas (#97 e #104), aplicada na
HUD da luta e nas duas telas da Estação (relatório da volta e Sala dos Personagens). As medidas e os passos são os de
[hud-target.md](../design/hud-target.md) e [hud-station.md](../design/hud-station.md).

## A biblioteca

- **`AHKit`** (`scripts/ui/kit/kit.gd`):
  - lê os dois `assets.json` (`art/ui/kit/combat` e `art/ui/kit/station`);
  - `style(peça)` monta o StyleBoxTexture: `nine_slice_ltrb` nas `texture_margin_*`, o recuo de `content_xywh` nas
    `content_margin_*` e `TILE_FIT` nas peças grandes (`report_band`, `panel_large`);
  - `style_button` dá os quatro estados: normal, foco (a peça `_focus` ou a moldura âmbar), apertado e desligado;
  - as fontes são a Barlow Condensed Medium e SemiBold. Os tamanhos de cada uso (`SIZE`) passam pelo
    `AHUiStyle.px()`, então o texto Maior (130%) vale na hora;
  - as cores dos alvos, com as do daltonismo. O Instinto fica em ferrugem e o XP em violeta (decisões do Lucas);
  - os estados de vida (decisão do Lucas): Em forma acima de 75%, Ferimento leve de 50% a 75% e Ferimento grave abaixo
    de 50%.
- **Componentes:**
  - `AHKitKey`: a tecla em aba, com o nome da tecla de uma ação, que acompanha as trocas das Opções;
  - `AHKitBar`: a calha (`main_bar`, ou `health_ally`/`health_enemy`, com a aba e o recorte) e o preenchimento
    tingido, com o valor por dentro;
  - `AHKitPill`: a pílula de estado de vida, com o ícone e o rótulo.

  Os três recolorem no `restyle()` quando o daltonismo muda.
- **O anel de quem age** (`scripts/combat/actor_ring.gd`): a peça `actor_ring` num plano deitado no chão, sob os pés,
  com teste de profundidade. O corpo esconde a parte de trás, e a profundidade do plano sai da inclinação da câmera,
  para a elipse ter a proporção do desenho na tela.
- **Galeria:** `tools/capture_kit.gd` mostra as peças e os componentes sobre o aço.
- **Teste:** `tests/test_kit.gd` confere o manifesto, as margens, o TILE_FIT, as fontes, o Maior, os limites dos
  estados, as cores do daltonismo e a tecla.

## A luta

![alvo e jogo, texto Normal](kit/combat.jpg)

![alvo e jogo, texto Maior](kit/combat_large.jpg)

![alvo e jogo, daltonismo](kit/combat_colorblind.jpg)

![alvo e jogo, Maior com daltonismo](kit/combat_large_colorblind.jpg)

À esquerda, o alvo aprovado (`docs/design/hud-target/hud*.webp`); à direita, o jogo, com as fotos de
`tools/capture_combat_kit.gd`. As peças estão nas posições do alvo (na base de 1920x1080):

- **Registro:** no alto à esquerda, com a tecla L em aba. Um clique abre as últimas linhas logo embaixo.
- **Faixa da rodada:** "RODADA n", a linha com o ponto e os retratos quadrados da ordem. As máquinas têm o fundo
  avermelhado, e quem age, a borda âmbar.
- **Vida sob as unidades:** as barras de 200x44, com a aba no herói e o recorte na máquina. Quem age ganha os cantos
  âmbar.
- **Anel:** sob os pés de quem age, no chão.
- **Nome do alvo:** a plaqueta escura com a linha na cor do lado, acima do apontado.
- **Painel do herói:** o retrato quadrado grande, o nome, a vida e o instinto.
- **Habilidade:** a aba "ESCOLHA UM ALVO" (na vez: "VEZ DE NICK"), a barra com o ícone, o nome e a faixa de dano, e
  os quatro slots com a tecla na aba. A escolhida ganha os cantos âmbar.
- **Ações:** a grade 2x2, com o ícone branco e a tecla em aba. F é a porta com a seta de saída.

![a vez, a dica e o fim da luta](kit/combat_states.jpg)

A dica, a tela do fim e o registro também passaram para o aço e a Barlow do kit.

**O que ficou diferente do alvo, e por quê:**
- **A intenção das máquinas continua:** uma plaqueta pequena acima da barra delas ("Pega-Pega → um de 4"). O alvo não a
  mostra, mas ela é a informação que diz o que a máquina vai fazer. A barra fica na linha das outras.
- **A aba diz o que fazer na vez:** "VEZ DE NICK", e na mira "ESCOLHA UM ALVO". A instrução inteira ("escolha uma
  habilidade (1–4) ou uma ação"; "clique no personagem e clique de novo para usar") fica na dica da aba.
- **Usos e recarga** aparecem numa aba pequena no alto do slot, quando existem. O alcance e a descrição completa ficam
  na dica da habilidade.
- **A ordem é a da sessão real,** e não a ilustração do alvo.

## A Estação

(Na próxima entrega deste PR.)

## Testes

- `tests/run_all.gd` passa inteiro.
- `tests/test_kit.gd` é novo.
- `tests/test_screen_fit.gd` confere os cantos de escolhida na habilidade (a camada `Selected`, `selected_slot`).
