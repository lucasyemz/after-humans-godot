# After Humans (Godot)

RPG tático por turnos, com personagens pintados em 2D sobre cenários 2,5D. Esta é a versão na Godot. Ela começou como o
protótipo da avaliação de migração da Unreal e hoje tem:

- **Combate:** o motor em GDScript, portado do C++ da Unreal. Reproduz as 48 lutas gravadas passo a passo
  (`tests/test_combat_parity.gd`).
- **Estação Raiz e campanha (fase 3 do plano):** o refúgio entre as expedições, em corte (plataforma do metrô e dois
  subterrâneos com oito cômodos), transcrito da Estação da Unreal com os modelos da Poly Haven e os cards pintados, e
  as cenas de lá: o relatório da volta na plataforma, a passagem secreta, o trem com o candidato, a equipe em fila para
  a partida e os moradores trabalhando e sentando. A economia da Estação (suprimentos, água, energia), os cômodos que se recuperam, os
  civis que chegam pelo trem, a noite da volta, o elenco, a forja, a pesquisa e a Preparação (fase, equipe, foco da
  rota e suprimentos). O jogo abre na Estação; a partida leva à rua e a volta traz de novo, com o relatório.
- **Jornada na rua (fase 2 do plano):** a Rua das Vitrines é o corredor de 10 trechos da Jornada 1, gerado pela semente
  da campanha como na Unreal: patrulhas que vigiam e avistam a equipe, suprimentos, eventos, descanso, o guardião no fim
  e o resultado. As lojas abrem para interiores (mercearia, oficina, cinema) com pontos de busca, emboscadas e fogueira.
- **Combate na rua (fase 1 do plano):** as patrulhas do corredor. Chegar perto começa a luta ali mesmo:
  - a equipe e os inimigos se alinham nas 4 posições;
  - o herói da vez escolhe a habilidade e o alvo no HUD (mouse, teclado ou gamepad);
  - cada ação mostra a preparação, a execução e o efeito no alvo, com o som dela;
  - os números de dano sobem, os atingidos reagem e o resultado (vitória, derrota ou fuga) volta para a campanha.
- **Fundação (fase 0 do plano):** autoloads `GameData`, `Campaign` (save em JSON com cópia de segurança) e `GameFlow`
  (troca de cenas), ações de input com teclado e gamepad e um runner de testes.
- **Rua das Vitrines:** a rua pintada com a atmosfera do Emberfall (câmera teleobjetiva, sol baixo, luzes quentes,
  névoa, tilt-shift), chuva com chão molhado e fogueira que apaga, e colisão com prédios, carros e props.

Roda no PC (Forward+) e no navegador (Compatibility). O plano para chegar ao jogo completo está em
[docs/plan.md](docs/plan.md). Versão: Godot 4.7.2 estável, a versão padrão (GDScript, sem .NET).

## Estrutura

