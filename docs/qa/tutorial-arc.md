# A abertura pelo arco (#144, #147, #145)

Decisão do Lucas (27/10): o tutorial segue o arco de `docs/narrative/bento-nick-arc.md` (§3, §4 e §26, Atos 1 e 2). O
Bento sai da Estação numa missão de abastecimento com a Íris e a **Véspera** (no lugar da Amora, que ainda não está no
jogo: opção B), a área automatizada entra em protocolo de contenção e o grupo fica preso. O Nick, que vigiava de longe,
volta para ajudar e mostra a rota alternativa. A troca da Véspera pela Amora fica anotada no arco e no
`docs/narrative/review.md`.

Continuam como o Lucas já tinha decidido: o cartão "Você precisa escapar.", o nome "Corredor de Contenção", as lutas
dentro do mapa e a saída pelo trem. O mapa é o do PR #173, aprovado pelo Lucas (`docs/qa/tutorial-map.md`).

## A ordem dos trechos (nova)

- **Antes:** a partida, a luta 1, o Nick, a busca, a luta 2, a luta 3 e o trem.
- **Agora:** a partida, a luta 1, o Nick, **a luta 2, a busca**, a luta 3 e o trem. No mapa do #173 o armário e o painel
  ficam no fim da sala das celas, então a luta 2 vem antes deles. As dicas seguem: a da patrulha logo depois do Nick, a
  das posições na luta 2, a da busca e a da Mochila depois dela, a do item na luta 3. Cada luta abre a dica dela pelo
  nome (`fight_1`, `fight_2`, `fight_3`), não mais pelo número do trecho.

## A equipe

- **Antes:** o Bento sozinho; o Nick entrava no encontro.
- **Agora:** o Bento, a Íris e a Véspera desde o começo (`StartTeam`); o Nick entra no encontro, quando o grupo está
  preso (`JoinTeam`). Os quatro fundadores chegam juntos à Estação.

## Os textos para o Lucas aprovar

| Onde | Antes | Agora (português) | Inglês |
|---|---|---|---|
| Título, "Começar pela abertura" | A fuga do Bento e do Nick pelo Corredor de Contenção: três lutas curtas que ensinam a jogar. | O Bento, a Íris e a Véspera presos no Corredor de Contenção, e o Nick, que volta para ajudar: três lutas curtas que ensinam a jogar. | Bento, Íris and Véspera trapped in the Containment Corridor, and Nick, who comes back to help: three short fights that teach you how to play. |
| Encontro, Nick | Essa porta não abre mais. As máquinas fecharam o corredor inteiro, e você ficou do lado de dentro. | Essa porta não abre mais. O protocolo de contenção fechou o corredor inteiro, e vocês três ficaram do lado de dentro. | That door won't open anymore. The containment protocol sealed the whole corridor, and the three of you are stuck on the inside. |
| Encontro, Véspera (nova) | — | Ele estava nos vigiando desde a escada. | He's been watching us since the stairs. |
| Encontro, Bento | Tem gente na Estação esperando por estes suprimentos. Eu não volto de mãos vazias: tem que haver outro caminho. | Tem gente na Estação esperando estes suprimentos. Íris, Véspera, atrás de mim: tem que haver outro caminho. | There are people at the Station waiting for these supplies. Íris, Véspera, behind me: there has to be another way. |
| Encontro, Nick | Tem. Pelo duto, depois a escada até o alçapão. Eu ia seguir viagem... Anda, antes que eu mude de ideia. | Tem. Pelo duto, depois a escada até o alçapão. Eu ia seguir viagem... Andem, antes que eu mude de ideia. | There is. Through the duct, then the ladder up to the hatch. I was going to keep moving... Go, before I change my mind. |
| Debriefing, Nick | Você ia ficar preso lá embaixo por causa de uma mochila de comida. | Você ia acabar morrendo junto com elas. | You'd have ended up dying right along with them. |
| Debriefing, Bento (nova) | — | Talvez. | Maybe. |
| Debriefing, Nick (nova) | — | Idiota. | Idiot. |
| Debriefing, Bento | Por quem está esperando por ela. Fica? Aqui tem comida, cama e porta que abre por dentro. | Fica? Aqui tem comida, cama e porta que abre por dentro. | Stay? There's food here, a bed, and a door that opens from the inside. |
| Debriefing, Nick | Só por uma noite. | Só por uma noite. (igual) | Just for one night. |
| Dica da habilidade | … O Broto é fraco: ataque. | … Os inimigos daqui são pequenos: ataque. | … These enemies are small: attack. |

As três primeiras falas do debriefing são as do arco (§4); o convite e o "Só por uma noite." são o §5. A fala nova da
Véspera é o papel que o arco dá à Amora (§21: ela testemunha o Nick escolhendo voltar) e combina com a Véspera da
lore (§15.6: "fala pouco, vê primeiro").

A visita da Estação (#145) fica como estava: é o Bento mostrando a Estação ao Nick, e o "Não que eu pretenda ficar
para isso" do Nick é o "Estou só passando" do arco (§5).

## As lutas

A vida dos heróis continua parando em 1 no tutorial (`min_hero_hp`). Só inimigos que já existem, sem mexer em
`enemies.json`, e com arte de combate (os Ecos de Sucata não têm).

| Luta | Antes | Agora | Por quê |
|---|---|---|---|
| 1 (os três) | Broto (6 de vida) | Broto, Faísca e Pipoco (6, 8 e 6) | Um Broto morria no primeiro golpe de três heróis. Com três pequenos, cada herói tem a vez e escolher o alvo importa, e a luta segue fácil. |
| 2 (os quatro, com o Nick) | Rastejante de Cabos (17) | Rastejante de Cabos e Broto atrás | Quatro heróis derrubavam o Rastejante antes de ele empurrar alguém. Com o Broto atrás, a luta dura o bastante para empurrar, mover e defender. |
| 3 (os quatro) | Drone de Expurgo (16) | Faísca na frente do Drone de Expurgo | Sozinho, o Drone caía antes de contaminar. Atrás da Faísca, ele age pelo menos uma vez, e a contaminação e o curativo da Mochila aparecem. |

## O que sai: o bloco "station"

As propostas A ("só o Bento e o Nick; a Íris e a Véspera chegam pelo trem") e B ("os quatro fundadores") deixam de
fazer sentido: a Íris e a Véspera já estão com o Bento desde a saída. Sai o bloco `station` de `data/tutorial.json`
e o caminho da proposta A em `AHTutorial.complete`; os quatro fundadores voltam juntos, como na B.

## Testes

- `test_tutorial` (61), `test_tutorial_map` (96), `test_title`, `test_briefing`, `test_station_tour` e `test_i18n`
  com a equipe nova (três no começo, o Nick entra no encontro, quatro falas no encontro, cinco no debriefing) e a
  ordem nova (a patrulha depois do Nick, a luta 2 com o recuo, a busca, o save e a luta 3).
- `tests/run_all.gd` inteiro na 145.
