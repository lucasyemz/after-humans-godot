# Direção de arte da interface: personalidade

## Padrão de componentes: o kit da Awesomic (decisão do Lucas, 25/10/2026)

A HUD tem dois kits de peças:
- **o da luta, feito pelo Codex:** `art/ui/kit/combat`, com 18 peças;
- **o da Estação, da exploração e do fluxo, feito pelo agente da Awesomic:** `art/ui/kit/station`, com 60 peças (45
  antes do lote 4, 57 antes do lote 5, 58 antes do lote 6), os estados de cada uma (foco, pressionado, desabilitado,
  selecionado) e as conferências de `docs/design/hud-kit/lib.mjs`.

O Lucas achou o da Awesomic mais completo, e **ele é o padrão** de toda a HUD, inclusive a luta.

- **Componentes genéricos vêm do kit da Awesomic em todas as telas.** A luta usa os mesmos, e não as versões do Codex:

  | Componente | Peças da Awesomic | Equivalente do Codex que deixa de valer |
  |---|---|---|
  | Painel | `panel_large`, `panel_inset` | `panel`, `hero_panel` |
  | Plaqueta | `room_plaque` | `register` |
  | Botões | `primary_button` (e os estados), `secondary_button`, `icon_button`, `chip_button` | `action_button` |
  | Barras | `main_bar` com `bar_fill` tingido (ciano nos heróis, vermelho nos inimigos) | `health_ally`, `health_enemy`, `active_health` |
  | Abas, chips e listas | `card_tab`, `status_pill`, `cost_chip`, `list_row`, `nav_tab` | — |
  | Teclas | `keys_bar`, `button_key` | — |
  | Foco | `focus_frame`, `selected_frame` | — |
- **As peças da luta que já entraram no kit da Awesomic** (`reuses_combat_kit` no `assets.json`) continuam como estão:
  `square_portrait`, `key_tab`, `main_bar`, `selected_slot` e `steel_material`.
- **As peças só de luta sem equivalente** continuam do kit do Codex até ganharem versão no mesmo padrão:
  - `round_strip` (a ordem da rodada);
  - `ability_header`, `ability_slot` e `target_tab` (as habilidades);
  - `actor_ring` (o anel no chão);
  - a forma do inimigo no daltonismo.

  O agente da Awesomic redesenha essas peças no mesmo padrão e com os mesmos estados, e elas entram no manifesto
  dele. Depois disso, `art/ui/kit/combat` fica só como histórico, como o kit de latão (`v2`).

  **Estado:** redesenhadas no lote 4, [hud-luta.md](hud-luta.md), com a tela da luta montada só com o kit, lado a lado
  com o alvo. O manifesto da Awesomic diz, em `replaces_combat_kit`, o que substitui cada peça do Codex.
- **No código (#60):** a biblioteca `scripts/ui/kit` expõe **componentes** (Painel, Plaqueta, Botão com os estados,
  Barra, Chip, Aba, Linha de lista, Tecla, Carta), e não arquivos de arte. Cada componente lê a peça do manifesto da
  Awesomic. A luta, a Estação, a exploração e o fluxo usam os mesmos componentes. Trocar uma peça muda todas as telas.
- **Peça nova** entra sempre no manifesto da Awesomic, no mesmo padrão: o chanfro, o bisel, o canto âmbar, o
  9-slice, os estados e as conferências do `lib.mjs`.

## Alvo aprovado da luta (25/10/2026)

O Lucas refez por cima a versão C do Codex e aprovou o resultado como **o alvo da HUD da luta**:

- **O alvo:** [reference/hud-target-2026-10-25.webp](reference/hud-target-2026-10-25.webp).
- **A versão do Codex que serviu de base:** [reference/hud-codex-c-2026-10-25.jpg](reference/hud-codex-c-2026-10-25.jpg),
  igual a `docs/design/hud-c/target.webp` no `codex-design`.

