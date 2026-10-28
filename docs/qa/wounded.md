# O herói ferido (#194)

![Antes (à esquerda) e depois (à direita): em cima, a equipe com o Bento a 6 de 34 e a Véspera a 9 de 30, com o coração rachado no retrato dos dois; embaixo, três momentos do andar, com o Bento pendendo no passo](wounded/before_after.jpg)

## A regra (`scripts/flow/wounded.gd`, `AHWounded`)

Os números ficam em `data/wounded.json`, para o Lucas ajustar:

- **Ferido** (`AHWounded.is_wounded(hero)`): vivo e com a vida abaixo de 50% da máxima (`Threshold`), ou Caído em
  recuperação (#118/#121), mesmo com a vida cheia. Uma função só, para a exploração, a Estação e a HUD. É o mesmo
  limite do "Ferimento grave" (o coração rachado) da Estação: o kit lê o `Threshold` daqui (`AHKit.heavy_below`), um
  número só para as duas telas. O kit trava o limite abaixo do "Em forma" (75%), para o "Ferimento leve" não
  sumir com um número alto demais. A issue propunha 40%; ficou 50%, o limite que o coração rachado já tinha na Estação.
- **O passo** (`AHWounded.speed_factor`): 70% da velocidade (`SpeedFactor`).
- **A pose** (`AHWounded.pose(idle)`): o `wounded.webp` da pasta da arte do herói, no canvas e na âncora do idle (a
  entrega do Codex, PR #209). Sem o arquivo, o idle de pé. A pose troca sozinha quando a arte entrar: até o #209 entrar na `main`, os heróis
  andam feridos no idle (o teste confere a troca com uma pose de mentira).

## Na exploração

- **A fila anda no passo do mais ferido** (`party_speed_factor`): ela anda junta, então com alguém ferido todos andam
  a 70%.
- **O mancar** de quem está ferido, andando:
  - um passo sobe inteiro e o outro só 55% (`LimpDip`);
  - o corpo pende até 3,5° para o lado do passo bom (`LimpTilt`);
  - a respiração fica duas vezes mais funda e mais lenta (`BreathDepth`).
- **"Reduzir efeitos" ligado:** só a pose e o passo mais lento, sem o balanço.
- **A pose de ferido**, quando a arte existir, troca na hora em que o herói fica ferido ou deixa de ficar (a vida muda
  com a luta, a comida e o curativo).

## Na HUD da exploração

O coração rachado (`state_wounded`, o da Sala dos Personagens) no canto do retrato do ferido, com a dica "Precisa se
recuperar". Some quando a vida volta acima do limite. O clique passa por ele até a plaquinha (a Formação escolhe o herói
clicando no retrato).

## Na Estação

A chegada do trem fica em `station.gd`, área do Claude 1: ele usa a mesma `AHWounded.is_wounded` e a `AHWounded.pose`
(combinado pelo Orquestrador).

## Testes

- `tests/test_wounded.gd` (novo, 28 verificações):
  - o limite (abaixo dele ferido, nele não), o Caído em recuperação, o morto e o herói ausente; o ferido é o
    "Ferimento grave" do kit em toda vida de 0 a 100, com o mesmo número;
  - a fração da velocidade e a pose (o arquivo da pasta com o canvas e a âncora do idle; sem o arquivo, o idle);
  - o limite travado abaixo do "Em forma";
  - na rua: a placa troca para a pose (uma de mentira, o `hurt.webp`) e volta ao idle com a cura; a velocidade que o
    `_physics_process` dá ao líder, ferido e inteiro; a troca de formação leva a pose e o mancar com o ferido;
  - a fila no passo do ferido, o ferido mancando e os inteiros retos, sem o balanço com "Reduzir efeitos";
  - o aviso na HUD só no ferido (com o clique passando para a plaquinha), e fora quando a vida volta;
  - o save: a vida baixa volta com ele.
- `tests/run_all.gd` inteiro.
- `tools/capture_194.gd`: a Rua com o Bento a 20% e a Véspera a 30%, parada e andando; roda também na `main` de antes.

## QA

- **Rodada 1: REPROVADO.** A regra, o passo (andando e correndo a 70%), o mancar, a pose com a arte do PR #209, a HUD
  no texto Maior e no daltonismo e o save passaram (`run_all` 86/86). Dois médios:
  - o coração rachado pegava o clique da Formação;
  - o limite de 40% não batia com o "Ferimento grave" (abaixo de 50%), que usa o mesmo ícone na Estação.

  Correção: o clique passa para a plaquinha, e um limite só, em `data/wounded.json` (50%), lido pelo kit. Das baixas: o
  corpo volta ao prumo suave ao parar, e a troca de formação confere de novo quem está ferido.
- **Rodada 2: APROVADO.** O clique no coração escolhe o herói na Formação (no xvfb); com 47% de vida o herói manca e
  mostra o aviso, e a Estação diz "Ferimento grave"; com 50%, nem um nem outro. O prumo volta suave ao parar. `run_all`
  86/86, com a paridade 48/48. Notas baixas: com o `Threshold` acima de 0,75 o "Ferimento leve" some (o
  `HEALTHY_ABOVE`); a pose de ferido dos recrutas pede uma pasta por recruta (#191).

- **Revisão do PR #216: AJUSTAR ANTES.** A pose de ferido fica pendente do #209 (dito na #194), e os testes ganharam
  a troca de pose na rua, a velocidade medida no `_physics_process` e a troca de formação com o ferido; o kit trava o
  `Threshold` abaixo do "Em forma".
