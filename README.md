# After Humans (Godot)

RPG tático por turnos, com personagens pintados em 2D sobre cenários 2,5D. Esta é a versão na Godot. Ela começou como o
protótipo da avaliação de migração da Unreal e hoje tem:

- **Combate:** o motor em GDScript, portado do C++ da Unreal. Reproduz as 48 lutas gravadas passo a passo
  (`tests/test_combat_parity.gd`).
- **Combate na rua (fase 1 do plano):** duas patrulhas na Rua das Vitrines. Chegar perto começa a luta ali mesmo:
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
scripts/core/     GameData (autoload): todas as tabelas de data/
scripts/campaign/ Campaign (autoload): campanha nova, save e load
scripts/flow/     GameFlow (autoload) e o boot
scripts/combat/   motor de combate, tabelas tipadas, a sessão de luta (comandos e lances) e a arena (animação)
scripts/ui/       HUD de combate
scripts/world/    AHSpriteCard: personagem pintado com o pé fixo ao trocar de pose
scripts/street/   Rua das Vitrines montada em código, chuva, colisão e as patrulhas
shaders/          pós-processamento Emberfall, fogueira que apaga, chuva e fumaça, feixes de luz, halos, silhuetas
scenes/           boot.tscn (cena inicial, abre a rua pelo GameFlow) e street.tscn
data/             JSON de produção (classes, habilidades, inimigos...) e a gravação de paridade do combate;
                  presentation/combat_art.json diz onde está cada pose, ícone e som e mede a âncora no pé
audio/            sons do combate
art/              arte pintada usada pelo jogo (street: a rua; combat: heróis, inimigos, efeitos e ícones)
tests/            run_all.gd e os test_*.gd (paridade 48/48, save, dados, cenas e input)
tools/            sync_assets.py e sync_combat_art.py (trazem dados, arte e sons da referência Unreal; o segundo
                  precisa do Pillow) e define_input.gd (grava as ações)
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

- **Jogar:** `"$GODOT" --path .`. Acrescente `--rendering-method gl_compatibility` para ver no PC o renderer da web.
  - A/D (ou ←/→) andam pela rua; W/S (ou ↑/↓) vão para o fundo e para a frente, inclusive dentro dos becos.
    No gamepad: analógico esquerdo ou direcional.
  - Shift (ou RB) corre.
  - R liga e desliga a chuva.
  - T troca entre fim de tarde e noite.
  - P liga e desliga o pós-processamento.
  - C mostra as caixas de colisão.
  - K leva a equipe até a próxima patrulha (as duas ficam em X 17 m e 46 m).
  - Na luta: clique na habilidade e depois no alvo (no teclado ou gamepad, setas e Enter/A; Backspace/B volta).
    Mover, Defender e Fugir ficam à direita.
- **Capturas, tempos de quadro e teste de colisão:** `"$GODOT" --path . --resolution 1920x1080 -- --capture=<pasta>`.
  Abre uma janela, tira 9 fotos (dia, noite e chuva), testa o líder andando contra um carro e contra uma fachada (`PASS`
  ou `FAIL`) e joga uma luta contra a primeira patrulha (fotos do HUD, de uma ação, do resultado e da rua depois). Grava
  `frames.txt` e sai.
- **Exportar:** `"$GODOT" --headless --path . --export-release "Web" build/web/index.html` e
  `"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/AfterHumansPrototype.exe`. Os export
  templates da 4.7.2 precisam estar instalados.
- **Servir a web:** `python -m http.server 8060 --directory build/web` e abrir `http://localhost:8060`.

## Referência Unreal

O projeto Unreal antigo é a pasta onde este repositório mora localmente. Ele não vai para o GitHub e serve só como fonte
de regras, dados e arte para portar. `tools/sync_assets.py` copia de lá o que o jogo usa, e o resultado é versionado
aqui: o projeto roda e exporta sem a pasta da Unreal.
