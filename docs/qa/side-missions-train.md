# A volta no trem (#183, segunda parte)

![A volta no trem. Em cima: o trem das missões, só com o Nick descendo, o painel "O trem chegou" com o relatório das duas missões e IR AO MAPA esperando ("Receba o trem antes de partir"); depois de RECEBER, o trem de sempre com o recruta (Brutus, com o Sereno). Embaixo: a Estação depois, com o Próximo passo do trem de sempre](side-missions-train/train.jpg)

Segue a decisão do Lucas de 28/10: "Prioridade é a missão principal que voltamos e só depois os secundários chegam no
trem também", com o relatório da missão.

## O que entra

- **Quem termina a missão volta no trem.** O resultado sai no dia da volta, mas o herói (o que deu certo e o ferido)
  fica no trem até a chegada ser vista. Até lá, conta como fora: não parte, não pega posto e não passeia na Estação. O
  capturado não vem no trem: espera o resgate (#188).
- **A missão principal primeiro.** O relatório da expedição não traz mais quem volta das missões; só quem foi
  capturado, na coluna "Com os robôs" (não vem no trem). Depois dele (e da noite, quando há), vem o trem.
- **O trem das missões é uma visita do trem** (`S.visit_pending`). Os mesmos caminhos que levam ao trem de sempre levam
  a ele: depois do relatório, ao amanhecer, ao abrir a Estação, na lista do que espera e no Próximo passo ("O trem trouxe
  quem estava em missão").
- **A cena:** o trem chega do túnel e o primeiro de quem volta desce na plataforma (o ferido, no passo de quem manca).
  O segundo do recruta do trem de sempre não desce junto: ele vem no trem de sempre, depois. O painel "O trem chegou"
  mostra o relatório das missões, uma linha por herói, e à parte quem ficou "Com os robôs". RECEBER traz todos para a
  Estação, e o trem parte.
- **Antes de partir, receber.** Com o trem das missões pendente, a Preparação espera ("Receba quem voltou no trem antes
  de partir"), como com o Mercador. Um dia sem receber guarda o relatório de quem ainda está no trem.
- **Depois:** se o trem de sempre traz alguém (recruta, civil ou Mercador), ele chega em seguida. Senão, a noite ou a
  vista geral.
- No dia de espera ("Esperar um dia"), quem volta naquele dia também chega no trem: ele aparece no Próximo passo e
  na lista do que espera.
- **A partida, ao mesmo tempo que a missão solo** (decisão do Lucas, 01/11): quem está fora aparece na lista da
  Estação, na tela da partida, com o motivo, e não entra na equipe:
  - "Em missão solo · volta em N dias";
  - "Com os robôs";
  - "Chega no trem".

  Antes, o texto dizia "sem arte de combate", inclusive na `main` do #286.

## Para o Lucas

- **Só o primeiro desce na cena.** Com dois voltando no mesmo dia, o painel lista os dois, mas só um desce do vagão (a
  cena do trem mostra um candidato por vez).
- **Pendências das propostas** (nenhuma está no texto das issues #183 e #188; ficam para você decidir):
  - o "Sinal fraco" no radar do Mapa da Rede para a fase com um resgate;
  - o Risco chegando de fato à Estação pelo `RecruitName` do evento da fase 5.

## Testes

- `tests/test_side_missions.gd` (695 verificações):
  - quem volta chega no trem e fica fora até a chegada;
  - o trem é uma visita pendente, e o Próximo passo leva à plataforma;
  - a Preparação espera o trem, e um dia sem receber guarda o relatório;
  - receber traz todos à Estação;
  - o capturado não vem no trem.
- `tests/test_mission_train.gd` (7 verificações): na Estação de verdade, com uma dupla de recrutas no trem de sempre,
  só a Íris desce (ferida, no passo de quem manca) e, depois de RECEBER, o trem de sempre traz o recruta.
- `tests/test_preparation_flow.gd`: na tela da partida de verdade, o Risco em missão solo, com os robôs e no trem, com
  o motivo de cada um, sem entrar na equipe.
- `tools/capture_183_train.gd`: as fotos acima.
- `tests/run_all.gd` inteiro.

## QA

- **Rodada 1: REPROVADO.** Quatro médios:
  - o segundo do recruta do trem de sempre descia junto no trem das missões;
  - partindo sem receber, o relatório se perdia e o herói ficava no trem;
  - a captura, sem ninguém voltando, não era avisada;
  - o ferido descia no passo normal.

  Correção: os quatro, como descrito acima, com o teste de cena novo e os de regra.

- **Rodada 2: REPROVADO.** As quatro correções foram confirmadas, no texto Normal e no Maior. Sobrou um médio: no
  Maior, o motivo do IR AO MAPA ("Receba quem voltou no trem antes de partir.") quebrava em duas linhas e a segunda saía
  da tela.

  Correção: o motivo ficou "Receba o trem antes de partir.", que cabe numa linha no Maior, como o do Mercador.

- **Rodada 3: APROVADO.** O `run_all` passa 104/104. No Maior, o motivo cabe numa linha, e a cena da rodada 2 continua
  certa. Ficam observações baixas:
  - a captura num dia de espera, sem ninguém voltando, não tem aviso (já era assim antes desta branch);
  - a lista do que espera diz "O Mercador espera na plataforma" mesmo quando o trem das missões vem primeiro;
  - o "Quem voltou" do quadro lista quem ainda está no trem;
  - o Mercador que já estava na plataforma sai de cena e chega de novo depois do RECEBER.
