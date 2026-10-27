# A água pintada do Cais e da Ponte das Raízes, e a câmera da Ponte (#140)

![O Cais, de antes e de agora](water/RiverDock-z0-golden.jpg)

## O que muda

- **A água do chão** (`shaders/water_painted.gdshader`, com a parte comum em `water_painted.gdshaderinc`), na linguagem
  pintada dos cards, sem luz própria e com a cor do clima e da hora:
  - faixas de cor em degraus (clara perto da margem, escura no fundo);
  - ondinhas desenhadas, traços curtos que andam devagar, maiores com a distância para não sumirem com a câmera rente;
  - um brilho que pisca nas cristas;
  - a espuma onde a água encosta: atrás do cais, na linha em que a água aparece na tela (`foam_lines`; com a câmera
    rente, a água logo atrás do piso fica escondida por ele), no casco do Navio, no barco do fim do cais, nas estacas
    e nos pilares (`foam_points` no material do mapa);
  - um balanço de poucos centímetros na malha e a névoa da distância, que leva a água de longe para a cor do horizonte.
- **O fundo da Ponte:** o panorama pintado (`scenario_card_water.gdshader`) fica igual acima da linha d'água; abaixo
  dela, no lugar da água parada da pintura (com o reflexo das árvores), entra a água pintada do Cais em escala de
  distância (menos detalhe, mais névoa para o horizonte), com só uma mancha apagada da margem. O céu, as margens e a
  ponte continuam. Na câmera da exploração, o tabuleiro e a balaustrada cobrem a água do chão da Ponte: a água que se
  vê é essa.
- **Nos interiores**, a água pintada (sem luz própria) escurece com a sala, vista pela porta.
- **"Reduzir efeitos"**: a água anda a 40% e não pisca (muda na hora, pelas Opções).
- **A câmera da Ponte** é a dos outros cenários (`EXPLORE_CAMERA.scenario`, da #129):

  | | Distância até o líder | Altura sobre o líder |
  |---|---|---|
  | Ponte, antes | 28,2 m | 2,9 m |
  | Cais, antes | 19,1 m | 1,9 m |
  | Ponte e Cais, agora (e os outros cenários) | 15,9 m | 1,6 m |

- As cores da água ficam no material de cada mapa (`surface_color`, `mid_color`, `deep_color`, `ripple_color`,
  `foam_color`, `horizon_color`), para ajustar sem mexer no shader. O Depósito e os Dutos seguem com a água de antes.

## Antes e depois

| | |
|---|---|
| Cais, fim de tarde ![](water/RiverDock-z0-golden.jpg) | Cais, noite com chuva ![](water/RiverDock-z0-night.jpg) |
| Ponte, fim de tarde ![](water/RootBridge-z0-golden.jpg) | Ponte, noite com chuva ![](water/RootBridge-z0-night.jpg) |
| Cais, no Baixo ![](water/RiverDock-z0-low.jpg) | Ponte, no Baixo ![](water/RootBridge-z0-low.jpg) |

O movimento, em 4 quadros a 0,4 s (recortes da água): no Ultra, [o Cais](water/RiverDock-sequence.jpg) e
[a Ponte](water/RootBridge-sequence.jpg); no Baixo, [o Cais](water/RiverDock-sequence-low.jpg) e
[a Ponte](water/RootBridge-sequence-low.jpg). [Um interior do Cais](water/RiverDock-inside.jpg).

## Testes

- `tests/run_all.gd`: 65 de 65, com a paridade 48/48.
- `tests/test_water.gd` (novo): a água pintada nos dois mapas, com a espuma; o panorama com a água viva; "Reduzir
  efeitos" na hora e de volta; a câmera da Ponte igual à do Cais e à do Abrigo.
- `tools/capture_140.gd`: as capturas acima (também roda na main de antes) e as medidas da câmera.

## QA

| Rodada | Veredito | O que a QA achou | Como ficou |
|---|---|---|---|
| 1 | REPROVADO | **Alta:** o fundo da Ponte seguia a pintura com o reflexo realista, só tremida. **Médias:** a espuma ficava onde a câmera não alcança (embaixo do piso, na frente); a água sem luz brilhava no interior do Cais. **Baixas:** a sequência só no Ultra, os curingas no `i18n_ignore`, a água preta de noite, o relâmpago | O fundo virou a água pintada; a espuma foi para onde a água aparece; a água escurece nos interiores; a sequência no Baixo e os recortes; os curingas só no `scenario_world.gd` |

## Para o Lucas

- **O desempenho no Baixo e no Ultra** com placa de vídeo fica com o Orquestrador PC: a nuvem só roda o
  Compatibility, por software, e lá o quadro inteiro custa uns 133 ms com ou sem a água. O shader é leve (sem textura
  de tela nem de profundidade; um laço de até 16 pontos de espuma).
- **Os personagens e a água:** nos dois mapas ninguém pisa na água, então o anel de espuma em volta de quem toca a água
  ficou só para as estacas, os pilares e a margem.
- **De noite com chuva** a água do Cais fica bem escura, como a de antes, e não pisca com o relâmpago (ela não tem luz
  própria). Se quiser a água mais viva de noite, é um ajuste nas cores do material.
- Este PR vem por cima do da #129 (a câmera nova).
