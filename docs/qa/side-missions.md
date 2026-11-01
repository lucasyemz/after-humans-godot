# As missões solo (#183, primeira parte)

![A aba Missões solo no Mapa da Rede: os pinos das missões do dia, a lista "Hoje no rádio" e a missão escolhida com a escolha do herói pelo selo](side-missions/board.jpg)

## O que entra

- **A Preparação vai ao nível 2** (4 sucatas e 1 fragmento). No nível 2, o Mapa da Rede ganha a aba **Missões solo**;
  antes, a aba aparece apagada, com o motivo.
- **O quadro do dia:** a cada dia da Estação (uma volta ou um dia de espera), o rádio capta de 2 a 4 missões
  (`Board`, pela fase mais alta liberada), sorteadas entre as das fases liberadas e postas em lugares da pintura
  (`Spots`). O sorteio usa a semente das missões e o dia: salvar e voltar não troca o quadro.
- **Mandar:** a missão leva comida (1 suprimento por dia), tira o herói do posto e o tira da Estação até a volta. No
  máximo 2 em curso. Quem está fora não parte na equipe (a Preparação diz por quê), não pega posto, não passa a noite
  (a noite conta só quem voltou na equipe) e não passeia na Estação. Com todos fora ou caídos, dá para esperar um dia.
- **A chance** (escondida; a tela mostra só o selo *Boa escolha*, *Arriscado* ou *Muito arriscado*):
  - a base pelo perigo (50, 40 ou 30);
  - a aptidão da classe em cada coisa que a missão pede (+20 forte, +10 parcial);
  - o nível do herói contra o da fase da missão (+3 por nível acima, até +15; −8 por nível abaixo);
  - a vida que falta (até −30), os traços (`Perks`), o trauma (−10) e a crise (−10);
  - sempre entre 5 e 95.
- **A volta** (no dia marcado), contra a chance:
  - **deu certo:** a recompensa do tipo da missão, na faixa da carga recuperada da fase mais alta liberada, a relíquia
    (1 em 14) nas missões que a têm e 10 de XP;
  - **com ferimentos:** a faixa de 25 pontos acima da chance; volta com 35% da vida e metade da recompensa, sem a
    relíquia;
  - **com os robôs:** o herói fica fora até o resgate, com um pino de resgate no mapa, prioritário e sem prazo. O
    resgate na rota é a próxima parte (#188).
- **O relatório:** a coluna "Missões solo" no retorno da expedição e "Quem voltou" na aba.

## Para o Lucas

- **O nível pesa:** uma missão da fase 3 (nível 5) com o time do começo (nível 1) fica *Muito arriscado* (cerca de
  8%). No nível típico de quem chega à fase 3 (4, `measure_balance`), a mesma missão de perigo médio dá 52% para a
  classe forte (*Arriscado*). O quadro também traz missões das fases de antes.
- **Ficam para as próximas partes:** a volta no trem e o resgate na rota da fase (#188).

## Testes

- `tests/test_side_missions.gd` (271 verificações): a Preparação nível 2 e a aba; o quadro (quantas, só das fases
  liberadas, lugares diferentes, estável, a troca no dia novo); a chance em cada parte e nos limites, e o selo; mandar
  (a comida, o posto, a volta marcada, fora do quadro, o máximo de 2, sem comida); quem está fora (não parte, não pega
  posto, deixa esperar um dia); a volta em 40 campanhas (os três resultados, o XP, a recompensa, os 35% da vida, o
  capturado fora) e o save de antes.
- `tools/capture_183.gd`: a aba apagada, o quadro, a missão com o herói, em curso, a volta e o capturado, nos textos
  Normal e Maior.
- `tests/run_all.gd` inteiro.
