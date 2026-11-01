# QA de design — formação compacta (#260 / PR #283)

Checklist: [QA de design](../qa.md). Segunda persona da mesma sessão, sem subagente. O aceite do Lucas continua pendente. A revisão atual segue as referências enviadas depois da primeira entrega.

## Histórico do primeiro estudo

O estudo anterior de painéis comparativos passou na quarta rodada de QA técnica, depois de correções de margem, ranks decimais, largura, posicionamento diferido e tamanho de fonte. Sua composição foi substituída nesta revisão a pedido do Lucas. As imagens grandes anteriores saem da versão atual do PR; não são a proposta recomendada.

## Revisão compacta — rodada 1 — VEREDITO: REPROVADO

- **Alta — composição da coluna:** substituir a coluna inteira ocultava os retratos do elenco e a ação de Alojamento. A mudança deve ficar no bloco HABILIDADES, sem retirar controles da Sala. Corrigido para `(28,510,540,394)`; personagem central e painel direito preservados.
- **Média — preferência versus origem:** uma legenda geral de alcance poderia fazer os marcadores de preferência parecerem uma restrição de ação. Corrigido com modos e cabeçalhos explícitos: PREFERÊNCIA / ALVOS · ATAQUES no resumo; PARTE DE / ALVO · INIMIGO ou ALIADO no foco.

## Revisão compacta — rodada 2 — VEREDITO: REPROVADO

- **Alta — marcadores de origem/alvo vazios indevidamente:** o JSON chega à Godot com ranks numéricos em ponto flutuante; a consulta ao array sem normalizar tipos falhava e desenhava marcadores vazios para ranks válidos. Corrigido normalizando os ranks para inteiros antes de associar as posições. A auditoria passa a registrar cada marcador e seu preenchimento, além de verificar o layout dos textos.
- **Baixa — encerramento do capturador:** avisos de objetos/recursos no término abrupto. Acrescentados descarregamento da cena, liberação das referências de revisão e encerramento pelo serviço de som; conferir resultado no log final, sem confundir a ferramenta documental com uma mudança no jogo.

## Revisão compacta — rodada 3 — VEREDITO: REPROVADO

- **Média — aviso de recursos no Maior:** o bloco em y=510 preservava o botão de Alojamento, mas cobria seu motivo de indisponibilidade após o crescimento do texto. Corrigido para y=554 no Maior, com altura de 350 px. A ordem das habilidades passa para plaquetas nos próprios ícones, recuperando altura sem diminuir a fonte.
- O preenchimento dos marcadores e a limpeza de recursos no encerramento já ficaram corretos nesta rodada.

## Revisão compacta — rodada 4 — VEREDITO: APROVADO

- **Composição e preservação:** bloco restrito à área de habilidades, com origem adaptativa no Maior. Os pixels da área superior esquerda (retratos, elenco, botão e motivo de Alojamento) são idênticos ao antes em todos os nove casos. Personagem central e navegação preservados. A dica de foco cobre temporariamente a parte inferior da ficha direita, sem cobrir o personagem.
- **Direção:** Barlow, aço, molduras, plaquetas e ícones do kit atual; nenhum material ou personagem novo. Os marcadores compactos seguem a leitura funcional das referências enviadas, no estilo do jogo.
- **Semântica:** 72 marcadores conferidos nos nove casos. Resumo: preferência 1/2 e ataques contra 1/2/3. Impacto: origem 1/2/3/4 e inimigos 1/2/3. Apoio: origem e aliados nas quatro posições. Distinção explícita entre preferência e origem da habilidade.
- **Layout:** 177 rótulos verificados quanto a tamanho e posição, Normal/Maior/daltonismo, sem extrapolações. O foco e as plaquetas dos quatro ícones permanecem centralizados.
- **Leitura e acessibilidade:** preenchimento/vazio, círculos/losangos, números, cabeçalhos e foco mantidos em cinza. Ícones existentes a 80 px dentro de slots de 96; não se introduziram ícones novos de 22/32 px. A 40%, o personagem, os ícones e as formas dos indicadores continuam identificáveis; notas pequenas exigem ampliar. Observação baixa: a captura reduzida não prova a futura UI responsiva/toque.
- **Arquivos e medidas:** 16 WebP, canvas 1920×1080, pranchas de comparação 3840×1140, versões reais a 768×432, cinza e medidas documentadas. Texto nas WebP é captura documental. PNG fora do Git. Nenhuma mudança em scripts/, data/, tests/, tools/ ou art/.
- **Reprodução:** capturador final encerrou com código 0, sem erros de script nem avisos de recursos retidos. O driver registra apenas a indisponibilidade de V-Sync em CPU. Renderer Compatibility/Mesa llvmpipe, sem GPU, explicitado.
- **Validação de produção:** a main permanece no mesmo 31e77ba6. Reaproveitado o resultado 100/100 e paridade 48/48 da rodada anterior, sem alegar novo teste de comportamento do jogo. A revisão documental tem auditoria própria de layout e semântica em capture_audit.json e verification.json.

Sem problemas altos ou médios pendentes. O aceite visual do Lucas e o contrato de seleção/desbloqueio da #259 ainda precedem a integração. Não foram inventadas habilidades extras, cadeados ou custos.
