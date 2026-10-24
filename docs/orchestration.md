# Orquestração: como o Lucas toca os agentes

Guia para continuar de qualquer máquina (Windows ou MacBook). O Lucas orquestra; o trabalho fica com os agentes na
nuvem. O Claude local (esta conversa, ou uma nova) revisa e integra os PRs.

## Quem faz o quê

| Agente | Branch | Faz | Ciclo |
|---|---|---|---|
| Claude da nuvem | `claude-cloud` | código, regras, integração, testes (issues `[Claude]`) | dev → QA (`.claude/agents/qa.md`) até APROVADO |
| Codex | `codex-design` | imagens e propostas de tela (issues `[Codex]`) | designer → QA de design (`docs/design/qa.md`) |
| Claude local | `main` | revisa, faz o merge, integra a arte do Codex e atualiza os branches | QA local antes do push |

Issues: `[Agente] Área: descrição`, etiquetas `agent:claude` ou `agent:codex` e o tipo; as de decisão do Lucas levam
`question`. Só o Lucas fecha uma issue, depois de jogar.

## Montar o MacBook (uma vez)

```bash
git clone https://github.com/lucasyemz/after-humans-godot.git
cd after-humans-godot
```

- Godot 4.7.2 para macOS (godotengine.org ou o GitHub `godotengine/godot-builds`, tag `4.7.2-stable`). O executável
  fica em `/Applications/Godot.app/Contents/MacOS/Godot`.
- `gh auth login` (GitHub CLI) e `pip3 install pillow soundfile`.
- Importar uma vez: `Godot --headless --path . --import`.
- Testes: `Godot --headless --path . -s tests/run_all.gd` (25 de 25, paridade 48/48).
- Captura da rua: `Godot --path . --resolution 1920x1080 -- --capture=/tmp/cap`. Do título: `-- --capture-title=/tmp/t`.
- Saves e opções do jogo no Mac: `~/Library/Application Support/Godot/app_userdata/After Humans`. As automações não
  gravam ali (conferir as datas antes e depois).
- A pasta da Unreal não está no Mac: `tools/sync_assets.py`, `sync_audio.py`, `unreal_export_*.py` e a parte da
  `sync_combat_art.py` que lê `SourceArt` só rodam no Windows. No Mac, a arte do Codex entra pelos WebP já convertidos.

## Rodada de um agente

Mandar na sessão do agente (a que já existe; não abrir duas no mesmo branch):

```
Nova rodada: git fetch origin && git checkout <branch> && git pull --ff-only origin <branch>.
Faça as issues #A, #B… nessa ordem, com o mesmo ciclo de sempre (QA até APROVADO, push no <branch>,
comentário em cada issue e um PR para a main no fim). Leia cada uma com "gh issue view N --comments".
```

## Integrar um PR (o Claude local faz; o Lucas pede "revisa e faz o merge do PR #N")

1. `git fetch origin`; ler o PR (`gh pr view N`), os commits e o CI (o workflow `tests.yml` roda em todo PR).
2. Conferir o escopo: o Codex não mexe em `scripts/`, `data/`, `tests/`; nada de PNG pesado fora de pasta com
   `.gdignore`; `docs/` não entra no pacote.
3. Merge na `main` local; resolver conflito mantendo os dois lados; testes inteiros; captura da rua e da luta (e do
   título, se mexeu).
4. Arte pesada do Codex: guardar o original numa tag (`codex-prN-originals`), deixar na `main` só o que o jogo usa.
5. Passar pela QA (agente `qa`) quando o merge pede código novo; corrigir até APROVADO.
6. Push na `main`, comentário no PR, e `git push origin main:claude-cloud main:codex-design` só quando o agente não
   estiver no meio de uma rodada.

## Revisor dos PRs (terceiro agente)

O workflow `.github/workflows/review.yml` põe um Claude independente para revisar todo PR para a `main` (aberto, saído
de rascunho ou atualizado). Ele usa os critérios das duas QAs e do `AGENTS.md` e responde com um veredito no próprio
PR: PRONTO PARA O MERGE, AJUSTAR ANTES ou NÃO INTEGRAR. Ele só comenta; o merge continua com o Lucas (ou o Claude
local). As instruções ficam em `.github/review-instructions.md`.

