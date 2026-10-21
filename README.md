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
scripts/ui/       HUD de combate, da exploração e do refúgio, e o mapa de fases
scripts/world/    AHSpriteCard (personagem pintado com o pé fixo ao trocar de pose) e AHHouseRoom (interior das lojas)
scripts/street/   Rua das Vitrines montada em código, chuva, colisão e o corredor (patrulhas, visão, portas, saque)
scripts/scenario/ AHScenarioWorld: monta os seis cenários da Unreal a partir de data/scenarios (zonas, portas, props)
scripts/station/  Estação Raiz em corte: a montagem transcrita da Unreal (station_build.gd), os auxiliares em cm
                  (station_builder.gd), os moradores, o trem e a câmera de cada cômodo
shaders/          cenários (blockout, cards, água com ondas), pós-processamento Emberfall, fogueira que apaga, chuva e fumaça, feixes de luz, halos, silhuetas
scenes/           boot.tscn (cena inicial: abre a Estação, ou a rua se há expedição), station.tscn e street.tscn
data/             JSON de produção (classes, habilidades, inimigos...) e a gravação de paridade do combate;
                  presentation/combat_art.json diz onde está cada pose, ícone e som e mede a âncora no pé;
                  scenarios/ traz os seis mapas exportados (peças, materiais, luzes, zonas) e as malhas
audio/            combat (sons das habilidades), music, ambience (cenários e chuva), world (passos, portas, busca),
                  station e ui
art/              arte pintada usada pelo jogo (street: a rua; rooms: interiores; station: superfícies, modelos da Poly Haven e cards
                  da Estação; civilians: os civis do trem; combat: heróis, inimigos, efeitos e ícones; scenarios: texturas dos cenários;
                  ui: o mapa de fases, as imagens das fases e os ícones dos nós)
tests/            run_all.gd e os test_*.gd (paridade 48/48, save, dados, cenas e input)
tools/            sync_assets.py e sync_combat_art.py (trazem dados, arte e sons da referência Unreal; o segundo
                  precisa do Pillow), unreal_export_scenarios.py (roda na Unreal e exporta os cenários para
                  build/unreal-export) e sync_scenarios.py (converte a exportação), sync_audio.py (trilha e sons, precisa
                  do soundfile), capture_scenarios.gd (QA dos cenários) e define_input.gd (grava as ações)
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

Para rodar só alguns, acrescente `-- --filter=campaign` (o filtro casa com o nome do arquivo). O save do jogo fica em
`user://saves/` (no Windows, `%APPDATA%\Godot\app_userdata\After Humans\saves`); os testes usam uma pasta temporária.

- **Jogar:** dois cliques em `play.bat` (ou `play.bat web` para o renderer da web), ou `"$GODOT" --path .`. Acrescente `--rendering-method gl_compatibility` para ver no PC o renderer da web.
  - A/D (ou ←/→) andam pela rua; W/S (ou ↑/↓) vão para o fundo e para a frente, inclusive dentro dos becos.
    No gamepad: analógico esquerdo ou direcional.
  - Shift (ou RB) corre.
  - R liga e desliga a chuva.
  - T troca entre fim de tarde e noite.
  - P liga e desliga o pós-processamento.
  - C mostra as caixas de colisão.
  - E interage: entrar ou forçar a porta de uma loja, vasculhar, abrir caixotes, acender a fogueira, voltar à Estação
    pela saída no começo da rua.
  - K leva a equipe até a próxima patrulha.
  - Na Estação: o menu da esquerda abre cada cômodo (mouse, ou setas e Enter); Esc volta à vista geral. A partida é na
    Preparação.
  - Na luta: clique na habilidade e depois no alvo (no teclado ou gamepad, setas e Enter/A; Backspace/B volta).
    Mover, Defender e Fugir ficam à direita.
- **Capturas, tempos de quadro e teste de colisão:** `"$GODOT" --path . --resolution 1920x1080 -- --capture=<pasta>`.
  Abre uma janela, tira 9 fotos (dia, noite e chuva), testa o líder andando contra um carro e contra uma fachada (`PASS`
  ou `FAIL`) e joga a jornada: a suspeita da primeira patrulha, a luta (HUD, uma ação, o resultado, a rua depois), a entrada
  numa casa e uma busca. Usa uma campanha própria, na pasta da captura. Grava
  `frames.txt` e sai.
- **Captura dos cenários:** `"$GODOT" --path . --resolution 1920x1080 -s res://tools/capture_scenarios.gd -- --out=<pasta>`
  (opcional `--maps=RiverDock,FloodedDepot`). Em cada zona dos seis mapas: fim de tarde e noite com chuva, tempo de quadro,
  equipe e patrulhas no piso e o líder preso à faixa (`PASS`/`FAIL`). Sai com código 1 se algo falhar.
- **Exportar:** `"$GODOT" --headless --path . --export-release "Web" build/web/index.html` e
  `"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/AfterHumans.exe`. Os export
  templates da 4.7.2 precisam estar instalados.
- **Servir a web:** `python -m http.server 8060 --directory build/web` e abrir `http://localhost:8060`.

## Referência Unreal

O projeto Unreal antigo é a pasta onde este repositório mora localmente. Ele não vai para o GitHub e serve só como fonte
de regras, dados e arte para portar. `tools/sync_assets.py` copia de lá o que o jogo usa, e o resultado é versionado
aqui: o projeto roda e exporta sem a pasta da Unreal.
