# Nível dos heróis, XP e Treino (#90)

Fotos de `tools/capture_levels.gd` (1920x1080, gl_compatibility): o Alojamento com o Bento pronto para treinar, o Nick
no meio do caminho e a Íris no nível 4; a escolha do Treino; e o relatório de uma volta com o XP.

![antes e depois](hero-levels/before-after.jpg)

À esquerda, o antes, na `main`: o Alojamento só com a vida, o instinto e a relíquia, e o relatório sem o XP. À
direita, o depois: o nível e a barra do XP de cada um, o Treino (com o custo em sementes), as melhorias escolhidas e
o XP de cada herói no relatório.

![o Treino](hero-levels/training.jpg)

A escolha do Bento entre as duas melhorias do cão, e o Bento no nível 2 com Mais fôlego (vida 36).

## Como funciona

- **O XP** (`data/hero-xp.json`):
  - cada herói que lutou ganha 8 por luta, 3 por inimigo derrubado, 2 por proteção (a guarda ou o bloqueio dado a
    outro herói), 1 a cada 5 de cura e 1 a cada 10 de dano (o `tally` da luta);
  - a fuga não dá o XP da luta;
  - cada herói vivo da equipe ganha 15 na jornada concluída;
  - os recrutas ganham 1,5 vez isso.

  O relatório da volta mostra o XP de cada um. No nível 10, o XP para de acumular.
- **O Treino** (no Alojamento, a Sala dos Personagens): com o XP do nível (`data/hero-levels.json`, de 30 a 140) e as
  sementes (de 1 a 4), o herói sobe um nível e escolhe uma de duas melhorias da espécie (`data/hero-upgrades.json`):

  | Melhoria | O que faz | Limite | Espécies |
  |---|---|---|---|
  | Mais fôlego | +2 de vida máxima | 9 | cão, sapo, rato, tatu (e reserva) |
  | Sangue frio | começa cada luta com 10 de instinto a menos (só na luta: depois, o instinto volta) | 4 | cão, sapo, tatu (e reserva) |
  | Passo ligeiro | +1 de velocidade | 2 | gato, coruja, rato |
  | Mão treinada | +1 no dano ou na cura da habilidade principal (Corte de Fase, Disparo Perfurante) | 3 | gato, coruja |

  Com uma melhoria da espécie no limite, as de reserva completam as duas, para todos chegarem ao nível 10 escolhendo.
- **Na luta,** o nível só soma por cima (`AHHeroLevels.combat_bonus`):
  - a vida fica no máximo do herói;
  - a velocidade e o +1 na habilidade, como o treino da Pesquisa (a faixa na tela da luta já mostra o +1);
  - o instinto a menos no começo da luta.

  Um herói de nível 1 é igual ao de antes, e a paridade com a Unreal continua 48/48.
- **O save** passou para a versão 2, com `level`, `xp` e `upgrades` em cada herói. O save da versão 1 abre migrado:
  cada herói vivo no nível 1, sem melhorias, com 85 de XP por fase já concluída (o de uma fase jogada), para treinar e
  escolher ele mesmo. O save não diz quando cada um chegou: o recruta recebe o mesmo.

## O equilíbrio (`tools/measure_balance.gd --levels=`, 40 sementes, política auto)

O nível suposto ao entrar em cada fase sem repetir fases (`LEVELS_TYPICAL`, pela curva e pelo XP de umas cinco lutas
e da jornada por fase): fase 1 no 1, fase 2 no 3, fase 3 no 4, fase 4 no 6, fase 5 no 7. Na tabela, o guardião em luta
avulsa e a jornada com cuidados (termina · voltam):

| Fase | Sem nível | Nível típico | Nível 10 |
|---|---|---|---|
| 1 | 100% · 100% · 3,75 | 100% · 100% · 3,75 | 100% · 100% · 3,98 |
| 2 | 100% · 92% · 3,02 | 100% · 98% · 3,45 | 100% · 100% · 3,98 |
| 3 | 95% · 35% · 0,95 | 100% · 78% · 2,48 | 100% · 100% · 3,75 |
| 4 | 90% · 30% · 0,72 | 100% · 78% · 2,58 | 100% · 92% · 3,35 |
| 5 | 12% · 0% · 0,00 | 80% · 10% · 0,15 | 88% · 30% · 0,72 |

Com o nível típico, as fases 3 e 4 ficam bem mais fáceis, e a fase 5 continua difícil. Os números das tabelas
(curva, sementes, XP e melhorias) são propostas para o Lucas ajustar; nenhum outro número do jogo mudou.

## Testes

`tests/test_hero_levels.gd` (47 verificações) confere:
- as tabelas: os níveis 2 a 10 e duas melhorias para cada classe;
- o Treino:
  - sem XP, não treina;
  - com XP e sementes, treina e gasta os dois;
  - a melhoria de outra espécie é recusada;
  - Mais fôlego dá +2 de vida;
  - o limite de cada melhoria, com a reserva completando as duas;
  - o limite no 10, e no 10 o XP não acumula;
- na luta: a velocidade, o +1 no Corte de Fase (com a mesma semente, o golpe nunca sai menor e às vezes sai maior) e o
  instinto a menos;
- o XP: o da luta pelo que cada um fez, o recruta ganhando mais, a jornada concluída e o relatório;
- o save: o nível, o XP e as melhorias voltam; o save da versão 1 abre migrado; uma versão de depois não abre;
- o Alojamento: o nível, o XP, o Treino, a escolha e o nível novo.

A paridade (`test_combat_parity`) continua 48/48.

## Rodadas da QA

- **Rodada 1 (reprovada):**
  - o Sangue frio gravava o instinto descontado, uma cura de graça a cada luta. Agora o desconto volta no fim da luta;
  - a tela da luta não mostrava o +1 da Mão treinada. Agora a faixa e a descrição somam o nível de quem age;
  - proteger não dava XP. Agora a guarda e o bloqueio dados a outro herói contam.
  - Também de gravidade baixa:
    - a escolha do Treino fecha com o painel;
    - a fuga não dá XP de luta;
    - a migração dá o XP de uma fase jogada (85) por fase concluída, e não aos mortos;
    - a mensagem do herói morto no Treino ficou clara.
- **Rodada 2 (aprovada):** as correções conferidas com saves v1 reais, o Alojamento com 12 heróis e o texto Maior.
  Ficam de gravidade baixa: o Sangue frio junto com um efeito que leva o instinto a 0 devolve um pouco a mais, e o
  recruta que chegou depois das fases recebe o XP da migração.