Roda pela assinatura do Lucas, sem chave de API: gasta da cota do plano, como as sessões. Para ligar, uma vez só, num
terminal com o `claude`:

```bash
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo lucasyemz/after-humans-godot
```

O revisor não chama agentes: o Lucas manda as correções manualmente para o Codex e para o Claude da nuvem, a partir
do comentário da revisão.

O primeiro comando gera o token da conta; o segundo pede para colar e guarda como segredo do repositório (ninguém mais
vê). Para revisar de novo um PR: em Actions, "Revisão", "Run workflow", com o número do PR.

## Fila de trabalho (24/10/2026)

- **Claude da nuvem:**
  1. #61 (trem fora do tempo);
  2. #62 (paredes sem textura);
  3. #57 (alvo pelo personagem inteiro);
  4. #13 (quedas ajoelhadas);
  5. #63 (varredura visual);
  6. #64 (narrativa);
  7. #35 (inglês);
  8. a parte segura da #56.
  - A #60 (componentes) e o resto da #56 esperam o Lucas aprovar a #59 e a #58.
- **Codex:** #59 (kit de componentes), depois #58 (telas novas montadas com o kit).
- **Regras novas no `AGENTS.md`:** narrativa coerente com `docs/narrative/` e coerência visual, que a QA confere.

## Onde paramos (24/10/2026)

- **Main:** com os PRs #67, #68, #71 e #81 do Claude da nuvem (trem, paredes, quedas ajoelhadas, narrativa, alvo pelo
  corpo, inglês, HUD enxuto em parte, varredura visual e a história nas fases 2, 3 e 5) e os do Codex #65 (kit da
  interface #59, vagão e cartão de passagem #79, descanso dos recrutas #80) e #83 (fundadores sentados no chão #82,
  etiquetas do mapa #69). Testes: 40 de 40, paridade 48/48. `claude-cloud` e `codex-design` iguais à `main`.
- **Issues:** as concluídas foram fechadas em 24/10 a pedido do Lucas (49). Ficaram 24 abertas.
- **Em andamento, não mexer sem olhar antes:**
  - `claude-cloud-passagens`: fluxo A do Claude da nuvem, issues #74 (passagem com título), #75 (partida no vagão) e
    #76 (volta à Estação). Depois vem a #77 (acampamento), que já tem a arte das #80 e #82.
  - `claude-cloud-eventos`: fluxo B, a #78. Os 20 eventos de busca (4 por fase) estão no branch e esperam a aprovação
    do Lucas na issue, junto com a decisão (A) ou (B) sobre os efeitos de fase que não funcionam.
- **A fazer:** #84 (efeitos de impacto e de estados da #41 na luta, a arte já está em `art/combat/effects/`), #72
  (pendências da revisão dos PRs #67, #68 e #71), #70, #66 (segunda parte), #35 (zonas e props em inglês), e a HUD:
  #58 (Codex, telas com o kit), #60 (Claude, biblioteca do kit) e o resto da #56.
- **No PC com a Unreal:** a #73 (referência das passagens, do acampamento e da chegada) é do Claude local.
- **Decisões do Lucas em aberto:** #59 (aprovar o kit), #9 (morte permanente), #11 (Bar e Dormitório), #12 (pacote
  do celular), #78 (textos e efeitos de fase), o cartão de título da passagem (simples ou com mais presença) e as
  propostas do Claude em `docs/narrative/review.md` (nomes de recruta, descrições dos inimigos).
- **Em espera:** #40 (respiração dos heróis), para o Auto Sprite.
- **Formato da arte:** o Codex entrega em WebP, na resolução de uso, com os originais fora do repositório.
- **Decidido:** treinos da Pesquisa valem na luta; dificuldade crescente dentro de cada fase; vilões do John pela
  distribuição dele; quedas da Íris e da Véspera ajoelhadas; o acampamento é dos fundadores, sentados no chão; todas as
  cenas de passagem podem ser puladas; o acampamento funciona como o HUD da luta; 4 eventos de busca por mapa.
- **Só no Windows:** as fontes das poses do John estão em `SourceArt/CharacterGallery/JohnCombatPoses20261022` na
  pasta da Unreal (e na tag `codex-pr46-originals`); o metrô sai de `tools/unreal_export_metro.py`.