Onde este alvo e o resto da página discordam, **vale o alvo**: metal escuro e cantos chanfrados com detalhe âmbar, em
vez de latão ornamentado; letra condensada, em vez da serifada. As raízes e a luz ciano continuam, mas com moderação.

**Entrega e QA contra o alvo:** [hud-target.md](hud-target.md), com comparações nos quatro perfis e o kit WebP/9-slice.

### O que muda da versão C para o alvo

| Peça | Versão C (Codex) | Alvo (Lucas) |
|---|---|---|
| **Material** | Latão com pontas enroladas, estilo steampunk ornamentado | Aço escuro (grafite) arranhado, com bisel fino, cantos **chanfrados** e **um detalhe âmbar** em dois cantos opostos de cada peça |
| **Letra** | Serifada em versalete (Cinzel) | **Sem serifa condensada, em caixa alta,** branco-creme (por exemplo, Barlow Condensed SemiBold ou Oswald, ambas OFL) |
| **Ordem da rodada** | Plaqueta solta e silhuetas redondas escuras, difíceis de ler | Uma faixa só: a plaqueta "RODADA 1", uma linha com um ponto e **retratos quadrados coloridos** (fundo avermelhado nos inimigos). O da vez tem a borda âmbar |
| **Barras sob os personagens** | Cilindros de latão, inimigos em marrom e o número da posição em cima | Barra chanfrada curta com o número dentro: **ciano nos heróis, vermelho nos inimigos**. Sem o número da posição |
| **Quem age** | Nada no chão | **Anel âmbar com setas no chão**, sob o herói da vez, e cantos âmbar na barra dele |
| **Nome do alvo** | Plaqueta ornamentada | Plaqueta escura pequena, com a barra vermelha fina embaixo |
| **Herói da vez** (embaixo, à esquerda) | Retrato redondo pequeno e peças soltas | **Um painel só:** retrato **quadrado grande e colorido** (cerca de 200 px), o nome, a barra de vida ciano e a barra de instinto escura, encaixados |
| **Habilidades** (embaixo, no meio) | Ícones apagados, número em círculo embaixo, "Escolha um alvo" longe, à direita | Uma aba pequena "ESCOLHA UM ALVO" em cima. A barra com o ícone, o nome e o alcance ("4-6") numa divisão à direita. Embaixo, **4 quadrados grandes (cerca de 130 px) com ícones vivos.** A selecionada tem moldura âmbar, e o número fica numa aba no canto inferior direito |
| **Ações** (embaixo, à direita) | Losangos soltos | **Grade 2x2 de botões quadrados chanfrados:** ícone branco de linha, a tecla numa aba no canto e o detalhe âmbar |
| **Registro** | Plaqueta de latão | A mesma peça chanfrada escura, com a tecla L numa aba |

### Medidas de referência (tela de 1920 x 1080, medidas do alvo)

- **Registro:** x 46–316, y 34–92.
- **Faixa da rodada:** x 637–1355, y 30–94. Retratos de cerca de 63 px.
- **Barras sob os personagens:** cerca de 200 x 40 px, com o topo em y ≈ 763.
- **Painel do herói da vez:** x 63–626, y 836–1045. Retrato de cerca de 207 px.
- **Habilidades:**
  - a aba do alvo em y ≈ 822;
  - a barra do nome em x 685–1303, y 852–901;
  - os quadrados de cerca de 132 px, em y 913–1039.
- **Ações:** grade em x 1584–1848, y 847–1047. Botões de cerca de 120 px.

### Cores de referência

| Uso | Cor |
|---|---|
| Painel | Grafite `#1b1d20` a `#25282c`, com textura de metal arranhado |
| Bisel | `#3a3e44` |
| Detalhe e foco | Âmbar `#f0a020` |
| Vida dos heróis | Ciano `#2fb6bd`, com a borda clara |
| Vida dos inimigos | Vermelho `#d23a2e` |
| Texto | Creme `#efe6d6` |

### Cuidados

