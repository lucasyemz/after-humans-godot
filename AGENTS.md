# AGENTS.md: como trabalhar neste repositório

Guia para agentes (Codex, Claude e outros) e para quem chega ao projeto. Vale para todo este repositório
(`lucasyemz/after-humans-godot`).

## Projeto

After Humans na Godot 4.7.2 (GDScript). Os comandos, a estrutura e os controles estão no [README](README.md).

A pasta acima deste repositório é o projeto Unreal antigo. Ele serve só como **referência** para portar regras, dados e
arte. Nada daqui depende dele em tempo de execução, e nada de lá entra neste Git.

## Regras

- **Leveza:** entra no Git só o que o jogo usa. A arte de origem pesada (PSD, FBX, PNG não usados), os `.uasset`, os
  builds (`build/`) e o cache (`.godot/`) ficam fora.
- **Arte e som do combate:** entram por `tools/sync_combat_art.py`, que converte para WebP na metade da resolução e
  mede a âncora no pé em `data/presentation/combat_art.json`. Personagem novo entra na tabela da ferramenta, nunca
  copiado à mão.
- **Dados:** os JSON em `data/` são a fonte de produção. Ao portar uma regra da Unreal, traga junto um teste que compare
  com o comportamento de lá, como `tests/test_combat_parity.gd` faz com o combate.
- **Nomes:** pastas, cenas, scripts e shaders em inglês e `snake_case`. A arte mantém o nome que tem na origem
  (`grocery-v1.webp`). Ids de dados e saves (`cao`, `hero_cao_bento`…) nunca mudam. O jogo e os textos de tela são em
  português.
- **Antes de commitar:** `tests/run_all.gd` precisa passar inteiro (inclui a paridade 48/48 e o save). Se mexeu na rua,
  rode também o modo de captura, que inclui o teste de colisão.
- **Estrutura do código:** os autoloads `GameData` (tabelas), `Campaign` (estado e save) e `GameFlow` (troca de cenas)
  são o ponto de entrada de cada sistema. Cena nova entra pelo id em `GameFlow.SCENES`, e as teclas entram como ações em
  `tools/define_input.gd`, sem tecla fixa no código.
- **QA em Play:** o Lucas joga e faz a QA. A automação roda sem janela (`--headless`) ou no modo de captura.
- **Git:** commit e push só quando pedido.

## Narrativa e coerência visual

- **Narrativa:** todo texto, evento, nome, lugar, item, inimigo e descrição de fase tem que fazer sentido na história. A
  base está em [docs/narrative/](docs/narrative/README.md) (lore, design narrativo, arco dos fundadores e progressão).
  Antes de escrever ou mudar um texto, passar pela regra de consistência (`narrative-design.md`, seção 14). Na dúvida,
  perguntar ao Lucas numa issue em vez de inventar.
- **Coerência visual:** nada de peça sem textura, personagem fora do cenário, animação fora do tempo ou HUD diferente
  em cada tela. Toda entrega que mexe no que se vê traz capturas de antes e depois, e a QA confere esses pontos.

## Ciclo dev e QA

Cada issue passa por duas personas antes de chegar ao Lucas:
- **Desenvolvedor sênior** (a sessão principal): implementa, roda `tests/run_all.gd` e entrega para a QA a issue, os
  commits e como testou.
- **QA sênior** (o agente `qa`, em `.claude/agents/qa.md`): avalia a entrega, tenta quebrar com scripts próprios numa
  pasta temporária e devolve `VEREDITO: APROVADO` ou `VEREDITO: REPROVADO` com os bugs (onde, como reproduzir,
  gravidade).
- Reprovado, o desenvolvedor corrige e manda de novo para a QA, até aprovar. O comentário da issue registra as rodadas
  (o que a QA achou e como foi corrigido). A QA não altera o código do jogo; o Lucas fecha a issue depois de jogar.

## Ciclo design e QA de design (Codex)

O Codex cuida de UI/UX e design gráfico (imagens, ícones, molduras, propostas de tela), no branch `codex-design`, sem
mexer em código. Cada entrega passa por duas personas:
- **Designer** (o Codex): faz a entrega e passa para a QA de design.
- **QA de design**: avalia com o checklist de [docs/design/qa.md](docs/design/qa.md) e devolve `VEREDITO: APROVADO` ou
  `VEREDITO: REPROVADO` com os problemas por gravidade. Reprovado, o designer corrige e manda de novo, até aprovar.
- Aprovado, o PR do `codex-design` para a `main` registra as rodadas; o Claude integra no jogo e a QA dele testa lá.
