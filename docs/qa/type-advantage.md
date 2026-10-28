# A vantagem de tipo: linhagens, famílias mecânicas e +25% no dano direto (#227)

![Antes (à esquerda) e depois (à direita): a inspeção do herói da vez e de um Rastreador, com a linhagem ou a família e as duas linhas da vantagem; a mira num alvo com vantagem, com "Vantagem +25%" na plaqueta, o ícone e a linha da dica, nos textos Normal e Maior](type-advantage/before_after.jpg)

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
  +25% de Gatos e Perseguidores" (os nomes curtos, para caber; os completos na explicação). No nível mais apertado da
  inspeção (o texto Maior com muitos traços, como o Bento), as duas linhas saem dos passivos e a classificação fica na
  linha da velocidade.
- **A mira:** a plaqueta do alvo diz "Vantagem +25%" com o ícone (as setas do kit) e a cor do bem; a dica soma
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
