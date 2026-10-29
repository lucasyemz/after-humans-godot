# Desempenho: medidas e o que mudou (#37)

## Como medir

O roteiro `--perf` passa sozinho pelo título, pela Estação, pela rua, por uma luta e pelos seis cenários, em cada
qualidade pedida. Em cada parada ele mede:
- o tempo de quadro (média e p95 de 120 quadros, sem vsync);
- as chamadas de desenho, as primitivas e os objetos;
- a memória de vídeo e a do jogo;
- as luzes com sombra.

As opções não são gravadas e a campanha fica numa pasta própria.

```
"$GODOT" --path . --resolution 1920x1080 -- --perf=<pasta> [--perf-levels=0,2] [--perf-only=station,street,combat]
"$GODOT" --rendering-method gl_compatibility --path . --resolution 1920x1080 -- --perf=<pasta>   # o renderizador da web
node tools/web_perf.mjs [--only=station,combat] [--levels=0]   # a web exportada (build/web), no Chromium
```

Ele grava `perf.csv` e `perf.md` na pasta. A medida de verdade de tempo de quadro é a do Lucas, no PC dele. As de
baixo foram tiradas numa máquina de nuvem sem placa de vídeo (llvmpipe, render por software, com outras tarefas
rodando junto). Ali o tempo em ms não diz nada, mas as chamadas de desenho, as primitivas e os objetos são os mesmos em
qualquer máquina.

## O que pesava: a sombra das luminárias na Estação

Cada OmniLight3D com sombra desenha a cena de novo seis vezes, uma por face do cubo de sombra. A Estação tem 18 luminárias com sombra acesas no Compatibility (20 no grupo, contando as do Forward+). A fogueira da rua e as luzes das casas também seguem a qualidade.

Antes e depois, no Compatibility (o renderizador da web), em 1920×1080:

| Cena | Qualidade | Chamadas antes | Chamadas depois | Primitivas antes | Primitivas depois | Luzes com sombra antes | Luzes com sombra depois |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Estação | Baixo | 4.986 | 482 | 5.140.325 | 155.729 | 18 | 0 |
| Estação | Alto | 4.828 | 482 | 5.014.283 | 240.076 | 18 | 0 |
| Rua | Baixo | 210 | 184 | 58.394 | 16.130 | 3 | 0 |
| Rua | Alto | 282 | 248 | 79.394 | 37.128 | 4 | 1 (o sol) |
| Luta na rua | Baixo | 312 | 255 | 69.274 | 23.260 | 3 | 0 |
| Luta na rua | Alto | 397 | 327 | 93.612 | 51.344 | 4 | 1 (o sol) |
| Cenários | Baixo | 158 a 177 | igual | 12 mil a 35 mil | igual | 0 | 0 |

Os cenários já tinham as peças fixas juntadas numa malha por material e as luminárias sem sombra no Compatibility, e
ficaram como estavam.

## Na web

A versão web exportada (preset Web, sem threads) roda o mesmo roteiro no Chromium, com `tools/web_perf.mjs`. Nesta
máquina sem placa de vídeo o WebGL 2 é feito por software (SwiftShader), então os ms não servem como medida, mas o
roteiro inteiro abre e passa: título, Estação, rua e luta no Baixo, sem travar.

| Cena (web, Baixo) | Chamadas | Primitivas | Objetos | Memória de vídeo |
| --- | ---: | ---: | ---: | ---: |
| Título | 8 | 62 | 31 | 46 MB |
| Estação | 464 | 153.343 | 1.086 | 376 MB |
| Rua | 184 | 16.130 | 649 | 220 MB |
| Luta na rua | 256 | 24.672 | 1.449 | 229 MB |

