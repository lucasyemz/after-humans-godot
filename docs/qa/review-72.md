# As pendências da revisão (#72)

![Antes (à esquerda) e depois (à direita), nos textos Normal e Maior: a luta cheia com os espaços no mínimo; antes, as placas dos heróis e as dos inimigos se cobriam e a "Garra de Captura" saía cortada; depois, uma placa sim e outra não sobe para cima da cabeça](review-72/before_after.jpg)

O que sobrou da auditoria do Claude 1 (comentário de 28/10 na issue), item por item.

## As placas no lugar mais apertado (`combat_hud.gd`)

Com os espaços da luta encolhidos até o mínimo (`MIN_GAP_SCALE`, num lugar apertado), os pés ficam a 105–117 px e
as placas, no mínimo de 140 px, se cobriam (a auditoria mediu 142–146 px sem obstáculo; com a luta cheia do passo 7
da Rua das Vitrines, cobriam). Agora, quando o vizinho está mais perto que a placa mínima, uma placa sim e outra não
sobe para cima da cabeça (o mesmo caminho dos baixinhos), e sobe de novo por cima da intenção e da placa dos vizinhos
se encostar nelas (`_lift_staggered`). Quem sobe sai do lugar de destino de cada um (`slot_position`), não de onde a
placa está no quadro: numa troca de posição as placas não pulam enquanto os dois se cruzam. O ALVO desvia das placas
já levantadas. Nas lutas de sempre, com os pés a ~175 px, nada muda.

## A origem do toque no alvo (`test_target_pick`)

Na primeira vez do jogador, com um `on_pick` do teste (sem gastar a vez): o clique escolhe e a tecla Enter de verdade
(`InputEventKey`, não a ação) usa no escolhido na hora; o primeiro toque na tela (`InputEventScreenTouch`) escolhe sem
usar e o segundo usa. As verificações de antes que dependiam da vez seguinte continuam como estavam (a vez seguinte
nem sempre tem uma habilidade de dois alvos, e aí elas não rodam); as novas rodam sempre.

## As saídas limpas da troca de cena (pendências do #85)

- **O vagão órfão:** a passagem recusada (outra troca em andamento) libera a cena de fundo do cartão.
- **A cena que não carrega:** `push_error`, o cartão sai, o `GameFlow.busy` solta e o jogo volta ao título
  (`_travel_failed`), em vez de o `instantiate()` quebrar com o `busy` preso.
- **O corredor preso:** com outra troca em andamento, o corredor não avança o trecho nem liga o `busy` dele.

## O aviso do save

O `load_warning` saiu: o jogo e os testes leem `warning_text()`, um caminho só.

## O rodízio de tocadores

O `Sound.play()` pegava o próximo da roda de 10 tocadores, tocando ou não: com o trem chegando (7 s), dez efeitos
nesse tempo tomavam o tocador dele e cortavam o trem. Agora pega o próximo livre na roda e, com todos tocando, o que
está mais perto de acabar (`_free_effect`). Combinado pelo Orquestrador com o Claude 1 (#66), que mexe em outra função
do `Sound`.

## Testes

- `tests/test_flow_guards.gd` (novo): o vagão recusado, a cena que não carrega e o corredor com a troca em andamento.
- `tests/test_sound_pool.gd` (novo): o trem tocando e mais dez efeitos curtos; o trem não é cortado.
- `tests/test_plates_crowd.gd`: a luta cheia também no espaço mínimo, nos textos Normal e Maior, com o ALVO em cada
  inimigo sem cobrir a vida de ninguém; e a troca de posição no espaço normal sem placa nenhuma pulando.
- `tests/test_target_pick.gd`: o clique e Enter e o toque, sempre na primeira vez.
- `tests/test_campaign.gd`, `tests/test_campaign_slots.gd`: o aviso pelo `warning_text()`.
- `tools/capture_72.gd`: a luta cheia no espaço mínimo, nos dois textos; roda também na `main` de antes.

## QA

- **Rodada 1: REPROVADO.** Uma alta e duas médias:
  - o `test_sound_pool` falhava em metade das vezes (o clique dura 0,07 s, e o teste esperava um quadro entre eles);
  - o ALVO desviava das placas na posição de antes de elas subirem e cobria a vida do alvo e do vizinho;
  - as placas pulavam para cima da cabeça durante uma troca de posição, até nas lutas de espaço normal.

  Correção: os cliques no mesmo quadro (e sem exigir todos os tocadores ocupados, que depende do relógio do áudio); o
  ALVO lê as placas depois de subirem; o escalonamento pelo lugar de destino. Da baixa: a cena que não carrega volta ao
  título.
- **Rodada 2: REPROVADO.** Um médio: o desvio do ALVO passava uma vez só pelas placas e, ao mirar o Relé no espaço
  apertado (texto Normal), subia por cima da placa e da intenção levantadas do Rastreador vizinho.

  Correção: as placas acima da cabeça em ordem de baixo para cima (quem desvia só sobe, então uma passada basta); o
  `_aim` confere a placa inteira e a intenção. O caso só aparece na tela de 1920x1080: o teste o pega rodando com
  janela (`xvfb-run`, como no modo de captura); sem janela, as medidas da tela são outras.
- **Rodada 3: APROVADO.** A varredura das placas de 0,6 a 1,0, nos textos Normal e Maior, mirando os quatro inimigos
  em cada passo (72 capturas): o ALVO não cobre placa nem intenção em nenhum caso (caiu também o do Pipoco sobre a
  intenção do Relé, que já existia na `main`). `run_all` 87/87, paridade 48/48. Nota baixa, de antes: no espaço
  mínimo, a intenção do Pipoco cobre 16% da altura do corpo do Relé.
