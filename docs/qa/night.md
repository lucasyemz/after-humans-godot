# A noite e o amanhecer (#132)

O pedido do Lucas (26/10): "Precisamos da transição do descanso para começar o dia, e dos eventos que ocorreram à
noite."

![antes e depois](night/before_after.jpg)

No Maior e no daltonismo: [screens.jpg](night/screens.jpg). As fotos saem de `tools/capture_132.gd` (`--text-size=2`,
`--colorblind`). O antes é o mesmo roteiro no código da #119: Iniciar descanso abria o amanhecer direto.

## A cena da noite

- **Ao INICIAR DESCANSO:**
  - a regra resolve a noite e salva antes da cena, então o save no meio da noite abre no amanhecer;
  - as luzes dos cômodos caem até 15% em 0,9 s;
  - quem dorme fica deitado no beliche, e o vigia de pé no Dormitório;
  - o cartão "Noite N" aparece embaixo, acima das teclas, para o Dormitório ficar à vista. Ele traz uma linha ("O vigia
    escuta os trilhos", ou "Ninguém vigia esta noite") e o tempo correndo numa barra por 2 s;
  - a luz da manhã volta, todos se levantam, e o amanhecer abre.
- **Pular:** Interagir, Esc, Voltar, um clique ou um toque pulam para o amanhecer. Nada passa para trás da cena.
- **Com "Reduzir efeitos",** a Estação não escurece: só o cartão.
- **O foco** do teclado e do controle volta para COMEÇAR O DIA, pulando ou esperando.

## O amanhecer

O painel do Dormitório abre "Amanhecer · Dia N", com:
- **o evento da noite,** num quadro. O ruim vem com o ícone de alerta e o título em vermelho (no daltonismo, o ícone
  avisa); o bom ou neutro vem com a lua;
- **as condições:** a fome e a sede, quando faltou comida ou água;
- **o que a noite gastou:** "3 suprimentos comidos · restam 3" e a água da Estação;
- **quem descansou:** só o que mudou ("+5 de vida, −15 de instinto"), "dormiu, sem nada a recuperar", ou "ficou de
  vigia";
- **a Enfermaria (#121):** cada caído e quando volta;
- **o Depois:** o passo seguinte ao amanhecer (o Próximo passo de depois de COMEÇAR O DIA).

## Os eventos da noite

Um sorteio por noite, de `data/night-events.json`. A semente é a da expedição, então a mesma volta sorteia sempre o
mesmo, e salvar e voltar não troca o evento. Os números são **propostas para o Lucas**:

| Evento | Peso | O que faz | Com vigia |
|---|---|---|---|
| Noite tranquila | 30 | Nada. | — |
| Ruídos distantes (ruim) | 14 | Quem dorme baixa 3 de instinto a menos. | O vigia verifica: nada. |
| Barulho na plataforma | 10 | A chance do próximo trem sobe um passo, como uma volta vazia (#122). | — |
| Goteira (ruim) | 12 | 2 de água a menos. | O balde segura: nada. |
| Baratas na despensa (ruim) | 12 | 2 suprimentos a menos. O Depósito no nível 2 protege. | O vigia espanta: nada. |
| O vigia vê algo | 10 | Só com vigia: o próximo lugar liberado fica lido no Mapa da Rede (o guardião e os inimigos). | — |
| Um morador conversa | 10 | Só com a Dora, o Otto ou a Cora na Estação: uma fala curta de quem estiver. | — |
| Sem sono (ruim) | 8 | Só com alguém com trauma: ele não dorme, e o instinto dele não baixa. | Não evita. |

- **O vigia diminui as chances ruins:** com alguém de vigia, o peso de cada evento ruim cai pela metade (`WatchFactor`
  50), e os ruídos, a goteira e as baratas viram o texto de "o vigia evitou". O preço é o de antes: o vigia não dorme.
- **Sem vigia, sem morador e sem trauma,** esses três eventos não saem.
- **Medido em 1000 noites** com a equipe dos fundadores: sem vigia, 47% das noites têm um evento ruim; com vigia, 24%,
  e nenhum deles custa nada.
- **O pedido dizia "um rato na despensa".** Na lore, os roedores são povos (os ratos, os esquilos), então a praga virou
  baratas. A fala dos moradores segue o que cada um faz na Estação (a Dora, cozinheira, que evita
  desperdício; o Otto, técnico, no gerador; a Cora, pesquisadora, nos fragmentos).
- **O evento antigo** (os ruídos sempre presentes, de antes da #132) continua nos saves velhos, com o texto de antes.

## Testes

- **`test_night_events` (novo):**
  - o sorteio: a mesma noite sorteia o mesmo, e em 80 noites saem vários eventos;
  - o vigia: em 300 noites, menos noites ruins com ele;
  - cada evento: o efeito (instinto, água, suprimentos, trem, radar) e o texto, com e sem vigia, e o Depósito melhorado;
  - os eventos que pedem vigia, morador ou trauma, que não saem sem eles;
  - o save no meio da noite, que abre no amanhecer com o mesmo evento;
  - a tela:
    - a cena abre com o cartão;
    - a Estação escurece, ou não, com "Reduzir efeitos";
    - quem dorme fica deitado e o vigia de pé;
    - Interagir pula, a luz volta e todos se levantam;
    - o amanhecer mostra os números, o evento, o Depois certo e nenhum "+0".
- **`test_keyboard_navigation`:** Iniciar descanso abre a cena; Interagir pula, e o foco fica no amanhecer.
- **`test_station_rules`:** a sede passa a ser uma condição da noite, à parte do evento.

## Para o Lucas

- Os pesos e os efeitos são propostas (a tabela acima).
- O botão IR AO MAPA, no Maior, corta a linha de baixo ("partir."). Isso já acontecia antes desta issue (vem da #123) e
  fica para um conserto à parte.
