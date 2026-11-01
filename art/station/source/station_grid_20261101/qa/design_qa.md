# QA de design — cartões soterrados (#275)

Checklist: [QA de design](../qa.md). Segunda persona da mesma sessão, sem subagente. Esta avaliação não substitui o aceite artístico do Lucas nem a QA da integração do Claude 1.

## Rodada 1 — VEREDITO: REPROVADO

- **Alta — `overturned_wagon`:** a primeira versão parecia um vagão só descarrilado. Refeito com o trecho tombado de lado e o rodado levantado; mantém escala de uma seção de veículo.
- **Média — máscaras de ícones:** a folha gerada tinha halo residual e transparências inadequadas para tingimento. Nova geração e conversão das silhuetas em máscaras brancas, com recorte de alfa e antialias na redução; brutos mantidos fora da main para rastrear a correção.
- **Alta — protótipo da grade:** a camada inicial ficava sob o pós-processamento do mundo, produzindo aberração cromática/desfoque na UI. Movida para a camada da HUD (2), depois do pós (1), sem alterar a luz/ambiente de produção.

## Rodada 2 — VEREDITO: REPROVADO

- **Alta — imagens no Maior:** atualização diferida do tamanho dos TextureRects conservava dimensões/posições anteriores e ocultava pinturas e prévias. Corrigidas criação e ordem de aplicação dos retângulos, com reaplicação após o layout e auditoria de cada imagem, além dos textos.
- **Média — proporção do cartão:** o recuo igual em x/y alterava ligeiramente o aspecto da pintura ao reduzir a vaga projetada. Trocado por redução uniforme, conservando a proporção do volume de 6 × 3,2 m.

## Rodada 3 — VEREDITO: APROVADO com observações baixas

Pinturas, alfa, estados, narrativa e retângulos aprovados. Duas observações de acabamento foram corrigidas antes de publicar:

- Concordância de “1 sucata” e “1 volta”, eliminando `volta(s)` na tela.
- Uso explícito do token `ON_AMBER` e do novo ícone de escavar na ação principal, para não deixar tinta clara sobre âmbar.

## Rodada 4 — VEREDITO: APROVADO

Conferidas as 21 pranchas finais: seis pinturas distintas, três estados sobre a mesma cena, cartão de cômodo, marca da obra e máscaras legíveis a 22/32 px. Conferidos os estados Normal, Maior e daltonismo em nove capturas, com 16 vagas por vista. Auditoria sem problemas: 339 rótulos e 312 retângulos de imagem dentro das áreas esperadas; custos, recompensas e razões de bloqueio correspondem ao estado real usado na prova.

Os 14 PNG normalizados têm canvas, âncora, alfa e margens documentados. Transparência sem RGB residual; máscaras brancas para tingimento; centros das molduras transparentes. Conversão independente dos 14 WebP idêntica byte a byte. O pacote preserva 24 PNG incluindo brutos e revisões, fora da main.

Passagem narrativa pela §14 concluída sem acrescentar poder, recompensa, facção ou mistério. Vagão tombado, máquina inerte, cabos sem energia, água não potável e raízes naturais.

Suíte da base: 104/104, paridade 48/48, 682,991 s. A prova usa Compatibility por CPU; não atesta Forward+ no PC nem a integração do PR #284. A redução a 40% aprova identificação das imagens e estados; texto longo continua dependendo do detalhe ampliado. Sem bloqueios de design nesta entrega.
