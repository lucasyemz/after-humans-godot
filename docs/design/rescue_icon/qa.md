# QA de design — node-rescue (#295)

Uma passada pelo checklist de `docs/design/qa.md`, pela segunda persona da sessão, sem subagente. Não substitui o aceite artístico do Lucas pela prancha.

## Rodada 1 — VEREDITO: APROVADO

- **Direção:** a mão aberta erguida representa pedido de ajuda sem copiar outra interface. Silhueta branca de recorte firme, coerente com os `node-*` do kit; não parece espada, caixa de busca, fogueira ou bilhete. O aço/envelhecimento permanecem na moldura existente, sem textura fina no glyph que prejudique a leitura.
- **Tamanho e cor:** conferidas amostras reais a 22/26/30/32/64 px, em fundo escuro e claro. Comparação com os ícones de combate, suprimentos, descanso e evento. Mantém identificação em cinza e nas tintas do modo daltonismo. A prancha inclui ainda a amostra `#d55e00` do checklist.
- **Estados:** conhecido, atual, resolvido e pino de alerta usam um só arquivo tingível e os tokens existentes. Moldura/check seguem o kit, sem depender só de cor. Desconhecido conserva `?`, conforme a regra existente; o ícone não determina descoberta de resgate.
- **Arquivo/medidas:** PNG 128×128, WebP 64×64, âncoras de centro documentadas, sem 9-slice. RGB branco onde há alfa, RGB zero onde alfa é zero; um componente no núcleo opaco. Nomes e destino documentados, mantendo `node-rescue` da issue. Reconversão independente do WebP idêntica byte a byte.
- **Prova na Godot:** seis duplas reais na main e2f0b58a: trecho de resgate e pino do mapa, em Normal, Maior e daltonismo. Mesma câmera/elenco/instante por dupla. A auditoria de pixels confirmou **zero mudança fora do retângulo do glyph** em todos os seis casos. As referências de antes são `node-loot` no trecho e `alert` no pino; no depois só a textura foi substituída.
- **40%:** a localização do resgate e a hierarquia da tela continuam compreensíveis; o mapa mantém o rótulo “Resgatar Véspera”. A redução da tela inteira não promete ler todas as notas nem os dedos individualmente. A legibilidade própria do desenho é conferida nas amostras nativas de 22/32 px.
- **Narrativa/escopo:** representa o resgate já existente da #188, sem acrescentar mecânica, espécie, arma ou informação de lore. PR somente com pranchas/documentação. Fontes e receitas fora da main, em tag independente. Nenhum arquivo de código, dado ou teste alterado.

Sem problemas altos ou médios. Observação baixa: as provas são Compatibility/CPU, sem GPU física; a conferência de integração e do renderizador final pertence ao Claude 2/Lucas.

Validação da base e2f0b58a: **115/115 testes**, paridade **48/48**, 809,604 s, saída 0.
