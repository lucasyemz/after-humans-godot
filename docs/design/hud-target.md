# HUD da luta — alvo aprovado de25/10/2026

**Referência atual do kit de combate:** o [alvo do Lucas](reference/hud-target-2026-10-25.webp), conforme o topo de [hud-direction.md](hud-direction.md). Ele substitui a aparência ornamentada da C. Esta entrega mantém sua estrutura sobre uma captura real, com aço grafite chanfrado, detalhe âmbar e Barlow Condensed Medium em caixa alta, com SemiBold no nome do herói.

**[Alvo e entrega lado a lado — Normal](hud-target/comparison.webp)** · **[Maior](hud-target/comparison_large.webp)** · **[Daltonismo](hud-target/comparison_colorblind.webp)** · **[Maior+daltonismo](hud-target/comparison_large_colorblind.webp)**

**[Antes e depois deste refinamento](hud-target/detail_before_after.webp)** · **[Detalhes: alvo × antes × refinamento](hud-target/detail_comparison.webp)**

![Entrega Normal](hud-target/hud.webp)

**[Luz, retrato e alinhamento — antes/depois](hud-target/light_alignment.webp)**

**[QA visual: dez peças lado a lado nos perfis](hud-target/piece_comparison.webp)** · [Tela Maior+daltonismo](hud-target/hud_large_colorblind.webp) · [Margens/âncoras do kit](hud-target/assets.json) · [Verificação](hud-target/verification.json).

## Estrutura reproduzida

| Peça do alvo | Entrega |
|---|---|
| Aço escuro arranhado, chanfros e detalhe âmbar | Biséis derivados do próprio alvo, conteúdo removido e miolos de aço preparados separadamente. Sem latão, voltas ornamentais ou medalhões. |
| Letra condensada, sem serifa e em caixa alta | Barlow Condensed Medium (rótulos) e SemiBold (nome do herói), ambas OFL. |
| Registro com L em aba | Peça chanfrada272×64 no alto à esquerda, com tecla em aba42. |
| Rodada numa faixa única | Faixa720×64, nome da rodada, linha/ponto e seis retratos quadrados64, coloridos; fundo avermelhado nas máquinas e borda âmbar no ator atual. |
| Vida sob as unidades | Barras200×44, ciano nos heróis e vermelho nos inimigos, valor dentro e bisel espesso com rebaixo. Sem número da posição. Aba superior nos heróis, recorte na borda dos inimigos. |
| Ator no chão | Anel âmbar com setas, centrado nos pés de Nick; cantos âmbar na barra dele. |
| Nome do alvo | Plaqueta pequena, escura, com linha vermelha embaixo. |
| Painel único do herói | Uma silhueta conectada564×212 com retrato quadrado grande, nome, Vida e Instinto encaixados. Não são peças soltas. |
| Habilidade e quatro ícones | Aba "ESCOLHA UM ALVO", barra com ícone/nome e célula4–6 à direita; quatro slots132×132, artes vivas e tecla na aba inferior direita; selecionada com cantos âmbar. |
| Ações | Grade2×2 de peças chanfradas, ícone branco e tecla em aba. **F usa porta com seta de saída**, não a mira do desenho de referência. |

A quarta habilidade permanece atenuada porque o quote real indica **Sem alvo válido** para Caçada Precisa. Os arquivos dos quatro ícones do Nick não foram alterados ou redesenhados. O campo4–6 conserva a faixa do alvo; na regra atual é a faixa de dano da habilidade, não as posições de alcance.

## Kit WebP e9-slice

Peças em `art/ui/kit/combat/`. **18 WebP**:17 RGBA e um material RGB repetível. O [assets.json do pacote](../../art/ui/kit/combat/assets.json) é espelhado automaticamente em [hud-target/assets.json](hud-target/assets.json). São a mesma fonte de dimensões, conteúdo, âncora, hashes e `nine_slice_ltrb` na ordem **esquerda/cima/direita/baixo**. No Godot, usar essas margens nas `texture_margin_*` do StyleBoxTexture.

