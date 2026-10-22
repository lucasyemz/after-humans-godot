# Plano: After Humans na Godot (2026-10-20)

Como levar o jogo da Unreal (referência na pasta acima deste repositório) para a Godot, em fases que terminam jogáveis.
Parte do protótipo atual: combate com paridade 48/48 e Rua das Vitrines com chuva e colisão.

## Decisão: mapas a partir dos dados e da arte que já existem, sem geração procedural

**Recomendação:** usar a arte pintada e os layouts que já existem, montando cada mapa a partir de dados. A geração
procedural fica só para variar o conteúdo de cada corrida (inimigos, saque, eventos), não para criar o cenário.

**Por quê:**

- **A arte é a identidade do jogo.** As fachadas, os cards e os interiores são pinturas compostas para um ângulo e uma
  escala. Um gerador procedural repetiria as mesmas peças e quebraria a composição. O Emberfall gera tudo por código
  porque é pixel art de blocos; a pintura do After Humans não funciona assim.
- **O trabalho já está feito.**
  - Os seis cenários novos (Ponte, Cais, Depósito, Abrigo, Dutos e Portão) estão descritos em
    `Data/ScenarioPreparation/layouts.json`, na referência: 175 peças com posição, tamanho, arte e colisão.
  - As 105 imagens de origem estão todas em `SourceArt`, com caminho e hash em `assets.json`.
  - A Rua das Vitrines já foi portada assim no protótipo.
- **O gênero pede caminho fixo e conteúdo variável.** No Darkest Dungeon, a referência de espírito, os corredores e
  salas são fixos; o que muda entre corridas é o que tem neles. A expedição do After Humans já funciona assim: um mapa
  de nós e corredores de 10 trechos com patrulhas, suprimentos e descanso.
- **Dá para ajustar à mão.** Uma cena montada por dados vira um `.tscn`, que o Lucas mexe no editor da Godot e qualquer
  agente lê e edita como texto.

**Como fica na prática:**

1. Um importador (`tools/`) converte cada layout e o manifesto de dressing da Unreal num JSON da Godot, em
   `data/scenarios/<scenario>.json`, e copia a arte usada.
2. Um montador (`scripts/world/scenario_builder.gd`, generalizando o `street.gd`) lê esse JSON e cria a cena: pisos,
   paredes, cards, luzes, colisão, portas e zonas.
3. O montador gera o `.tscn` uma vez. Dali em diante, o `.tscn` é a fonte e recebe os ajustes finos no editor. O JSON só
   volta a ser usado se for preciso remontar o mapa do zero.
4. Por corrida, um gerador com semente (o mesmo mulberry32 do combate) sorteia o que vai em cada trecho a partir das
   regras de `data/`: patrulhas, props de busca, saque e eventos.

**Onde a geração procedural ajudaria mais tarde:**
- variações de dressing num cenário (entulho, poças, folhagem) a partir de um kit;
- o mapa de nós da expedição, que a web já gerava (`expeditionGenerator.ts`);
- interiores pequenos montados com peças de um conjunto.

Nada disso precisa estar no primeiro jogável.

## Fases

Cada fase termina num build que o Lucas joga, com os testes automáticos verdes. As estimativas são em dias de trabalho
com agente, sem contar as rodadas de QA.

### Fase 0: fundação (2 a 3 dias) — feita em 2026-10-20

- Autoloads:
  - `GameData`: lê todos os `data/*.json`;
  - `Campaign`: estado e save em JSON, com cópia de segurança;
  - `GameFlow`: troca de cenas e fases.
- Ações de input no `project.godot` (teclado e gamepad), no lugar das teclas fixas do protótipo.
- Organização: `scenes/`, `scripts/<area>/` (combat, world, flow, campaign, ui) e `data/`.
- Testes headless num só comando (`tests/run_all.gd`): paridade, save e load, regras.

**Pronto quando:** salvar e carregar uma campanha nova passa no teste, e a rua abre pelo `GameFlow`.

**Feito:** `tests/run_all.gd` passa com 4 testes e 169 verificações em menos de 1 s (paridade 48/48, campanha nova e
save com recuperação pela cópia, tabelas e referências, cenas e input). A rua abre pelo boot e pelo `GameFlow`, e o modo
de captura e os testes de colisão continuam passando. Ficaram para as próximas fases: a Estação e a expedição dentro do
save (`station` e `session` estão vazios) e a migração de versões antigas do save (o leitor já recusa versão diferente).

