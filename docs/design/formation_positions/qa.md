# QA de design — posições do kit (#260)

Checklist: [QA de design](../qa.md). Avaliação em segunda persona da mesma sessão, sem subagente; não substitui a aprovação do Lucas. Protótipo documental, sem integração ou alteração de regras.

## Rodada 1 — VEREDITO: REPROVADO

- **Média — `capture_proposal.gd`, células e matriz no Maior:** o conteúdo recebia os recuos do PanelContainer e mais o deslocamento manual; estados saíam das células e notas invadiam a coluna vizinha. Correção: usar o StyleBox do componente em Panel com composição explícita, sem duplicar margem.
- **Baixa — matriz de origens:** `JSON` fornece números em ponto flutuante e os rótulos apareciam como `3.0 · 4.0`. Correção: formatar os ranks como inteiros.

## Rodada 2 — VEREDITO: REPROVADO

- **Média — ficha Normal/Maior/daltonismo:** a nota sobre deslocamento ainda conservava largura mínima anterior à ativação da quebra de linha (696 em vez de 580 px). Ela invadia a matriz. Correção: fixar o retângulo do Label depois de aplicar fonte e autowrap, não antes.
- **Média — células no Maior:** o tamanho real das linhas excedia os retângulos reservados, embora os caracteres ainda fossem reconhecíveis. Correção: célula de 128 px, linhas de 36/52/34 px, espaçamento e nome do personagem ampliados; a fonte permanece a 130%.
- **Baixa — nota do exemplo hipotético no Maior:** duas linhas precisavam de 79 px, mas havia 68. Correção: reservar 86 px e reposicionar a nota sem encobrir a orientação anterior.

## Rodada 3 — VEREDITO: REPROVADO

- **Alta — disposição dos textos:** ao mudar a ordem de aplicação de largura e quebra de linha, a posição final de alguns Labels se deslocou. Capturas não publicáveis. Correção: criar o rótulo vazio, configurar a fonte e a quebra, atribuir o texto e o tamanho e, por último, fixar a posição.
- **Média — tamanho declarado versus tamanho efetivo:** `label_px` adiciona 2 px como adaptação de telas antigas. Isso fazia as fontes maiores que o dimensionamento especificado. Correção: manter `AHKit.label`, a Barlow e as cores do kit e aplicar o tamanho documentado através de `AHUiStyle.px`, sem a adaptação legada.

## Rodada 4 — VEREDITO: APROVADO

A composição final reaplica tamanho e posição após a atualização diferida da quebra de linha. A captura recusa salvar uma vista se algum rótulo exceder seu retângulo ou se deslocar. Conferidos **411 rótulos em nove vistas**, sem problemas de tamanho/posição. As imagens finais substituem integralmente as capturas reprovadas; não há capturas reprovadas no PR.

- **Direção:** todas as molduras, retratos e fontes vêm do kit e da arte existentes. Aço/chanfro/canto âmbar preservados. Não há ícones novos; conferência de ícone 22/32 px não se aplica.
- **Leitura:** Normal, Maior 130%, daltonismo e três vistas em cinza. A 40%, nomes, contagens e destaque continuam distinguíveis; notas pequenas exigem ampliar. Isso é uma observação baixa e não prova responsividade final para celular, que ainda precisa de rolagem e alvos de toque na integração.
- **Contraste:** contra a base `#0d1012`, texto do kit 15,42:1, texto secundário 7,53:1, bom 9,18:1 / 8,27:1 no daltonismo, alerta 5,21:1 / 6,36:1. Cálculo de referência sobre a base sólida, complementado pela inspeção das capturas reais sobre a textura; não é uma medição de cada pixel do material.
- **Sem depender de cor:** contagem, REC./POSSÍVEL/SEM OPÇÃO e moldura mantidas em cinza. Origem separada de alvo; estado sem opção separado de recarga/falta de alvo/impedimento por estado.
- **Coerência:** seis classes e 24 habilidades conferidas contra a main atual. Exemplos de edição com três/uma habilidades identificados como simulações, não novos loadouts permitidos. Não há kit completo atual com origem vazia.
- **Medidas:** canvas, retângulos, células de 128 px, fontes, orientação 4–3–2–1 e margens de 9-slice documentados. Sem sprite novo/âncora de pé.
- **Arquivo/escopo:** 16 WebP de revisão, nomes em inglês/snake_case; PNG fora do Git. Texto nas imagens é captura documental, nunca textura a integrar. Somente `docs/`; nenhuma mudança em scripts, dados, testes, ferramentas ou arte de produção.
- **Provas:** antes/depois com a Sala real da Godot e modal do kit na mesma cena; CPU/Compatibility explicitados. Capturas não alegam integração funcional na partida nem aceite de luz Forward+.
- **Validação da base:** `tests/run_all.gd`: **100/100**, em 694,373 s; paridade **48/48**. O resultado é da base sem alterações de produção. O protótipo tem auditoria de layout própria em `capture_audit.json`.

Sem problemas altos ou médios pendentes. Aprovação de produto/regra ainda cabe ao Lucas, especialmente local inicial e critério de recomendação, com o contrato de habilidades da #259.
