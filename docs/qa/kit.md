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
  habilidade (1–4) ou uma ação"; "clique no alvo e clique de novo para usar") fica na dica do kit da habilidade e do
  alvo apontado, que abre com o mouse, o foco e o toque.
- **Usos e recarga** aparecem numa aba pequena no alto do slot, quando existem. O alcance ("Sai das posições 1 · 2 ·
  alcança 1 · 2") e a descrição completa ficam na dica da habilidade.
- **As áreas de toque** são as do alvo (Registro 272x112, ações 128x112, habilidades 140x140), numa camada invisível em
  volta de cada botão: o desenho continua com as medidas do alvo.
- **A ordem é a da sessão real,** e não a ilustração do alvo.

## A Estação

### O relatório da volta

![alvo e jogo, texto Normal](kit/report.jpg)

![alvo e jogo, texto Maior](kit/report_large.jpg)

![alvo e jogo, daltonismo](kit/report_colorblind.jpg)

![alvo e jogo, Maior com daltonismo](kit/report_large_colorblind.jpg)

![os detalhes (VER DETALHES), Normal e Maior](kit/report_details.jpg)

O relatório é a tela inteira (`scripts/ui/station/station_report.gd`), por cima da fila na plataforma. O título, os
recursos e o canto da Estação saem enquanto ele está aberto.
- **A faixa do alto:**
  - a fase e o resultado;
  - os chips do que aconteceu: o guardião, o lugar liberado na primeira vitória da fase, e o objetivo da rota,
    cumprido ou não;
  - a dica da noite;
  - os recursos recuperados.

  No Maior, a faixa cresce para baixo e os chips quebram em duas linhas. O nome longo da fase diminui até caber.
- **As cartas:** uma por herói, na ordem da fila, com o topo em y 678 e 416 px entre os centros.
  - Cada carta tem o retrato, o nome, a classe, a pílula do estado, o XP da volta, a vida e os contadores
    (Expedições e Abates da carreira).
  - Tem também a relíquia e a aba "Melhoria · 3 frag." quando a Pesquisa da classe está aberta.
  - O destaque da volta ganha a ★.
  - **A fila fica alinhada às cartas** (ajuste da revisão do #104): cada herói fica de pé sobre o centro da sua carta,
    pela chave da câmera do relatório, e nenhuma carta corta um herói.
- **VER DETALHES (V/LB)** troca as cartas pela segunda faixa: o que a equipe viu, o que chegou, a Estação no ciclo e
  "Agora dá para". VER A EQUIPE volta.
- **ENTRAR NO ABRIGO (E/A)** segue para a noite, o trem ou o cômodo.

### A Sala dos Personagens

![alvo e jogo, texto Normal](kit/characters.jpg)

![alvo e jogo, texto Maior](kit/characters_large.jpg)

![alvo e jogo, daltonismo](kit/characters_colorblind.jpg)

![alvo e jogo, Maior com daltonismo](kit/characters_large_colorblind.jpg)

![o Treino, Normal e Maior](kit/training.jpg)

A Sala (`scripts/ui/station/character_room.gd`) também é a tela inteira:
- **No alto:** a plaqueta, Comida, Água e Energia, e a engrenagem (as Opções).
- **À esquerda:** as abas dos heróis, as HABILIDADES e o detalhe da escolhida (a faixa com o treino da Pesquisa e do
  nível, as posições e em quem vale).
- **No meio:** o herói de corpo inteiro, na pose idle com a respiração, sobre a sombra.
- **À direita, o painel PERSONAGEM:**
  - "Fundador" nos quatro do começo e "Recruta" nos que vieram pelo trem (decisão do Lucas);
  - o nível, o XP em violeta e TREINAR (bloqueado, diz o que falta);
  - a vida, a velocidade e o instinto em ferrugem;
  - a relíquia (com Trocar), o trauma (com Tratar), os contadores e os traços pintados com o + e o −.
- **Embaixo:** VOLTAR, + RECRUTAR (o recrutamento e o Memorial, que estavam no painel antigo), as teclas, as abas da
  Estação e PREPARAR EXPEDIÇÃO (G/X). Bloqueado, o motivo fica dentro do botão.
- **O fundo é o próprio cômodo** (ajuste da revisão do #104): a câmera enquadra o Alojamento entre os dois painéis, sem
  a plataforma nem o trem. Os moradores do cômodo somem enquanto a Sala está aberta.
- **TREINAR** abre o diálogo com as duas melhorias da espécie. A escolhida ganha a moldura âmbar; TREINAR confirma e
  CANCELAR volta.

**As teclas novas** (decisão do Lucas, só nas telas da Estação):
- `report_details` (V/LB) e `station_prepare` (G/X), em `tools/define_input.gd`;
- as duas podem ser trocadas nas Opções.

**O que ficou diferente do alvo, e por quê:**
- **Os ícones de recurso pintados ainda não existem** (ajuste da revisão do #104). O código já procura
  `art/ui/kit/station/icons/resource_<seeds|scrap|fragments|water|supplies|food|power>.webp` e usa o pintado quando
  ele existir. Até lá, mostra o SVG do jogo. **Pendente para o Codex.**
- **Abates** é a conta da carreira (`kills_count`, que existia no herói sem ser contado). A volta agora soma nela as
  máquinas derrubadas. Os saves antigos começam do zero.
- **+ RECRUTAR** fica ao lado de VOLTAR: as quatro abas dos heróis enchem a coluna, como no alvo.
- **O fundo da Sala é mais aberto que o do alvo:** a câmera mostra o Alojamento inteiro numa faixa atrás do herói.

## Rodadas da QA

1. **A luta, reprovada.**
   - **Alta:** a intenção das máquinas cobria o corpo delas no Maior (a #63 voltou). Corrigido: passando de um quinto
     do corpo, a placa inteira vai para cima da cabeça. A largura da intenção desconta as margens da plaqueta. O teste
     novo `test_plates_crowd` cobre uma luta de quatro máquinas, no Normal e no Maior.
   - **Médias, todas corrigidas:**
     - o tooltip nativo saía junto com a dica do kit;
     - a instrução da aba não chegava ao jogador;
     - o alcance das habilidades tinha sumido;
     - a aba do Examinar era larga demais no Maior;
     - o retrato do Rastejante saía vazio. Agora o recorte cai no corpo inteiro, e um teste confere todos os
       retratos;
     - a ficha estava na fonte antiga e cobria o nome do alvo. Agora está no aço e na Barlow, e o nome fica por cima;
     - as áreas de toque eram menores que as do alvo.
   - **Baixas corrigidas:** a crise em ferrugem e o anel saindo já na tela do fim.

## Testes

- `tests/run_all.gd` passa inteiro.
- `tests/test_kit.gd` é novo, e confere também que nenhum retrato da ordem sai vazio.
- `tests/test_plates_crowd.gd` é novo: as placas de quatro máquinas não cobrem o corpo nem umas às outras.
- `tests/test_hero_levels.gd` treina pela Sala nova: TREINAR, a melhoria e a confirmação.
- `tests/test_screen_fit.gd` confere os cantos de escolhida na habilidade (a camada `Selected`, `selected_slot`).