| Peça | Canvas | Margens9-slice |
|---|---|---|
| `panel.webp` |256×80|24/24/24/24|
| `register.webp` |272×64|24/20/24/20|
| `round_strip.webp` |720×72|24/16/24/16|
| `square_portrait.webp` |72×72|8/8/8/8|
| `hero_panel.webp` |564×212|224/24/24/24; manter altura212 e preservar coluna do retrato|
| `ability_header.webp` |624×56|20/12/20/12|
| `target_tab.webp` |336×40|16/12/16/12|
| `action_button.webp` |128×100|14/14/14/14|
| `key_tab.webp` |42×42|6/6/6/6|
| `ability_slot.webp` |132×132|16/16/16/16|
| `health_ally.webp`, `health_enemy.webp` |200×44|20/12/20/12|
| `main_bar.webp` |320×44|12/10/12/10|
| `selected_slot.webp` |132×132|28/28/28/28|
| `active_health.webp` |200×44|28/12/28/12|
| `actor_ring.webp` |256×80|Não fatiar: elipse de perspectiva, âncora128,40|
| `exit.webp` |64×64|Não fatiar: símbolo, âncora32,32|
| `steel_material.webp` |512×512|Repetir material; não é uma moldura|

Não há nomes, números, retratos ou ícones de habilidade embutidos nessas molduras. Textos, fotografias, preenchimento de Vida e separação da célula4–6 são conteúdo do componente. Os overlays de escolha/ator são camadas separadas, não uma alteração dos dados. Os PNG mestres de material e anel ficam fora do Git; as referências já aprovadas permanecem intactas.

## Fonte e texto Maior