### Fase 1: combate jogável na rua (5 a 7 dias) — feita em 2026-10-21

- Arena na faixa da rua (port do `AHCombatArena`):
  - 4 posições por lado e entrada dos inimigos;
  - câmera de ação aproximada;
  - poses (ataque, defesa, dano, morte, esquiva, apoio) e as fases das ações dos aliados (`_preparacao`, `_execucao`).
- HUD de combate (port do `AHCombatHUDWidget`): fila de iniciativa, habilidades com alvo e prévia, status, instinto,
  números de dano.
- Arte e som:
  - sprites e poses dos inimigos, vindos de `Content/.../Characters` (exportar da Unreal o que não tiver origem em
    `SourceArt`);
  - sons de combate de `SourceArt/Audio`.

**Pronto quando:** uma luta completa contra uma patrulha da rua é jogável do começo ao fim, com vitória, derrota e fuga.

**Feito:** duas patrulhas na rua (robô e robô fungo; vigia enferrujado e robô).
- A luta acontece no lugar: as 4 posições de cada lado, a câmera mais perto e acompanhando o lance.
- Ações dos heróis: as três fases da arte aprovada (preparação, execução e efeito no alvo) com o som de cada uma.
- Reações: ferido e derrotado (por enquanto só Bento e Nick têm a arte nova; Íris e Véspera ficam na pose parada e
  piscam). Inimigos com ataque, defesa, apoio, ferido, esquiva e morte.
- HUD: ordem dos turnos, barras sobre cada um, o painel do herói com os motivos de cada habilidade indisponível,
  marcadores de alvo e o resultado. Funciona com mouse, teclado e gamepad.
- Fim da luta: vida, instinto e trauma voltam para a campanha; quem morre sai da equipe. Na fuga, a equipe recua e a
  patrulha volta ao posto. Na derrota, a rua recomeça (o refúgio vem na fase 3).
- Testes: `test_combat_session` (24 lutas automáticas, opções, fuga, volta para a campanha) e `test_combat_art` (todo
  arquivo existe, cada habilidade tem ícone, fases e som, e nenhum quadro de folha está vazio). O modo de captura joga
  uma luta inteira.

**Pendências:**
- **As patrulhas estão fáceis:** a equipe venceu as 24 lutas automáticas. Precisa de balanceamento ou das patrulhas
  certas do corredor (fase 2).
- **Arte faltando:** reações de Íris e Véspera (dano e queda) e a esquiva e a defesa dos heróis com a arte nova: não
  existem na fonte da Unreal (só Bento e Nick têm dano e queda). Já entraram as poses de todos os inimigos e a de usar
  item dos quatro heróis (`SourceArt/AllyActions/ItemUse`), que a Mochila mostra na luta. As folhas de andar antigas
  (`T_*_Walk`) ficam de fora, como na Unreal: a caminhada é a pose parada com o passo de 3 cm (`WalkBobHeight`). As
  poses de dormir do Dormitório esperam a revisão do Lucas (o manifesto diz "not integrated").
- ~~**Ainda não entraram**~~ feitos depois da Fase 5: a prévia de quem a habilidade atinge (`ability_hit_ids`, port do
  `AbilityHitIds`, com `test_hit_preview`: apontar um alvo diz todos os atingidos e acende o par da granada ou o vizinho
  do coquetel), os itens da Mochila na luta e a crise de instinto com o lance próprio (câmera perto, pose de apoio ou de
  dano e a faixa "CRISE DE INSTINTO" com o resultado em dourado ou vermelho).

### Fase 2: exploração e a primeira jornada (5 a 8 dias) — feita em 2026-10-21

- Corredor de 10 trechos (port do `AHStreetCorridor`): patrulhas, suprimentos, descanso, guardião no fim.
- Rastreador, visão e detecção (`AHTracker`, `AHSightComponent`): a vantagem de abertura no combate.
- Pontos de busca e saque (`AHSearchSpot`, `AHLootContainer`), mochila e eventos narrativos (`events.json`).
- Interiores das lojas (port do `AHHouseRoom`): porta, entrar, vasculhar, voltar.
- A rua deixa de ser montada a cada abertura e vira `.tscn` (com o montador da Fase 4 ou direto do `street.gd`).

