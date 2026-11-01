# O resgate (#188, com as missões solo da #183)

![O resgate. Por linha: os pinos vermelhos no Mapa das missões solo, com a lista "Resgates" no topo, e o painel do resgate com PREPARAR NESTA FASE; na rota da fase 2, a Véspera presa (o aviso "Soltar Véspera") e a escolha depois de soltar; com a equipe cheia, quem dá o lugar, e a Véspera de volta na fila (o Bento voltou para a Estação)](rescue/rescue.jpg)

Segue a proposta aprovada na #188 e a decisão do Lucas de 28/10: o pedido de ajuda entra no mapa das missões solo e
usa a mesma mecânica do resgate de quem foi capturado.

## O que entra

- **A captura ligada** (`CaptureEnabled: true` em `data/side-missions.json`): o pior resultado da missão solo é o
  herói ficar com os robôs. Ele fica fora (não parte, não pega posto) e conta no Alojamento.
- **O pedido de ajuda** (`data/rescue.json`): num dia novo, sem pedido no mapa, o rádio capta um com 25% de chance,
  mais 10 a cada dia sem pedido, até 60%. Só com uma das fases 2 a 5 liberada, e no máximo um por vez. O animal é de
  uma classe com arte e lugar no Alojamento, como o do trem (nome, traços, variação de arte e a linha de origem de
  `recruitment.json`, que fica de fora do modal). O sorteio sai da semente das missões e do dia. O trem não traz o
  mesmo nome nem a mesma arte do pedido no mapa (#182).
- **No Mapa das missões solo:**
  - os resgates são pinos vermelhos no lugar da fase deles, do lado da âncora que não cobre os pinos de missão;
  - eles ficam numa lista "Resgates" no topo do painel, antes das missões do dia;
  - o painel do resgate diz quem é, onde está e que não há prazo;
  - PREPARAR NESTA FASE leva à plataforma com a fase escolhida.
- **Na rota:** a próxima expedição à fase do resgate tem o preso num trecho de Suprimentos com uma patrulha antes. O
  sorteio é da expedição e fica à parte, então a rota continua com os mesmos 10 trechos. O capturado vem antes do
  pedido de ajuda (é nosso).
  - O preso fica dentro do trecho dele, no ponto mais livre dos objetos de busca e das portas.
  - Soltar depende das patrulhas vencidas antes do trecho, não do trecho de agora: andar para trás não o prende.
  - Perto dele (15 m), a HUD avisa: "Batidas de metal adiante. Alguém pede ajuda."
  - Antes do trecho, o aviso diz "<nome> · a patrulha guarda".
  - No trecho, "E  Soltar <nome>", com a ação `interact` (o `AHMapActor` da #179). Solto antes de um save, o aviso
    vira "E  Decidir com <nome>" e reabre a escolha.
- **A escolha depois de soltar** (o modal do kit), com a classe e os traços de quem foi solto e o motivo de cada opção
  que não vale:
  - **Entrar na equipe**, com metade da vida e 20 de instinto. Se a equipe está cheia, o jogador escolhe quem dá o
    lugar. Quem sai volta para a Estação com a vida que tinha, sem o XP da jornada. O caído no mapa não pode dar o
    lugar.
  - **Mandar <nome> à Estação** (por exemplo, "Mandar Véspera à Estação", decisão do Lucas de 01/11): chega na volta,
    até na derrota.
  - **Deixar**, só no pedido de ajuda: a equipe deixa 1 de comida (sem comida, "Deixar para trás"), e o pedido não
    volta.
  - **Alojamento cheio:** o pedido de ajuda só pode ser deixado.
- **O capturado volta como era:** o mesmo nível, os traços e o XP, só com metade da vida.
- **O relatório da volta:** a coluna "Resgate".
- **O save:** o resgate fica em `expedition.corridor.rescue` e o pedido em `station.side_missions.help`. O save no
  meio volta com a escolha aberta. O save de antes abre sem resgate.
- A partida (`start_expedition`) também deixa de fora quem está em missão solo ou com os robôs.

## Para o Lucas

- **A arte do preso** (Awesomic 1, pelo Orquestrador): até ela chegar, o preso usa a pose de ferido (#194),
  acinzentado, sem grade nem corda. A proposta pede a pose de preso e a prisão em dois estados (preso e aberto). O
  ícone `node-rescue` da barra de trechos fica para o Codex.
- **Ficam para depois:** a volta no trem (a segunda parte da #183), o "Sinal fraco" no radar do Mapa da Rede e o Risco
  chegando à Estação pelo `RecruitName` (item 4 da proposta da #188).

## Testes

- `tests/test_rescue.gd` (64 verificações):
  - o pedido de ajuda: só com a fase 2, um por vez, estável, e a chance com o passo e o máximo;
  - a partida: a rota de 10 trechos, o trecho de Suprimentos que não é o primeiro, e nada na outra fase;
  - soltar só no trecho;
  - entrar com e sem a equipe cheia (o caído não dá o lugar; quem sai fica no elenco sem o XP da jornada);
  - seguir para a Estação, até na derrota;
  - deixar, com a comida;
  - o Alojamento cheio;
  - o capturado primeiro, que não é deixado e volta como era;
  - o save no meio e o save de antes.
- `tests/test_rescue_street.gd` (60 verificações): na cena de verdade, fases 1 a 5 e duas sementes, o preso dentro do
  trecho, a ação de soltar com o líder em cima e um trecho atrás.
- `tests/test_side_missions.gd`: a captura nos dois modos, agora ligada nos dados.
- `tools/capture_188.gd`: as fotos acima, com `--text-size=2` para o Maior.
- `tests/run_all.gd` inteiro e o modo de captura da rua (a colisão), porque a rua mudou.

## QA

- **Rodada 1: REPROVADO.** Três altos, quatro médios e cinco baixos:
  - alto: o `run_all` vermelho (o literal `corridor` no i18n);
  - alto: o preso fora do trecho dele e, na fase 3, impossível de soltar (3 de 8 sementes);
  - alto: o pedido de ajuda com o nome e a arte do recruta do trem;
  - médio: o pino do resgate sobre o pino de missão;
  - médio: a linha de origem do trem no texto do preso;
  - médio: o modal sem a classe e os traços;
  - médio: o ponto sem patrulha antes em 40% das rotas;
  - baixas: o motivo repetido, deixar sem comida, o preso parecido com a equipe, a escolha que não reabre depois do
    save e o foco depois de escolher o resgate.

  Correção: todos, como descrito acima. O tom do preso ficou mais escuro, e o foco vai a PREPARAR NESTA FASE.

- **Rodada 2: APROVADO.** O `run_all` passa 103/103, com a paridade 48/48. A QA testou:
  - a rua nas fases 1 a 5 com 10 sementes (o preso no trecho e solto andando como o jogador, o save no meio, o líder
    dando o lugar);
  - o pedido de ajuda contra 6 chegadas do trem;
  - 595 rotas, todas com uma patrulha antes do preso;
  - deixar sem comida;
  - o mapa com um pino de missão ao lado do resgate, e o foco.

  Ficam três observações baixas:
  - nos trechos curtos (fase 3 e parte da fase 5), o preso fica a cerca de 1 m de um objeto de busca: com o líder no
    meio, o aviso é o do objeto, e um passo para o lado solta;
  - com três resgates na mesma fase, a ordem dos pinos no mapa não segue a da lista;
  - o Esc no painel do resgate fecha o Mapa da Rede, como no painel de missão.
