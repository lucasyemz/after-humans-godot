# As poses do acampamento no chão (#205)

![Antes (à esquerda) e depois (à direita): a Véspera deitada e a Íris, o Nick e o Bento sentados, o Tatu e o Guaxinim de pé e a Coruja sentada, no acampamento da casa](camp-ground/before_after.jpg)

## A causa

Levantamento com `tools/capture_205.gd`: o acampamento numa casa com os fundadores, os recrutas com pose (cão e gato,
sapo e coruja) e o Guaxinim e o Tatu (#196), com o último de cada equipe ferido (deita).

- **A âncora e a escala estão certas.** Em todas as 16 poses (`data/presentation/camp_poses.json`), o último pixel
  opaco da arte cai a no máximo 3 px da âncora, num corpo de cerca de 1.400 px. A textura reduzida pela metade (os
  sentados) é convertida pela carta (`AHSpriteCard._layout`).
- **O deitado que vem da Estação também está certo:** canvas próprio (887x443), com a âncora no último pixel opaco.
- **O que faltava era o contato com o chão.** Na rua, quem está de pé ganha a sombra comprida do sol. No acampamento,
  a fogueira e a luz da sala não fazem sombra embaixo do corpo, e sob teto o sol fica sem sombra (#175). Sem nada
  embaixo, o sentado e o deitado parecem soltos do chão, mesmo com o pé na linha dele.

## O que muda

- **A sombra de contato** (`AHCampScene._contact`): cada herói em volta da fogueira ganha uma mancha escura e macia no
  chão, embaixo do corpo visível da pose (o `visible` de `camp_poses.json`), com 90% da largura dele.
  - Quem não tem pose de acampamento (o Guaxinim e o Tatu, por ora) fica de pé, com a sombra de 0,8 m sob o pé.
  - A sombra sai ao levantar acampamento.
- **Nada muda nos dados nem na arte.**

## Para a Awesomic 1

O Guaxinim e o Tatu ainda não têm as poses de acampamento (sentado no chão e deitado). Até chegarem, eles ficam de pé
em volta da fogueira, com a sombra de contato.

## Testes

- `tests/test_camp_ground.gd` (novo, 33 verificações):
  - em cada pose, o ponto mais baixo do corpo na linha do chão (até 2 cm), medido na própria arte;
  - na cena, com o Bento, o Guaxinim, o Tatu e o Nick deitado: a sombra de contato no chão embaixo de cada um, na
    largura do corpo, e fora depois de levantar acampamento.
- `tests/run_all.gd` inteiro.
- `tools/capture_205.gd`: as capturas de antes (na `main`) e de depois.