**Pronto quando:** a Jornada 1 inteira (Rua das Vitrines) é jogável: preparar, andar, lutar, vasculhar uma loja,
descansar, enfrentar o guardião e ver o resultado.

**Feito:** a Rua das Vitrines virou o corredor da jornada (`AHJourneyRules`, port do `FAHGameFlowRules` com as mesmas
sementes e constantes, então a mesma campanha gera o mesmo corredor da Unreal).
- **Corredor de 10 trechos** de 7,8 m: patrulhas, suprimentos, eventos, descanso e o guardião no fim. O clima de cada
  fase sai da semente (fim de tarde, noite, chuva, neblina, tempestade com relâmpagos) e muda depois de acampar. O HUD
  mostra os trechos, a comida, os curativos, a esperança e o que já foi achado. A equipe não passa de um trecho sem
  resolvê-lo.
- **Visão e detecção:** cada patrulha olha num cone de 60° e 14 m (menor de noite, na chuva e na neblina), com raio
  contra os prédios. A suspeita sobe enquanto vê a equipe ("?"); cheia, a patrulha avista ("!") e corre. Chegar perto
  sem ser visto dá a vantagem de abertura no combate.
- **Busca e saque:** as casas da fase (trancadas em ~35%, abertas com pé de cabra ou forçadas) têm até 3 pontos de
  busca com os resultados da Unreal (comida, sementes, sucata, curativos, o pé de cabra, eventos narrativos com
  escolhas). Caixotes na rua também dão saque.
- **Interiores das lojas** (port enxuto do `AHHouseRoom`): mercearia, oficina e cinema com o chão, a parede, o rodapé e
  os itens pintados de cada loja. Entrar e sair com fade; dentro, a patrulha da casa embosca, os pontos de busca e a
  fogueira do acampamento (comida e curativo curam; sair muda o clima).
- **Fim da jornada:** vencer o guardião, recuar pela saída ("Voltar à Estação") ou perder a equipe mostra o resultado
  (o saque volta inteiro, pela metade ou nada) e começa uma expedição ou campanha nova.
- Testes: `test_journey_rules` (forma do corredor em 300 sementes, inimigos e arte de todos eles, casas em 400 sementes,
  busca e pé de cabra, eventos, acampamento, combate, volta e o save). O modo de captura agora joga a suspeita da
  patrulha, a luta, a entrada numa casa e uma busca.

**Corrigido depois da primeira QA em Play (21/10):**
- a equipe nascia dentro da caixa de colisão da fogueira e não andava (o posicionamento agora procura o ponto livre);
- as alturas dos personagens vêm da tabela da Unreal (`AHCharacterHeights`: Bento 1,72 m, Nick 1,50, Íris 1,38,
  Véspera 1,66, inimigos pela proporção), em vez de todos com ~1,8 m;
- os móveis no chão das lojas (prateleiras, balcões, bancadas, cortinas) e a fogueira da casa têm colisão;
- os heróis de trás entravam na parede do fundo das lojas: o recuo de desenho da fila se acumulava a cada quadro
  (~0,25 m por herói a 120 fps). Agora a equipe anda com folga das paredes, e a câmera vai até perto das paredes do lado
  para ninguém sair do quadro nas pontas da sala;
- combate como na Unreal: quem ataca corpo a corpo vai até o alvo (os inimigos, 40% do caminho; a distância, um passo),
  passa na frente dos outros e o alvo é empurrado; a câmera enquadra a luta inteira e se aproxima do golpe; os pés ficam
  acima do painel, que só aparece na hora de escolher a ação, e o registro foi para o canto de cima;
- `test_scripts` compila todos os scripts do jogo (um erro na arena passava despercebido pelos testes).

**Pendências:**
- **A rua ainda é montada em código** (não virou `.tscn`); os cenários da Fase 4 vêm de dados exportados, não de `.tscn`.
- ~~**Mochila sem tela**~~ feita depois da Fase 5: a tela da Mochila (I ou o botão, na exploração e na luta) e os
  cuidados do `FAHExplorationCare` (comer pouco ou bem, curativo, ampola da Íris), com `test_exploration_care`.
