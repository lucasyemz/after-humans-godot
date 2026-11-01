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
  `recruitment.json`). O sorteio sai da semente das missões e do dia.
- **No Mapa das missões solo:**
  - os resgates são pinos vermelhos no lugar da fase deles;
  - eles ficam numa lista "Resgates" no topo do painel, antes das missões do dia;
  - o painel do resgate diz quem é, onde está e que não há prazo;
  - PREPARAR NESTA FASE leva à plataforma com a fase escolhida.
- **Na rota:** a próxima expedição à fase do resgate tem o preso num trecho de Suprimentos que não é o primeiro. O
  sorteio é da expedição e fica à parte, então a rota continua com os mesmos 10 trechos. O capturado vem antes do
  pedido de ajuda (é nosso).
  - Perto dele (15 m), a HUD avisa: "Batidas de metal adiante. Alguém pede ajuda."
  - Antes do trecho, o aviso diz "<nome> · a patrulha guarda".
  - No trecho, "E  Soltar <nome>", com a ação `interact` (o `AHMapActor` da #179).
  - O preso fica longe dos objetos de busca e das portas, para os avisos não disputarem o lugar.
- **A escolha depois de soltar** (o modal do kit), com o motivo de cada opção que não vale:
  - **Entrar na equipe**, com metade da vida e 20 de instinto. Se a equipe está cheia, o jogador escolhe quem dá o
    lugar. Quem sai volta para a Estação com a vida que tinha, sem o XP da jornada. O caído no mapa não pode dar o
    lugar.
  - **Seguir para a Estação:** chega na volta, até na derrota.
  - **Deixar**, só no pedido de ajuda: a equipe deixa 1 de comida, e o pedido não volta.
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

- `tests/test_rescue.gd` (57 verificações):
  - o pedido de ajuda: só com a fase 2, um por vez, estável, e a chance com o passo e o máximo;
  - a partida: a rota de 10 trechos, o trecho de Suprimentos que não é o primeiro, e nada na outra fase;
  - soltar só no trecho;
  - entrar com e sem a equipe cheia (o caído não dá o lugar; quem sai fica no elenco sem o XP da jornada);
  - seguir para a Estação, até na derrota;
  - deixar, com a comida;
  - o Alojamento cheio;
  - o capturado primeiro, que não é deixado e volta como era;
  - o save no meio e o save de antes.
- `tests/test_side_missions.gd`: a captura nos dois modos, agora ligada nos dados.
- `tools/capture_188.gd`: as fotos acima, com `--text-size=2` para o Maior.
- `tests/run_all.gd` inteiro e o modo de captura da rua (a colisão), porque a rua mudou.
