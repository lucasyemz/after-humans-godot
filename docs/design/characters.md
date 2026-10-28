# O padrão de imagem dos personagens

Vale para todo personagem novo: herói, recruta, civil, mercador ou inimigo de pé. O Guaxinim e o Tatu da web antiga
fugiam dele (#225) e por isso estão sendo redesenhados. A regra é do Lucas, 28/10/2026: as alturas mudam de um
personagem para outro, mas a largura quase não muda.

A referência são os fundadores: o Bento, a Vespera, o Nick e a Íris, em `SourceArt/AllyActions/Approved20261013` e
`Reactions20261020`.

## A imagem

- **A tela:** 1178×1335, PNG com alfa. O Bento é a exceção antiga, com 1086×1448.
- **O corpo:** ocupa de 90% a 95% da altura da tela, do topo da cabeça (orelhas e chapéu incluídos) ao pé. Nada de
  personagem pequeno no meio de uma tela vazia: o Guaxinim antigo ocupava 75%, e o Tatu, 60%.
- **O pé:** fica no mesmo ponto em todas as poses do personagem (parado, golpes, reações). A ferramenta mede a âncora no
  centro da base do que é visível.
- **A direção:** voltado para a direita, como os outros.

## A proporção

- **O desenho:** a cabeça, o tronco e as pernas na mesma relação dos fundadores, com o mesmo traço, a mesma luz e a
  mesma paleta. Nada de cabeça grande ou corpo atarracado de mascote. Um personagem baixo continua com essa proporção,
  só que menor.
- **A largura quase não muda:** no parado, a largura visível fica perto da dos fundadores, entre 0,9 m e 1,1 m no
  jogo, seja qual for a altura. Em relação à altura, os fundadores ficam entre 0,58 (o Bento) e 0,66 (o Nick e a
  Vespera).
  - Um personagem robusto pode ser um pouco mais largo, sem passar de 1,2 m, o espaço entre dois heróis na fila.
  - Cauda, escudo, arma e mochila ficam junto do corpo no parado, sem abrir para os lados.
- **A altura:** vem da tabela `scripts/world/character_heights.gd`, não da imagem. O pedido de arte diz a altura de
  destino, e quem integra confere com a captura do Forward+ ao lado dos fundadores.

  | Fundador | Altura | Largura no jogo | Largura ÷ altura |
  | --- | --- | --- | --- |
  | Bento | 1,72 m | 1,00 m | 0,58 |
  | Vespera | 1,66 m | 1,09 m | 0,66 |
  | Nick | 1,50 m | 0,99 m | 0,66 |
  | Íris | 1,38 m | 0,89 m | 0,64 |

## Como conferir

- **A prancha:** a entrega traz o personagem novo ao lado dos quatro fundadores, na mesma escala, com os pés na mesma
  linha e uma régua em metros. É o mesmo formato de `docs/qa/recruits-redraw/scale-before.jpg`.
- **A integração:** a arte entra por `tools/sync_combat_art.py`. A ferramenta grava `body_reference_pixels` (a altura)
  e `body_width_pixels` (a largura) em `data/presentation/combat_art.json`. Com a altura da tabela, a largura no jogo é
  `body_width_pixels × altura ÷ body_reference_pixels`.
- **A QA de design:** confere este padrão no checklist de `docs/design/qa.md`.