- **Preparar a expedição** (escolher a equipe e os itens) vem com a Estação, na Fase 3; hoje a equipe é a dos
  fundadores vivos.
- **Arte:** os inimigos novos (cão eco, condutor raiz, sussurrador, rastejante) só têm a pose parada; os pontos de busca
  ainda não têm marcador visual (só o aviso "E Vasculhar…" perto deles).
- **QA em Play:** o guardião e o descanso passaram pelos testes de regra, mas ainda não por uma jornada inteira jogada.

### Fase 3: Estação Raiz e campanha (7 a 10 dias)

Aqui fica a maior parte da UI. Na Unreal são ~12 mil linhas (a Estação, o HUD do refúgio e o fluxo), então a fase
vai em três etapas:

- **3a, regras e o ciclo jogável:** todas as regras da Estação e da campanha com testes, a casca da Estação em corte
  com as medidas da Unreal, o HUD do refúgio com o serviço de cada cômodo e a volta inteira entre a rua e a Estação.
- **3b, a Estação em 3D:** a abóbada e o vagão de verdade, o mobiliário de cada cômodo (os modelos da Poly Haven em
  `SourceArt/ThirdParty`, CC0), a luz de cada sala e os moradores passeando pelos cômodos.
- **3c, as cenas da Unreal:** o relatório na plataforma com a equipe em fila, a equipe esperando a partida com os
  cartões da formação, a chegada e a partida do trem com o candidato, e a passagem secreta.

**Pronto quando:** dá para jogar várias jornadas seguidas com volta à Estação, e salvar e carregar em qualquer ponto.

**3a feita em 2026-10-21:**
- **Regras** (`AHStationRules`, port de FAHStationRooms, FAHStationEconomy, FAHStationCivilians, FAHNightRestRules,
  FAHShelterRules, FAHRouteFocus e da partida e da volta do FAHGameFlowRules, com os números aprovados na Unreal):
  - cômodos do nível zero (Forja, Pesquisa e Depósito recuperados ou melhorados com sucata e fragmentos);
  - economia por volta: suprimentos da Cantina, água do coletor, energia por prioridade, o que estraga acima do
    Depósito;
  - civis pelo trem (Dora, Otto, Cora): acolher ou recusar, pontos forte e fraco, fome, pedidos pessoais;
  - a noite da volta: vigia, suprimentos, sede, eventos;
  - elenco: recrutar, voluntários, enfermaria, pesquisa, forja e relíquias, formação;
  - foco da rota: garante a casa da loja certa e marca o objetivo;
  - a partida (equipe com ataque na posição, fase liberada, suprimentos extras) e a volta (saque, carga do objetivo,
    pedido, noite, ciclo, trem), uma vez por expedição.
- **Save:** campanha nova já vem com a Estação; saves antigos migram com todos os cômodos recuperados, como na Unreal.
- **Estação:** o corte com a plataforma, os dois subterrâneos e o eixo de escadas, nas medidas da Unreal, com as
  superfícies da Poly Haven e do ambientCG e a luz de cada cômodo (mais fraca sem energia ou com o cômodo vazio). Os
  heróis ficam espalhados pelos cômodos; os civis, no cômodo deles; o trem aparece com o candidato na plataforma.
- **HUD do refúgio:** recursos, o menu dos oito cômodos e o painel de cada um (recuperar e melhorar, elenco e
  memorial, preparação, cantina, depósito, forja, pesquisa, dormitório), o relatório da volta e o trem. A câmera
  enquadra o cômodo na faixa livre entre o menu e o painel.
- **Fluxo:** o jogo abre na rua se a expedição está em andamento e na Estação se não está. A partida é pela Preparação;
  a volta (pela saída da rua, pelo guardião ou pela derrota) leva à Estação com o relatório, a noite e o trem.
- Testes: `test_station_rules` (117 verificações, inclusive três viagens seguidas e o save com a noite pendente). O
  runner agora reprova o teste que tiver um erro de script no meio (antes o teste parava e passava com menos
  verificações).

