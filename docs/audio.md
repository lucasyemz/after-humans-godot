# Áudio: o que toca em cada momento (#36)

Os sons ficam em `audio/` e tocam pelo autoload `Sound` (`scripts/core/sound_service.gd`).

**Barramentos:** quatro, todos indo para o Master:

| Barramento | O que leva | Volume nas Opções |
| --- | --- | --- |
| Music | Trilhas | Música |
| Ambience | Ambientes, chuva e os loops da Estação | Ambiente |
| SFX | Efeitos do mundo e da luta | Efeitos |
| UI | Sons de `audio/ui` | Efeitos (não há um quarto controle) |

**Mixagem:**
- A tabela `data/presentation/audio_mix.json` guarda o volume medido de cada arquivo (LUFS integrado, EBU R128, pelo ffmpeg) e o ganho que o leva ao alvo da categoria. A ferramenta é `tools/measure_audio.py`.
- O ganho de cada cena (o `music_gain` e o `ambience_gain` de `soundscape()`) entra por cima.
- A música e os ambientes vão ao alvo. Os efeitos que já existiam só são medidos, para não mexer no equilíbrio que foi acertado jogando. Os efeitos novos, de `tools/synth_sounds.py`, vão ao alvo deles.

| Categoria | Alvo |
| --- | --- |
| Música | -18 LUFS |
| Ambiente | -26 LUFS |
| Efeitos novos | -20 LUFS |
| Interface nova | -24 LUFS |

**Abaixar a música (duck):** a música cai 9 dB na crise de instinto, enquanto ela dura, e 9 dB no toque de vitória ou derrota. No golpe crítico cai 5 dB por 0,35 s, e volta em 0,8 s.

## Cenas

| Cena | Música | Ambiente | Chuva |
| --- | --- | --- | --- |
| Estação | `explore_3` (Contemplation), ganho 0,26 | `station/hum_loop` (0,45); ventilador do Bar e lâmpada do Depósito em 3D | — |
| Rua e cenários | `explore_1/2/3` conforme a fase; `explore_root_bridge` na Ponte | `ambience/<mapa>` (0,8) | `rain_outdoor` ou `rain_indoor` (0,7) |
| Luta | `battle`; `boss` no guardião | O do lugar | A do lugar |
| Título | — | — | — |

Volume medido das trilhas, antes do ajuste:

| Trilha | Medido | Ganho do ajuste |
| --- | --- | --- |
| `boss` | -6,9 LUFS | -11,1 dB |
| `battle` | -12,8 LUFS | -5,2 dB |
| `explore_1` | -13,5 LUFS | -4,5 dB |
| `explore_2` | -20,7 LUFS | +2,7 dB |
| `explore_3` | -26,8 LUFS | +8,8 dB |
| `explore_root_bridge` | -15,7 LUFS | -2,3 dB |

Antes do ajuste, a trilha do chefe soava 20 dB acima da da Estação.

Os ambientes iam de -24 a -33 LUFS e agora ficam todos em -26.

## Momentos

| Momento | Som | Onde |
| --- | --- | --- |
| Clique, confirmar, negar | `ui/click`, `ui/confirm`, `ui/deny` | Botões, Mochila, ações da Estação recusadas |
| Abrir e fechar painéis | `ui/panel_open`, `ui/panel_close` **(novo)** | Cômodos e serviços da Estação; janelas da exploração |
| Abrir a Mochila | `ui/bag_open` | Exploração e luta |
| Fabricar na Forja | `ui/forge_confirm` **(novo)** | Forja |
| Pesquisa concluída | `station/research_beep` (existia e não tocava) | Pesquisa |
| Trem chegando | `station/train_arrival`, depois `station/train_brake` **(novo)** 1,6 s antes de parar e `station/train_bell` **(novo)** ao parar | Plataforma |
| Trem partindo | `station/train_departure` e `station/train_bell` | Plataforma |
| Passos | `world/footstep_<piso>_N`: concreto, água no Depósito e nos Dutos, madeira na Ponte e no Cais | Exploração |
| Porta de casa | `world/door_open`, `world/door_close` | Rua |
| Busca | `world/find_coins` (objetivo da rota), `world/prop_open` (prop que abre), `world/search_cloth_N` (o resto) | Rua e cenários |
| Achado raro (fragmento ou ferramenta) | `world/find_rare` **(novo)**, por cima do som da busca | Rua e cenários |
| Ações dos heróis e dos inimigos | `combat/*` | Luta |
| Crise de instinto | `combat/crisis` **(novo)** e a música abaixa | Luta |
| Golpe crítico | A música abaixa um instante | Luta |
| Vitória e derrota | `ui/victory` e `ui/defeat` **(novos)**; a fuga não tem toque | Fim da luta |

Os passos levam o jeito de cada herói, pela classe de quem vai na frente. É a mesma gravação com outra altura e outro volume:

| Herói | Altura | Volume |
| --- | --- | --- |
| Bento | 0,88× | 85% |
| Nick | 1,12× | 50% |
| Íris | 1,0× | 65% |
| Véspera | 1,05× | 60% |

## Ainda falta

- **Passos de verdade por herói:** uma gravação própria de cada um; hoje é a mesma com outra altura.
- **Volume dos efeitos que já existiam:** foram só medidos. Há ações de herói de -6 a -31 LUFS, como a Véspera 4 a -31,5 e o Nick 4 a -5,9. Igualar muda a sensação de cada golpe, então fica para o Lucas decidir jogando.
- **Fim da expedição:** o toque de vitória ou derrota é o da luta. O fim da expedição não tem toque próprio.

## Créditos

Os créditos estão no [README](../README.md#créditos-de-áudio).
