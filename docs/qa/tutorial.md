# O tutorial da abertura (#144)

A campanha nova começa pela fuga do Bento e do Nick pelo Corredor de Contenção (#147): três lutas fáceis, a busca, o
trem e a chegada à Estação, com a recompensa. A visita guiada da Estação é a #145, por cima desta.

![O cartão, a primeira luta, o Nick, a Mochila, o item, a recompensa, o vagão e a chegada](tutorial/overview.jpg)

## O que muda

- **A campanha nova** (o título, e também a Nova campanha da Estação e da rua) pergunta "Como começar?": pela abertura
  (o padrão) ou Pular tutorial. Pular dá o mesmo estado de quem joga até o trem: a recompensa, o elenco e o relatório.
- **A abertura:** o cartão "Você precisa escapar." (decisão do Lucas; o quadro da tirinha fica em `data/tutorial.json`,
  `opening`) e o Corredor de Contenção com o Bento sozinho.
- **As dicas do tutorial** (`AHTutorialGuide` e `AHTutorialHint`, no kit): nove passos de `data/tutorial.json`, uma de
  cada vez, cada uma com o destaque e as teclas:
  - andar; a habilidade e o alvo (a primeira escolha trava as outras ações e escurece o resto); vasculhar; a Mochila;
    a patrulha; a posição e a defesa; os estados e o item na luta; o embarque;
  - a dica some quando o jogador faz o que ela pede, sai da frente com uma janela aberta e não cobre as cabeças;
  - as dicas de primeira vez (`Tips`) ficam caladas durante a abertura e contam como vistas no fim.
- **Ninguém cai:** no tutorial a vida do herói para em 1 (`AHCombat.Context.min_hero_hp`); quem foge recomeça a mesma
  luta com a equipe inteira.
- **O Nick chega** numa conversa com retrato (a caixa do briefing, #88) e entra na equipe.
- **O fim:** a recompensa à vista (+10 sementes, +1 curativo e o pé de cabra), a passagem do vagão (#75), a chegada na
  plataforma (#76) com o debriefing do Bento e do Nick, que termina em "Só por uma noite.", e o relatório.
- **O save** guarda o ponto (`campaign.tutorial`): fechar no meio e voltar retoma dali, com as dicas já vistas.
- **Quem fica na Estação:** a proposta B (os quatro fundadores) em `data/tutorial.json` (`station`), com a A pronta.
- **Os textos** em português e inglês (`data/i18n/en.po`).

## Testes

- `tests/run_all.gd`: 65 de 65, com a paridade 48/48.
- `tests/test_tutorial.gd` (novo, 60 verificações): pular dá o mesmo estado de jogar; a vida mínima; o título até o
  cartão e o mapa; a jornada pela cena de verdade (cada dica, as travas, Voltar na mira, a dica sob o Menu, o Nick, a
  busca e a Mochila, o save no meio e o Continuar, a fuga que recomeça, as três lutas sem ninguém cair, o trem, a
  recompensa e a chegada); a Nova campanha da Estação pelo título.
- `test_title`: a janela "Como começar?" nas campanhas novas.
- `tools/capture_tutorial.gd`: as 15 capturas do fluxo, em `docs/qa/tutorial/`.

## QA

| Rodada | Veredito | O que a QA achou | Como ficou |
|---|---|---|---|
| 1 | REPROVADO | **Médias:** a Nova campanha da Estação e da rua pulava o tutorial sem a recompensa; a dica ficava por cima do Menu, das Opções e da Mochila; a dica cobria as cabeças na luta e no trem; Voltar na mira deixava a dica do alvo e soltava as ações; "a barra roxa" do instinto; passar pelo armário pulava a dica da patrulha; a fala do Bento perdia o motivo do arco (§3). **Baixas:** as setas em inglês, as teclas no toque, o erro do foco adiado, os destaques | Todas corrigidas |
| 2 | APROVADO | As observações baixas (o erro do foco, a dica da busca que ficava, o aviso do trem sob a dica) | Corrigidas depois do veredito |

## Para o Lucas

- **A abertura só com o Bento e o Nick:** no arco (§3), o Bento fica preso por causa da Íris e da Amora. Aqui ele
  arrisca a pele pelos suprimentos de quem espera na Estação. Fica assim, ou entram a Íris e a Amora?
- **As falas** (o encontro com o Nick, o debriefing e as nove dicas) esperam a sua aprovação antes do merge.
- **O elenco depois da abertura:** está a proposta B (os quatro fundadores); a A (só a dupla, e a Íris e a Véspera pelo
  trem dos recrutas, #122) é uma linha em `data/tutorial.json`.
- **Fora deste PR:** a linha do Registro "Combate iniciado nas ruínas do Bairro Submerso!" é fixa no motor (e na
  paridade) e aparece em qualquer luta.
