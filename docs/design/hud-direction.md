# Direção de arte da interface: personalidade

Pedido do Lucas (25/10/2026), depois da primeira versão das telas do laço (#96, `docs/design/loop-screens/overview.webp`
no `codex-design`): "muito básico, com cara de feito por IA; quero personalidade". As referências (packs de UI de
fantasia sombria, ícones em losango, runas brilhantes, barras de HUD pintadas, molduras de carta) foram mandadas pelo
Lucas direto ao Codex e não entram neste repositório, que é público.

## O que está errado hoje

- **Tudo é o mesmo retângulo preto com uma linha fina.** A barra do título, o painel, o botão e a dica de teclas têm a
  mesma caixa: não há hierarquia nem forma própria.
- **Cara de aplicativo:** faixas pretas de ponta a ponta em cima e embaixo de toda tela, e painéis grandes que tampam a
  cena com espaço vazio.
- **Informação em planilha:** "Vida 34/34 · Instinto 0/200 · Velocidade 2 · Posição 1" em texto solto, critérios em
  lista com um tique, estrelas minúsculas, barras de XP como linhas brancas.
- **Sem ícones:** quase tudo é palavra. Os poucos ícones são genéricos (seta, escudo, bandeira).
- **Sem material e sem luz:** nada é metal, madeira, papel ou vidro; nada brilha, nada tem sombra ou volume.
- **Sem relação com o mundo:** a mesma interface caberia em qualquer jogo.

## O que as referências têm (e o que pegar de cada uma)

| Referência | Pegar | Não pegar |
|---|---|---|
| Packs de fantasia sombria (molduras douradas, Gothic UI, Dark Fantasy) | Cantos trabalhados, títulos numa plaqueta própria, divisores com ornamento no meio, molduras de tamanhos diferentes para funções diferentes | O ouro limpo de catedral e o gótico religioso |
| Ícones em losango coloridos | Um losango com borda grossa e o símbolo em silhueta chapada, uma cor por família (espécie, estado, recurso) | Copiar os símbolos |
| Runas e faixas brilhantes sobre madeira | O brilho que vaza do traço, os glifos riscados, a textura de madeira por baixo | Runa mágica: aqui não há magia |
| Barras de HUD pintadas (orbes e alça de metal) | Peças com volume e material, o encaixe dos slots numa estrutura, o número da tecla numa moedinha | Os orbes vermelho e azul, o layout de ARPG |
| Cartas com retrato (moldura de metal e vidro, a carta do corvo) | O retrato como protagonista, os números em medalhões nas pontas, as pedras (gemas) como contadores, o nome numa plaqueta | Dinossauro de terno, ficção científica limpa |
| Pack com janelas e árvore de habilidades | Janela com a aba do título saindo da borda, a árvore com conectores de verdade | O fundo de gradiente liso |

## Como fica no After Humans

O mundo é a cidade alagada depois dos humanos: animais que montam a vida com o que sobrou, máquinas velhas da rede
VIGIA, raízes que tomaram tudo e a Estação Raiz como casa. A interface é **feita à mão pelos sobreviventes com sucata**.

- **Materiais:**
  - latão e cobre oxidados (verde-azulado nas bordas), chapa rebitada, parafusos;
  - madeira escura da Estação;
  - papel e tecido gasto para textos longos (briefing, relatório);
  - vidro rachado de tela velha para o que vem da Rede.
- **Raízes como ornamento:** no lugar da filigrana gótica, raízes finas e musgo entram pelos cantos das molduras
  principais. É a assinatura do jogo. Com moderação: só nas peças grandes.
- **Duas luzes, com sentido:**
  - **ciano bioluminescente das raízes** = o que é nosso (a equipe, a Estação, o que se pode fazer);
  - **âmbar e vermelho de LED velho** = a VIGIA e as máquinas (inimigos, perigo, o radar do Mapa da Rede).
  - O brilho vaza do traço como nas runas das referências.
- **Glifos:** os ícones e marcas seguem a linguagem das runas e dos losangos, mas são **marcas riscadas pelos
  sobreviventes** (pata, osso, raiz, engrenagem, gota, chama) e **sinais da VIGIA** (geométricos, de máquina) para o que é
  dela.
- **Losangos por família,** com uma cor cada (vale também no daltonismo, porque o símbolo muda junto):
  - espécies: cão, gato, sapo, coruja;
  - estados: sangrando, atordoado, protegido, crise…;
  - recursos: comida, sucata, sementes, fragmentos.
- **Tipografia:** uma serifada com personalidade nos títulos e nomes (gravada numa plaqueta de metal) e uma sem serifa
  sóbria só no texto corrido. Números importantes (vida, nível, dano) em medalhão, não em texto solto.

## Peças que o kit precisa ter (versão 2 da #59)

1. **Três molduras com papéis diferentes:**
   - grande (janela com a aba do título saindo da borda e raízes nos cantos);
   - média (ficha, carta);
   - pequena (slot, chip).
2. **Plaqueta de título e plaqueta de nome,** em metal, com a ponta recortada.
3. **Botão principal** (chapa com volume, estado de foco brilhando em ciano) e **botão secundário** (mais discreto).
4. **Barras:**
   - vida, instinto e XP com tubo de vidro ou chapa, líquido com cor e brilho e marcações;
   - o instinto ganha cor quente perto da crise.
5. **Medalhão de número** (nível, vida, contagem) e **gemas como contadores** (estrelas, cargas, pontos).
6. **Losango de ícone** em 3 tamanhos, com o conjunto inicial dos glifos.
7. **Divisor** com ornamento no meio, e **conector** para a árvore da Pesquisa.
8. **A carta do personagem:**
   - o retrato grande como na carta do corvo;
   - nome na plaqueta, espécie e papel embaixo;
   - vida e instinto em barras;
   - nível em medalhão;
   - passivos como losangos com o texto ao apontar.
9. **Dica de teclas** em moedinhas de metal (E, Esc, Q…) soltas na borda da tela, sem a faixa preta inteira.

## Regras para não voltar ao básico

- **Nada de faixa de ponta a ponta,** e nenhuma caixa maior que o conteúdo. A cena aparece.
- **Toda informação que pode ser ícone, barra ou medalhão vira ícone, barra ou medalhão.** Texto fica para o que só
  texto explica (passivos, falas).
- **Cada tipo de tela tem a sua forma:**
  - o briefing é papel com o retrato;
  - a ficha é carta;
  - o fim de luta é placa com gemas;
  - a carga são caixas de verdade;
  - a Pesquisa é árvore com conectores;
  - o Mapa da Rede é vidro de terminal âmbar.
- **Antes de montar telas, uma prancha de estilo:** as peças do kit lado a lado, sobre uma captura real da luta, para o
  Lucas aprovar. Só depois as telas.
- **Legível:** texto no mínimo do `AHUiStyle`, contraste, texto Maior e daltonismo continuam valendo. O ornamento nunca
  fica em cima do texto.