**3b feita em 2026-10-21:** a Estação da Unreal transcrita peça por peça (`station_build.gd`, das funções Build* do
`AAHShelterStation` e dos arquivos de cada sala), com as mesmas medidas em centímetros e os mesmos auxiliares (Box, Beam,
Cylinder, Prop, Hang, PropPlaced, Light, Sign, WallWithOpenings) em `AHStationBuilder`.
- A plataforma com a abóbada de tijolo em arco, as pilastras e nervuras, a via com dormentes, trilhos e o batente com a
  lanterna, as placas, os bancos pintados, o relógio, o quadro elétrico e os pendentes; a porta de manutenção com o
  painel do mapa da rede (fechado) e o corredor escondido; o eixo de escadas com os lances, o guarda-corpo e as
  arandelas.
- Os oito cômodos com o casco da Unreal (piso, parede com a porta pintada, lambri, rodapé, divisórias, perfil do corte,
  tubulação, corredor de serviço) e o mobiliário de cada um: a cozinha e o refeitório da Cantina, as estantes do
  Depósito com o estoque por faixa, a Forja com a fornalha, a coifa, a bigorna de trilho e a bancada pintada, as camas
  do Dormitório, o balcão e as garrafas do Bar, a sala de estar dos Personagens, a mesa e os armários da Pesquisa, a
  Preparação com o quadro de rotas; os cantos e os armários baixos das laterais.
- 43 modelos da Poly Haven (CC0) com as texturas em 512 px e 30 cards pintados recortados no alfa (`tools/sync_assets.py`);
  as superfícies usam o shader da Unreal (projeção pelo mundo por face, tamanho real da amostra, umidade no rodapé).
- O mobiliário some nos cômodos vazios e a luz cai sem energia; os moradores passeiam pela faixa do cômodo (anda, para,
  escolhe outro ponto).
- As peças fixas viram uma malha por material: no renderizador da web, de 12 mil para 4,7 mil chamadas de desenho
  (56 → 106 fps nesta máquina).

**3c feita em 2026-10-21:** as cenas da Estação da Unreal.
- **Câmera:** as chaves da Unreal (posição, campo de visão e inclinação) com a mesma suavização; a vista geral, cada
  cômodo e a plataforma.
- **Passagem secreta:** entre a plataforma e o abrigo a câmera percorre o caminho da Unreal (diante do painel, a porta,
  a antecâmara, o eixo de escadas) enquanto o painel do mapa da rede desliza, a alavanca gira e a fresta de luz some;
  depois o painel fecha atrás da equipe.
- **Relatório da volta:** a equipe de pé na plataforma, a câmera baixa olhando um pouco para cima e o cartão sob cada
  um (vida, expedições, ferido ou trauma).
- **Partida:** "Escalar a equipe na plataforma" leva a equipe pela passagem até a fila (a posição 1 à direita), com os
  cartões da posição e do ataque; trocar ou reordenar refaz a fila.
- **Trem:** chega do túnel desacelerando com o sinal vermelho piscando, pausa na porta e o candidato desce e anda até
  a plataforma; a câmera fecha nele de corpo inteiro. Decidido, o trem fecha e acelera para o túnel (o recusado vai
  junto) e o acolhido passa a morar no cômodo dele.
- **Moradores:** os fundadores trabalham na sala deles (Bento na Forja, Nick no Depósito, Íris e Véspera na Pesquisa),
  só com a sala recuperada e ligada, alternando trabalho e pausa; na Cantina, às vezes sentam no banco atrás da mesa;
  os civis alternam o idle e a pose de trabalho. As brasas da Forja tremulam.
- As poses vêm de `SourceArt/RootStation` (`tools/sync_assets.py`, com os pés e o topo dos manifestos da Unreal).

**Pendências da 3c:**
- Sem os sons do trem e do sino de chegada (não há fonte em `SourceArt/Audio`; ficam para o áudio da Fase 5).
- O vagão não abre as portas (o metrô de portas deslizantes é um `.uasset`); o candidato desce pela lateral.
- As poses de dormir (Dormitório) e as folhas de andar da Íris e da Véspera ainda não entraram.

**Pendências da 3b:**
- O vagão é o de corte da própria Unreal (o metrô Bombardier, a cadeira do bar, o binóculo, o kit de química, o sofá 3D e
  a xícara só existem como `.uasset`; ficaram de fora ou com a peça parecida).
- A coifa da Forja é feita de caixas (a malha cônica da Unreal é gerada em C++).
- O pacote da web passou de 34 para 65 MB com os modelos.

