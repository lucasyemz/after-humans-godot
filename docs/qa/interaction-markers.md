# O indicador de interação em todos os mapas (#142)

A marca de interação (o losango sobre o que se usa) agora aparece do mesmo jeito em todos os mapas: na Rua das
Vitrines, nos seis cenários, nos interiores laterais e nas casas.

![Antes (só o aviso da vez) e depois (as marcas de tudo o que está ao alcance na zona)](interaction-markers/before_after.jpg)

## O que muda

- **O ponto da marca** de cada prop dos cenários fica em cima do desenho dele (`AHScenarioWorld.prop_marker_point`),
  e não no piso.
- **Tudo ao alcance já tem a marca:** antes, nos cenários, um objeto só ganhava a marca quando a equipe pisava no
  trecho dele. Agora, com o caminho livre (nenhuma patrulha de pé no meio), o que está na zona já aparece marcado.
  Vasculhado, sai das marcas.
- **Os interiores laterais** ganharam as marcas dos props e da porta de volta, como no corredor; a fogueira e a porta
  das lojas nas casas também.
- **A saída para a Estação** tem a marca no começo do mapa da fase.

## Testes

- `tests/run_all.gd`: 64 de 64, com a paridade 48/48.
- `tests/test_interaction_markers.gd` (novo, 91 verificações): os seis cenários pela cena de verdade, com a equipe ao
  lado de cada prop, de cada porta de interior e da saída; o que está à frente marcado de longe; o vasculhado sem marca.
- A captura da rua (`-- --capture=`), com a colisão: `08-collision-car` e `09-collision-facade` PASS.