```
project.godot  export_presets.cfg
scripts/core/     GameData (autoload): todas as tabelas de data/; Settings (qualidade gráfica, tela cheia, vsync, em
                  user://settings.cfg) e Sound (música, ambiente, chuva, efeitos e passos nos canais das opções)
scripts/campaign/ Campaign (autoload): campanha nova, save e load
scripts/flow/     GameFlow (autoload), o boot, as regras da jornada (corredor, casas, busca, acampamento) e as da
                  Estação e da campanha (cômodos, economia, civis, noite, elenco, foco, partida e volta)
scripts/combat/   motor de combate, tabelas tipadas, a sessão de luta (comandos e lances) e a arena (animação)
scripts/ui/       HUD de combate, da exploração e do refúgio, o mapa de fases, as opções e a Mochila
scripts/world/    AHSpriteCard (personagem pintado com o pé fixo ao trocar de pose) e AHHouseRoom (interior das lojas)
scripts/street/   Rua das Vitrines: a montagem fixa (street_set.gd, gravada em scenes/street_set.tscn), chuva, colisão e o
                  corredor (patrulhas, visão, portas, saque)
scripts/scenario/ AHScenarioWorld: monta os seis cenários da Unreal a partir de data/scenarios (zonas, portas, props)
scripts/station/  Estação Raiz em corte: a montagem transcrita da Unreal (station_build.gd), os auxiliares em cm
                  (station_builder.gd), os moradores, o trem e a câmera de cada cômodo
shaders/          cenários (blockout, cards, água com ondas), pós-processamento Emberfall, fogueira que apaga, chuva e fumaça, feixes de luz, halos, silhuetas
scenes/           boot.tscn (cena inicial: abre a Estação, ou a rua se há expedição), station.tscn, street.tscn e
                  street_set.tscn (a rua montada, editável no editor)
data/             JSON de produção (classes, habilidades, inimigos...) e a gravação de paridade do combate;
                  expedition-teams.json diz quantos partem em cada jornada (mínimo e máximo); em events.json,
                  Places e Objects dizem em que cenários e objetos cada evento de busca cabe;
                  presentation/combat_art.json diz onde está cada pose, ícone e som e mede a âncora no pé;
                  scenarios/ traz os seis mapas exportados (peças, materiais, luzes, zonas) e as malhas
audio/            combat (sons das habilidades), music, ambience (cenários e chuva), world (passos, portas, busca),
                  station e ui
art/              arte pintada usada pelo jogo (street: a rua; rooms: interiores; station: superfícies, modelos da Poly Haven e cards
                  da Estação, metro: o metrô Bombardier, CC BY 4.0, créditos em art/station/metro/CREDITS.md; civilians: os civis do trem; combat: heróis, inimigos, efeitos e ícones; scenarios: texturas dos cenários;
                  ui: o mapa de fases, as imagens das fases e os ícones dos nós)
tests/            run_all.gd e os test_*.gd (paridade 48/48, save, dados, cenas e input; test_full_journey joga
                  uma campanha da Estação à volta com as cenas de verdade)
tools/            sync_assets.py e sync_combat_art.py (trazem dados, arte e sons da referência Unreal; o segundo
                  precisa do Pillow), unreal_export_scenarios.py (roda na Unreal e exporta os cenários para
                  build/unreal-export) e sync_scenarios.py (converte a exportação), sync_audio.py (trilha e sons, precisa
                  do soundfile), capture_scenarios.gd e capture_scenario_fight.gd (QA dos cenários), capture_impact.gd (gravação de um golpe) e define_input.gd (grava as ações)
```

`build/` e `.godot/` são gerados e ficam fora do Git.

## Comandos

`GODOT` é o executável de console da Godot (ex.: `D:\Godot\Godot_v4.7.2-stable_win64_console.exe`). Rode a partir desta
pasta.

Na primeira vez, importe os recursos:

```bash
"$GODOT" --headless --path . --import
```

Todos os testes, sem janela (imprime `PASS`/`FAIL` por teste e sai com código 0 se todos passarem):

```bash
"$GODOT" --headless --path . --script res://tests/run_all.gd
```

Um deles, `test_full_journey`, joga uma campanha inteira com as cenas de verdade, sem janela (uns 15 s): Estação, mapa de
fases, Preparação, a Rua das Vitrines (andar, vasculhar, as lutas no automático, o guardião), a volta, o relatório, a noite e
o trem. Os itens do [checklist de Play](docs/play-checklist.md) que ele cobre estão marcados com **[auto]**.

Para rodar só alguns, acrescente `-- --filter=campaign` (o filtro casa com o nome do arquivo). O save do jogo fica em
`user://saves/` (no Windows, `%APPDATA%\Godot\app_userdata\After Humans\saves`); os testes usam uma pasta temporária.

