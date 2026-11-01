# O Guaxinim e o Tatu redesenhados (#225) e as duas poses deles (#221)

![Antes (a main, à esquerda) e depois (à direita). Por linha: os seis lado a lado na rua, na pose de exploração (os pés na mesma linha, as alturas do jogo); os mesmos na pose de luta (a guarda de quem tem uma); a fila na rua com o Bento, a Íris, o Guaxinim e o Tatu; a primeira luta da fase 1 com essa fila](recruits_redraw/before_after.jpg)

A arte é do Codex: o redesenho no PR #229 (`docs/design/recruits_redraw.md`, tag `codex-pr229-originals`) e as poses
paradas no PR #231 (tag `codex-pr231-originals`). Pela decisão do Lucas de 01/11, a integração passou para o Claude 2.

## O que entra

- **A ferramenta:** `tools/sync_combat_art.py --recruits-redraw` (e o mesmo passo na conversão completa). O modo
  reaplica as poses da #221 em seguida e pede as fontes das duas tags (`codex-pr229-originals` e `codex-pr231-originals`).
  - Lê o contrato `docs/design/recruits_redraw/contract.json` e os PNG da tag.
  - Converte todas as poses que o jogo usa dos dois: o parado, os 4 golpes de cada um, o dano, a queda, a esquiva, o
    bloqueio e a pose nova de usar item. Usa o registro fixo do parado: o pé no mesmo ponto em todas.
  - Copia o retrato de 256 px 1:1.
  - Os ids não mudam (`raccoon_recruit_01`, `armadillo_recruit_01`, `rato`, `tatu`).
  - Só os ícones das habilidades continuam os da web antiga.
  - Os PNG extraídos ficam no `.gitignore`, e as camadas antigas da #211 não entram.
- **As alturas** (`scripts/world/character_heights.gd`): Guaxinim 1,30 → 1,44 m e Tatu 1,35 → 1,56 m, as de destino do
  redesenho.
- **A largura:** o Tatu redesenhado mede 0,84 m (antes, 1,48 m) e cabe na posição da fila, como pede a issue. O espaço
  maior para quem é mais largo que a posição (#196) continua e é testado com um herói largo de teste.
- **As duas poses (#221):**
  - o Guaxinim ganhou a guarda;
  - o Tatu passou a ter a exploração com as mãos livres (o `idle.webp` novo) e a guarda com a marreta e o escudo (o
    parado do redesenho, agora `combat_idle.webp`);
  - a ferramenta tirou os dois de `STANCES_WAIT_FOR_225`, e o `--stances` agora aplica as duas poses;
  - na luta, a arte do recruta traz a guarda dele (`AHCombatArena._variant_entry`); os recrutas sem guarda (o cão, o
    gato, o sapo e a coruja) não herdam a do fundador.

## O que fica de fora

- **As poses de acampamento dos dois** (seat e sleep, #210). O redesenho já as traz, mas a ferramenta do acampamento
  (`tools/build_camp_poses.py`) pede a altura do assento (`support`), que o contrato não tem, e o acampamento ainda não
  mostra os dois. Ficam para quando o acampamento os usar.

## Testes

- `tests/test_stances.gd` (75 verificações). Novo nesta parte:
  - o redesenho com o pé, a altura do corpo e todas as poses do contrato;
  - os golpes com o pé do parado;
  - a pose de item;
  - as alturas de destino;
  - a guarda dos dois;
  - a guarda do recruta na luta, sem herança para o recruta sem guarda.
- `tests/test_recruit_art.gd`: a escala da #225 no lugar da do #196 (o Guaxinim entre a Íris e o Nick, o Tatu entre o
  Guaxinim e o Bento).
- `tests/test_combat_room.gd`: o Tatu e o Guaxinim cabem na posição e ficam na fila de sempre; o espaço maior é testado
  com um herói largo de teste, na medida do Tatu antigo.
- `tests/test_combat_art.gd` e `tests/test_skins.gd`.
- `tools/capture_225.gd`: as fotos acima. Roda também na `main` de antes.
- `tests/run_all.gd` inteiro e o modo de captura da rua.

## QA

- **Rodada 1: REPROVADO.**
  - Um problema médio: o `--recruits-redraw` rodado sozinho gerava diff e desfazia a #221 dos dois. O parado do Tatu
    voltava a ser a guarda, e o `combat_idle` dos dois sumia do manifesto.
  - Duas observações baixas:
    - a branch estava atrás da `main`;
    - o parado do Tatu leva a largura da guarda.
  - A QA conferiu e aprovou a luta de verdade, com o Tatu, o Guaxinim, o Bento e o Nick:
    - a exploração na rua, a guarda na luta e a volta à exploração depois da vitória;
    - as folgas entre vizinhos;
    - os golpes e as reações com o pé e a altura do parado;
    - os retratos na HUD;
    - as capturas.

  **Correção:** o `--recruits-redraw` reaplica as poses da #221 logo depois, como a conversão completa. Numa cópia
  isolada, ele não gera mais diff. A largura do Tatu fica a da guarda de propósito, e o comentário da ferramenta
  explica o motivo: a fila se espaça pela pose mais larga. A `main` foi juntada.