**Pendências da 3a:**
- Só a fase 1 tem mapa; as outras aparecem no mapa de fases e liberam em ordem, mas a partida fica fechada até os
  cenários (Fase 4).
- O trem parte na hora da decisão (a cena é da 3c); o Bar e o Dormitório continuam sem recuperação, como na Unreal.
- Recrutas novos usam a arte do fundador da mesma classe.
- QA em Play: o Lucas ainda não jogou a Estação.

### Fase 4: os outros cenários (5 a 8 dias)

- Importador e montador da seção de decisão acima, aplicados aos seis layouts.
- Água com ondas (`docs` da Unreal: `Docs/Systems/water.md`), lanterna, portas laterais e zonas.
- Jornadas 2 a 5 nos mapas certos, com trechos de passagem (Cais para Ponte, Depósito para Dutos) e o Porteiro.

**Pronto quando:** as cinco jornadas da campanha são jogáveis nos seus mapas.

**Feito:** os seis cenários da Unreal entram por exportação, e as jornadas 2 a 5 rodam neles do começo ao Porteiro.
- **Exportação:** `tools/unreal_export_scenarios.py` roda num commandlet da Unreal (só lê) e grava em `build/unreal-export`
  as peças de cada mapa (transformações, materiais e parâmetros, luzes, textos), as seções das malhas e as texturas tiradas
  dos `.uasset` (os caminhos de origem estavam velhos). `tools/sync_scenarios.py` converte para os eixos da Godot e grava
  `data/scenarios/<Mapa>.json`, `meshes.json` e `art/scenarios/*.webp` (158 texturas, 32 MB).
- **Montagem** (`AHScenarioWorld`): materiais por tipo (blockout projetado no mundo, superfícies, cards unlit com
  brilho, fachadas, água com as ondas da Unreal, emissivos), luzes em lúmens, peças fixas unidas por material.
  Zonas caminháveis saem dos pisos marcados; as portas laterais (Cais: Navio e Galpão; Depósito: Estoque, Manutenção e
  Arquivo) levam aos interiores fora da sequência de trechos.
- **Corredor por segmentos** (port do `SetupScenario`): os trechos se dividem entre as zonas pelo comprimento, a equipe
  viaja de zona no fim de cada uma e troca de mapa no fim do de passagem (Cais → Ponte, Depósito → Dutos). Props
  vasculháveis com o objetivo da rota (semente ^ 0x51ed27, do trecho 4 em diante), guardados pela patrulha do trecho.
  Com o guardião vencido, a volta à Estação vale de qualquer ponto do cenário (como o `RequestExpeditionReturn`).
- **Luz e clima:** lanterna no Depósito e nos Dutos; chuva só ao ar livre; os locais abertos (Cais, Ponte, Portão)
  levam o mínimo de lua e céu do `AHWeatherSite` da Unreal, para a noite continuar legível.
- **Arte:** o Porteiro, o ninho errante e a carcaça colonizada entram no `sync_combat_art.py`.
- **Teste:** `test_scenario_rules` (mapa de cada trecho, faixas, props e objetivo, interiores, dados dos seis mapas).
  As cinco jornadas foram percorridas pelas cenas de verdade, com lutas automáticas até o resultado.

- **Depois da primeira QA do Lucas:** o mapa de fases da Unreal (`AHPhaseMap`: o bairro alagado, a Estação e as
  fases como nós, o painel da fase e Preparar expedição, que leva à Preparação); Esc na exploração abre o menu com
  Continuar e Voltar à Estação (antes do guardião, retirada com confirmação); de noite e na chuva uma luz de leitura
  acompanha a equipe e a luta.

**Pendências da 4:**
- Sem colisão nos cenários: a equipe fica presa à faixa da zona, sem bater nos props.
- O portão animado do Portão de Triagem não entrou (a jornada da Unreal também não o usa), nem as baias do Cais que
  escondem as outras zonas; o sol exportado é trocado pelo da rua.
- Os cenários fechados de noite ficam escuros fora do alcance das luminárias e da lanterna: calibrar na QA em Play.
- O pacote da web cresce com os 32 MB de arte dos cenários; os builds ficam para a Fase 5.
- QA em Play: o Lucas ainda não jogou as jornadas 2 a 5.

### Fase 5: acabamento e lançamento (4 a 6 dias)