- **Jogar:** dois cliques em `play.bat` (ou `play.bat web` para o renderer da web), ou `"$GODOT" --path .`. Acrescente `--rendering-method gl_compatibility` para ver no PC o renderer da web.
  - A/D (ou ←/→) andam pela rua; W/S (ou ↑/↓) vão para o fundo e para a frente, inclusive dentro dos becos.
    No gamepad: analógico esquerdo ou direcional.
  - Shift (ou RB) corre.
  - Na Estação, as setas (ou o direcional) andam entre os cômodos, E abre e F2 oculta a interface. Esc (ou Start) leva o
    foco aos botões da esquerda (Próximo passo, Preparar expedição, Opções).
  - Em toda tela (mapa de fases, Preparação, cômodos, relatório, noite, trem, Opções, pausa, Mochila, luta) dá para jogar
    só com o teclado ou o controle: as setas (ou o direcional) andam entre os botões, E, Enter ou A confirma e
    Backspace, Esc ou B volta. As teclas desenhadas na tela seguem as trocas das Opções. As teclas dá para trocar em Opções > Controles (salvo nesta máquina). O tamanho do texto fica em Opções > Jogo. Com tela de toque aparecem um analógico (andar; até a borda corre) e o botão Usar; Opções > Controles de toque liga sempre ou desliga.
  - F1 liga o modo de desenvolvedor (fica salvo): o contador de quadros e as teclas de teste abaixo (R, T, P, C, K).
  - R liga e desliga a chuva.
  - T troca entre fim de tarde e noite.
  - P liga e desliga o pós-processamento.
  - C mostra as caixas de colisão.
  - I abre a Mochila (comida, curativo e a ampola da Íris; na luta, no herói da vez).
  - Esc abre o menu (continuar, opções, voltar à Estação, nova campanha).
  - E interage: entrar ou forçar a porta de uma loja, vasculhar, abrir caixotes, acender a fogueira, voltar à Estação
    pela saída no começo da rua.
  - K leva a equipe até a próxima patrulha.
  - Na Estação: o cartão "Próximo passo" diz o que fazer; os cômodos abrem clicando no nome deles no corte; Esc volta à
    vista geral. Preparar expedição abre o mapa de fases e depois a Preparação, onde se monta a equipe e se parte.
  - Na luta: 1 a 4 escolhem a habilidade (ou o clique), depois o alvo; Q move, W defende, I abre a Mochila, F foge
    (no gamepad, setas e Enter/A; Backspace/B volta).
    Mover, Defender e Fugir ficam à direita.
- **Tela de título:** o jogo abre nela (`scenes/title.tscn`), com Continuar (a última campanha usada, só com um save que
  abre), Nova campanha (escolhe um dos três espaços e pergunta antes de sobrescrever um ocupado), Campanhas (abre outro
  espaço, quando há mais de uma campanha) e Opções. Os espaços ficam em `user://saves`: `campaign.json` (o espaço 1, o
  save de antes das vagas), `campaign_2.json`, `campaign_3.json`, cada um com a cópia `.backup`, e `slots.json` com o
  último usado. Captura: `"$GODOT" --path . --resolution 1920x1080 -- --capture-title=<pasta>` tira 10 fotos (sem save e
  com save, os espaços, a confirmação e as Opções, no texto Normal e no Maior) e sai; o save das fotos fica na pasta da
  captura.
- **Capturas, tempos de quadro e teste de colisão:** `"$GODOT" --path . --resolution 1920x1080 -- --capture=<pasta>`.
  Abre uma janela, tira 9 fotos (dia, noite e chuva), testa o líder andando contra um carro e contra uma fachada (`PASS`
  ou `FAIL`) e joga a jornada: a suspeita da primeira patrulha, a luta (HUD, uma ação, o resultado, a rua depois), a entrada
  numa casa e uma busca. Usa uma campanha própria, na pasta da captura. Grava
  `frames.txt` e sai.
