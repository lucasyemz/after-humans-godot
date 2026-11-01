# As duas poses paradas: exploração e combate (#221)

![Antes (a main, à esquerda) e depois (à direita). Por linha: a fila na rua (a pose de exploração, igual); a primeira luta da fase 1 (os fundadores na guarda, com as armas na mão: a espada do Nick, o rifle da Véspera, a guarda do Bento); a mesma luta com o Bento na Ronda (a guarda da skin); a fila de volta à rua depois da vitória (a pose de exploração de novo)](stances/before_after.jpg)

A arte é do Codex (PR #231, `docs/design/stances.md`). Os originais ficam na tag `codex-pr231-originals`.

## O que entra

- **A ferramenta** ganhou o modo `tools/sync_combat_art.py --stances`, sem a pasta da Unreal, e o mesmo passo na
  conversão completa. Ele lê o contrato `docs/design/stances/contract.json` e os PNG da tag (`git archive
  codex-pr231-originals art/combat/source/stances_20261028 | tar -x`). A guarda de cada fundador vira
  `combat_idle.webp` ao lado do `idle.webp`, em WebP na metade da resolução, com a tela, a âncora no pé e a altura do
  corpo do `idle`. A escala não muda pela guarda flexionada. A da skin Bento Ronda vai para a pasta dela, com o mesmo
  nome. Nada é copiado à mão, e os PNG de origem não entram no Git.
- **O manifesto** (`data/presentation/combat_art.json`) ganhou `combat_idle` nos quatro fundadores.
- **Na luta:** a pose parada é a guarda (`combat_idle`), quando o herói tem uma. Senão, é o `idle`. Ao entrar na luta,
  a fila passa para a guarda; ao sair (vitória, fuga), volta à pose de exploração, a de sempre na rua, na Estação e no
  acampamento. A pose de ferido (#194) e as poses de ataque não mudam.
- **As skins:** a skin usa a guarda dela. Uma skin sem a guarda própria luta no parado dela, nunca na guarda da roupa
  padrão (seria outro figurino). O `AHSkins.missing` lista a guarda que falta.

## O que fica para depois

- **O Guaxinim e o Tatu.** As poses deles na #221 (a guarda do Guaxinim e a exploração do Tatu, com as mãos livres)
  foram desenhadas sobre o redesenho da #225 (tag `codex-pr229-originals`), e o jogo ainda usa a arte antiga dos dois.
  A integração da #225 é do Orquestrador PC, como diz a própria issue. Depois dela, é só tirar os dois de
  `STANCES_WAIT_FOR_225` na ferramenta e converter de novo. Para o Tatu, a pose de hoje (com a marreta e o escudo) vira
  o `combat_idle`, e a nova vira o `idle`.

## Testes

- `tests/test_stances.gd` (33 verificações):
  - nos dados, cada fundador tem a guarda, com o arquivo, a mesma tela, a mesma âncora e a mesma textura do `idle`;
  - a skin Bento Ronda luta na guarda dela, e uma skin sem guarda fica no parado dela;
  - na luta de verdade, a fila entra na guarda e volta à pose de exploração depois da vitória.
- `tests/test_skins.gd`: a Ronda com as 18 poses (a guarda entrou).
- `tools/capture_221.gd`: as fotos acima, com `--skin` para a Ronda. Roda também na `main` de antes.
- `tests/run_all.gd` inteiro, com a paridade 48/48.

## QA

- **Rodada 1: REPROVADO.** Um médio: a pasta das fontes extraída pela receita (`art/combat/source/stances_20261028/`,
  8,4 MB de PNG) não estava no `.gitignore`, e um `git add -A` a levaria para o Git. A troca de pose passou em todos os
  caminhos testados (a fase 2 com herói ferido e recruta, a fuga e a vitória), e a ferramenta rodada duas vezes não
  mudou nada.

  Correção: a pasta entrou no `.gitignore`, como as fontes das poses ajoelhadas (#13). A largura do corpo da guarda
  (a do idle, de propósito) ganhou um comentário na ferramenta.

- **Rodada 2: APROVADO.** A pasta das fontes extraídas fica fora do Git (conferido com o `git check-ignore` e o `git
  status` depois de extrair a tag). Nenhum código do jogo mudou desde a rodada 1. Ficam observações baixas: a conversão
  completa refaz as guardas uma vez por herói (o mesmo padrão do `codex_reactions()`), e uma skin sem arte nenhuma
  perde a guarda padrão (a Sala não lista skins sem arte).
