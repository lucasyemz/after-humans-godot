# Os interiores e os cômodos fechados (#175)

![Antes (à esquerda) e depois (à direita): a mercearia na porta, a oficina no fundo, o Cais do Rio por dentro, os Dutos de Esgoto e o Depósito Inundado, no fim de tarde](interiors/before_after.jpg)

## O que estava errado

Levantamento com `tools/capture_175.gd`, que passa pelas três lojas da Rua (na porta, no meio e no fundo) e por cada zona dos
cenários (nas duas pontas e no meio), no fim de tarde e de noite:

- **As lojas:** o sol baixo entrava na diagonal pela frente aberta da sala. Ele riscava o chão e a parede do fundo e
  deixava a parede do lado da porta clara e lisa. As paredes do lado eram de reboco sem textura.
- **As zonas cobertas dos cenários** (o Cais do Rio por dentro, o Abrigo Lacrado, o Depósito Inundado e os Dutos de
  Esgoto): o mesmo sol iluminava a equipe e as paredes como se não houvesse teto.
- **Ao ar livre** (a Ponte das Raízes, o Portão de Triagem e o cais): nada a corrigir.

## O que muda

- **O sol sob teto** (a sala de uma loja ou uma zona coberta de cenário): fica com 30% da força (`COVERED_SUN`), sem
  sombra. Somem os raios e o clarão, e a equipe continua legível. A luz da sala fica com as luminárias, a porta e a
  ambiente. Ao sair para a rua, o sol volta inteiro. Trocar a qualidade gráfica dentro da sala não devolve a sombra.
- **As paredes do lado das lojas:** usam a arte da parede do fundo de cada loja, um pouco mais escura e projetada pelo
  mundo, para não esticar na profundidade.
- **Os cenários:** as paredes do lado já tinham textura de concreto, e pareciam lisas por causa do sol. Ficam como
  estão.

## Testes

- `tests/test_interiors.gd` (novo, 12 verificações):
  - as paredes do lado das três lojas com a arte da loja;
  - na rua, o sol com sombra;
  - na loja, o sol sem sombra e a 30%, mesmo depois de trocar a qualidade;
  - de volta à rua, o sol inteiro.
- `tests/run_all.gd` inteiro.
- O modo de captura da Rua, com o teste de colisão.
- `tools/capture_175.gd`: as capturas de antes (na `main`) e de depois, com as mesmas posições.