Fontes: [Barlow Condensed Medium](../../art/ui/fonts/barlow_condensed_medium.ttf), para rótulos e valores, e [SemiBold](../../art/ui/fonts/barlow_condensed_semibold.ttf), para o nome do herói. [Licença SIL OFL1.1](../../art/ui/fonts/OFL-BarlowCondensed.txt), copyright The Barlow Project Authors; origem oficial [Google Fonts](https://github.com/google/fonts/tree/main/ofl/barlowcondensed). O binário da fonte não foi modificado; o texto integral da licença foi preservado, normalizando apenas espaços finais. Família, caminho e SHA estão no manifesto.

| Uso | Normal | Maior |
|---|---|---|
| Registro e rodada |30|39|
| Nome do herói |40|52|
| Nome da habilidade e números do painel principal |32|42|
| Barras no mundo |24|31|
| Aba do alvo, nome do inimigo e teclas |26|34|
| Campo4–6 |28|36|

Maior usa130%, sem encolher texto ou cortar letras. As caixas de valores do herói têm32 de altura para comportar a fonte42. As posições e a estrutura permanecem iguais nos quatro perfis. [checks.json](hud-target/checks.json) guarda cada caixa de texto e seu resultado medido. O texto do alvo é condensado, não Cinzel nem a Jakarta da versão anterior.

## Cores e daltonismo

Normal: aço `#1b1d20`–`#25282c`, bisel grafite, detalhe/foco `#f0a020`, Vida dos heróis `#2fb6bd`, Vida das máquinas `#d23a2e`, texto `#efe6d6`. O material preserva os riscos e o desgaste dos biséis, sem ouro limpo ou cobre ornamental.

Daltonismo: heróis `#56b4e9`, inimigos no vermelhão `#d55e00` (decisão do Lucas, 25/10: o laranja `#e69f00` se confundia com o âmbar do foco); a linha do nome do alvo acompanha a cor inimiga. A forma também muda: **aba no herói e recorte no inimigo**, preservados em cinza, além do lado, do corpo e do valor. O anel e as marcas de turno continuam âmbar; não dependem da cor da Vida para identificar quem age. As artes originais não são recoloridas.

Há [prova de saída em22/32/48 sobre claro/escuro](hud-target/readability.webp), [cinza](hud-target/hud_gray.webp) e versões `_40.webp` dos quatro perfis (768×432). São provas do desenho; navegação, safe area e toque precisam da QA na implementação.

## Geometria e alvos de interação

Base1920×1080. O arquivo aprovado1672×941 é normalizado a essa base **somente para comparar**; a captura real já tem1920×1080. Não se reconstituiu o cenário nem se redesenhou o corpo dos personagens.

| Região | Retângulo da entrega (x,y,w,h) |
|---|---|
| Registro |46,32,272,64|
| Rodada |636,30,720,64|
| Herói |64,836,564,212; imagem quadrada184 dentro da coluna208|
| Aba "Escolha um alvo" |856,816,336,40|
| Barra da habilidade |684,852,624,56; ícone40; divisão direita em x1192|
| Quatro ícones |688+i×160,916,132,132; conteúdo116, teclas42 na aba inferior direita, em x+90,y+90|
| Grade2×2 |1584+coluna×136,836+linha×112,128,100|
| Vida sob a unidade |centro projetado−100,760,200,44|
| Nome do alvo |1280,348,176,56; linha vermelha inferior|
| Anel |248×64, centro nos pés de Nick; na imagem, máscara alfa oculta partes atrás do corpo, botas e cauda|

[Diferenças geométricas para as medidas aproximadas da especificação](hud-target/target_comparison.json): painéis ficam próximos do alvo, sem mudar sua organização. A grade termina em1848,1048; seu topo fica11px acima da medida aproximada. O passo vertical112 permite alvos de toque112 de altura sem sobreposição. A faixa da rodada agora tem64px de altura, como o alvo; imagens60px dentro das células64px.

Na integração: ancorar o rodapé à área segura e escalar uniformemente, sem achatar chanfros. Registro tem alvo272×112; ações128×112; habilidades140×140 incluindo as abas. O retrato abre a inspeção do ator. Os pequenos retratos da ordem são informativos; não criar alvos de toque sobrepostos sobre eles. Não trocar bindings: `combat_log`, `combat_move`, `combat_defend`, `inventory`, `combat_flee`, `combat_ability_1..4`. As teclas mostradas são os defaults atuais, não teclas fixas no código.

Teclado e controle mantêm os bindings existentes e navegação por foco; apontar ou focar não confirma uma ação. A seleção persistente usa cantos âmbar grossos; foco de navegação acrescenta um contorno interno claro, independente da seleção. Pressionado desloca somente o desenho2px, sem mover o hitbox. Bloqueados continuam explicáveis por wrapper de foco, sem disparar o comando; os motivos vêm da sessão. Reduzir efeitos mantém anel e marcas estáticos, sem pulso. Em toque, a aba com a tecla faz parte do controle maior, e a descrição não pode depender só de hover. Usos/recarga aparecem em pequenas abas do mesmo idioma quando existirem; não mostrar contador0 para usos ilimitados. Reutilizar as inspeções e o Registro já existentes, sem perder seu conteúdo.

O anel deve ser um decal/plano **sob** a unidade, com oclusão/depth test e acompanhamento do ator real. A máscara acompanha o alfa do sprite completo, incluindo botas e cauda, na composição congelada. Não pintar o anel sobre os pés. A mesma informação aparece na barra e no retrato da rodada.

## Conteúdo dinâmico e diferenças deliberadas

O objetivo é reproduzir a **HUD**, sem transformar a arte da referência em regra de jogo. A captura real vem de [loop-screens/before/combat_clean.webp](loop-screens/before/combat_clean.webp), com os [DTOs](loop-screens/before/combat.json) e os quotes de sessão já documentados. Fonte/hashes dos dois lados estão no manifesto e em `checks.json`.

- **Nick age na sessão real e é o primeiro da ordem capturada.** O desenho do alvo põe o destaque em outro índice; não se duplicaram retratos ou mudou a iniciativa para imitar o desenho.
- Corpos, roupas, retratos canônicos e ícones são os do jogo. A referência tem diferenças de ilustração; elas não são um pedido para redesenhar os fundadores ou substituir os ícones reservados do Nick.
- Retratos inimigos vêm de recortes dos sprites originais, convertendo coordenadas do canvas original para a resolução física da textura. Não usar pixels do canvas1178 como se a textura reduzida também tivesse1178.
- **F é saída**, diferença exigida explicitamente pela especificação; a mira da imagem não foi copiada.
- Vida30/30,23/23,24/24,34/34 e8/8,6/6 permanecem iguais nos quatro perfis. Sem posição sobre a barra. `usable`, motivo, usos, alvos e dano efetivo devem vir de `AHCombatSession`, incluindo pesquisa e recarga, sem copiar a aproximação de um mockup.

## QA de design — alvo peça por peça

Usado o [checklist](qa.md) com prioridade ao alvo atual, que substitui a paleta/serifa ornamentadas anteriores.

### Rodada1 — VEREDITO: REPROVADO

- **Alta — números do herói no Maior:** caixas de28 não comportavam os glifos da fonte42. Aumentadas para32; fonte mantida.
- **Média — acabamento das molduras:** a primeira reconstrução tinha contornos excessivamente simples e marcas âmbar grandes. Preparados biséis a partir do próprio alvo e miolos de material limpos, preservando suas bordas gastas.

### Rodada2 — VEREDITO: REPROVADO

- **Alta — retratos inimigos:** recortes em coordenadas originais aplicados à textura reduzida deixavam as células vazias. Convertidos por `texture_size/canvas_size` e adicionada a conferência de alfa não vazio.
- **Média — anel:** pouco visível junto às botas e à barra. Ampliado para248×64, reforçado o halo e mantida a oclusão dos pés.

### Rodada3 — VEREDITO: APROVADO

Conferida a matriz **alvo × Normal × Maior × Maior+daltonismo**, nas dez peças: material/Registro, faixa da rodada, Vida dos heróis, Vida dos inimigos, nome do alvo, painel único, habilidades, ações, anel e F. A estrutura e o idioma do alvo estão mantidos. As exceções são as exigidas/documentadas: F de saída, retratos canônicos e ordem real do combate.

Aço/chanfros e detalhe âmbar conferidos; sem ornamentação de latão ou serifa. Retratos quadrados não vazios, cor das máquinas, faixa única, retrato grande encaixado, ícones vivos, selecionado âmbar, teclas em abas e anel junto aos pés. Sem posição nas barras. Normal usa ciano/vermelho; daltonismo usa azul/laranja com as formas de origem preservadas.

Auditoria:18 WebP nas dimensões declaradas, margens9-slice válidas, fonte OFL com checksum, quatro perfis sem texto fora de suas caixas e **zero alvos interativos sobrepostos**. Verificados os hashes dos quatro ícones originais do Nick. Redução real a40%, cinza e saída22/32 conferidos. Nenhum problema alto ou médio pendente na entrega de design. Navegação, touch/safe area e oclusão dinâmica precisam ser testadas pelo Claude na integração.

**Godot4.7.2 na base atualizada da main:** importação concluída,46/46 testes em256,681s, paridade48/48 (3351 passos), saída0. Persistem avisos de recursos/RID/ObjectDB no encerramento. Não são falhas do verificador de design.

### Rodada4 — VEREDITO: APROVADO

Observação baixa na ampliação da matriz: o bisel de Vida perdia leitura junto ao piso escuro. Reforçado o contorno metálico seguindo o polígono da aba e do recorte, sem mudar medidas, cores, conteúdo ou9-slice. Matriz e quatro perfis regenerados; alfas, importação e auditoria estática conferidos novamente. Continua sem problema alto ou médio pendente.

## Reprodução e escopo

`python docs/design/hud-target/build_assets.py` prepara as peças e os dois manifestos idênticos; o material WebP versionado dispensa o mestre PNG externo. A base sem texto da Vida está em `health_source.webp`; o anel gerado foi normalizado em `ring_source.webp`, sem texto e com alfa, para reprodução; o mestre PNG permanece fora do Git. A base sem texto da Vida está em `health_source.webp`; o anel gerado foi normalizado em `ring_source.webp`, sem texto e com alfa, para reprodução; o mestre PNG permanece fora do Git. `render.py` monta os quatro perfis e as quatro comparações completas. `compare.py` gera a matriz peça por peça; `verify.py` confere9-slice, fonte/OFL, limites, alvos, quatro ícones originais e hashes. Dependências: Pillow, numpy e CairoSVG.

Entrega de design/arte para integração do Claude na #60; sem alterações próprias em `scripts/`, `data/` ou `tests/`. O merge da `main` foi feito antes do trabalho e trouxe o trabalho do Claude; essas mudanças não são alterações do designer. Não foram refeitas as outras telas da #96 nesta rodada. O novo idioma fica disponível para elas, conforme a direção aprovada.

## Novo ciclo de QA — refinamento dos detalhes (25/10/2026)

Pedido: aproximar ainda mais do alvo, mantendo a HUD aprovada. Foram refinados a espessura da letra, recortes dos rostos, biséis específicos de retratos e ações, teclas42px com chanfro pequeno, textura menos contrastada e cantos de seleção com núcleo claro. A faixa diminuiu de72 para64px. O anel agora tem núcleo quente, halo e setas, com o PNG mestre fora do repositório. Os quatro ícones canônicos do Nick continuam intactos.

### Rodada1 — VEREDITO: REPROVADO

- **Média — `health_ally.webp` e `health_enemy.webp`:** o preenchimento de limpeza enfraqueceu o bisel; a sobreposição do contorno também podia apagar a diferença de silhueta. Sugestão: redesenhar o bisel seguindo o polígono próprio de cada facção e aplicar a máscara de alfa por último. Corrigido: aba superior aliada e corte inferior inimigo preservados em todos os perfis.
- **Média — `actor_ring.webp`:** a linha vetorial anterior era apagada e uniforme perto do alvo luminoso. Substituída por arte com núcleo claro e bloom âmbar, mantendo a oclusão das botas e o centro projetado do ator.
- **Baixa — documentação:** medidas antigas de teclas, rodada e margens corrigidas para os manifestos atuais.

### Rodada2 — VEREDITO: APROVADO

Revisão visual na matriz das dez peças e na prancha de detalhes alvo/antes/depois: Registro, rodada, Vida de cada facção, placa do alvo, painel único, barra da habilidade, slots, ações, anel e saída. Conferidos Normal, Maior130%, daltonismo, combinação dos dois, cinza e redução real40%. Textos sem extravasar; contornos e silhuetas preservam a informação sem depender só de cor. Saída legível22/32/48px. Sem lettering nos WebP reutilizáveis, sem alteração dos quatro ícones originais, sem mudança em scripts/data/tests. Nenhum problema alto ou médio pendente na entrega.

A arte canônica dos personagens e a ordem da sessão real continuam diferentes da ilustração do alvo; esta rodada aproxima a construção das peças. A integração e a navegação dentro do jogo seguem com o Claude na #60.

Validação deste refinamento: Godot4.7.2, importação concluída; **46/46 testes em257,438s**, paridade48/48 (3351 passos), saída0. Permanecem avisos/erros de recursos/RID/ObjectDB no encerramento do runner. Auditoria dos quatro perfis,18 WebP, OFL, margens, hashes e limites aprovada; diff --check limpo.

## Cor, volume, enquadramento e luz — revisão solicitada

[Comparação alvo × antes × agora](hud-target/detail_comparison.webp) · [Antes/depois completo](hud-target/detail_before_after.webp) · [Detalhes de luz e alinhamento](hud-target/light_alignment.webp). O antes desta revisão é o commit2ce2f7a.

### O que faz as cores parecerem mais vivas

A referência tem separação maior entre o fundo preto-azulado das peças e os reflexos claros dos biséis. O piso junto da HUD é menos claro, o preenchimento ciano tem uma faixa clara superior e uma base mais escura, e o âmbar tem núcleo claro, halo e luz de retorno no chão. São diferenças de contraste, material e iluminação local; aumentar saturação global também estouraria os tijolos e as luzes. Os retratos e corpos canônicos têm ainda pintura diferente da ilustração do alvo, diferença que não deve ser corrigida recolorindo os arquivos originais.

Amostrando apenas o preenchimento ciano em recortes correspondentes, o antes já tinha mediana aproximada RGB53,176,183 e saturação HSV0,741, contra RGB43,156,156 e0,718 na referência. A impressão de menor vivacidade não era falta de saturação desse preenchimento. As amostras são locais, com compressão e iluminação diferentes, e não descrevem a imagem inteira. A medição e os recortes estão no JSON de análise.

Os [valores regionais de luminância](hud-target/color_analysis.json) são apenas descritivos: a referência já tem HUD, a captura limpa não, e os desenhos diferem. Eles não permitem atribuir uma porcentagem de saturação ao jogo. A revisão aplica uma sombra inferior gradual de até24% somente entre y796 e1080, preservando os detalhes e as cores do cenário acima. O preenchimento ganha reflexo superior e sombra na base; a moldura da Vida recupera material e volume, em vez de apenas uma linha fina.

### Medidas atualizadas

- **Vida no mundo:** canvas200×44 e9-slice20/12/20/12 mantidos; conteúdo útil14,5,172,34; faixa dinâmica172×12 em x+14,y+5. Valor24px Normal/31px Maior, em x+14,y+17,172×24. O valor continua acima de18px na base. Ciano/vermelho ou azul/laranja; aba aliada e corte inimigo preservados. Os cantos do ator agora acompanham o chanfro.
- **Retrato de Nick:** mantém184×184 em76,848. Recorte no original256×256: **40,14–208,182**, sem esticar nem alterar o arquivo. Centro óptico da cabeça usado como referência:124,98, mapeado próximo de168,940. O enquadramento continua fechado, com o rosto no centro do quadrado.
- **Ícones das ações:** alfa recortado antes de encaixar numa área44×44 em x+42,y+24. Centro óptico64,46 dentro do botão128×100; ligeiramente acima do centro geométrico para compensar a aba de tecla inferior. Mesmo centro para os quatro símbolos, sem depender das margens transparentes do SVG/WebP. As teclas continuam42×42 em x+78,y+54. Centros medidos em `checks.json`.

### Ordem das camadas do anel e luz de retorno

1. Sombra de contato estreita sob os pés, com queda suave.
2. Luz âmbar difusa no piso: elipse centrada em768,756, raios visuais142×34; intensidade máxima de composição28%, excluindo o alfa do personagem.
3. Anel248×64 em644,724, com núcleo claro e halo. Oclusão pelo alfa do sprite inteiro; retirado o corte retangular que ignorava a cauda.
4. Personagem acima do anel. Luz de retorno quente, localizada nas botas, pernas e cauda próximas ao piso; máximo23% na prova, sem pintar os pixels do sprite original.
5. Barras e HUD por cima da cena.

A composição congelada usa o sprite canônico projetado264×300 em659,467 para obter a máscara; são medidas desta captura. **Na implementação, usar a projeção real da câmera, depth test e materiais que recebam iluminação.** Um WebP emissivo sozinho não ilumina o mapa ou o personagem: é preciso uma luz local/recepção de luz equivalente, com alcance curto e sem pulso quando reduzir efeitos estiver ativo. Não usar a máscara congelada ou as intensidades em pixels como regra do combate. A prova é uma direção visual para o Claude na #60, não uma captura de iluminação dinâmica já implementada.

### QA deste ciclo

**Rodada1 — VEREDITO: REPROVADO.** Média: Vida com bisel muito fino e cantos de seleção quadrados; ícones alinhados pelo canvas e margens desiguais; máscara retangular do anel ignorava cauda e não demonstrava retorno de luz. Corrigidos com nova base sem texto, chanfros, recorte pelo alfa e composição em camadas. Média: primeiro deslocamento do retrato desceu demais a cabeça; recorte ajustado pelo centro óptico sem mudar a escala.

**Rodada2 — VEREDITO: APROVADO.** Conferidos os quatro perfis, cinza,40%, matriz peça a peça e prova de alinhamento. Vida recupera bisel e rebaixo, mantém diferenças de forma no daltonismo; retrato mantém escala e centraliza a cabeça; os quatro símbolos usam o mesmo centro óptico; anel tem oclusão completa e luz quente localizada na prova. Nenhuma alteração nos ícones originais do Nick, ids, scripts, data ou tests. A iluminação dinâmica e a oclusão em movimento ficam para a QA da integração.

## Validação desta revisão e pendência para integração

Auditoria de design aprovada:18 WebP, quatro perfis,9-slice/OFL/hashes, limites, centros dos símbolos, ícones canônicos e diff --check. Godot4.7.2 importou os arquivos. Duas execuções normais completas ficaram em **45/46** (257,167s e256,475s): somente `test_occlusion`, na verificação “o caixote na frente esmaece (0.60)”. A paridade passou48/48 (3351 passos). O teste de oclusão passou isoladamente,33 verificações em7,309s.

A espera em tests/test_occlusion.gd aceita `crate.transparency >= FADED - 0.001`, mas a asserção seguinte usa `is_equal_approx` com tolerância mais estrita. Ela pode prosseguir antes de alcançar o valor final. Diagnósticos com relógio fixo e limite de quadros afetaram testes de tempo real/jornada e foram interrompidos; não contam como validação aprovada. Persistem avisos/erros de recursos/RID/ObjectDB ao encerrar o runner.

**Pendência de teste registrada para o Claude; a bateria completa não ficou verde nesta revisão.** Scripts/data/tests não foram alterados, conforme o escopo autorizado, e o kit de combate desta proposta ainda não é carregado pelos scripts do jogo. O veredito APROVADO acima é da entrega de design, não da integração ou do runner completo.