O workflow da versão web (#39) roda esse roteiro a cada exportação.

## O que mudou

- **Sombra das luminárias por qualidade** (`Settings.effects().lamp_shadows`):
  - no Forward+ (o desktop), só no Alto e no Ultra;
  - no Compatibility (a web), só no Ultra;
  - no resto, as luminárias acendem sem sombra;
  - a sombra do sol continua a partir do Médio.

  A troca vale na hora, pelo grupo `shadow_lamps`, que junta as luminárias da Estação, dos cenários e os postes da rua.
- **LOD por qualidade** (`Viewport.mesh_lod_threshold`): 6 px no Baixo, 3 no Médio e 1 no Alto e no Ultra. Os
  modelos importados (o metrô, os props da Estação) já tinham LOD; no Baixo, o mais simples entra antes. Na rua no Baixo, as primitivas caíram de 58 mil para 16 mil.
- **O que já existia e continua:**
  - a resolução interna por qualidade (0,67 no Baixo);
  - oclusão, neblina volumétrica e reflexos da chuva só a partir do Médio ou do Alto;
  - a quantidade de chuva por qualidade.

## Pendências (para conferir no PC do Lucas)

- **Meta:** todas as cenas a 60 fps no Alto e jogáveis no Baixo.
  - **Como medir:** rodar o roteiro no Forward+ e no Compatibility no PC do Lucas e colar o `perf.md` aqui.
- **O que olhar se a Estação ainda passar de 16 ms no Alto do Forward+:**
  - as 18 sombras: deixar com sombra só a luminária do cômodo em foco;
  - os props de 23 mil triângulos (a luminária de gaiola aparece 7 vezes): trocar pela versão de 512 px ou juntar as cópias num MultiMesh.
- **Web:** o pacote tem 127 MB (`index.pck`) e demora a baixar. É o assunto da #12 (pacote mais leve).

## A câmera de cinema por lugar (#153)

O perfil de ambiência (`data/presentation/ambience.json`) muda o grading, o glow, a névoa e as partículas, e no Baixo
tira o desfoque de profundidade e deixa 35% das partículas. As medidas abaixo são do `--perf` na nuvem (Compatibility
em software, `--perf-only=street,combat`, no Baixo e no Ultra), comparando a `main` (be4f6a1) com a #153. Os ms não
servem como medida aqui; as chamadas, as primitivas e os objetos servem.

| Cena | Qualidade | Chamadas main | Chamadas #153 | Primitivas main | Primitivas #153 | Objetos main | Objetos #153 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Rua | Baixo | 196 | 197 | 8.642 | 8.650 | 633 | 633 |
| Rua | Ultra | 295 | 296 | 71.924 | 72.268 | 723 | 724 |
| Luta na rua | Baixo | 178 | 180 | 8.112 | 8.114 | 376 | 369 |
| Luta na rua | Ultra | 320 | 328 | 78.558 | 79.094 | 489 | 524 |

Na rua, as folhas e os dois respiros de vapor custam uma chamada cada, e as primitivas sobem pouco (as folhas e o
vapor são quads). Na luta, a diferença maior (35 objetos e 8 chamadas no Ultra) vem em parte da luta sorteada em cada
rodada, que não é a mesma nas duas medidas. O desfoque de profundidade e a névoa volumétrica, que são o custo de verdade, não aparecem nessas colunas: o
tempo de quadro no Forward+, no Baixo e no Ultra, fica para o PC do Orquestrador, com o mesmo comando.

## A luz prática na Rua (#154)

O tambor com fogo, o lampião, a luz de emergência e o farol do drone (`AHPracticalLight`). No `--perf` da nuvem
(Compatibility em software), a parada de rua do roteiro fica longe dos becos das fontes (x 37 a 52) e as chamadas e
primitivas são as da #153 (Rua: 196 e 8.640 no Baixo, 295 e 71.982 no Ultra). No Compatibility e no Baixo, as fontes não
acendem luz da cena (só o halo e a poça desenhados): cada fonte custa três ou quatro quads somados e, no tambor, as 10
fagulhas.

O custo que importa é no Forward+, da Média para cima: três OmniLight (a do tambor com sombra pelo `lamp_shadows`) e a
SpotLight do drone, com a névoa volumétrica. Para medir no beco do tambor, o tempo de quadro de cada foto de
`tools/capture_154.gd` sai em `frames.txt` (`--rendering-method forward_plus`), no Baixo, no Alto e no Ultra: fica para
o PC do Orquestrador.
