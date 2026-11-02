# Relíquias: dois slots por herói (#263, parte 1)

O desenho aprovado está na #263 (a proposta do Orquestrador e o aceite de 01/11). Esta é a primeira parte: os dois
slots, os campos novos dos dados e os sorteios presos à origem e à raridade. As origens especiais, os gatilhos novos, a
perda na derrota e o Colar de Circuito ficam para a parte 2.

As capturas são do jogo, pela cena de verdade (`tools/capture_263.gd`, o mesmo roteiro no código de antes e no de
agora), em 1920x1080, por software (xvfb). À esquerda o antes, à direita o agora.

## A Sala dos Personagens

![a Sala, antes e depois](relics/room.jpg)

- **Antes:** um slot ("Relíquia: Botão de Cobre") e um botão de trocar.
- **Agora:** "Relíquia 1" e "Relíquia 2", cada uma com o ícone, o que faz e o seu botão TROCAR. O Bento leva o Botão de
  Cobre e a Semente no Bolso.

## O bloqueio explicado

![o bloqueio, antes e depois](relics/blocked.jpg)

O Nick tem a Pena de Vidro no slot 1, e a única do estoque é outra Pena. No slot 2, o TROCAR passa só pelas opções que
o slot aceita; sem nenhuma, o aviso diz o motivo: "Pena de Vidro: Já equipada no outro slot.". Os outros motivos são
"Só para %s." (o papel) e "Só %s usa." (o fundador). Antes, o mesmo toque desequipava a Pena.

## A ficha

![a ficha, antes e depois](relics/sheet.jpg)

Uma linha por relíquia equipada nos efeitos passivos. O relatório da volta mostra os dois ícones lado a lado, com os
nomes juntos.

## As regras

- **O save:** o `relic_id` antigo vira o slot 1 no load (`AHStationRules.migrate`), a chave sai e o estoque fica igual.
  Rodar de novo não muda nada.
- **Os slots:** a mesma relíquia não entra nos dois slots do mesmo herói; cópias em heróis diferentes valem. Trocar
  devolve a que saiu ao estoque.
- **Os bônus:** cada relíquia conta uma vez. A Velocidade vinda delas tem teto de +2; a que tira não tem piso.
- **Os dados** (`data/relics.json`): `Rarity`, `Only` (`role:<classe>` ou `hero:<id>`), `Sources` e `Phase`.
- **As origens:**
  - a carga só sorteia as de `cargo`, e a de `Phase` só na fase dela;
  - a escavação, as de `dig`;
  - a missão solo, as de `cargo` sem fase;
  - a Forja fabrica só as comuns de `forge`.
  - Nenhum sorteio escolhe rara, pessoal ou lembrança.
- **As três novas** usam efeitos que já existem:
  - Semente no Bolso, comum, da Forja: +5 pp de Superação;
  - Sininho de Vitrine, incomum, da carga da fase 1: +1 Vel. e −2 Vida máx.;
  - Raiz Trançada, incomum, da carga da fase 2: +4 Vida máx. e −1 Vel.
- **Os ícones** das novas são o genérico (`relic-generic`) até a arte do ciclo de design.

## Como testar

- `tests/test_relics.gd`: a migração, os slots, a troca sem perda, o teto, as restrições, os sorteios, a Forja e o
  bônus na luta.
- **Em Play:**
  - fabrique a Semente no Bolso na Forja (a Coleira não aparece mais lá);
  - na Sala, equipe as duas Penas no mesmo herói: o slot 2 recusa, com o motivo;
  - abra a ficha na Preparação: as duas relíquias aparecem.