- **A rua no editor:** `scenes/street_set.tscn` é a Rua das Vitrines montada (chão, prédios, becos, postes, carros, props
  e silhuetas, com a colisão de cada um), e a rua do jogo carrega essa cena. Cada peça é um nó (`Lamp1`, `Building3`,
  `Car2`, `Prop7`, `Alley4`...) com a placa, a colisão (`Collider`), a luz e o halo dela.
  - Pode mexer à mão (vale no jogo): mover, girar ou apagar postes, luzes de porta, carros, props, becos e silhuetas;
    mover os prédios no X (`Building1` a `Building7`): a porta da loja, onde se entra, vai junto (sem sair do corredor
    de 0 a 78 m; quais lojas têm porta e o trecho de cada uma ficam os da montagem, para os saves continuarem valendo).
  - Continua no código (mexer na cena não muda): a frente da calçada e a altura do piso, os limites por onde a equipe
    anda, o comprimento do corredor (78 m, 10 trechos) e o lado de cada porta. Uma peça girada colide certo, mas o
    teste de ponto livre ao pôr a equipe (`_blocked`) usa a caixa sem a rotação.
  - Por cima da cena, em código: o corredor sorteado, as patrulhas, as portas abertas das casas, os caixotes, a fogueira,
    o clima e a chuva.
  - Para não perder o que foi mexido à mão, não rode de novo a ferramenta abaixo: ela é para quando a montagem em código
    (`scripts/street/street_set.gd`) mudar, e sobrescreve a cena:
    `"$GODOT" --headless --path . --script res://tools/bake_street.gd -- --force`. Ao mexer na rua, rode a captura (o
    teste de colisão) acima.
- **Captura dos cenários:** `"$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_scenarios.gd -- --out=<pasta>`
  (opcional `--maps=RiverDock,FloodedDepot`). Em cada zona dos seis mapas: fim de tarde e noite com chuva, tempo de quadro,
  equipe e patrulhas no piso e o líder preso à faixa (`PASS`/`FAIL`). Sai com código 1 se algo falhar.
- **Captura de luta nos cenários:** `"$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_scenario_fight.gd -- --out=<pasta>`
  (padrão: Depósito e Dutos; `--maps=` escolhe). A equipe contra Broto, Faísca e Pipoco, de dia e de noite, e o
  `feet.txt` com o pé de cada um na tela e se o cenário o cobre. Sai com código 1 se algum pé ficar coberto.
- **Gravação de um golpe:** `"$GODOT" --path . --resolution 960x540 --fixed-fps 30 -s res://tools/capture_impact.gd -- --out=<pasta>`
  (opcional `--speed=2`). Um PNG por quadro do golpe de um herói num robô, com semente fixa, para comparar o impacto
  (pausa, tremor, clarão) antes e depois.
- **Exportar:** `"$GODOT" --headless --path . --export-release "Web" build/web/index.html` e
  `"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/AfterHumans.exe`. Os export
  templates da 4.7.2 precisam estar instalados.
- **Servir a web:** `python -m http.server 8060 --directory build/web` e abrir `http://localhost:8060`.

### Testes no GitHub (CI)

`.github/workflows/tests.yml` roda os mesmos testes em cada PR e em cada push na `main`. Ele:
- baixa a Godot 4.7.2 Linux (com a soma SHA-512 conferida e cache);
- importa o projeto (com cache da `.godot/`);
- roda `tests/run_all.gd`.

Falha deixa o PR vermelho. O resumo do job traz o `PASS`/`FAIL` de cada teste com as falhas, e o log completo fica como
artefato.

No PR, o job **Leveza do PR** (`tools/ci_size_check.sh`) avisa, sem falhar, em dois casos:
- quando `art/` cresce mais de 5 MB, listando os maiores arquivos. A conta é líquida: o que entra ou cresce menos o que encolhe ou sai;
- quando entra uma imagem em `docs/` fora de uma pasta com `.gdignore`.

Para conferir antes de abrir o PR: `bash tools/ci_size_check.sh origin/main HEAD`. Ao trocar de versão da Godot, mude
`GODOT_VERSION`, `GODOT_ZIP` e `GODOT_SHA512` no workflow (a soma está em `SHA512-SUMS.txt` da release).

## Referência Unreal

O projeto Unreal antigo é a pasta onde este repositório mora localmente. Ele não vai para o GitHub e serve só como fonte
de regras, dados e arte para portar. `tools/sync_assets.py` copia de lá o que o jogo usa, e o resultado é versionado
aqui: o projeto roda e exporta sem a pasta da Unreal.