- No alvo, a quarta ação (F) tem uma mira, mas **F é Fugir:** usar o ícone de saída da versão C.
- **Continua valendo:**
  - o texto Maior;
  - o daltonismo (a vida dos heróis e a dos inimigos se diferem também pela forma: a aba do herói e o recorte do
    inimigo);
  - o teclado, o controle e o toque.
- **O mesmo idioma vale para as outras telas** (Preparação, fim de luta, ficha, Estação): a mesma chapa chanfrada, o
  mesmo âmbar e a mesma letra.

### Estado (25/10)

O Codex entregou o kit da luta no PR #97 (`codex-design`):
- as peças em `art/ui/kit/combat/`, com as margens de 9-slice em `assets.json`;
- as fontes Barlow Condensed (Medium e SemiBold, OFL) em `art/ui/fonts/`;
- a comparação com o alvo e a QA em `docs/design/hud-target.md`.

O kit de latão (`art/ui/kit/v2/`) fica só como histórico. A integração no jogo é da #60 (Claude).

O relatório da volta e a Sala dos Personagens (os alvos da Estação, abaixo) estão no branch `design-station`:
- as peças estão em `art/ui/kit/station/`;
- as telas, as comparações e as medidas estão em [hud-station.md](hud-station.md).

## Como produzir as peças (qualquer agente com geração de imagem)

A imagem gerada é matéria-prima e referência. O jogo recebe peças limpas, medidas e sem texto.

- **Molduras, chapas, abas e botões:** desenhadas por código (SVG ou Python com Pillow), com o chanfro, o bisel e o
  detalhe âmbar exatos, nas medidas do alvo e com as margens de 9-slice. A textura de aço vem por cima (veja o próximo
  item). Assim a borda fica nítida, e todas as peças combinam entre si e com `art/ui/kit/combat/`.
- **Textura de aço arranhado:** uma imagem gerada, repetível (seamless), em tons neutros. Ou recortada dos alvos do
  Lucas, que são do projeto.
- **Ícones pintados** (traços, chips de resultado, recursos):
  - gerados em folhas por família, com o mesmo prompt de estilo, sobre um fundo chapado magenta (`#FF00FF`);
  - recortados por código para ter o alfa limpo;
  - leitura conferida a 32 e a 64 px.
- **Maquete da tela inteira:** gerada com a captura real do jogo e o alvo como referências, só para comparar e aprovar.
  Nunca vai para o jogo.
- **Texto nunca na imagem:** a Godot escreve todo texto com a Barlow Condensed (traduzível e no texto Maior).
- **A prova de que chegou perto:** cada peça e cada tela lado a lado com o alvo, no Normal, no Maior e no daltonismo.

## Alvos aprovados da Estação (25/10/2026)

O Lucas fez mais dois alvos no mesmo idioma da luta: a mesma chapa, o mesmo âmbar, a mesma letra, e as mesmas cores de
vida. As peças da luta (`art/ui/kit/combat/`) são a base; o que falta entra como peça nova no mesmo kit.

### Relatório da volta (a chegada na Plataforma 1)

**O alvo:** [reference/hud-target-report-2026-10-25.webp](reference/hud-target-report-2026-10-25.webp).

**Faixa do alto,** de ponta a ponta, uma chapa só com divisões:
- **À esquerda:**
  - o ícone da Estação e a linha pequena "ESTAÇÃO RAIZ · RELATÓRIO DA EXPEDIÇÃO";
  - o nome da fase em letra muito grande (cerca de 70 px em 1920);
  - "Expedição concluída", com o círculo verde de check.
- **No meio,** três chips de resultado, cada um com o ícone e duas linhas:
  - "Guardião derrotado" (escudo com check);
  - "Ponte das Raízes liberada" (cadeado aberto);
  - "Objetivo: água não cumprido" (gota com X, em vermelho).
  - Embaixo, a dica com o ícone da cama: "Descanse no Dormitório antes da próxima expedição."
- **À direita,** "RECURSOS RECUPERADOS" em quadrados de ícone grandes, com o número em âmbar ("+17") e o nome
  embaixo.