- Áudio completo (música, ambiente, passos) e menu de opções (qualidade gráfica, volume, controles).
- Builds para Windows e web, testados em hardware fraco e num celular.
- QA automatizada por captura para cada mapa (como o modo `--capture` da rua) e checklist de Play.

**Feito (primeira parte):**
- **Áudio** (`Sound`, port do `UAHSoundscapeSubsystem` e do `FAHAudio`): a mesma tabela do `import-sounds.py` da Unreal,
  convertida por `tools/sync_audio.py` (WAV para OGG). Música de exploração (uma de três pela expedição; a Ponte tem a
  sua), batalha e chefe (o Porteiro), a do refúgio na Estação; o ambiente de cada cenário e da rua; a chuva de fora e de
  dentro; crossfade de 1,5 s e os mesmos ganhos. Passos a cada 75 cm pelo piso (água, madeira, concreto), portas,
  busca (pano, metal, moedas no objetivo), o clique da interface em todo botão, o trem, o zumbido da Estação e os loops
  com lugar do Bar e do Depósito.
- **Opções** (Esc → Opções na exploração, e no menu da Estação): volume de música, ambiente e efeitos, qualidade
  gráfica (Baixo, Médio, Alto, Ultra: resolução interna, sombra, oclusão, neblina, reflexos e chuva), tela cheia,
  vsync, velocidade da batalha (1x ou 2x), reduzir os efeitos do ambiente e a lista dos controles.
- **QA dos cenários:** `tools/capture_scenarios.gd`: 26 conferências nos seis mapas, todas PASS; de 4 a 8 ms por
  quadro em 1080p no Forward+ (RTX 3050).
- **Builds:** `build/` ganhou `.gdignore` (a Godot importava a exportação da Unreal e os builds antigos para dentro do
  pacote). As texturas dos cenários e da Estação passam a WebP 0,75 (sem diferença visível). Web: 120 MB de pacote
  (era 220); Windows: 230 MB. A web abre, mostra a Estação e o mapa de fases no navegador.

- **Hardware fraco:** no Baixo, noite com chuva em 1080p custa 1,5 ms no Compatibility (o renderer da web) e de 2,5 a
  3 ms no Forward+ (RTX 3050): de 4 a 8 vezes de folga abaixo dos 60 FPS para uma placa mais fraca.
- **Celular (emulado no navegador, paisagem 812 x 375):** a Estação abre e responde ao toque, mas o texto do HUD fica
  pequeno (~9 px) e a exploração não anda sem teclado ou controle: não há controle de toque.
- **Checklist de Play:** [play-checklist.md](play-checklist.md).

