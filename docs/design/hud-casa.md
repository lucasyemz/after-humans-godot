# A Estação nova: Enfermaria, Caído, postos, trem e plataforma (26/10/2026)

O lote 7, as issues #120 e #124 juntas, porque as telas se cruzam:
- **Ninguém morre (#118):** o estado Caído nas cartas do relatório, na Sala dos Personagens e na
  Preparação, e "Íris caiu" no popup de fim de luta;
- **limites e postos (#119):** "Heróis 6 de 8" e "Ajudantes 3 de 4", o campo Posto na Sala, "Quem trabalha aqui" no
  painel do cômodo e o rendimento no relatório da volta;
- **a Enfermaria (#121):** o cômodo novo na Estação em corte (a arte nova principal), o painel e "Íris volta amanhã" no
  Próximo passo;
- **o recrutamento pelo trem (#122):** quem chegou, ACEITAR e RECUSAR, a casa cheia e a volta sem ninguém;
- **a preparação na plataforma (#123):** IR AO MAPA, PREPARAR NESTE LUGAR, a equipe de pé com as cartas e a confirmação
  INICIAR EXPEDIÇÃO;
- **ícones novos** no mesmo método dos traços.

Tudo no kit da Awesomic (`art/ui/kit/station`), sobre as capturas do jogo, nos quatro perfis (Normal, Maior, daltonismo
e Maior com daltonismo). Nada em `scripts/`, `data/` nem `tests/`. As telas servem para comparar e aprovar; a
integração é do Claude. Os números são exemplos coerentes entre as telas (o que cada posto rende, os dias, os limites):
os valores de verdade entram em `data/` na integração.

## A Enfermaria na Estação

![A Enfermaria no nível 1, na câmera do cômodo (captura da Godot)](hud-casa/infirmary_room_1.webp)
![A Enfermaria no nível 2](hud-casa/infirmary_room_2.webp)

### Os ajustes do Lucas (26/10)

| O que o Lucas pediu | Como ficou |
|---|---|
| Os objetos colados na parede do fundo | Os móveis ficam nos planos do Dormitório: os leitos da frente na linha dos beliches (y −665, 2,35 m à frente da parede do fundo, ROOM_BACK −900), os do fundo, o armário, o lavatório e o biombo a y −780 a −840. Entre eles e a parede fica o chão, como nos outros cômodos |
| A Enfermaria do tamanho do Dormitório | 12 m, de x −1840 a −640 no subsolo 2 (a escolha do Lucas de 27/10): ela começa onde já está no jogo, embaixo do Dormitório, e avança 6 m na rocha da esquerda. A Pesquisa não muda. A rocha das pontas vai até −2400, e a Visão geral passa a enquadrar a Estação a partir de −18,4 m |
| Nível 1: 2 leitos em uso e 2 esperando; nível 2: os 4 | No nível 1, dois leitos em uso com o soro entre eles, e dois que esperam a melhoria: um quebrado (sem colchão, a frente arrancada, a perna amarrada) e um coberto com a lona, com a caixa e o cobertor em cima (cards novos). No nível 2, os quatro em uso, com o biombo, o lavatório, o carrinho, um segundo soro e um segundo pendente |
| Mais gente: os caídos, quem cuida e alguém de pé | A Íris caída no leito (a pose de dormir), a Lupa no posto de quem cuida (#119), junto do soro, e o Bento de pé à frente do segundo leito. No nível 2, o Nick caído também, para mostrar mais leitos em uso |
| Refazer as telas da Enfermaria | A Visão geral e o painel, sobre as capturas novas; o painel mostra os leitos 3 e 4 esperando a melhoria |

**As capturas são da Godot sem placa de vídeo:** a máquina da Awesomic não tem GPU. A Estação roda no Compatibility
(OpenGL 3 por software, em Xvfb) a 1920 × 1080, cada quadro em mais de um minuto. Por isso as fotos usam o mínimo de
quadros; o Forward+ (Alto e Ultra) e o Baixo numa máquina com placa de vídeo ficam com o Orquestrador PC.

**Como a captura monta o cômodo:** até a integração, o cômodo novo existe só como protótipo.
[infirmary_proto.py](hud-casa/infirmary_proto.py) lê `station_build.gd` e `station.gd` do repositório, aplica as
mudanças (o lugar, a rocha, os móveis, os leitos de quem deita, a faixa de passeio, a ponta esquerda da Visão geral e a
regra "só no nível 1") e grava um pacote. [capture_infirmary.gd](hud-casa/capture_infirmary.gd) carrega o pacote por
cima do projeto e fotografa a Estação de verdade. Nada em `scripts/` muda.

**A linguagem:** as paredes, o lambri de azulejo branco, o piso e a luz fria (`COOL`) são os que o jogo já usa na
Enfermaria (os do Centro de Pesquisa): a parte limpa do subsolo. A porta do fundo fica atrás do primeiro leito. Os
móveis são cards pintados, de frente, como os dos outros cômodos (`art/station/cards/`), feitos de sucata.

| Card | Largura no cômodo | Uso |
|---|---|---|
| `Infirmary_Bed` (477×220) | 172 cm (79 de altura) | O leito. O colchão fica a 68 cm do piso: é onde a pose de dormir deita |
| `Infirmary_Bed_Broken` (502×242) | 181 cm | O leito quebrado, só no nível 1 (novo) |
| `Infirmary_Bed_Covered` (505×261) | 182 cm | O leito coberto com a lona, só no nível 1 (novo) |
| `Infirmary_Cabinet` (328×398) | 124 cm (150 de altura) | O armário de remédios, no canto esquerdo |
| `Infirmary_Drip` (129×402) | 55 cm (171 de altura) | O soro, entre os leitos (o segundo no nível 2) |
| `Infirmary_Screen` (422×377) | 150 cm | O biombo de lata e lona (nível 2) |
| `Infirmary_Washstand` (265×339) | 70 cm | O lavatório com o galão (nível 2) |
| `Infirmary_Trolley` (327×378) | 80 cm | O carrinho de supermercado com o material (nível 2) |

![Os cards da Enfermaria](hud-casa/cards.webp)

## As telas

| Tela | Normal | Maior | Daltonismo | Maior e daltonismo | Antes e depois |
|---|---|---|---|---|---|
| Visão geral com a Enfermaria e "Íris volta amanhã" | [infirmary_overview](hud-casa/infirmary_overview.webp) | [large](hud-casa/infirmary_overview_large.webp) | [colorblind](hud-casa/infirmary_overview_colorblind.webp) | [large_colorblind](hud-casa/infirmary_overview_large_colorblind.webp) | [comparar](hud-casa/before_after_infirmary_overview.webp) |
| O painel da Enfermaria | [infirmary](hud-casa/infirmary.webp) | [large](hud-casa/infirmary_large.webp) | [colorblind](hud-casa/infirmary_colorblind.webp) | [large_colorblind](hud-casa/infirmary_large_colorblind.webp) | (tela nova) |
| Relatório: a Íris caiu | [report_fallen](hud-casa/report_fallen.webp) | [large](hud-casa/report_fallen_large.webp) | [colorblind](hud-casa/report_fallen_colorblind.webp) | [large_colorblind](hud-casa/report_fallen_large_colorblind.webp) | [comparar](hud-casa/before_after_report_fallen.webp) |
| Relatório: os detalhes e o que os postos renderam | [report_posts](hud-casa/report_posts.webp) | [large](hud-casa/report_posts_large.webp) | [colorblind](hud-casa/report_posts_colorblind.webp) | [large_colorblind](hud-casa/report_posts_large_colorblind.webp) | [comparar](hud-casa/before_after_report_posts.webp) |
| Sala: a Íris caída | [characters_fallen](hud-casa/characters_fallen.webp) | [large](hud-casa/characters_fallen_large.webp) | [colorblind](hud-casa/characters_fallen_colorblind.webp) | [large_colorblind](hud-casa/characters_fallen_large_colorblind.webp) | [comparar](hud-casa/before_after_characters_fallen.webp) |
| Sala: o campo Posto | [characters_post](hud-casa/characters_post.webp) | [large](hud-casa/characters_post_large.webp) | [colorblind](hud-casa/characters_post_colorblind.webp) | [large_colorblind](hud-casa/characters_post_large_colorblind.webp) | (como a anterior) |
| Forja: quem trabalha aqui | [room_workers](hud-casa/room_workers.webp) | [large](hud-casa/room_workers_large.webp) | [colorblind](hud-casa/room_workers_colorblind.webp) | [large_colorblind](hud-casa/room_workers_large_colorblind.webp) | [comparar](hud-casa/before_after_room_workers.webp) |
| Fim de luta: "Íris caiu" | [fight_fallen](hud-casa/fight_fallen.webp) | [large](hud-casa/fight_fallen_large.webp) | [colorblind](hud-casa/fight_fallen_colorblind.webp) | [large_colorblind](hud-casa/fight_fallen_large_colorblind.webp) | [comparar](hud-casa/before_after_fight_fallen.webp) |
| O trem: chegou alguém | [train_recruit](hud-casa/train_recruit.webp) | [large](hud-casa/train_recruit_large.webp) | [colorblind](hud-casa/train_recruit_colorblind.webp) | [large_colorblind](hud-casa/train_recruit_large_colorblind.webp) | [comparar](hud-casa/before_after_train_recruit.webp) |
| O trem: a casa cheia | [train_full](hud-casa/train_full.webp) | [large](hud-casa/train_full_large.webp) | [colorblind](hud-casa/train_full_colorblind.webp) | [large_colorblind](hud-casa/train_full_large_colorblind.webp) | (como a anterior) |
| O trem: voltou vazio | [train_nobody](hud-casa/train_nobody.webp) | [large](hud-casa/train_nobody_large.webp) | [colorblind](hud-casa/train_nobody_colorblind.webp) | [large_colorblind](hud-casa/train_nobody_large_colorblind.webp) | (tela nova) |
| A Estação: IR AO MAPA | [go_map](hud-casa/go_map.webp) | [large](hud-casa/go_map_large.webp) | [colorblind](hud-casa/go_map_colorblind.webp) | [large_colorblind](hud-casa/go_map_large_colorblind.webp) | (como a Visão geral) |
| O Mapa: PREPARAR NESTE LUGAR | [map_prepare](hud-casa/map_prepare.webp) | [large](hud-casa/map_prepare_large.webp) | [colorblind](hud-casa/map_prepare_colorblind.webp) | [large_colorblind](hud-casa/map_prepare_large_colorblind.webp) | [comparar](hud-casa/before_after_map_prepare.webp) |
| A plataforma: a equipe de pé | [platform](hud-casa/platform.webp) | [large](hud-casa/platform_large.webp) | [colorblind](hud-casa/platform_colorblind.webp) | [large_colorblind](hud-casa/platform_large_colorblind.webp) | [comparar](hud-casa/before_after_platform.webp) |
| A plataforma: INICIAR EXPEDIÇÃO? | [platform_confirm](hud-casa/platform_confirm.webp) | [large](hud-casa/platform_confirm_large.webp) | [colorblind](hud-casa/platform_confirm_colorblind.webp) | [large_colorblind](hud-casa/platform_confirm_large_colorblind.webp) | (como a anterior) |

Cada tela também tem a redução a 40% (`*_40.webp`), o cinza (`*_gray.webp`) e, quando o painel rola, o painel rolado
até o fim (`*_scrolled.webp`). O "antes" é a tela aprovada do lote anterior que o jogo segue hoje (hud-estacao,
hud-station, hud-fluxo e hud-ajustes).

[checks.json](hud-casa/checks.json) mede cada texto e cada alvo de toque com as conferências do `lib.mjs`. As 60 telas
(15 telas, 4 perfis) passam: nenhum texto cortado, fora da sua peça ou fora da tela; nenhum alvo sobreposto ou menor que
56 px; nenhuma peça cortada pelo painel; nenhum texto por cima de medalhão; o menor texto tem 20 px.

![Visão geral](hud-casa/infirmary_overview.webp)
![A plataforma](hud-casa/platform.webp)

## Os dias e os números

As telas contam uma história só, com os números de `data/` onde eles existem:
- **Dia 4, a volta:** o fim de luta, o relatório, o painel da Enfermaria, a Sala, a Forja e o trem. A Íris caiu no
  trecho 4 e volta amanhã: os dias de `data/recovery.json` são 2 no leito da Enfermaria (3 no Dormitório, sem leito),
  e a Lupa, no posto, tira 1. Um dia é uma volta de expedição: a noite não conta. O Nick volta com Ferimento grave (9/24).
- **Dia 5, depois da noite:** a Visão geral, IR AO MAPA, o Mapa e a plataforma. Falta um dia: "Íris volta amanhã".
  O Nick recuperou 8 de vida no Dormitório (35% da vida máxima, `station_rules.gd`) e está com Ferimento leve (17/24).
  A Comida segue a conta de `AHStationRules.forecast`: 8, mais 4 da Cantina e da Dora, menos 4 que os civis comem
  (Dora 1, Otto 2, Cora 1) e 4 da noite: passa de 8 para 4. A Forja de nível 1 aparece acesa no corte, com o Brasa e
  o Otto.
- **Vida e velocidade:** o sapo tem 23 de vida e 4 de velocidade (a Íris, Ágil, tem 5; a Lupa, Lenta, 3); o cão tem 34
  (o Brasa, recruta, nasce com a vida da classe). O XP segue `hero-levels.json`.
- **Sucatas:** a próxima obra é a Forja no nível 2 (6 sucatas e 2 fragmentos). O Brasa e o Otto tiram 1 cada (6 → 4);
  a relíquia só tem o desconto do Brasa (3 → 2), porque o do Otto vale só para obras. Se o Brasa sai na expedição, a
  obra passa de 4 para 5. O custo da Enfermaria é o de `data/recovery.json` (a regra de 27/10): recuperar,
  4 sucatas e 1 fragmento; MELHORAR para o nível 2, 6 sucatas e 2 fragmentos, como o painel mostra. O desconto dos
  postos da Forja vale para a próxima obra, que é a Forja.
- **Traços:** os de `perks.json`, nunca dois incompatíveis no mesmo herói (o Sereno é Corajoso e Lento).

## O que cada tela mostra

**A Enfermaria (#121)**
- **Visão geral:** a Enfermaria no subsolo 2, escolhida (os cantos âmbar e a etiqueta), e o cartão do cômodo embaixo
  ("Os leitos de quem caiu", Nível 1, GERENCIAR). O Próximo passo é **"Íris volta amanhã"**, com o retrato dela e VER A
  ENFERMARIA.
- **O painel:**
  - o que o cômodo é, "Leitos 1 de 2 em uso" e o que acontece sem ele ("Sem a Enfermaria: 3 dias no Dormitório");
  - um bloco por leito ocupado: o retrato, o nome, a classe, a pílula **Caído** com **"Volta amanhã"** ao
    lado (a informação principal, no alto do bloco), a vida, o que ele tem ("Caiu na Rua das Vitrines, na luta do
    trecho 4."), o curativo com o que se tem e USAR CURATIVO ("menos 1 dia");
  - o leito livre ("Quem cair na próxima expedição vem para cá.");
  - os leitos 3 e 4, que esperam a melhoria (um quebrado e um coberto com a lona, como no cômodo);
  - quem cuida, o posto: a Lupa, com o que rende e TROCAR;
  - no pé, fixos: o custo e MELHORAR ("nível 2: 4 leitos").
- **O cômodo:** a Enfermaria de 12 m, na captura do jogo: a Íris deitada no primeiro leito (a pose de dormir que já
  existe), a Lupa no posto junto do soro, o Bento de pé na cabeceira dela, e os leitos 3 e 4 esperando a melhoria.

**Caído (#118)**
- **O estado:** uma pílula nova do kit, na cor do perigo, com o glifo da recuperação. O texto é **"Caído"**, o mesmo para
  todos (a regra de 27/10),
  neutro de gênero, como "Em forma" e "Ferimento leve" (os heróis não têm gênero nos dados). "Caído" é o nome do
  estado e o ícone do evento (alguém deitado na maca), usado em "Íris caiu".
- **Fim de luta:** o popup do lote 5 ([hud-ajustes.md](hud-ajustes.md)) sobre a luta de verdade em que a Íris caiu
  ([capture.gd](hud-casa/capture.gd)), com a linha "Íris caiu" e "Volta à Estação com a equipe e se recupera na
  Enfermaria." logo abaixo das estrelas. No Último Fôlego, ela fica na arena, e a barra dela diz "Caído" (o nome do
  estado, como no lote 5), no lugar da vida.
- **Relatório:** na faixa, o destaque "Íris caiu · foi para a Enfermaria". A carta dela fica apagada (o véu das
  habilidades sem uso), com a pílula e, no lugar da relíquia, "Enfermaria · volta em 2 dias". Na plataforma, o lugar
  dela na fila fica vazio: ela desceu direto para a Enfermaria. Nos detalhes, "Quem caiu" com o trecho e os dias.
- **Sala:** a aba da Íris com o glifo da recuperação no canto do retrato. No painel PERSONAGEM, tudo o que a Sala tem
  hoje (o nível e o XP, a classe, a vida, a velocidade e o instinto, a relíquia, as expedições e os abates, os traços),
  mais a pílula, "Volta em 2 dias" e o motivo; TREINAR sai enquanto ela está no leito, e o Posto diz "Sem posto
  enquanto se recupera". O corpo dela aparece apagado e curvado na sombra.
- **Preparação:** na coluna "Fica na Estação", apagada, com "Caído · volta amanhã · não pode sair" e sem
  Trocar.

**Limites e postos (#119)**
- **Os limites** ficam na barra do alto da Estação, antes dos materiais: "Heróis 6 de 8" e "Ajudantes 3 de 4", cada um
  com o ícone. Na Sala, repetem embaixo das abas dos heróis. Na casa cheia, o número fica na cor de alerta.
- **Sala, a coluna da esquerda:** as Habilidades de hoje (a lista e o detalhe da escolhida) e, ao lado, a vista nova
  **Postos da Estação**, em dois chips de opção (o escolhido em âmbar). Nos Postos: a explicação dos limites (o
  Alojamento abre lugar para heróis, o Dormitório para ajudantes, e quem está em recuperação conta) e uma linha por
  posto (Enfermaria, Forja, Pesquisa, Cantina, Dormitório), com o ícone, quem está nele e o rendimento.
- **Sala, o campo Posto:** uma seção nova do painel PERSONAGEM, depois da vida e antes da relíquia: os postos como chips
  com o ícone (Nenhum, Pesquisa, Forja, Cantina, Dormitório, Enfermaria), o escolhido em âmbar; embaixo, o que ele rende
  ali ("Sapo cuida melhor: mais 1 dia a menos a cada duas voltas") e "Se entrar na equipe, sai do posto: a Preparação
  avisa." O painel rola, como hoje no Maior (veja os `_scrolled`).
- **Quem trabalha aqui (a Forja):** a Forja de nível 1, acesa, com o Brasa e o Otto lá dentro. No painel, um bloco por
  pessoa, herói ou ajudante (o Otto é "Ajudante · Castor, técnico", como em `station_rules.gd`), com o retrato, o
  rendimento e TIRAR, mais PÔR ALGUÉM ("1 lugar livre"). Embaixo, "Na próxima volta", os custos com o desconto.
- **Relatório, os detalhes:** a coluna "Os postos renderam", uma linha por posto, com quem ficou e o que rendeu (em
  verde). Na faixa, "Os postos renderam: veja os detalhes."
- **A Preparação avisa:** a carta de quem sai de um posto ganha uma aba no alto ("Sai do posto · Forja"), e a
  confirmação diz o que muda ("com só o Otto, a próxima obra passa de 4 para 5 sucatas").

**O trem (#122)**
- **Chegou alguém:** o trem parado na plataforma e quem desceu dele, de pé entre o trem e o banco. No painel, a carta:
  classe, de onde veio, o ponto forte e o ponto fraco, o que pede (um chip por opção, com o que se tem), "Heróis 6 de 8:
  cabe." e o aviso de que, sem decisão, ele vai embora no trem. ACEITAR (âmbar) e RECUSAR (de aço, sem tecla). IR AO
  MAPA fica bloqueado com o motivo.
- **A casa cheia:** o limite em alerta na barra e no painel ("Heróis 8 de 8: a casa está cheia. Para aceitar, abra
  lugar: melhore o Alojamento (10 lugares) ou dispense alguém."), e ACEITAR travado com o motivo. RECUSAR segue livre.
- **Voltou vazio:** o trem na plataforma sem ninguém, "O trem voltou vazio", a chance que sobe a cada volta vazia e os
  limites.

**A preparação (#123)**
- **Estação:** o botão principal vira **IR AO MAPA** (G / X), no lugar de PREPARAR EXPEDIÇÃO; com o foco do teclado nele,
  o Próximo passo explica a ordem nova: o lugar e a missão primeiro, a equipe depois, na plataforma. Sem cômodo
  escolhido, sem o cartão do cômodo.
- **Mapa:** o painel do lugar ganha **PREPARAR NESTE LUGAR** no pé. A plaqueta conta "Equipe: 5 prontos · 1 em
  recuperação" (dizia "4 vivos").
- **Plataforma:** a equipe de pé na plataforma, ao lado do trem, como na chegada da missão, com uma carta embaixo de
  cada um: o medalhão da posição, o retrato, o papel, o estado, a vida, TROCAR e a posição na formação (Frente, Meio,
  Fundo, com o ícone da troca). No alto, a faixa do lugar: o nome, a fase, o que o radar leu, o **Foco da rota** (a
  opção escolhida em âmbar) e a **Comida** (− e +). À direita, quem **fica na Estação**: quem está em posto (entra com
  Trocar e sai do posto) e quem não pode sair, apagado. Embaixo, VOLTAR AO MAPA e **INICIAR EXPEDIÇÃO**.
- **Confirmação:** "Iniciar expedição?" com o lugar, a equipe na ordem, o foco, a comida e o que muda nos postos; VOLTAR
  e INICIAR EXPEDIÇÃO. A tela de baixo fica sob o véu.

## Os fundos de before/

As telas da Estação com a Enfermaria e a Forja de nível 1 estão sobre capturas da Godot
([capture_infirmary.gd](hud-casa/capture_infirmary.gd), levadas para `before/` por
[prepare_infirmary.py](hud-casa/prepare_infirmary.py)):
- `station-infirmary_clean.webp`: a câmera do cômodo da Enfermaria no nível 1 (o painel);
- `station_day5_clean.webp`: a Visão geral na câmera da HUD, com a Enfermaria de 12 m e a Forja de nível 1 acesa (a
  Visão geral, IR AO MAPA e as telas do Dia 5);
- `station-forge-workers_clean.webp`: a câmera da Forja de nível 1, com o Brasa junto da bancada e o Otto no posto dele
  ("Quem trabalha aqui").

As montagens que o PR tinha para a Enfermaria e para a Forja (`build_room.py` e `build_forge.py`) saíram: a cena 3D
da Estação abre sem placa de vídeo, só que devagar (mais de um minuto por quadro).
[build_platform.py](hud-casa/build_platform.py) continua: a plataforma da chegada sem a Íris, com o Brasa no lugar
dela, e sem ninguém, com o trem à esquerda. Ela só tira e põe gente sobre a captura; o cenário e a luz são os da
captura.

## Ícones novos

Em `art/ui/kit/station/icons/`, glifos brancos de 64 px para tingir (`glyph_white_tintable` no manifesto
[assets.json](../../art/ui/kit/station/assets.json) e na cópia de [hud-station/assets.json](hud-station/assets.json)).
Gerados no Nano Banana Pro em folhas sobre magenta e recortados por [cut_art.py](hud-casa/cut_art.py), o mesmo recorte
dos traços: alfa direto, RGB branco onde há alfa. O Caído e o Amanhecer foram refeitos numa segunda folha, só com traço
branco grosso: na primeira, as pernas da maca e o horizonte eram traço preto, e o recorte (o alfa vem da luminância)
os perdia.

![Os glifos novos](hud-casa/glyphs.webp)

| Ícone | Uso |
|---|---|
| `state_fallen` | Caído: alguém deitado na maca de pernas em X ("Íris caiu", "Quem caiu") |
| `state_recovering` | Caído: o coração com o curativo (a pílula, a aba da Sala, "Volta em N dias") |
| `job_research`, `job_forge`, `job_canteen`, `job_dormitory`, `job_infirmary` | Um por posto: o livro com a lupa, a bigorna, a panela, o travesseiro com a lua e as mãos com o coração |
| `room_infirmary` | O cômodo Enfermaria (a etiqueta no corte, o painel, o Próximo passo) |
| `helpers` | Ajudantes (o avental), no limite da barra do alto |
| `inspect` | INSPECIONAR, para a #134 (o próximo PR) |
| `formation_swap` | A troca de posição na formação (a Preparação e, na #134, a exploração) |
| `dawn` | O amanhecer: o sol nascendo sobre o horizonte, para a #134 |

A prancha mostra cada glifo a 64, 32 e 22 px, tingido como o jogo faz; a prancha em cinza
([glyphs_gray](hud-casa/glyphs_gray.webp)) confere a leitura sem cor.

## O kit das maquetes (`hud-kit/lib.mjs`)

Duas mudanças que valem para as próximas maquetes (as telas já aprovadas não foram geradas de novo):
- **Os ícones pela ordem do jogo:** desde a #125 e a #135, o jogo usa, pelo nome antigo do ícone, o recurso pintado
  (sem tinta), depois o glifo do kit com o mesmo nome e só então o SVG antigo (`AHKit.painted` e `AHKit.legacy_icon`).
  O `glyph()` do `lib.mjs` faz o mesmo: as telas deste lote já mostram os recursos pintados.
- **Os lotes anteriores:** como as telas aprovadas deles não foram geradas de novo, o "Como refazer" de cada um não sai
  mais byte a byte com o `lib.mjs` de agora. Para refazer um deles igual, use o `lib.mjs` do commit dele
  (`git show <commit>:docs/design/hud-kit/lib.mjs`).
- **A borda da área que rola:** quando o painel rola, os últimos 44 px somem num esmaecido (no `_scrolled`, os
  primeiros): a linha pela metade não lê como texto cortado, e o esmaecido diz que há mais.

## Para integrar (é do Claude)

- **A Enfermaria:** o protótipo em [infirmary_proto.py](hud-casa/infirmary_proto.py) diz o que muda em
  `station_build.gd` e `station.gd`:
  - o cômodo de x −1840 a −640, a rocha das pontas até −2400 e `LEFT_END` em −18,4 m;
  - os móveis em `INFIRMARY_PIECES`, com as marcas de nível, e os leitos de quem deita em `INFIRMARY_BEDS`, com o colchão
    a 68 cm;
  - a regra nova de visibilidade "infirmary@=1", para a peça que só aparece no nível 1;
  - os dois pendentes de luz.

  Quem está no posto (#119) fica de pé junto do soro. A Visão geral fica um pouco menor, porque a Estação ganhou 6 m à
  esquerda no subsolo 2.
- **A queda na luta:** no Último Fôlego, quem não tem a pose de caída (a Íris, os recrutas) fica de pé na arena, e só a
  barra diz "Caído". Vale pedir a pose de caída desses heróis, ou apagar o desenho de quem caiu.
- **O estado:** `status_pill` ganha o estado `recovering` (tinta de perigo, o glifo `state_recovering`, o texto
  "Caído"), nas duas tintas (normal e daltonismo).
- **Os dias:** "Volta em N dias" conta voltas (cada expedição é um dia, como o "Dia 5" da barra). Os números são os
  de `data/recovery.json`: 2 dias no leito da Enfermaria, 3 no Dormitório; o curativo tira um dia e o posto da
  Enfermaria (#119) tira outro.
- **Os limites:** a ficha "Heróis N de M · Ajudantes N de M" vai na barra do alto de todas as telas da Estação; o
  Alojamento hoje tem `max_level 1`, e o segundo nível (10 lugares) é proposta da #119.
- **Os postos:** o rendimento por espécie e traço fica em `data/` (a Sala mostra o texto que vem de lá).
- **A Sala:** a coluna da esquerda ganha a vista Postos da Estação ao lado das Habilidades, e o painel PERSONAGEM, a
  seção Posto; nada do que ela tem hoje sai.
- **O botão principal:** IR AO MAPA substitui PREPARAR EXPEDIÇÃO; a Preparação sai da Estação e vai para a plataforma,
  aberta pelo PREPARAR NESTE LUGAR do Mapa. INICIAR EXPEDIÇÃO pede confirmação.

## Como refazer

As imagens brutas ficam fora do Git, em `images/hud-casa/` do projeto na Awesomic: `infirmary-props-sheet-2.png` (os seis
móveis), `casa-glyphs-sheet.png` (os doze glifos), `casa-glyphs-sheet-3.png` (o Caído e o Amanhecer refeitos), `infirmary-bed-broken-covered-2.png` (os leitos que esperam a
melhoria) e
`ref-cards.png` (a referência dos cards de hoje que foi junto no pedido ao Nano Banana Pro).

Da raiz do repositório:
1. `python3 -B docs/design/hud-casa/cut_art.py <infirmary-props-sheet-2.png> <casa-glyphs-sheet.png> <casa-glyphs-sheet-3.png> <infirmary-bed-broken-covered-2.png>`:
   os cards e os glifos (a quarta folha é a dos leitos que esperam a melhoria, uma edição do `Infirmary_Bed`).
2. A Estação na Godot (precisa de uma tela; no Linux sem tela, Xvfb; sem placa de vídeo, a captura leva perto de uma
   hora): `python3 -B docs/design/hud-casa/infirmary_proto.py <pasta>/proto.zip` e
   `"$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://docs/design/hud-casa/capture_infirmary.gd -- --out=<pasta> --pack=<pasta>/proto.zip --views=room,clean,hud,forge`.
   Depois, `python3 -B docs/design/hud-casa/prepare_infirmary.py <pasta> <montagem antiga.webp>` (a montagem antiga
   sai de `git show 05a6b3c:docs/design/hud-casa/before/station-infirmary_clean.webp`). Por fim,
   `python3 -B docs/design/hud-casa/build_platform.py`: as montagens da plataforma.
3. A luta com a Íris caída (precisa de uma tela; no Linux sem tela, `xvfb-run`):
   `xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://docs/design/hud-casa/capture.gd -- --out=<pasta>`.
   Ela grava `fight_fallen.png` (sem a HUD) e `fight_fallen.json` em `<pasta>`; o PNG vai para `before/` convertido em
   WebP (qualidade 88), com o nome `fight_fallen_clean.webp`, e o JSON é copiado. A luta corre no automático e não sai
   igual a cada vez (a semente que derruba a Íris pode mudar): a de `before/` saiu na `main` com a #125 e a #135, na
   semente 6464. No Último Fôlego, a Íris fica na arena, de pé (ela não tem a pose de caída), e a barra dela diz "Caído".
4. `python3 -m http.server 8765 --bind 127.0.0.1` e, noutro terminal, `node docs/design/hud-casa/render.mjs http://127.0.0.1:8765`.
5. `python3 -B docs/design/hud-casa/compose.py` (as reduções, o cinza, o antes e depois e o `checks.json`) e
   `python3 -B docs/design/hud-casa/art_sheet.py` (as pranchas dos cards e dos glifos).

A pasta `.render/` é temporária e fica fora do Git.

## QA de design

As rodadas seguem [qa.md](qa.md) e ficam registradas abaixo e no PR.

### Rodada 1: REPROVADO

Aprovados na rodada: o escopo, a reprodução byte a byte, o `checks.json`, os cards, o lugar da Enfermaria e a cobertura
do pedido. Antes desta rodada, o branch foi refeito sobre a `main` com a #125 e a #135.

**Média, corrigidos:**
- O Caído e o Amanhecer perdiam partes no recorte: refeitos numa folha nova, só com traço branco grosso, e centrados.
- Os números com `data/`: a Lupa com 23 de vida, o Brasa com 34, a relíquia com 3 → 2 sucatas (o desconto do Otto vale
  só para obras), o Otto como "Castor, técnico".
- O tempo entre as telas: a volta é o Dia 4 e a preparação, o Dia 5 (veja "Os dias e os números"); o Nick com 17/24 e
  Ferimento leve na plataforma, a Íris "volta amanhã" na plataforma, 4 dias no Dormitório sem a Enfermaria.
- A Sala volta a ter tudo o que tem hoje: as Habilidades (com a vista Postos da Estação ao lado), o nível e o XP,
  TREINAR, a velocidade e o instinto, a relíquia, as expedições e os abates e os traços.
- A Forja com quem trabalha nela: a montagem da Forja de nível 1, acesa, com o Brasa e o Otto.
- As telas do trem mostram o trem: a plataforma da chegada, com o trem à esquerda.

**Baixa, corrigidos:**
- O armário (150 cm de altura) e o soro (171) na altura dos heróis; o biombo com 152; o colchão a cerca de 68 cm.
- A linha cortada pela borda da área que rola: o esmaecido no `lib.mjs`, e "Volta em 2 dias" subiu para o alto do bloco
  do leito.
- O papel nas cartas da plataforma (o Brasa, "Tanque e Proteção", como o Bento); "Herói · Cão Protetor" na Forja.
- IR AO MAPA sem o cartão da Enfermaria e com o texto sem redundância.
- O popup sem "Ninguém morre." (fala de design): "se recupera na Enfermaria".
- O `capture.gd` sem as opções de outro lote. Rodado de novo na `main` de hoje, ele deu outra luta (a semente que
  derruba a Íris mudou, e ela agora fica na arena no Último Fôlego): a captura de `before/` é a nova, e a página diz que
  a luta não sai igual a cada vez.
- A prancha dos glifos a 22 e 32 px.
- A próxima obra é a Forja no nível 2 (o Bar não tem custo em `station_rules.gd`), no painel e no relatório.

### Rodada 2: APROVADO

As seis correções Médias conferidas nas telas e nos números; "Como refazer" reproduz byte a byte (as montagens, as
telas e as provas); o escopo e os manifestos conferem. Observações baixas, aplicadas depois do veredito:
- a Comida do Dia 5 seguia uma conta incompleta (6/12): agora 4/12, pela conta de `AHStationRules.forecast` (os civis
  também comem);
- a Forja aparecia apagada na Visão geral do Dia 5: agora acesa, com o Brasa e o Otto (`station_day5_clean.webp`);
- a próxima obra da Forja diz também os 2 fragmentos;
- "Para integrar" ganhou a nota da pose de caída, e "O kit das maquetes", a dos lotes anteriores.
