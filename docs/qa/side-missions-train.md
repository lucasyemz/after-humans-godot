# A volta no trem (#183, segunda parte)

![A volta no trem. Em cima: o trem das missões, com o Nick descendo e o painel "O trem chegou" com o relatório das duas missões; depois de RECEBER, o trem de sempre com o recruta (Brutus, com o Sereno). Embaixo: a Estação depois, com o Próximo passo do trem de sempre](side-missions-train/train.jpg)

Segue a decisão do Lucas de 28/10: "Prioridade é a missão principal que voltamos e só depois os secundários chegam no
trem também", com o relatório da missão.

## O que entra

- **Quem termina a missão volta no trem.** O resultado sai no dia da volta, mas o herói (o que deu certo e o ferido)
  fica no trem até a chegada ser vista. Até lá, conta como fora: não parte, não pega posto e não passeia na Estação. O
  capturado não vem no trem: espera o resgate (#188).
- **A missão principal primeiro.** O relatório da expedição não traz mais a coluna "Missões solo". Depois dele (e da
  noite, quando há), vem o trem.
- **O trem das missões é uma visita do trem** (`S.visit_pending`). Os mesmos caminhos que levam ao trem de sempre levam
  a ele: depois do relatório, ao amanhecer, ao abrir a Estação, na lista do que espera e no Próximo passo ("O trem trouxe
  quem estava em missão").
- **A cena:** o trem chega do túnel e o primeiro de quem volta desce na plataforma. O painel "O trem chegou" mostra o
  relatório das missões do dia, uma linha por herói. RECEBER traz todos para a Estação, e o trem parte.
- **Depois:** se o trem de sempre traz alguém (recruta, civil ou Mercador), ele chega em seguida. Senão, a noite ou a
  vista geral.
- No dia de espera ("Esperar um dia"), quem volta naquele dia também chega no trem: ele aparece no Próximo passo e
  na lista do que espera.

## Para o Lucas

- **Só o primeiro desce na cena.** Com dois voltando no mesmo dia, o painel lista os dois, mas só um desce do vagão (a
  cena do trem mostra um candidato por vez).
- **Pendências das propostas** (nenhuma está no texto das issues #183 e #188; ficam para você decidir):
  - o "Sinal fraco" no radar do Mapa da Rede para a fase com um resgate;
  - o Risco chegando de fato à Estação pelo `RecruitName` do evento da fase 5.

## Testes

- `tests/test_side_missions.gd` (693 verificações):
  - quem volta chega no trem e fica fora até a chegada;
  - o trem é uma visita pendente, e o Próximo passo leva à plataforma;
  - receber traz todos à Estação;
  - o capturado não vem no trem.
- `tools/capture_183_train.gd`: as fotos acima.
- `tests/run_all.gd` inteiro.
