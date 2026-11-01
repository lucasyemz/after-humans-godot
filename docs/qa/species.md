# A espécie no indivíduo e os nomes de papel (#189, PR 1, com a #258)

![Antes, na main, à esquerda, e depois, à direita. Por linha: a ficha do Bento na luta ("Cão · Tanque e Proteção" vira "Cão · Proteção", e a Linhagem dos Cães não muda); o recruta no trem ("Coruja Atiradora · Atiradora e Controle" vira "Coruja · Tiro"); a Sala dos Personagens ("Cão Protetor · Tanque e Proteção" vira "Cão · Proteção")](species/before_after.jpg)

Segue a decisão de 01/11 na #189, aprovada pelo Orquestrador em nome do Lucas: a classe vira o papel, e a espécie
passa a ser do indivíduo. Esta é a primeira parte. Os atributos por papel e as resistências (#258) e o compositor de
camadas dos recrutas vêm nos PRs seguintes.

## O que entra

- **`data/species.json`**, com as seis espécies: `cao`, `gato`, `sapo`, `coruja`, `guaxinim` e `tatu`. Cada uma traz:
  - o nome na tela;
  - a linhagem da vantagem de tipo (#227);
  - a altura;
  - a pasta das camadas da arte (`art/combat/recruits/layers`);
  - os nomes da cultura dela, que eram o `NAME_POOLS` da `station_rules.gd`.

  A espécie não dá atributos.
- **A classe é o papel.** O `DisplayName` passa a ser Proteção, Incursão, Química, Tiro, Sabotagem e Resgate. O
  `DefaultSpecies` substitui `Species` e `Lineage`. O `Role` e a `Description` ficam com uma descrição curta, sem
  "Assassino", que a revisão narrativa já tinha recusado para o gato. **Os ids não mudam:** o `rato` continua sendo o
  Guaxinim.
- **O save:**
  - o herói guarda `species`;
  - o herói novo nasce com a espécie padrão da classe;
  - o save de antes ganha a dele na migração (`AHStationRules.migrate`), sem mudar a de quem já tem.
- **A linhagem vem da espécie da unidade**, no motor, na ficha, na inspeção e na mira: um cão na Química vence como
  Canidae. Os kits históricos da paridade não têm espécie e continuam sem linhagem, então a paridade 48/48 não muda.
- **A altura** vem da espécie do herói no elenco. Para quem ainda não está no elenco, como o recruta no trem, vem da
  espécie padrão da classe do id. Os civis, o Mercador e os inimigos ficam como estavam.
- **Os nomes do recruta** vêm da espécie.
- **Na tela, "Cão · Proteção"**, na ficha, na Sala dos Personagens, na partida, no relatório, no trem e no preso do
  resgate.
- **O texto do evento do Risco** muda para "(Classe Sabotagem liberada.)".

## Para o Lucas

- **A lista de nomes do sapo** ainda tem nomes de coruja (Bubo, Noctis, Mirante). Ela passou para a espécie como estava,
  porque mexer nela muda os nomes sorteados. A revisão fica para quando as fichas do elenco chegarem.
- **Todo recruta ainda chega com a espécie padrão da classe**, porque a arte do recruta é por classe. A espécie livre
  (um cão na Química) depende do compositor de camadas, que vem no PR 3. Até lá, só um save editado tem uma espécie
  diferente da padrão. Nesse caso, a altura segue a espécie e a arte segue a classe. O PR 3 traz as duas juntas, e
  também leva a espécie no recruta do trem, no pedido de ajuda e no memorial antigo.
- **O "Resgate"** é ao mesmo tempo o papel do tatu e a mecânica do #188, e na escolha do preso aparece "Tatu · Resgate".
  É o nome aprovado; só fica o registro.

## Testes

- `tests/test_species.gd`:
  - os dados: as seis espécies completas, a padrão de cada classe e os nomes de papel;
  - o save: o herói novo, a migração e a segunda migração;
  - a linhagem pela espécie no motor de verdade, incluindo o kit histórico sem linhagem, e na ficha;
  - a altura do indivíduo e a de quem não está no elenco;
  - o nome do recruta pela espécie.
- Os testes da #227 (`test_type_advantage`), das alturas (`test_recruit_art`, `test_stances`), da ficha
  (`test_character_sheet`), dos termos (`test_narrative_terms`, que agora lê a tabela de espécies) e do popup
  (`test_fight_popup`) passam a ler a espécie.
- `tests/run_all.gd` inteiro, com a paridade 48/48 e o save.
- As fotos acima: `tools/capture_227.gd` e `tools/capture_122.gd`, na `main` e nesta branch.

## QA

- **Rodada 1: APROVADO**, só com observações baixas. A QA conferiu:
  - o save de antes, sem `species`, pelo load de verdade (`Campaign.save` e `load_or_new`);
  - um cão no papel Química numa sessão de luta real: o motor, a ficha e a altura;
  - o Bento como gato na inspeção e na mira da #227, no Normal e no Maior;
  - o trem, o relatório, a Sala e a partida no Maior, em português e em inglês;
  - os filtros, a paridade 48/48 e as 7 habilidades da #259.

  Corrigidas na hora:
  - a espécie que a tabela não conhece (um save editado) deixava o texto como " · Proteção" e o herói sem linhagem.
    Agora cai na padrão da classe, na tela e no combate, com o teste;
  - no en.po, "Tiro" passa a ser "Marksmanship" e "Incursão" passa a ser "Incursion", como atividades, igual aos
    outros papéis.

  Ficam:
  - a altura e a arte que podem divergir até o PR 3;
  - a espécie no trem e no memorial, que fica para o PR 3;
  - o `Role` e a `Description` das classes, que não aparecem mais em nenhuma tela;
  - `docs/narrative/review.md`, que lista os nomes antigos como histórico.
