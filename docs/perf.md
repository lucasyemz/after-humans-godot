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
