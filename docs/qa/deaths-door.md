# O Último Fôlego de pé, piscando em vermelho (#281)

Pedido do Lucas (31/10/2026): no Último Fôlego o personagem continua de pé, na pose normal de combate, em destaque e
piscando em vermelho, como a Porta da Morte do Darkest Dungeon. Só cai quando é derrotado depois do Último Fôlego.

Antes (a `main`, à esquerda), os fundadores ficavam ajoelhados na pose de caído e os recrutas, de pé e escurecidos.
Depois (à direita), todos ficam de pé, na cor normal, com o pulso vermelho (aqui no ponto mais forte):

![antes e depois no Último Fôlego](deaths-door/pair_ultimo_folego.jpg)

O pulso no ponto mais forte e no mais fraco (um ciclo de 1,1 s):

![o pulso](deaths-door/pulso.jpg)

Derrotado de vez depois do Último Fôlego, o herói cai, fica cinza e perde a placa, como antes. Os outros continuam
piscando:

![antes e depois do derrotado](deaths-door/pair_derrotado.jpg)

As fotos saem de `tools/capture_281.gd` (a luta da Rua das Vitrines com a equipe toda no Último Fôlego). O antes é o
mesmo roteiro no código da `main`.

## O que muda

- **`AHSpriteCard.set_danger()`:** um pulso de luz vermelha no desenho (de 0,04 a 0,3, num seno de 1,1 s), somado ao
  destaque da mira (#57). O piscar do acerto volta para ele. Com os efeitos reduzidos, fica um brilho fixo no meio do
  pulso, sem piscar.
- **`AHCombatArena.rest_pose()`:** no Último Fôlego, a pose parada, a cor normal e o pulso. Derrotado de vez, a pose de
  caído e o cinza. A cura desliga o pulso, e o fim da luta também (quem sobrevive volta para a rua com 1 de vida, sem a
  luz).
- **O #70 (PR #278):** com o herói de pé no Último Fôlego, o ALVO e o clique já ficam na altura certa. O #278 deixa de
  ser necessário.

## Testes

- `tests/test_deaths_door_pulse.gd`: o pulso vai e volta, soma ao destaque da mira, volta depois do acerto, fica fixo
  com os efeitos reduzidos e apaga ao desligar.
- `tests/test_deaths_door_fight.gd`: uma luta da rua termina com um herói no Último Fôlego, e o pulso apaga.
- `tests/test_street_scene.gd`: o recruta no Último Fôlego fica de pé, na pose parada, na cor normal e com o pulso.

## QA

- **Rodada 1: REPROVADO**, por um ponto médio: nenhum teste conferia que o pulso apaga no fim da luta. Entrou o
  `test_deaths_door_fight` (ele falha se o fim da luta não desligar o pulso). As observações baixas foram corrigidas
  junto: a checagem da mira ficou mais rígida, os efeitos reduzidos ganharam o brilho fixo e um arquivo de outra entrega
  saiu do commit.
- **Rodada 2: APROVADO.** A QA rodou a suíte inteira (101/101, paridade 48/48), as capturas do pulso, da mira (#57) e do
  derrotado, e uma luta real na rua com o herói no Último Fôlego agindo, em crise, curado e terminando por vitória,
  derrota e fuga. Conferiu também os efeitos reduzidos (fixo em 0,17, sem piscar), o ALVO, as placas e que nada foi
  gravado nos saves e nas opções do jogador.
