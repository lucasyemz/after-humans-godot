# Roupas confortáveis do lobby — proposta #243

**Aguardando a aprovação visual do Lucas. Não integrar nem produzir poses.**

A pedido do Lucas em 28/10/2026, o estudo de paletas foi cancelado (#242, #239 e PR #240). Esta proposta muda o
vestuário para a vida na Estação: tecido leve, lavado, remendos discretos e poucos acessórios. XCOM 2 é referência
para a separação entre roupa de descanso e equipamento de missão; os desenhos são próprios do After Humans.

## Fundadores

Da esquerda para a direita: **Bento, Nick, Íris e Véspera**.

Roupa original para comparação (arte canônica, não captura de jogo):

![Fundadores com roupa original](lobby_outfits/founders_originals.webp)

![Conceitos dos quatro fundadores com roupas confortáveis](lobby_outfits/founders.webp)

| Personagem | Roupa proposta | Identidade preservada |
| --- | --- | --- |
| Bento | Camisa oliva leve aberta, camiseta clara, calça marrom folgada e calçado baixo | Cabeça, peito branco, pelagem preta e branca e cauda; sem o punho equipado |
| Nick | Camiseta carvão com botões, calça confortável e pequeno lenço vermelho | Pelagem cinza, olhos verdes, cauda e lenço; sem lâminas, ombreiras e cintos de carga |
| Íris | Blusa verde-sálvia sem mangas e calça curta de tecido | Pele amarela e azul, mãos e pés anfíbios; sem capuz, capa, tubos e frascos |
| Véspera | Colete cruzado de tecido cru sobre blusa escura e calça curta | Disco facial, penas naturais e garras; sem rifle, binóculos e capa de equipamento |

As duas corujas têm **braços articulados, cotovelos, antebraços, punhos e mãos com dedos**, como nas artes
originais. As penas naturais cobrem ombros e braços, sem substituir as mãos por asas fechadas nem escondê-las.
A roupa do lobby não usa luvas; as duas mãos devem aparecer livres ao lado do corpo. Não acrescentar outro par
de asas ou membros. A capa de equipamento da expedição sai, a anatomia fica. O punho de sucata do Bento foi tratado aqui
como equipamento retirado; a aprovação visual inclui confirmar essa leitura antes de desenhar as mãos nas poses.

## Recrutas

Uma roupa por tipo de recruta, mantendo o desenho aprovado. A proposta não reabre o seletor de cores.

Da esquerda para a direita: **cão, gato, sapo e coruja**.

![Recrutas com roupa original](lobby_outfits/recruits_originals.webp)

![Conceitos dos quatro recrutas](lobby_outfits/recruits.webp)

**Guaxinim e Tatu**, usando como referência o redesenho aprovado na #225, não os corpos antigos mais horizontais.

![Guaxinim e Tatu com roupa original aprovada](lobby_outfits/raccoon_armadillo_originals.webp)

![Conceitos do Guaxinim e do Tatu](lobby_outfits/raccoon_armadillo.webp)

| Tipo | Roupa proposta |
| --- | --- |
| Cão | Camisa azul desbotada, calça marrom confortável e calçado leve |
| Gato | Camiseta de botões cor de tecido cru, calça carvão e calçado leve |
| Sapo | Camisa ferrugem leve, calça curta clara e pés livres |
| Coruja | Colete azul-acinzentado sobre camisa clara, calça curta e garras livres |
| Guaxinim | Camisa oliva de manga dobrada e calça marrom simples; sem rádio, ferramentas e mochila |
| Tatu | Camisa ocre desbotada e calça carvão; sem escudo, martelo e armadura pintada. Escamas naturais ficam |

Não estão incluídos novos figurinos de mercador, civis ou inimigos. Não há novas variações de pelagem nem novas
opções de personalização neste pacote.

## Quando vestir cada roupa

| Situação | Vestuário |
| --- | --- |
| Morador no lobby/Estação, depois da chegada | Confortável |
| Ação **Ver personagem** | Original de expedição |
| Preparação e saída para expedição | Original de expedição |
| Chegada de expedição | Ainda original; só depois troca para confortável |
| Exploração, luta e acampamento fora da Estação | Original de expedição |

A troca de roupa é uma regra de apresentação futura, não uma substituição da skin de missão salva. A integração
deverá manter a escolha original de expedição e evitar exibir roupa confortável na ficha **Ver personagem**.
Nenhuma dessas trocas foi implementada por esta entrega.

## Poses: somente depois da aprovação

Leitura da main `5bb29281`: `scripts/station/station.gd` usa o idle para moradores andando/parados, `seat` na Cantina,
`sleep` no Dormitório/recuperação e `work` nos postos específicos dos fundadores. Não existe necessidade comprovada
de gerar uma sequência de caminhada só para esta skin.

Depois que Lucas aprovar cada roupa, levantar a cobertura real por personagem e sala, reaproveitando apenas os
encaixes necessários. O lobby usa âncoras diferentes por pose; não copiar a âncora do idle para sentado ou deitado.
Não fazer ataques, habilidade, combate, item ou acampamento de expedição para estas roupas.

## Formato e limites desta etapa

As três pranchas são **conceitos com fundo**, não sprites com alfa. A postura de pé serve apenas para comparar
figurinos; não é um novo idle pronto para o jogo. A escala entre figuras é ilustrativa: não usar a prancha para
extrair âncoras ou calcular alturas. As proporções e a escala finais serão conferidas com os corpos canônicos.

As imagens não contêm nomes nem textos gravados. Os nomes e decisões ficam nesta página. Há reduções reais a 40%
e em cinza para conferir a separação das silhuetas sem depender de cores. Tamanhos e hashes estão em
[assets.json](lobby_outfits/assets.json).

Como esta etapa está explicitamente bloqueada antes das poses, não há sprites recortados, margens de 9-slice,
âncoras novas ou captura de troca de roupa dentro da Godot. Não se apresenta uma montagem como prova de integração.
O antes/depois no jogo será exigido no pacote de poses após a aprovação, na mesma câmera e na mesma escala.

## QA de conceito

A QA aplica [qa.md](qa.md) ao escopo de aprovação de figurino. Não aprova integração, alfa ou âncoras que ainda
não foram produzidos. O aceite artístico do Lucas permanece pendente mesmo com a conferência técnica concluída.

### Rodada 1 — VEREDITO: REPROVADO

- **Média, fundadores:** o primeiro conceito da Íris tinha pontas e cordas demais; o Nick ainda tinha faixas de
  equipamento nos punhos. Corrigidos para blusa curta simples e braços livres.
- **Média, corujas:** a silhueta de penas ainda parecia uma capa longa. Reduzida para braços/alas compactos, sem a
  capa de expedição. As penas naturais continuam.
- **Média, recrutas:** luvas do gato, faixas do cão e costuras decorativas excessivas deixavam a roupa carregada.
  Removidos; mantidos apenas remendos pontuais e costuras de construção.

### Rodada 2 — APROVADO inicial, superado pela revisão do Lucas

A revisão inicial conferiu roupas, leitura reduzida e escopo, mas deixou passar um erro de anatomia nas duas
corujas: as penas escondiam os braços e as mãos. Lucas identificou o problema; o aceite inicial não vale para
aquelas imagens.

Observações para a próxima etapa: confirmar a mão sem o punho do Bento;
normalizar alturas com as referências; não copiar das pranchas uma anatomia ou âncora nova. O Guaxinim ainda
usa um pequeno pano nos tornozelos; Lucas pode pedir sua remoção junto com os ajustes do figurino.

### Rodada 3 — VEREDITO: REPROVADO (correção solicitada pelo Lucas)

- **Alta, `founders.webp` e `recruits.webp`:** Véspera e a coruja recruta não mostravam braços/mãos articulados
  como os originais. As penas foram tratadas como asas fechadas. Correção: restaurar dois braços com cotovelos,
  antebraços e mãos visíveis, sem luvas ou equipamento pesado. Usar também a Véspera trabalhando com livro
  (`art/station/poses/hero_coruja_vespera_work.webp`) como referência de articulação.

### Rodada 4 — VEREDITO: APROVADO para revisão de figurino

Conferidas novamente as duas corujas com os originais e com a Véspera segurando o livro: dois braços com
cotovelos/antebraços e duas mãos visíveis, sem os painéis de penas que os escondiam. As mãos continuam legíveis
a 40% e em cinza. Figurinos e identidades dos demais personagens mantidos. Sem problemas altos ou médios no
escopo do conceito; a aprovação artística do Lucas continua pendente.

A correção continua restrita ao figurino ilustrado de pé. Não há novas poses de produção.

A entrega não modifica código nem arte de produção. A suíte completa já passou na mesma base `5bb29281`
(92/92, incluindo paridade 48/48); não foi repetida para estes documentos. As imagens, hashes e dimensões
foram verificados separadamente.

## Fontes e pranchas pequenas

As três imagens PNG de conceito ficam fora da main, na tag `codex-pr244-originals-r2`, pasta
`art/combat/source/lobby_outfits_20261028/`: [Release](https://github.com/lucasyemz/after-humans-godot/releases/tag/codex-pr244-originals-r2) e
[ZIP](https://github.com/lucasyemz/after-humans-godot/archive/refs/tags/codex-pr244-originals-r2.zip). Nenhum desses PNG é origem
pronta para conversão direta em pose do jogo. A tag anterior `codex-pr244-originals` permanece como histórico;
esta revisão a substitui para a avaliação das roupas.

| Grupo | 40% | Cinza a 40% |
| --- | --- | --- |
| Fundadores | [Cor](lobby_outfits/founders_40.webp) | [Cinza](lobby_outfits/founders_gray_40.webp) |
| Recrutas | [Cor](lobby_outfits/recruits_40.webp) | [Cinza](lobby_outfits/recruits_gray_40.webp) |
| Guaxinim/Tatu | [Cor](lobby_outfits/raccoon_armadillo_40.webp) | [Cinza](lobby_outfits/raccoon_armadillo_gray_40.webp) |