**Uma carta por herói,** embaixo de cada um na plataforma:
- **Aba no alto:** "Melhoria · 3 frag.", com o ícone âmbar.
- **Cabeçalho:** o retrato quadrado, o nome, a espécie e o papel.
- **O estado numa pílula com ícone:**
  - verde: Ativo;
  - âmbar: Levemente ferido;
  - vermelho: Ferido.
- **A barra de VIDA:** ciano, e vermelha quando baixa.
- **Os números:** Expedições e Abates, com os ícones.
- **A linha da relíquia:** "Sem relíquia" ou o nome dela.

**Embaixo, no meio,** o botão principal âmbar "ENTRAR NO ABRIGO", com a tecla numa aba ("Enter / A").

### Sala dos Personagens

**O alvo:** [reference/hud-target-characters-2026-10-25.webp](reference/hud-target-characters-2026-10-25.webp).

- **Barra do alto:**
  - à esquerda, a plaqueta com o ícone e "ESTAÇÃO RAIZ / Sala dos Personagens";
  - à direita, os chips de Comida, Água e Energia, cada um com o ícone, o rótulo, o valor em âmbar e a linha de
    baixo;
  - o botão de opções (a engrenagem).
- **Coluna da esquerda:**
  - as abas dos heróis em retratos quadrados com o nome (a escolhida com a borda âmbar);
  - "HABILIDADES": quatro linhas com o ícone e o nome (a escolhida com a borda âmbar);
  - a caixa do detalhe:
    - o nome e o dano em âmbar ("Dano 5–8");
    - as posições de origem e de alvo;
    - a descrição;
    - a etiqueta do alvo ("Inimigo").
- **No meio,** o herói de corpo inteiro na sala, sem moldura.
- **Painel da direita, "PERSONAGEM",** com o X para fechar:
  - a linha pequena âmbar "SOBREVIVENTE DA ESTAÇÃO";
  - o nome grande, a espécie e o papel em âmbar, e o estado em verde ("Estável");
  - a VIDA com a barra ciano, a VELOCIDADE e o INSTINTO com a barra;
  - a relíquia e a linha dos números;
  - "TRAÇOS" em duas colunas:
    - PONTOS FORTES (verde, com +);
    - PONTOS FRACOS (vermelho, com −);
    - cada traço num quadrado de ícone com o nome e o efeito.
- **Embaixo:**
  - VOLTAR à esquerda e a barra das teclas no meio;
  - as abas de navegação: VISÃO GERAL, INSTALAÇÕES, PERSONAGENS (ativa, sublinhada em âmbar), PESQUISA, OCULTAR HUD;
  - o botão principal âmbar "PREPARAR EXPEDIÇÃO".

### Cuidados nestes dois alvos

- **Os nomes de classe são os do jogo,** não os da imagem: Gato Batedor (e não "Gato Assassino") e Coruja Atiradora
  (e não "Coruja Sniper"). Os números das imagens são de exemplo.
- **O relatório de hoje tem mais que o alvo:** "O que a equipe viu" (o texto da história), "O que chegou" e "A Estação
  no ciclo" (produção e consumo). Nada disso some: entra numa segunda faixa ou num "Ver detalhes" no mesmo idioma.
