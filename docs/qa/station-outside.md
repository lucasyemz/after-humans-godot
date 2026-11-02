# A vista de fora no fim da linha (#217)

Antes, a Estação era toda fechada e não dava para saber se era dia ou noite. Agora, no fim da linha (a ponta esquerda
da plataforma, sobre a boca do túnel por onde o trem sai), a abóbada se abre para fora: por ela aparece um pedaço do
Bairro Submerso com a cor da hora do dia, e a luz de fora cai de leve na ponta da plataforma. O resto da Estação não
muda.

![a plataforma, com a mesma câmera, nas quatro horas: antes e agora](station-outside/platform.jpg)

![de perto, o fim da linha de dia e de noite: antes e agora](station-outside/exit.jpg)

![a vista geral de dia: antes e agora](station-outside/overview.jpg)

As fotos saem de `tools/capture_217_outside.gd` (roda também no código de antes, com as mesmas câmeras).

## A hora

A campanha não tem relógio. A hora sai do ciclo da Estação que já existe (o dia e a noite do #132):

| Hora | Quando | A vista | A luz que entra |
| --- | --- | --- | --- |
| Fim de tarde | na volta, com a noite a planejar (`night.phase` `planning`) | pêssego, com o brilho no horizonte | quente |
| Noite | durante a cena da noite (`AHStation.night_scene`) | azul-escura, com estrelas | fria e fraca |
| Amanhecer | no resumo do amanhecer (`night.phase` `dawn`) | rosada, com um resto de estrelas | quente e fraca |
| Dia | no resto (e em "Esperar um dia") | clara | branca, a mais forte |

- **A troca é suave:** 1,5 s de uma hora para a outra quando a fase muda com a Estação aberta. Ao abrir a Estação, a
  hora já está certa.
- **O clima:** a Estação não guarda o tempo da rua (ele só existe dentro da expedição e some na volta), então a vista
  não tem chuva, como a issue prevê ("se o jogo já tiver isso nos dados").
- **O save não muda:** a hora é calculada, nada novo é gravado.

## A arte

A vista usa o panorama da cidade alagada dos cenários (`art/scenarios/T_BridgePanorama.webp`), recortado e tingido
num shader (`shaders/station_outside.gdshader`). A arte própria (o fundo de fora e o acabamento da abertura) está
pedida ao design na #315, como a issue manda quando falta arte.

## Onde fica

- `scripts/station/station_outside.gd` (`AHStationOutside`): a hora (`hour_of`), as cores por hora (`LOOK`), a vista
  e a luz.
- `scripts/station/station_build.gd`: o vão nos 6 segmentos da frente da abóbada, entre x 0,8 e 7,2 m
  (`OUTSIDE_X0`, `OUTSIDE_X1`, `OUTSIDE_SEGMENTS`), e o lintel no alto dele.
- `scripts/station/station.gd`: monta a vista e acompanha a hora (`refresh_outside`).
- `tests/test_station_outside.gd`: a hora em cada fase, as quatro vistas diferentes, a troca acompanhando a volta, a
  cena da noite e o amanhecer, a abertura na câmera da plataforma, a vista fora do salão e o save intacto.
