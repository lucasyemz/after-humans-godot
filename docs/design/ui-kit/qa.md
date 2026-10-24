# QA de design — kit único #59

Avaliação com a segunda persona de QA de design, na mesma sessão, após produzir as pranchas; checklist de `../qa.md` e critérios extras da issue. Não é revisão de implementação nem aprovação visual do Lucas.

## Rodada 1 — VEREDITO: REPROVADO

| Arquivo | Problema | Gravidade | Sugestão e correção aplicada |
|---|---|---|---|
| `states_03_*.png` | Alerta da placa disputava o slot da intenção com outro símbolo sobreposto | Média | Um slot só; alerta substitui o glifo e a dica deve preservar as duas informações. Ajustado em todos os perfis |
| `states_04_*.png`, `feedback_*.png` | Losango e riscos da sequência ficavam longe do nó; foco cercava a sequência inteira; abas aparentavam mudar todas de estado | Média | Prender as marcas ao nó/linha pertinente. Ajustado o foco, a escolha, o alerta, o desligado e a aplicação da pele |
| `variants_*.png` | Retrato de herói pequeno demais no slot, apesar da especificação de64px | Média | Usar retrato64 e preservar slot64 também para glifo centralizado. Corrigido, sem trocar o PNG de origem |
| `anatomy_large.png`, `unity_large*.png`, `states_04_large*.png` | Exemplos Maior ainda conservavam altura de cartão/nó do Normal; botão no rodapé tocava a borda inferior | Média | Aplicar cartão208, nó80 e manter inset inferior24; ajustar botão de fechar para80. Corrigido |
| `states_02_*.png` | Hover da ficha visualmente igual ao normal | Média | Reusar pele hover existente mantendo anatomia; corrigido |
| `render.py`, `../ui-kit.md` | Entrelinhas e contraste citados inicialmente não batiam exatamente com o desenho/medição | Média | Fixar as entrelinhas pelos três papéis e recalcular contraste sRGB; contrato e documento alinhados |

## Rodada 2 — VEREDITO: APROVADO

Conferência após as correções:

- Direção: metal envelhecido e filete da #20 preservados; fontes reais do repositório; ícones e retratos aprovados, sem nova linguagem flat para substituir a arte.
- Unidade: as mesmas funções de desenho compõem painel, botão, placa e cartão nos quatro contextos da prancha `unity_*`. Cartão de habilidade/item/cômodo/fase/herói compartilha anatomia. Abas, listas e confirmação são composições, não estilos concorrentes.
- Medidas: contrato de12 componentes, anatomia, origem, ancoragem, padding, 9-slice, tipo, movimento e uso/não uso documentados. Os exemplos compactos de matriz são identificados como amostras e não como mínimos de produção.
- Estados: sete situações examinadas por família; não aplicáveis estão explícitos. Foco não seleciona; seleção não confirma; mira atua sobre o corpo. Desligado/alerta têm sinais de forma e explicação, sem depender da cor.
- Acessibilidade: quatro perfis por família (Normal, Maior, daltonismo, Maior+daltonismo), além da escala intermediária especificada. Bom/perigo trocam por azul/laranja; texto e estrutura permanecem. Ícones rasterizados de verdade a22/32 e em cinza; unidade em cinza e a40%. Rótulos não são encolhidos para caber. Os alvos físicos no celular e a adaptação do layout são requisitos da integração, não provados por uma imagem a40%.
- Contraste: texto14,442:1 e secundário6,514:1 sobre superfície opaca; sem transparência necessária para ler. Modo daltonismo não é declarado simulação clínica.
- Arquivos: 47 PNG (43 de1920×1080 e4 de768×432), índice e links locais conferidos; sem arte runtime nova, sem texto gravado em textura do jogo. `docs/.gdignore` mantém tudo fora do pacote.
- Escopo: só `docs/design/ui-kit.md` e `docs/design/ui-kit/`; nenhum arquivo em scripts/,data/,tests/, nenhum id alterado.

Resoluções: **43 PNG de1920×1080 e4 reduções de768×432**, total47. As quatro versões cinza continuam em1920×1080. Fonte mínima18, sem texto fora do canvas pelo relatório `render_checks.json`. A checagem de canvas não substitui a inspeção visual de sobreposições feita nas pranchas.

Sem problema alto ou médio restante. Observações baixas: as matrizes usam conteúdo curto de demonstração; textos longos/localização exigem altura dinâmica como documentado. O exemplo de alvo usa Íris como manequim e não implica mudar sua facção. O teste final de teclado/controle/toque, foco em scroll e sobreposição no cenário depende de código na #60 e das telas da #58.

## Validação técnica

Godot4.7.2, base `fceda77`: após importar o checkout atualizado com `--headless --editor --import`, `tests/run_all.gd` concluiu **34/34**, paridade **48/48**, saída0, 93,6s. A primeira tentativa com cache anterior falhou por classes e áudio novos ainda não importados; a importação resolveu essa falha sem editar código. O log final ainda traz erros diferidos `_restyle` e avisos de recursos/RIDs no encerramento, também observados nas rodadas anteriores; não são ocultados como log limpo.

Captura auxiliar de13 telas atuais por `tools/capture_ui.gd`, em1920×1080, cenário real e campanha isolada em pasta temporária; saída0. Usada como referência da linguagem existente, não como entrega da #58 nem como captura da implementação deste kit. O ambiente sem áudio físico usou driver dummy; houve avisos de recursos no encerramento. Nada gravado no perfil do jogador. Não houve alteração da rua, portanto não foi necessário teste de colisão de rua para este PR de documentação.

Próximo marco: Lucas aprova o PR da #59; depois a #58 compõe telas só com o kit aprovado. Componente ausente numa tela entra primeiro neste contrato e passa por QA antes de ser usado.