- **A Sala dos Personagens precisa também do nível, do XP e do Treino (#90):**
  - no painel PERSONAGEM, o nível num medalhão e a barra de XP;
  - o botão "TREINAR";
  - a escolha de 1 de 2 melhorias, no mesmo idioma.
- **Ícones novos:**
  - os oito traços de `data/perks.json`: Ágil, Corajoso, Esperançoso, Companheiro fiel, Lento, Ansioso, Pessimista,
    Temor das máquinas;
  - os chips de resultado: guardião, lugar liberado, objetivo cumprido ou não;
  - as pílulas de estado;
  - Expedições e Abates.
  - Os ícones de habilidade e de recurso que já existem continuam.
- **Continuam valendo** o texto Maior, o daltonismo (a pílula de estado também muda de ícone, não só de cor), o teclado,
  o controle e o toque.

Pedido do Lucas (25/10/2026), depois da primeira versão das telas do laço (#96, `docs/design/loop-screens/overview.webp`
no `codex-design`): "muito básico, com cara de feito por IA; quero personalidade". As referências (packs de UI de
fantasia sombria, ícones em losango, runas brilhantes, barras de HUD pintadas, molduras de carta) foram mandadas pelo
Lucas direto ao Codex e não entram neste repositório, que é público.

## O que está errado hoje

- **Tudo é o mesmo retângulo preto com uma linha fina.** A barra do título, o painel, o botão e a dica de teclas têm a
  mesma caixa: não há hierarquia nem forma própria.
- **Cara de aplicativo:** faixas pretas de ponta a ponta em cima e embaixo de toda tela, e painéis grandes que tampam a
  cena com espaço vazio.
- **Informação em planilha:** "Vida 34/34 · Instinto 0/200 · Velocidade 2 · Posição 1" em texto solto, critérios em
  lista com um tique, estrelas minúsculas, barras de XP como linhas brancas.
- **Sem ícones:** quase tudo é palavra. Os poucos ícones são genéricos (seta, escudo, bandeira).
- **Sem material e sem luz:** nada é metal, madeira, papel ou vidro; nada brilha, nada tem sombra ou volume.
- **Sem relação com o mundo:** a mesma interface caberia em qualquer jogo.

## O que as referências têm (e o que pegar de cada uma)

| Referência | Pegar | Não pegar |
|---|---|---|
| Packs de fantasia sombria (molduras douradas, Gothic UI, Dark Fantasy) | Cantos trabalhados, títulos numa plaqueta própria, divisores com ornamento no meio, molduras de tamanhos diferentes para funções diferentes | O ouro limpo de catedral e o gótico religioso |
| Ícones em losango coloridos | Um losango com borda grossa e o símbolo em silhueta chapada, uma cor por família (espécie, estado, recurso) | Copiar os símbolos |
| Runas e faixas brilhantes sobre madeira | O brilho que vaza do traço, os glifos riscados, a textura de madeira por baixo | Runa mágica: aqui não há magia |
| Barras de HUD pintadas (orbes e alça de metal) | Peças com volume e material, o encaixe dos slots numa estrutura, o número da tecla numa moedinha | Os orbes vermelho e azul, o layout de ARPG |
| Cartas com retrato (moldura de metal e vidro, a carta do corvo) | O retrato como protagonista, os números em medalhões nas pontas, as pedras (gemas) como contadores, o nome numa plaqueta | Dinossauro de terno, ficção científica limpa |
| Pack com janelas e árvore de habilidades | Janela com a aba do título saindo da borda, a árvore com conectores de verdade | O fundo de gradiente liso |

## Como fica no After Humans

O mundo é a cidade alagada depois dos humanos: animais que montam a vida com o que sobrou, máquinas velhas da rede
VIGIA, raízes que tomaram tudo e a Estação Raiz como casa. A interface é **feita à mão pelos sobreviventes com sucata**.

- **Materiais:**
  - latão e cobre oxidados (verde-azulado nas bordas), chapa rebitada, parafusos;
  - madeira escura da Estação;
  - papel e tecido gasto para textos longos (briefing, relatório);
  - vidro rachado de tela velha para o que vem da Rede.
- **Raízes como ornamento:** no lugar da filigrana gótica, raízes finas e musgo entram pelos cantos das molduras
  principais. É a assinatura do jogo. Com moderação: só nas peças grandes.
- **Duas luzes, com sentido:**
  - **ciano bioluminescente das raízes** = o que é nosso (a equipe, a Estação, o que se pode fazer);
  - **âmbar e vermelho de LED velho** = a VIGIA e as máquinas (inimigos, perigo, o radar do Mapa da Rede).
  - O brilho vaza do traço como nas runas das referências.
- **Glifos:** os ícones e marcas seguem a linguagem das runas e dos losangos, mas são **marcas riscadas pelos
  sobreviventes** (pata, osso, raiz, engrenagem, gota, chama) e **sinais da VIGIA** (geométricos, de máquina) para o que é
  dela.
- **Losangos por família,** com uma cor cada (vale também no daltonismo, porque o símbolo muda junto):
  - espécies: cão, gato, sapo, coruja;
  - estados: sangrando, atordoado, protegido, crise…;
  - recursos: comida, sucata, sementes, fragmentos.
- **Tipografia:** uma serifada com personalidade nos títulos e nomes (gravada numa plaqueta de metal) e uma sem serifa
  sóbria só no texto corrido. Números importantes (vida, nível, dano) em medalhão, não em texto solto.

## Peças que o kit precisa ter (versão 2 da #59)

1. **Três molduras com papéis diferentes:**
   - grande (janela com a aba do título saindo da borda e raízes nos cantos);
   - média (ficha, carta);
   - pequena (slot, chip).
2. **Plaqueta de título e plaqueta de nome,** em metal, com a ponta recortada.
3. **Botão principal** (chapa com volume, estado de foco brilhando em ciano) e **botão secundário** (mais discreto).
4. **Barras:**
   - vida, instinto e XP com tubo de vidro ou chapa, líquido com cor e brilho e marcações;
   - o instinto ganha cor quente perto da crise.
5. **Medalhão de número** (nível, vida, contagem) e **gemas como contadores** (estrelas, cargas, pontos).
6. **Losango de ícone** em 3 tamanhos, com o conjunto inicial dos glifos.
7. **Divisor** com ornamento no meio, e **conector** para a árvore da Pesquisa.
8. **A carta do personagem:**
   - o retrato grande como na carta do corvo;
   - nome na plaqueta, espécie e papel embaixo;
   - vida e instinto em barras;
   - nível em medalhão;
   - passivos como losangos com o texto ao apontar.
9. **Dica de teclas** em moedinhas de metal (E, Esc, Q…) soltas na borda da tela, sem a faixa preta inteira.

## Regras para não voltar ao básico

- **Nada de faixa de ponta a ponta,** e nenhuma caixa maior que o conteúdo. A cena aparece.
- **Toda informação que pode ser ícone, barra ou medalhão vira ícone, barra ou medalhão.** Texto fica para o que só
  texto explica (passivos, falas).
- **Cada tipo de tela tem a sua forma:**
  - o briefing é papel com o retrato;
  - a ficha é carta;
  - o fim de luta é placa com gemas;
  - a carga são caixas de verdade;
  - a Pesquisa é árvore com conectores;
  - o Mapa da Rede é vidro de terminal âmbar.
- **Antes de montar telas, uma prancha de estilo:** as peças do kit lado a lado, sobre uma captura real da luta, para o
  Lucas aprovar. Só depois as telas.
- **Legível:** texto no mínimo do `AHUiStyle`, contraste, texto Maior e daltonismo continuam valendo. O ornamento nunca
  fica em cima do texto.

## Decisão do Lucas — 25/10/2026

- **Direção escolhida: C — Latão noturno**, a terceira das [variações de HUD](hud-variations.md): distribuição compacta, ornamento contido e espaço para a cena. Consolidar a HUD a partir dela; isto não aprova uma integração já implementada ou todas as telas da #96.
- **Ícones do Nick:** Lucas gostou e pediu para guardar como possibilidade futura. Preservar os estudos e as imagens atuais, incluindo os ícones ilustrados visíveis na C e os glifos alternativos da B; não interpretar a preferência como autorização para substituir os ícones usados pelo jogo. A seleção final do conjunto fica para uma tarefa futura.
- **Foco atual: somente a HUD.** Não expandir agora para redesenho ou integração de habilidades/ícones. A bandeira de Fugir/Retirar foi identificada como pouco clara; revisar a clareza desse controle dentro do trabalho da HUD.

A consolidação da HUD de combate, peças e medidas está em [hud-c.md](hud-c.md). Essa é a referência atual de implementação da HUD C; as variações e a prancha inicial continuam como histórico.
