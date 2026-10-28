# O ícone do trem no mapa do tutorial (#147)

![Antes (à esquerda), a casa do trem com a caveira do guardião; depois (à direita), com o trem](train-icon/before_after.png)

Decisão do Lucas (28/10): no mapa do tutorial (o Corredor de Contenção), a casa do trem, no fim da barra de trechos,
mostrava o ícone do guardião. Agora mostra o trem do lobby (`train_arrival`, o do serviço do trem na Estação), um glifo
branco tingido como os outros ícones da exploração: âmbar no trecho de agora, verde quando resolvido, claro à frente.
O guardião continua com a caveira, em alerta até ser vencido.

## Testes

- `tests/test_route_bar.gd`: a casa do trem com o glifo do trem (não o do guardião), no âmbar do trecho de agora e na
  cor dos outros à frente.
- `tools/capture_tutorial.gd` (`12-train-hint`), na `main` de antes e na branch.
