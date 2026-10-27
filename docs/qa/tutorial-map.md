# O Corredor de Contenção: o mapa do tutorial (#147)

O código do mapa da abertura, montado com peças provisórias até a arte da Awesomic (PR #152) chegar. O fluxo do tutorial
(o título, as dicas, a recompensa, a chegada) é da #144, que vem por cima deste.

![As quatro zonas, de noite (o clima do tutorial)](tutorial-map/zones.jpg)

## O mapa

- `data/scenarios/ContainmentCorridor.json`, gerado por `tools/build_containment_corridor.py` no contrato dos cenários
  (as peças com as malhas de `meshes.json`, os materiais, as luzes, as zonas e os props). As medidas são as da página
  `docs/design/tutorial.md` do PR #152.
- **As zonas:** o corredor de contenção (a partida e a primeira luta), a sala das celas (o Nick, o armário de
  manutenção e a segunda luta), a rota do Nick (o duto, a escada até o alçapão e a terceira luta) e a plataforma (o
  vagão no fosso e o embarque).
- **As peças provisórias:** a parede e o piso de concreto molhado, a porta de aço (`T_DI20`) e o arco aberto (`T_PT02`)
  no lugar da porta de segurança, o armário de ferramentas (`T_DEX01`) no lugar do de manutenção, o painel (`T_PT12`), as
  grades (`T_PT03`), o duto (`T_DE05`), a escada (`T_DE10`), as raízes e o metrô da Estação no lugar do vagão pintado.
  Quando a arte TU estiver em `art/scenarios`, rodar `python tools/build_containment_corridor.py` troca cada peça.
- **A luz:** as lâmpadas de emergência vermelhas que piscam (0,6 s acesas, 0,4 s a 25%, fora de fase; acesas com
  "Reduzir efeitos"), a luz fria de serviço em cada zona, a lanterna do líder e a luz fria do vagão. Cada zona tem os
  materiais dela: no Compatibility, cada malha pega no máximo 8 luzes.
- **A caixa fechada:** concreto além das pontas, acima do teto e atrás de tudo. A câmera nunca vê céu.
- **O som:** o ambiente da contenção, com o alarme ao fundo, e a porta de segurança baixando e subindo, por síntese
  (`tools/synth_sounds.py`, CC0); o trem chegando é o da Estação.

## A jornada

- A fase "tutorial" (`AHTutorial`, `data/tutorial.json`) joga pelo corredor de sempre, mas fica fora de
  `AHJourneyRules.PHASES`: não aparece no Mapa da Rede nem no "Jogar de novo".
- Sete trechos: a partida, a luta 1 (o Broto), o encontro com o Nick, a busca, a luta 2 (o Rastejante de Cabos e o
  Broto), a luta 3 (o Rastreador Quadrúpede e o Robô) e o trem.
- A porta do fim de cada zona só abre com a zona vencida. A de trás baixa quando a equipe passa, e não há volta.
- O vagão chega quando a equipe entra na plataforma. O embarque leva à Estação pela passagem do vagão (#75).

## Testes

- `tests/test_tutorial_map.gd`: o contrato do mapa, a fase fora do Mapa da Rede, a jornada pela cena de verdade
  (as lutas, as portas, o Nick, sem volta, o Menu sem retirada, o vagão escondido até chegar e o embarque).
- `tools/capture_scenarios.gd --maps=ContainmentCorridor`: as 4 zonas no piso e na faixa (8 de 8).
- A captura da rua (`-- --capture=`), com a colisão: `08-collision-car` e `09-collision-facade` PASS.

## Antes e depois

![A primeira rodada (o céu atrás das paredes e o escuro) e a de agora](tutorial-map/before_after.jpg)

## QA

| Rodada | Veredito | O que a QA achou | Como ficou |
|---|---|---|---|
| 1 | REPROVADO | **Médias:** o Menu deixava voltar à Estação e abandonava a abertura; o objetivo dizia "Vencer o guardião"; o vagão aparecia parado durante o fade e depois sumia para chegar; o embarque não usava a passagem do vagão; o céu atrás das paredes e o escuro na noite real. **Baixas:** a plaqueta com o clima, o painel parado, o som da porta, o ícone do trem, os nomes das zonas fora do PO, o Pipoco e a Faísca soltos na lore | Todas corrigidas |

## Para o Lucas

- O ícone do trecho do trem é o do fim do corredor (o do guardião), até haver um ícone de trem.
- As capturas em Baixo e em Ultra das portas e do embarque ficam para a máquina com placa de vídeo: aqui a Godot roda
  só no Compatibility, por software.
