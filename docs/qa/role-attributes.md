# As resistências e o crítico por papel (#189 PR 2, #258)

![Por linha: a ficha do Bento na partida, no PR 1 à esquerda e nesta branch à direita, que ganha "Resiste: dano por turno 20% · deslocamento 40% · atordoamento 30%"; a luta, igual; e a ficha da Nick no texto Maior, em português e em inglês, com os números no título e "Crítico 15% (papel +5)"](role-attributes/before_after.jpg)

Segue a matriz da seção 5 da proposta da #189, aprovada pelo Orquestrador em nome do Lucas. Vale também para a #258.

## O que entra

- **As colunas novas em `data/classes.json`:**

  | Papel | Dano por turno | Deslocamento | Atordoamento | Crítico |
  |---|---|---|---|---|
  | Proteção | 20% | 40% | 30% | 10% |
  | Incursão | 10% | 10% | 10% | 15% |
  | Química | 40% | 10% | 10% | 10% |
  | Tiro | 10% | 20% | 20% | 13% |
  | Sabotagem | 30% | 20% | 10% | 12% |
  | Resgate | 30% | 60% | 40% | 10% |

- **O motor** lê o papel do herói em quatro pontos:
  - o dano por turno (sangramento e contaminação);
  - o empurrão, tanto o da ação do inimigo quanto o de uma habilidade;
  - o atordoamento;
  - a chance de crítico, que passa a ser 10% mais o crítico do papel.
- **A paridade:** os padrões são os de antes. Hoje todo herói já resistia 20% ao dano por turno e ao empurrão (o motor
  usava 0,2 fixo), não resistia ao atordoamento e tinha 10% de crítico. Os kits históricos da paridade não têm as
  colunas, então lutam e sorteiam igual, com 48 de 48.
- **O atordoamento** só sorteia com resistência acima de 0, e não acrescenta sorteio a quem não tem.
- **A ficha fora da luta**, na partida, ganha a linha "Resiste: dano por turno N% · deslocamento N% · atordoamento N%".
  No Incursão, no Tiro e na Sabotagem, ganha também "Crítico N% (papel +N)". Os números ficam no título, porque no texto
  Maior a ficha esconde as explicações. A inspeção na luta não muda: ela tem altura fixa, e com uma linha a mais as
  explicações dos passivos sumiam.
- **O inimigo** que usa uma habilidade de classe fica com o crítico de todos, sem o do papel.

## Para o Lucas

- **Muda o equilíbrio.** O Incursão e o Tiro passam a resistir menos ao dano por turno (10% contra os 20% de antes), e a
  Química e o Resgate passam a resistir mais. O Resgate quase não é empurrado (60%), e o Incursão quase sempre é (10%).
- **Hoje nenhum inimigo atordoa herói.** Só os heróis atordoam (o Impacto Hidráulico, a Poeira e a Investida), então a
  resistência a atordoamento fica pronta para quando houver um inimigo que atordoe.

## Testes

- `tests/test_role_attributes.gd`:
  - a matriz como foi aprovada, e os padrões no kit histórico;
  - o motor com o sorteio fixo: o dano por turno, o empurrão, o atordoamento (sem sorteio quando a resistência é 0) e o
    crítico do Incursão;
  - a ficha.
- `test_combat_parity`: 48 de 48.
- `tests/run_all.gd` inteiro.
- As fotos acima saem de `tools/capture_sheet.gd`, no PR 1 e nesta branch.

## QA

- **Rodada 1: REPROVADO.** Um médio: no texto Maior, as linhas "Resistências do papel" e "Olho para o ponto fraco"
  apareciam sem os números, porque eles estavam só na explicação.

  A QA conferiu a ordem dos sorteios caminho por caminho:
  - o empurrão de inimigo e o de habilidade;
  - o inimigo imune;
  - o dano por turno e o tutorial;
  - o atordoamento.

  Também conferiu, numa luta com o sorteio fixo:
  - o Resgate segurando o empurrão;
  - o crítico do Incursão, do Tiro e da Sabotagem.

  **Correção:** os números passaram para o título, com um teste no nível mais encolhido da ficha. Também entraram as
  baixas: o comentário do empurrão, e o inimigo com classe sem o crítico do papel.
- **Rodada 2: APROVADO.** Na partida, no Maior e no Normal, em português e em inglês, os números aparecem no título nos
  quatro cartões. No Maior, a linha "Resiste: …" quebra em duas, sem cortar. A luta com o sorteio fixo e a contagem de
  sorteios continuam iguais à rodada 1, e a paridade fica em 48 de 48.
