# A vantagem de tipo: linhagens, famílias mecânicas e +25% no dano direto (#227)

![Antes (a main, à esquerda) e depois (à direita), o Bento mirando um Rastreador. Por linha: a mira no Normal e no Maior ("+25%" na plaqueta e a linha da vantagem na dica), a inspeção do Bento e do Rastreador no Normal e no Maior (a linhagem ou a família e as linhas da vantagem). A ordem das vezes varia entre as execuções: no depois, a vez do Bento chega mais tarde na rodada](type-advantage/before_after.jpg)

## Os dados

- **`Lineage` na classe** (`data/classes.json`): `cao` Canidae, `gato` Felidae, `sapo` Anura, `coruja` Strigiformes,
  `rato` Procyonidae (o Guaxinim) e `tatu` Cingulata. Vale igual para fundadores e recrutas; o save não muda, porque a
  linhagem vem da classe.
- **`MechFamily` no inimigo** (`data/enemies.json`), nos 26, com a tabela do Lucas. O Hóspede Rubro e os três Ecos têm
  `MechFamilyProvisional: true` (classificação provisória). O `Category: Machine` continua.
- **As classificações** (`data/type-classes.json`): o nome na tela (`DisplayName`, "Linhagem dos Cães", "Família
  Perseguidora"), o curto (`ShortName`, "Cães", "Perseguidores") e quem cada uma vence (`Beats`). O nome científico fica
  só nos dados.
- **A chave** (`data/type-advantage.json`): `Enabled` e `Multiplier` (1,25).

## A regra (`AHCombatEngine.type_multiplier`)

- O atacante cuja classificação vence a do defensor causa ×1,25; os demais, ×1. Só no sentido do atacante: o cão
  vence o gato, o gato no cão é neutro.
- **Só no dano direto**, nos dois lados (o herói atacando e o inimigo atacando), na ordem: sorteio, crítico ×1,5,
  fraqueza, percentual contra máquina, **o tipo**, Vulnerável ×1,5, Bloqueio, mínimo de 1.
- **O arredondamento** é para o mais próximo, com o meio para cima (`floor(x × 1,25 + 0,5)`): 2 → 3, 3 → 4, 4 → 5,
  6 → 8.
- **Fora da regra:** o dano contínuo (sangramento, contaminação, corrosão), a cura e o Instinto.
- **Na luta**, o golpe com vantagem mostra "Vantagem +25%" sobre o alvo.

### O acúmulo da Carga Voltaica (a Íris contra uma máquina Industrial)

| | Sem o tipo | Com o tipo |
|---|---|---|
| Golpe normal (4–7) | 5–8 (o percentual de 125%) | 6–10 |
| Crítico (6–10) | 7–12 | 9–15 |

## Na tela

- **A ficha** (a do apontar, a da Preparação) e **a inspeção** da luta: a linhagem ou a família numa linha própria
  (na inspeção apertada, junto da velocidade) e, nos efeitos passivos, "Dano +25% em Guaxinins e Emissores" e "Recebe
  +25% de Gatos e Perseguidores" (os nomes curtos, para caber; os completos na explicação). No inimigo, as duas
  linhas são tentadas em todos os níveis antes de sair: saem antes as explicações dos passivos e dos estados, e o
  inimigo as mostra no Normal e no Maior, com ou sem estados (salvo no Maior com muitos estados ao mesmo tempo:
  aí a família fica na linha da velocidade). Sem estados, a coluna dos estados fica do tamanho do
  "Nenhum agora", e a folga vai para os passivos (as explicações cabem junto). Na inspeção do herói com muitos traços (o Bento e a Íris), as linhas não cabem junto das explicações
  dos passivos: ficam as explicações, e a linhagem vai para a linha da velocidade (as duas linhas estão na ficha, como
  a issue pede).
- **A mira:** a plaqueta do alvo diz "NOME · +25%", com o ícone (as setas do kit) dentro e a cor do bem; a dica soma
  "Vantagem +25%" ao alvo e a linha com o ícone, e o "pode cair" já conta o multiplicador. Com a plaqueta mais larga, a
  dica que não cabe com folga de nenhum lado vai para o lado que menos cobre (`_dodge_tip`): no texto Maior, encostada
  na borda esquerda, ela não cobre mais a plaqueta.
- Com a regra desligada, a tela não fala de vantagem. Os ícones das 12 classificações ficam para um pedido de design.

## A medição (`tools/measure_balance.gd --types=off|on`, 40 sementes)

Vitória contra o guardião e a jornada com cuidados (quantas terminam e quantos fundadores voltam), com a regra
desligada → ligada. As patrulhas mudam pouco (rodadas de 0,1 a 0,3 a menos com ela ligada).

**Os fundadores da campanha nova** (sem relíquias, treinos nem níveis):

| Fase | Guardião: vitórias | Jornada com cuidados: termina · voltam |
|---|---|---|
| 1 | 100% → 100% | 100% · 3,75 → 100% · 3,77 |
| 2 | 100% → 100% | 92% · 3,02 → 90% · 2,85 |
| 3 | 95% → 95% | 35% · 0,95 → 45% · 1,23 |
| 4 | 90% → 90% | 30% · 0,72 → 22% · 0,45 |
| 5 | 12% → 5% | 0% → 0% |

**O progresso típico** (`--gear=typical --levels=typical`):

| Fase | Guardião: vitórias | Jornada com cuidados: termina · voltam |
|---|---|---|
| 1 | 100% → 100% | 100% · 3,75 → 100% · 3,77 |
| 2 | 100% → 100% | 98% · 3,42 → 98% · 3,23 |
| 3 | 100% → 98% | 58% · 1,60 → 62% · 1,85 |
| 4 | 100% → 100% | 58% · 1,65 → 58% · 1,70 |
| 5 | 45% → 50% | 0% → 0% |

O efeito é pequeno: nas fases 1 a 4 fica dentro da variação de 40 sementes. Na fase 5, sem progresso, O Porteiro
(Blindado, que vence o Nick) pesa mais (12% → 5%); com o progresso típico, os bônus dos heróis compensam (45% → 50%).

## Observações para o Lucas

- **Os contra-ataques fortes estão nos recrutas raros.** O Condutor (o Relé de Defesa, o inimigo mais comum) só
  recebe o bônus do Tatu, e o Blindado (O Porteiro, o guardião da fase 5) só o do Guaxinim. O time inicial não tem
  vantagem contra eles; o Porteiro tem contra o gato.
- **A família Emissora quase não ataca.** O Emissor de Comando e o Pipoco não dão dano direto: o bônus contra Canidae só
  vale no Recreador.
- **O Drone de Expurgo** fica Perseguidor até a medição (lê mais como Industrial).
- **A Faísca** (Industrial) é ajudante do Demolidor (Blindado), e o **Núcleo Nulo** é chefe, mas não está em nenhum
  encontro.

## A paridade

`tests/test_combat_parity.gd` liga `type_advantage.Enabled = false`: 48 de 48, sem mudar nenhum resultado esperado.

## Testes

- `tests/test_type_advantage.gd` (novo):
  - a cobertura (toda classe e todo inimigo, os protótipos também) e a tabela de quem vence quem;
  - o arredondamento;
  - pelo motor, com o sorteio fixo: a vantagem, o neutro, a direção, o lado do inimigo e o acúmulo com o crítico, a
    Carga Voltaica, o Vulnerável e o Bloqueio, com números fechados, e desligada;
  - fora da regra: o sangramento, a cura e o Instinto;
  - a ficha e a inspeção, ligada e desligada.
- `tests/test_combat_parity.gd` com a regra desligada; `tests/run_all.gd` inteiro.
- `tools/capture_227.gd`: a inspeção e a mira, nos textos Normal e Maior; roda também na `main` de antes.

## QA

- **Rodada 1: REPROVADO.** A regra do motor, a paridade, o `run_all` 89/89 e a medição passaram. Três médias:
  - a inspeção perdia as explicações dos passivos no Normal e cortava a espécie no Maior;
  - a dica da mira com vantagem esticava (de 478 para 744 px no Maior) e cobria a equipe;
  - "Linhagem dos Cães" desde a fase 1 contradiz o relatório da fase 3, em que "linhagem" é uma palavra que ninguém
    entende (§14): perguntado ao Lucas na issue.

  Correção: na inspeção, cada nível tenta primeiro com a vantagem inteira (sem as explicações dela), depois só a
  classificação e, sem caber, como era; ninguém cai de nível nem corta. A linha da vantagem na dica quebra na largura
  de sempre. Das baixas: a plaqueta do ALVO encurta para "NOME · +25%" (o ícone e a cor seguem) e o "pode cair" conta
  o percentual contra máquina.

- **Rodada 2: REPROVADO.** Os três médios da rodada 1 corrigidos, o `run_all` 101/101. Um médio: no texto Normal, a
  inspeção do inimigo mostrava a família, mas nunca as duas linhas (a coluna vazia dos estados tinha 220 px de mínimo).

  Correção: a coluna dos estados vazia fica do tamanho do título e do "Nenhum agora" (`_states_floor`), e a folga vai
  para os passivos. O `test_character_sheet` confere, na luta de verdade e no texto Normal, as duas linhas em cada
  inimigo sem estados.

- **Rodada 3: REPROVADO.** Sem estados, certo; com um estado só (Sangra 2), os 4 inimigos perdiam as duas linhas de
  novo, porque o nível 0 sem as linhas vinha antes do nível 1 com elas. O caso do Bento e da Íris foi aceito.

  Correção: no inimigo, as tentativas com as duas linhas vêm todas antes das sem elas. O `test_character_sheet` confere
  também com Sangra 2 em todos (falha no código da rodada 3).

- **Rodada 4: APROVADO.** Os 8 personagens no Normal e no Maior, sem estados, com um e com 10 estados: nada cortado,
  e as duas linhas do inimigo aparecem em todos os casos, salvo no Maior com 10 estados ao mesmo tempo. O `run_all`
  101/101, com a paridade 48/48.
