# O Guaxinim e o Tatu redesenhados (#225) e as duas poses deles (#221)

![Antes (a main, à esquerda) e depois (à direita). Por linha: os seis lado a lado na rua, na pose de exploração (os pés na mesma linha, as alturas do jogo); os mesmos na pose de luta (a guarda de quem tem uma); a fila na rua com o Bento, a Íris, o Guaxinim e o Tatu; a primeira luta da fase 1 com essa fila](recruits_redraw/before_after.jpg)

A arte é do Codex: o redesenho no PR #229 (`docs/design/recruits_redraw.md`, tag `codex-pr229-originals`) e as poses
paradas no PR #231 (tag `codex-pr231-originals`). Pela decisão do Lucas de 01/11, a integração passou para o Claude 2.

## O que entra

- **A ferramenta:** `tools/sync_combat_art.py --recruits-redraw` (e o mesmo passo na conversão completa).
  - Lê o contrato `docs/design/recruits_redraw/contract.json` e os PNG da tag.
  - Converte todas as poses que o jogo usa dos dois: o parado, os 4 golpes de cada um, o dano, a queda, a esquiva, o
    bloqueio e a pose nova de usar item. Usa o registro fixo do parado: o pé no mesmo ponto em todas.
  - Copia o retrato de 256 px 1:1.
  - Os ids não mudam (`raccoon_recruit_01`, `armadillo_recruit_01`, `rato`, `tatu`).
  - Só os ícones das habilidades continuam os da web antiga.
  - Os PNG extraídos ficam no `.gitignore`, e as camadas antigas da #211 não entram.
- **As alturas** (`scripts/world/character_heights.gd`): Guaxinim 1,30 → 1,44 m e Tatu 1,35 → 1,56 m, as de destino do
  redesenho.
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
- `tests/test_combat_art.gd` e `tests/test_skins.gd`.
- `tools/capture_225.gd`: as fotos acima. Roda também na `main` de antes.
- `tests/run_all.gd` inteiro e o modo de captura da rua.
