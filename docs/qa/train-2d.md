# O trem 2D no jogo (#256)

Fotos de `tools/capture_256.gd` (1920x1080, Compatibility, sem placa de vídeo), nas cenas de verdade: o tutorial direto
na plataforma e o cartão da partida da Preparação. O antes é a mesma sequência rodada na `main` de antes da integração.
O design está em [docs/design/trem-2d.md](../design/trem-2d.md) (#149) e a pose de frente em
[docs/design/poses-frente.md](../design/poses-frente.md) (#253).

![antes e depois na plataforma](train-2d/before-after-platform.jpg)

Em cima, o mesmo momento: o trem parado com as portas abertas. Antes era o card pintado `T_TU10`; agora é o vagão em
camadas, no mesmo lugar do fosso. Embaixo, uns 3,5 s depois de embarcar: antes a passagem já tinha aberto (a equipe
não entrava no vagão); agora a equipe está dentro, vista pela porta da esquerda e pelas janelas.

![a plataforma](train-2d/platform.jpg)

1. O trem sai do túnel pela esquerda e freia, com as portas fechadas (anda sempre para a direita: chega e parte no
   mesmo sentido, como no túnel da passagem). A faísca sai na metade de baixo da velocidade, mas o piso
   da plataforma cobre as rodas, como pede o design; aparece só a luz laranja no trilho.
2. Parado, as portas abrem (0,8 s). No Embarcar, a recompensa sobe e a equipe anda até a beira, entra pela porta da
   direita e segue para dentro; a fila vai atrás pelo rastro.
3. As portas fecham e o vagão parte para a direita (`train_departure`), com a equipe dentro, pelas janelas.
4. A passagem para a Estação mostra só o interior, com o trem andando (`train_ride`): a partida já passou no mapa e a
   chegada é na plataforma da Estação.

![a passagem](train-2d/passage.jpg)

Em cima, antes e depois do interior. Embaixo, os planos do túnel da partida da Preparação: o vagão sai de lado com as
rodas girando, e no fim, depois do título, chega freando com a faísca e a freada (`train_brake`). A chegada só começa
com a fase já montada por baixo (o quadro que monta trava a tela, e numa máquina lenta cortava a chegada ao meio), e o
cartão espera ela terminar (`AHPassageCard.backdrop_done`). Pulada no meio, a freada para junto.

## Como funciona

- **O vagão** (`scripts/world/train_car.gd`, `AHTrainCar`) monta as camadas do contrato
  (`data/presentation/train_2d.json`, a cópia de `docs/design/trem-2d/contract.json` que vai no jogo; o teste confere que
  as duas são iguais), sem luz própria como os cards (`shaders/train_layer*.gdshader`), com o brilho do card que ele
  substitui e o clima do cenário. O interior fica 0,9 m atrás e cresce pela distância da câmera; quem está dentro fica a
  0,45 m, entre o interior e a carroceria. As rodas giram pelo que o vagão anda e a faísca segue o contrato; com
  "Reduzir efeitos", sem faísca e sem a luz dela.
- **No mapa** (`tools/build_containment_corridor.py`): o card some (`hidden`) e `train.car` diz onde fica o vagão (o
  plano do card, o chão na altura da plataforma) e a distância da câmera. Ele fica no grupo `Metro`, com as luzes frias,
  e é o grupo que anda.
- **O embarque** (`AHStreetCorridor._walk_into_train`): o líder vai até a beira na frente da porta da direita, entra e
  anda 4,6 m para dentro; sem a silhueta, que pintava a equipe por cima da carroceria. Na partida, a fila vai presa ao
  rastro (`carry_party`), sem a suavização que a deixava para trás.
- **A passagem** (`scripts/station/wagon_ride.gd`, `AHWagonRide`, agora um Control): o túnel nas janelas, o fundo, as
  sombras de contato, a equipe e as barras na frente. Os lugares são os quatro do contrato; a posição 1 no da direita, e
  uma equipe menor senta junta do lado direito. Quem tem `*_seat_front` senta de frente (o ponto `hip` no assento); quem
  não tem (os recrutas, ou a skin sem a pose, como a Ronda do Bento) fica de pé na frente do lugar, na roupa dele. O
  vagão de lado do túnel é `AHTrainCar2D`. O tempo é pelo relógio, como o do cartão.
- **A pose pela direção do banco** (`AHSkins.seat_pose`): "front" no vagão, "side" na cantina, que não mudou.
- **`tools/sync_assets.py`** grava `facing: side` nas `*_seat` e mantém as entradas de frente que já estão no JSON (elas
  não vêm da Unreal).

## Não verificado

- **Forward+:** as capturas são do Compatibility, sem placa de vídeo.
- **A equipe no túnel:** nos planos de fora da passagem, o vagão passa vazio (a equipe aparece só no interior).
- **A plataforma da Estação Raiz** continua com o metrô vermelho 3D: é a decisão que a #256 deixa para o Lucas.