- **Mochila** (port do `UAHInventoryWidget` e do `FAHExplorationCare`, #37): suprimentos, ferramentas, recursos e
  relíquias por grupo; à direita o item com as ações, a cura, o custo e o motivo quando não dá. Fora da luta escolhe o
  aliado (o mais ferido primeiro): comer pouco (15% da vida, 1 comida), comer bem (35%, 3), curativo (+8) e a ampola
  da Íris (5 a 8, 3 cargas, recarrega na vitória). Na luta é ação livre do herói da vez, um item por vez dele.
  `test_exploration_care` traz os testes da Unreal (52 verificações).

- **Nova HUD, etapa 1 (clareza)**, da proposta de UX aprovada pelo Lucas em 21/10/2026 (direção visual e dicas da
  primeira vez aprovadas; a intenção dos inimigos fica para depois):
  - `AHUiStyle`: a folha de estilo única (paleta, painéis, fichas, teclas, barras, rostos recortados da arte) e as
    fontes da Unreal (Plus Jakarta Sans e Cinzel) como tema padrão de todas as telas; texto de 18 px ou mais.
  - Modo de desenvolvedor (F1, salvo em `user://settings.cfg`): o contador de quadros e as teclas de teste saem da tela
    do jogador.
  - Combate: ordem da rodada com rostos, placas sob os pés com vida em número e estados por extenso, o herói da vez
    com o instinto até a crise, cartões com as bolinhas de "de" e "em", o número grande e as teclas 1–4 (Q, W, I, F nas
    ações), a dica completa ao apontar (o que faz, quem atinge, se pode cair, os termos explicados) e o registro legível.
  - Exploração: o lugar e o objetivo da rota, a rota em trilho com ícones, os recursos com ícone e dica, a equipe com
    rosto, losangos sobre o que dá para usar, o aviso de interação no próprio objeto, o aviso da patrulha à frente na
    borda e só as teclas do jogo, que somem depois de um tempo andando.

- **Nova HUD, etapa 2 (aprender jogando):**
  - Dicas da primeira vez (`Tips`): Estação, Preparação, explorar, patrulha, combate, instinto, busca, Mochila, guardião
    vencido e a volta. Uma vez cada, num cartão que não para o jogo; "Desligar dicas" e "Mostrar as dicas de novo" nas
    Opções; o que já foi visto fica em `user://tips.cfg`. Nas capturas e nos scripts de teste ficam desligadas e nada é
    gravado (`AH_TIPS_QA=1` mostra só na memória).
  - Estação: o cartão "Próximo passo" (`AHStationRules.next_step`, com teste: relatório, noite, trem, cômodo que já dá
    para recuperar, o que falta para o próximo e a próxima fase) com o botão principal, as pendências, os recursos com
    ícone e dica e os cômodos com nome e estado clicáveis no próprio corte; a lista de doze botões saiu e a Nova
    campanha foi para dentro das Opções.
  - Preparação numa tela: os quatro cartões no sentido da luta (rosto, papel, vida, as habilidades que saem daquela
    posição, os avisos), troca com dois cliques, os de fora da equipe, o aviso de quem cura, e à direita a missão, o
    foco, a comida e "Partir · destino".

**Pendências da 5:**
- Celular: controles de toque para andar e interagir, HUD maior em tela pequena e um pacote mais leve (120 MB pesa em
  dados móveis); falta testar num aparelho de verdade.
- Passar o checklist de Play com o Lucas.

**Total: 28 a 42 dias de trabalho com agente**, perto da faixa da avaliação (24 a 40). O combate e a rua já estão
adiantados, mas a Estação e a UI pesam mais do que parecia.

## Ordem e paralelismo

- **Em sequência:** 0 → 1 → 2. A primeira jornada jogável é o marco que valida o resto.
- **Em paralelo:** a Fase 4 (importador e montador dos cenários) pode começar junto com a Fase 2, por outro agente. Ela
  só precisa do montador da rua e não toca nos mesmos arquivos.
- **A Fase 3 depende da 2**, porque o fluxo de campanha precisa da jornada pronta.

## Pipeline de arte

| O quê | De onde vem | Como entra |
|---|---|---|
| Cards de cenário, props e fachadas | `SourceArt/<Scenario>` e tag `alphaweb` | `tools/sync_assets.py`, com o catálogo `assets.json` |
| Personagens, poses e ícones | `SourceArt` (HeroStatics, AllyActions, ApprovedActionIcons, CharacterGallery…) | Mesma ferramenta, por personagem |
| Texturas sem origem fora da Unreal | `.uasset` da referência | Exportar para PNG com um script Python no `UnrealEditor-Cmd` (sem abrir o editor) |
| Materiais PBR e malhas | Poly Haven e AmbientCG (CC0) | Baixar de novo pelo id, em glTF e PNG, para `art/external/<fornecedor>/<id>/` |
| Sons | `SourceArt/Audio` | OGG para música e ambiente, WAV para efeitos |

**Regra de leveza:** entra no repositório só o que alguma cena usa. A cada fase, um teste lista os arquivos de `art/`
que nenhuma cena ou script referencia.

## Riscos

| Risco | Como tratar |
|---|---|
| A Estação 3D (3.500 linhas de C++, malhas da Poly Haven) é a peça mais cara | Começar pela versão mais simples (cômodos e serviços); deixar o dressing fino para a Fase 5 |
| Os ajustes manuais nos mapas da Unreal (scripts de `refine-*` e `polish-*`) não estão nos layouts | Comparar cada mapa com a captura de QA da Unreal e ajustar no `.tscn` |
| O Compatibility (web) perde a névoa volumétrica e as reflexões | Manter a calibração por renderer, como no protótipo, e testar sempre os dois |
| Regras de campanha sem gabarito de paridade, como existe no combate | Portar junto os testes de regra da Unreal (`AHShelterRules`, `AHStationEconomy`, `AHNightRestRules`) |
