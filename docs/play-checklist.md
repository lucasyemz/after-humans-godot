# Checklist de Play

O que o Lucas confere jogando, de ponta a ponta, antes de dar uma fase por pronta. A automação (`tests/run_all.gd`, a
captura da rua e `tools/capture_scenarios.gd`) já cobre as regras, a colisão, o piso e o tempo de quadro; aqui fica o
que só se vê jogando: leitura, ritmo, som e se nada trava.

Anote cada item como **ok**, **estranho** (com o que viu) ou **quebrado** (com como chegou lá). Um save travado vale
guardar: a pasta é `%APPDATA%\Godot\app_userdata\After Humans\saves`.

## Começo

- [ ] `play.bat` abre o jogo; sem save, começa na Estação.
- [ ] Opções (no menu da Estação): os três volumes mudam na hora; a qualidade Baixo/Médio/Alto/Ultra muda a imagem
      sem travar; tela cheia e vsync funcionam.
- [ ] Nova campanha pede confirmação e volta a uma Estação do zero.

## Estação

- [ ] A música do refúgio e o zumbido tocam; perto do Bar e do Depósito se ouvem o ventilador e a lâmpada.
- [ ] Cada cômodo do menu abre o painel e a câmera vai até ele; Esc volta à vista geral.
- [ ] O trem chega com o candidato (som de chegada), aceitar ou recusar faz ele partir (som de saída).
- [ ] A noite pendente leva ao Dormitório antes da partida.
- [ ] **Preparar expedição** abre o mapa de fases; escolher uma fase e **Preparar expedição** leva à Preparação com a
      Missão certa; **Escolher no mapa** volta ao mapa.
- [ ] Confirmar partida leva à jornada da fase escolhida.

## Jornada (cada uma das cinco)

| Fase | Mapas | O que olhar |
| --- | --- | --- |
| 1 · Rua das Vitrines | a rua | casas trancadas, pé de cabra, acampamento, chuva apagando a fogueira |
| 2 · Ponte das Raízes | Cais do Rio → Ponte | interiores do Navio e do Galpão, a troca de mapa no fim do Cais |
| 3 · Sala Esquecida | Abrigo Lacrado | as três zonas, viajar de zona no fim de cada uma |
| 4 · Laboratório Silencioso | Portão de Triagem | a noite ao ar livre legível |
| 5 · Túneis do Eco | Depósito → Dutos | a lanterna, os três interiores do Depósito, o Porteiro |

Em cada uma:

- [ ] A música de exploração e o ambiente do lugar tocam; os passos têm o piso certo (água, madeira, concreto).
- [ ] As patrulhas avistam ("?" e "!") e chegar sem ser visto dá a vantagem de abertura.
- [ ] A luta: a música troca para a de batalha (a do chefe com o Porteiro); os personagens e os alvos ficam visíveis
      de noite e na chuva; Continuar no fim volta à exploração.
- [ ] Vasculhar faz som (pano, metal ou as moedas do objetivo) e o prop abre.
- [ ] Portas laterais: o som da porta, o interior e o Voltar.
- [ ] **Menu (Esc)**: Continuar, Opções, Voltar à Estação (antes do guardião pergunta se quer abandonar) e Nova campanha.
- [ ] Com o guardião vencido aparece **Concluir jornada · Voltar à Estação**; o resultado mostra o achado e volta à
      Estação, com a fase concluída no mapa.

## Desempenho

- [ ] No Alto, a rua e os cenários ficam lisos (o contador no canto mostra o fps); no Baixo, num PC fraco, ainda jogável.
- [ ] Na web (`play.bat web` ou o build em `build/web`), a Estação, o mapa de fases e uma luta funcionam.
