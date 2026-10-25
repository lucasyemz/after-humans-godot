# QA de design — #58

Persona: QA de design, avaliando a proposta como revisão independente do desenho, com o checklist de [qa.md](../qa.md). São pranchas estáticas para o Lucas aprovar; não certificam a integração que o Claude ainda fará.

## Rodada1 — VEREDITO: REPROVADO

| Arquivo/área | Problema | Gravidade | Sugestão e correção |
|---|---|---|---|
| `ui-kit/contract.json`, placas/fichas/botões/ordem | As medidas compactas usadas no rascunho ainda não estavam no contrato | Alta | Registrar variantes nas famílias existentes, aprovar a prancha do kit e só então remontar as telas. Feito em8325ca7, antes da montagem corrigida; nenhuma textura nova |
| `combat-area-target_large.png`, dica | O painel cobria o herói atual | Média | Mudar o lado conforme o ator; largura480 Normal/640 Maior e definição longa no detalhe18/23. Ator e alvo ficam visíveis |
| `counts.json`, mapa | A árvore de Controls incluía textos da Estação encobertos pelo fundo opaco do mapa | Alta | Excluir a camada encoberta e revisar os recortes visualmente; exclusões guardam caminho, texto e motivo |
| `station-train_large.png` | Pedido encobria o rosto de Dora | Média | Painel de pedido448×352 na área livre à esquerda; rosto e corpo livres |

## Rodada2 — VEREDITO: REPROVADO

| Arquivo/área | Problema | Gravidade | Sugestão e correção |
|---|---|---|---|
| `explore-resources-focus*.png` | Resumo de comida ainda usava10%, regra da fogueira | Alta | Separar regras: Mochila15%/35% por1/3 comidas; fogueira10% e−5 instinto. Conferido contra `exploration_care.gd` e HUD atual |
| `combat-inventory*.png` | O detalhe podia conservar Bento enquanto outro herói agia | Alta | Derivar aliado e vida do ator atual da captura; Maior agora mostra Íris23/23, coerente com a barra |
| `options-*.png` e entradas de Opções | Categoria Jogo sem entrada própria na lista | Média | Quatro categorias iguais em todas as entradas: Som, Imagem, Jogo e Acessibilidade; dicas e idioma mantidos |
| `station-map*.png` | Layout preliminar não preservava as coordenadas lógicas dos nós | Média | Projetar as coordenadas existentes em1100×660; deslocar só etiqueta e ligar ao ponto. Posições conferidas com `journey_rules.gd` |
| Textos com setas; prancha compacta | A fonte exportada não possui alguns glifos usados nas anotações | Média | Empregar palavras/ASCII ou os SVG; checagem de glifos sem faltas na versão final |
| `explore-touch*.png` | Alvos88px ficavam35,2px na redução a40% | Média | Alvos e retratos de toque112×112, passo128, ícones48;44,8px a40%. Variante registrada no botão do kit |
| `station-depot*.png` | Notas de estoque próximas demais da última ficha | Média | Separar fichas, relíquias, ferramentas e custo, mantendo o custo junto da decisão |

## Rodada3 — VEREDITO: APROVADO

Sem problema alto ou médio restante na proposta. Conferidos:

- 54 telas/estados, **216 PNG1920×1080**, quatro perfis: Normal, Maior, daltonismo e Maior com daltonismo.41 capturas reais por tamanho,82 hashes de PNG originais verificados. Há cinza e redução real a40% de cada tela.
- Pranchas de título/campanhas/confirmação, oito cômodos, Plano, trem, Preparação, mapa, rua/interior/busca/achado, risco, evento da rua e do Abrigo, fogueira, Mochila nos dois contextos, luta/mira única/mira com vizinho/crise/resultado, relatório, noite, Opções e toque.
- Inspeção visual da galeria Maior, das pranchas críticas completas e da comparação com o antes; conferência dos estados de foco, escolha, bloqueio, alerta e alvo. Daltonismo e cinza da mira conservam “Alvo”, marca e “Também atingido”, sem depender da luz vermelha/laranja.
- Molduras, fontes e arte existentes; 9-slice16; somente as famílias do kit #59. Variantes compactas contratadas antes da montagem corrigida. Nenhuma arte de produção nova ou personagem regenerado.
- Fontes mínimas18px; nenhum glifo faltante, texto fora da tela ou interseção de textos na conferência geométrica dos216 perfis. Cabeçalhos e custos continuam legíveis no Maior. No40%, verificadas formas, hierarquia e alvos de toque44,8px; detalhes permanecem acessíveis no foco e com o texto ampliado.
- Contagem manual das duas vistas fixas comparada ao registro: exploração25→1 textos,19→4 números; combate43→6 textos,33→11 números. A meta de metade é atingida separadamente para textos e números, em Normal e Maior. Detalhes estão em estados próprios, sem omitir a regra da decisão.
- As capturas são identificadas por commit. O candidato, a crise, o resultado e a casa liberada estão declarados como estados preparados para captura; não fingem comprovar uma campanha jogada completa.

Evidência geométrica, glifos, dimensões, cobertura e hashes das pranchas: [checks.json](checks.json). Dados da contagem, coordenadas de cada bloco desenhado e exclusões de visibilidade: [counts.json](counts.json). A alfa é a dos assets existentes; PNG desta pasta é documentação opaca, não textura de runtime.

## Validação e versão

Godot4.7.2, após sincronizar com `main`4f5e811: **43/43 testes**, paridade **48/48**, saída0,240,2s. Persistem avisos de recursos/ObjectDB/RID no encerramento; nenhum código foi alterado para tratá-los. A rodada anterior, na base das capturas, também passou40/40 e48/48.

As imagens congelam a interface da basebc81822, com as capturas adicionais de mira/achado eme0c15e9; só documentação mudou entre esses dois commits. A sincronização posterior incorporou o PR85 e a proposta de laço do jogo à base Git, sem reescrever as capturas históricas. Os cartões de passagem e as novas telas do laço não são apresentados aqui como se tivessem sido capturados nesta série; suas entregas continuam nas issues próprias. A integração deve manter essas melhorias ao aplicar a HUD. A cobertura desta entrega é a lista da #58 e seus estados documentados, não as futuras telas da #96.
